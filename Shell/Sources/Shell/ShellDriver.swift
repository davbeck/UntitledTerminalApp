import ArgumentParser
import Dependencies
import Foundation
import OSLog
import ShellSyntax

public actor ShellDriver {
	private let logger: Logger

	@Dependency(\.fileManager) private var fileManager
	@Dependency(\.environment) private var environment
	@Dependency(\.date.now) private var now

	let builtins: [String: AsyncParsableCommand.Type] = [
		"cd": CD.self,
	]

	private let historyDB: Task<HistoryDB, Swift.Error>

	public let sessionID = UUID()

	let inputPipe = Pipe()
	let outputPipe = Pipe()

	public private(set) var windowSize: winsize = .init()

	public var currentProcess: PTYProcess?

	public let storage: any ShellStorage

	public init(storage: any ShellStorage) {
		// annoying that we can't use self.fileManager in init
		@Dependency(\.fileManager) var fileManager

		self.storage = storage

		logger = Logger(subsystem: "co.davidbeck.Terminal", category: "driver")
		historyDB = Task { [logger] in
			do {
				let userDataDirectory = URL.homeDirectory
					.appending(component: ".local")
					.appending(component: "share")
					.appending(component: "swish")
				logger.info("creating user data directory at '\(userDataDirectory.path())'")
				try await fileManager.createDirectory(
					at: userDataDirectory,
					withIntermediateDirectories: true
				)

				let historyURL = userDataDirectory
					.appending(component: "history")
					.appendingPathExtension("sqlite")
				return try await HistoryDB.bootstrap(at: historyURL)
			} catch {
				logger.error("failed to bootstrap history: \(error)")
				throw error
			}
		}

//		self.workingDirectory = fileManager.homeDirectoryForCurrentUser

		Task { [weak self, inputPipe] in
			let stream = AsyncStream<Data> { continuation in
				inputPipe.fileHandleForReading.readabilityHandler = { fileHandle in
					let availableData = fileHandle.availableData
					if availableData.isEmpty {
						continuation.finish()
					} else {
						continuation.yield(availableData)
					}
				}
			}
			for await availableData in stream {
				try await self?.currentProcess?.send(availableData)
			}
		}
	}

	deinit {
		try? inputPipe.fileHandleForReading.close()
		try? outputPipe.fileHandleForWriting.close()
	}

	public nonisolated
	func exec(input: String) {
		Task {
			await self.exec(input: input)
		}
	}

	public func exec(input: String) async {
		let start = now
		let exitCode: Int32

		do {
			self.feed("> " + input + "\r\n")

			exitCode = try await Self.$currentShellStorage.withValue(storage) {
				try await withDependencies(from: self) {
					try await self._exec(parse(input))
				}
			}
		} catch {
			if let error = error as? ShellError {
				feed(error.feedOutput)
				exitCode = error.exitCode
			} else {
				feed(error.localizedDescription)
				exitCode = -1
			}
			feed("\r\n")
		}

		await saveHistory(start: start, input: input, exitCode: exitCode)
	}

	private func feed(_ text: String) {
		try! self.outputPipe.fileHandleForWriting.write(contentsOf: Data(text.utf8))
	}

	private func saveHistory(start: Date, input: String, exitCode: Int32) async {
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

	private func resolve(command: String, withPath path: String) async throws -> String {
		let paths = path.components(separatedBy: ":")
		for path in paths {
			let pathURL = URL(filePath: path, directoryHint: .isDirectory).absoluteURL
			let resolved = URL(filePath: command, relativeTo: pathURL).absoluteURL

			if await fileManager.fileExists(at: resolved) == .file {
				return resolved.path()
			}
		}

		throw UnknownCommand(command: command)
	}

	private func _exec(_ command: CommandSyntax) async throws -> Int32 {
		let context = await storage.context

		let commandName = try await self.interpret(command.executable)
		var arguments: [String] = []
		for argument in command.arguments {
			try await arguments.append(self.interpret(argument))
		}
		let environment = context.environment

		if let builtin = builtins[commandName] {
			try await builtin.run(arguments)
			return 0
		} else {
			let executable = try await self.resolve(
				command: commandName,
				withPath: context.environment["PATH"] ?? ""
			)

			let process = PTYProcess.start(
				executing: executable,
				arguments: Arguments(arguments),
				environment: environment,
				workingDirectory: context.currentDirectory,
				windowSize: self.windowSize
			)
			process.fileHandle.readabilityHandler = { [outputPipe] fileHandle in
				try? outputPipe.fileHandleForWriting.write(contentsOf: fileHandle.availableData)
			}

			self.currentProcess = process

			return await process.termination()
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

extension ShellDriver: PTY {
	public nonisolated
	var output: FileHandle.AsyncBytes {
		outputPipe.fileHandleForReading.bytes
	}

	public func send(_ bytes: some DataProtocol & Sendable) async throws {
		try inputPipe.fileHandleForWriting.write(contentsOf: bytes)
	}

	public func setWindowSize(_ windowSize: winsize) async {
		self.windowSize = windowSize
		currentProcess?.setWindowSize(windowSize)
	}
}
