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
		@Dependency(\.currentDirectoryManager) var currentDirectoryManager

		let path = dir
		let currentDirectory = await currentDirectoryManager.currentDirectory

		guard
			let directory = URL(
				string: path,
				relativeTo: currentDirectory
			)?.standardizedFileURL
		else {
			throw InvalidPath(path: path)
		}

		var isDirectory: ObjCBool = false
		guard
			FileManager.default.fileExists(
				atPath: directory.path(),
				isDirectory: &isDirectory
			)
		else {
			throw DirectoryDoesNotExist(path: directory.path())
		}
		guard isDirectory.boolValue else {
			throw NotADirectory(path: directory.path())
		}

		let success = await currentDirectoryManager.changeCurrentDirectory(directory)

		guard success else {
			throw FailedToChangeDirectory(path: directory.path())
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
