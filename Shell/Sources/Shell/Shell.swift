import ArgumentParser
import Dependencies
import Foundation
import ShellSyntax
import OSLog

@Observable
@MainActor
public class Shell {
	private let logger: Logger
	
	@ObservationIgnored
	@Dependency(\.date.now) private var now

	let builtins: [String: AsyncParsableCommand.Type] = [
		"cd": CD.self,
	]

	public var workingDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
	public func changeCurrentDirectory(_ url: URL) {
		self.workingDirectory = url
	}

	public var environment: [String: String]

	private var historyDB: Task<HistoryDB, Swift.Error>

	@ObservationIgnored
	public var startProcess: (_ executable: String, _ arguments: [String], _ environment: [String], _ workingDirectory: String) -> Void = { _, _, _, _ in }
	@ObservationIgnored
	public var feed: (_ text: String) -> Void = { _ in }

	public let sessionID = UUID()

	public init() {
		logger = Logger(subsystem: "co.davidbeck.Terminal", category: "driver")
		historyDB = Task { [logger] in
			do {
				let userDataDirectory = URL.homeDirectory
					.appending(component: ".local")
					.appending(component: "share")
					.appending(component: "swish")
				logger.info("creating user data directory at '\(userDataDirectory.path())'")
				try FileManager.default.createDirectory(at: userDataDirectory, withIntermediateDirectories: true)
				
				let historyURL = userDataDirectory
					.appending(component: "history")
					.appendingPathExtension("sqlite")
				return try await HistoryDB.bootstrap(at: historyURL)
			} catch {
				logger.error("failed to bootstrap history: \(error)")
				throw error
			}
		}
		
		// TODO: load env from /etc/paths, /etc/paths.d and configs
		environment = ProcessInfo.processInfo.environment
		environment["TERM"] = "xterm-256color"
		environment["COLORTERM"] = "truecolor"
		environment["LANG"] = "en_US.UTF-8"
	}

	public func exec(input: String) {
		let start = now

		Task {
			self.feed("> " + input + "\r\n")

			do {
				try await self._exec(parse(input))
			} catch {
				if let error = error as? ShellError {
					feed(error.feedOutput)
				} else {
					feed(error.localizedDescription)
				}
				feed("\r\n")
			}

			await saveHistory(start: start, input: input)
		}
	}
	
	private func saveHistory(start: Date, input: String) async {
		do {
			let end = now
			let historyItem = Item(
				sessionUuid: sessionID.uuidString,
				input: input,
				startTimestamp: start.timeIntervalSince1970,
				endTimestamp: end.timeIntervalSince1970,
				exitCode: 0 // TODO:
			)
			_ = try await historyDB.value.insert(historyItem)
		} catch {
			logger.error("failed to save history: \(error)")
		}
	}

	private func parse(_ input: String) throws -> CommandSyntax {
		do {
			return try CommandSyntax.parse(input)
		} catch {
			throw ParseError(underlyingError: error)
		}
	}

	private func interpret(_ word: WordToken) async throws -> String {
		switch word {
		case let .unquoted(word):
			word.content
		case let .doubleQuoted(word):
			// TODO: actually interpret interpolations
			word.content
		}
	}

	private func resolve(command: String) async throws -> String {
		let path = self.environment["PATH"]
		let paths = path?.components(separatedBy: ":") ?? []
		for path in paths {
			let pathURL = URL(filePath: path, directoryHint: .isDirectory).absoluteURL
			let resolved = URL(filePath: command, relativeTo: pathURL).absoluteURL

			if FileManager.default.fileExists(atPath: resolved.path()) {
				return resolved.path()
			}
		}

		throw UnknownCommand(command: command)
	}

	private var currentDirectoryManager: CurrentDirectoryManager {
		.init {
			await self.workingDirectory
		} changeCurrentDirectory: { url in
			await self.changeCurrentDirectory(url)
			return true
		}
	}

	private func _exec(_ command: CommandSyntax) async throws {
		let commandName = try await self.interpret(command.executable)
		var arguments: [String] = []
		for argument in command.arguments {
			try await arguments.append(self.interpret(argument))
		}
		let environment = self.environment.map { "\($0.key)=\($0.value)" }

		if let builtin = builtins[commandName] {
			try await withDependencies {
				$0.currentDirectoryManager = self.currentDirectoryManager
			} operation: {
				try await builtin.run(arguments)
			}
		} else {
			let executable = try await self.resolve(command: commandName)

			startProcess(
				executable,
				arguments,
				environment,
				workingDirectory.path()
			)
		}
	}

	// MARK: - History

	public func historyItemBefore(_ item: CommandHistoryItem?, query: String) async -> CommandHistoryItem? {
		do {
			return try await historyDB.value.readTransaction { [sessionID] tx in
				if let item {
					try tx.items.fetch(sql: """
					SELECT *
					FROM item
					WHERE start_timestamp < \(item.start.timeIntervalSince1970)
					ORDER BY session_uuid = \(sessionID.uuidString) DESC, start_timestamp DESC
					LIMIT 1
					""").first
				} else {
					try tx.items.fetch(sql: """
					SELECT *
					FROM item
					ORDER BY session_uuid = \(sessionID.uuidString) DESC, start_timestamp DESC
					LIMIT 1
					""").first
					//			return history.last
				}
			}
		} catch {
			logger.error("failed to read history: \(error)")
			return nil
		}
	}

	public func historyItemAfter(_ item: CommandHistoryItem, query: String) async -> CommandHistoryItem? {
		do {
			return try await historyDB.value.readTransaction { [sessionID] tx in
				try tx.items.fetch(sql: """
				SELECT *
				FROM item
				WHERE start_timestamp > \(item.start.timeIntervalSince1970)
				ORDER BY session_uuid = \(sessionID.uuidString) ASC, start_timestamp ASC
				LIMIT 1
				""").first
			}
		} catch {
			logger.error("failed to read history: \(error)")
			return nil
		}
	}
}
