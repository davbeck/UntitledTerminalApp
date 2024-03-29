import Foundation
import SwiftTerm
import ShellSyntax

@MainActor
@Observable
class Shell {
	var workingDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
	var environment: [String:String]

	@ObservationIgnored
	var startProcess: (_ executable: String, _ arguments: [String], _ environment: [String], _ workingDirectory: String) -> Void = { _, _, _, _ in }
	@ObservationIgnored
	var feed: (_ text: String) -> Void = { _ in }
	
	init() {
		// TODO: load env from /etc/paths, /etc/paths.d and configs
		environment = ProcessInfo.processInfo.environment
		environment["TERM"] = "xterm-256color"
		environment["COLORTERM"] = "truecolor"
		environment["LANG"] = "en_US.UTF-8"
	}
	
	private func resolve(command: String) throws -> String {
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

	func exec(_ input: String) {
		guard let command = Command.parse(input) else { return }

		do {
			feed("> " + input + "\r\n")

			switch command {
			case let .executable(executable: executable, arguments: arguments):
				let executable = try self.resolve(command: executable)
				
				let environment = self.environment.map { "\($0.key)=\($0.value)" }
				startProcess(
					executable,
					arguments,
					environment,
					workingDirectory.path()
				)
			case let .changeDirectory(path: path):
				if let path {
					guard
						let directory = URL(
							string: path,
							relativeTo: workingDirectory
						)?.absoluteURL
					else {
						return
					}
					var isDirectory: ObjCBool = false
					guard
						FileManager.default.fileExists(
							atPath: directory.path(),
							isDirectory: &isDirectory
						)
					else {
						throw DirectoryDoesNotExist(path: path)
					}
					guard isDirectory.boolValue else {
						throw NotADirectory(path: path)
					}

					workingDirectory = directory.absoluteURL
				} else {
					workingDirectory = FileManager.default.homeDirectoryForCurrentUser
				}
			}
		} catch {
			feed("\(command.name): ")
			if let error = error as? ShellError {
				feed(error.feedOutput)
			} else {
				feed(error.localizedDescription)
			}
			feed("\r\n")
		}
	}
}
