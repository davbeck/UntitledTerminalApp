import Dependencies
import Foundation
import Observation
import Shell

@Observable
@MainActor
final class SessionCoordinator {
	@ObservationIgnored
	@Dependency private var fileManager: FileManager.Value
	@ObservationIgnored
	@Dependency private var environment: EnvironmentManagerDependency

	let storage: ObservableShellStorage
	let shell: ShellDriver

	init() {
		_fileManager = Dependency(\.fileManager)
		_environment = Dependency(\.environment)

		var environment = _environment.wrappedValue.getEnvironment()
		// TODO: load PATH from /etc/paths, /etc/paths.d and configs
		environment["TERM"] = "xterm-256color"
		environment["COLORTERM"] = "truecolor"
		environment["LANG"] = "en_US.UTF-8"

		let currentDirectory = _fileManager.wrappedValue.homeDirectoryForCurrentUser

		storage = .init(
			environment: environment,
			currentDirectory: currentDirectory
		)

		shell = ShellDriver(storage: storage)
	}
}
