import ArgumentParser
import Dependencies
import Foundation

struct CD: AsyncParsableCommand, Sendable {
	static let configuration = CommandConfiguration(
		abstract: "Change Directory - change the current working Folder.",
		usage: """
		If a dir is given, changes the shell's working directory to dir. If not, changes to HOME (shell variable).

		$ cd - will go back to the last folder you looked at. This does not stack, so issuing CD - repeatedly will just toggle between two directories, to go back further use pushd/popd. Previous directory - equivalent to $OLDPWD

		./ or just . is shorthand for the current directory.
		"""
	)

	@Flag(name: .customShort("P"), help: "Use the physical directory structure instead of following symbolic links (see also the -P option to the set builtin command)")
	var usePhysicalDirectory = false

	@Flag(name: .customShort("L"), help: "Force symbolic links to be followed")
	var followSymbolicLinks = false

	@Argument var dir: String

	mutating func run() async throws {
		@Dependency(\.fileManager) var fileManager
		let storage = ShellDriver.currentShellStorage

		let path = dir
		let currentDirectory = await storage.getCurrentDirectory()

		guard
			let directory = URL(
				string: path,
				relativeTo: currentDirectory
			)?.standardizedFileURL
		else {
			throw InvalidPath(path: path)
		}

		let presence = await fileManager.fileExists(at: directory)
		switch presence {
		case .none:
			throw DirectoryDoesNotExist(path: directory.path())
		case .file:
			throw NotADirectory(path: directory.path())
		case .directory:
			let success = await storage.changeCurrentDirectory(directory)

			guard success else {
				throw FailedToChangeDirectory(path: directory.path())
			}
		}
	}
}

struct InvalidPath: ShellError {
	var path: String

	var feedOutput: String {
		"cd: Invaoid path '\(path)'"
	}
}

struct DirectoryDoesNotExist: ShellError {
	var path: String

	var feedOutput: String {
		"cd: The directory '\(path)' does not exist"
	}
}

struct NotADirectory: ShellError {
	var path: String

	var feedOutput: String {
		"cd: '\(path)' is not a directory"
	}
}

struct FailedToChangeDirectory: ShellError {
	var path: String

	var feedOutput: String {
		"cd: Failed to change directory to '\(path)'"
	}
}
