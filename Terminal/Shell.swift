import Foundation
import SwiftTerm

@MainActor
@Observable
class Shell {
	var workingDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
	var environment: [String] = Terminal.getEnvironmentVariables(termName: "xterm-256color")

	@ObservationIgnored
	var startProcess: (_ executable: String, _ arguments: [String], _ environment: [String], _ workingDirectory: String) -> Void = { _, _, _, _ in }
	@ObservationIgnored
	var feed: (_ text: String) -> Void = { _ in }

	func exec(_ input: String) {
		guard let command = Command.parse(input) else { return }

		do {
			feed("> " + input + "\r\n")

			switch command {
			case let .executable(executable: executable, arguments: arguments):
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
