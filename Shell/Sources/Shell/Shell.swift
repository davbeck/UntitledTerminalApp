import ArgumentParser
import Foundation
import ShellSyntax
import Dependencies

@Observable
@MainActor
public class Shell {
	let builtins: [String: AsyncParsableCommand.Type] = [
		"cd": CD.self,
	]

	public var workingDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
	public func changeCurrentDirectory(_ url: URL) {
		self.workingDirectory = url
	}

	public var environment: [String: String]

	@ObservationIgnored
	public var startProcess: (_ executable: String, _ arguments: [String], _ environment: [String], _ workingDirectory: String) -> Void = { _, _, _, _ in }
	@ObservationIgnored
	public var feed: (_ text: String) -> Void = { _ in }

	public var input = ""

	public init() {
		// TODO: load env from /etc/paths, /etc/paths.d and configs
		environment = ProcessInfo.processInfo.environment
		environment["TERM"] = "xterm-256color"
		environment["COLORTERM"] = "truecolor"
		environment["LANG"] = "en_US.UTF-8"
	}

	public func exec() {
		let input = self.input
		self.input = ""

		Task {
			self.feed("> " + input + "\r\n")

			do {
				try await self.exec(input)
			} catch {
				if let error = error as? ShellError {
					feed(error.feedOutput)
				} else {
					feed(error.localizedDescription)
				}
				feed("\r\n")
			}
		}
	}

	private func parse(_ input: String) throws -> CommandSyntax {
		do {
			return try CommandSyntax.parse(input)
		} catch {
			throw ParseError(underlyingError: error)
		}
	}

	private func exec(_ input: String) async throws {
		let command = try parse(input)

		try await self.exec(command)
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

	private func exec(_ command: CommandSyntax) async throws {
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
}
