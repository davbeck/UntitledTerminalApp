import AppKit
import Foundation
import SwiftTerm
import SwiftUI

struct LocalProcessTerminalView: NSViewRepresentable {
	var shell: Shell

	func makeCoordinator() -> Coordinator {
		Coordinator()
	}

	func makeNSView(context: Context) -> SwiftTerm.LocalProcessTerminalView {
		let view = SwiftTerm.LocalProcessTerminalView(frame: .zero)
		view.processDelegate = context.coordinator

		let terminal = view.getTerminal()
		view.cursorStyleChanged(source: terminal, newStyle: .steadyBlock)
//		view.hideCursor(source: terminal)
		terminal.hideCursor()

//		let shell = context.coordinator.getShell()
		////		let shell = "/bin/zsh"
//		let shellIdiom = "-" + NSString(string: shell).lastPathComponent
//		FileManager.default.changeCurrentDirectoryPath(FileManager.default.homeDirectoryForCurrentUser.path)
//		var environment = Terminal.getEnvironmentVariables(termName: "xterm-256color")
//		print(environment)
		////		environment.append("PWD=\(FileManager.default.homeDirectoryForCurrentUser.path)")
		////		view.getTerminal().hostCurrentDirectory
//		view.startProcess(
//			executable: shell,
//			environment: environment,
//			execName: shellIdiom
//		)

		return view
	}

	func updateNSView(_ view: SwiftTerm.LocalProcessTerminalView, context: Context) {
		shell.feed = view.feed
		shell.startProcess = {
			view.startProcess(
				executable: $0,
				args: $1,
				environment: $2,
				workingDirectory: $3
			)
		}
//		promptCoordinator.onExec = { [weak promptCoordinator] input, command in
//			guard let promptCoordinator else { return }
//
//			view.startProcess()
//		}
	}

	final class Coordinator {
		// Returns the shell associated with the current account
		func getShell() -> String {
			let bufsize = sysconf(_SC_GETPW_R_SIZE_MAX)
			guard bufsize != -1 else {
				return "/bin/bash"
			}
			let buffer = UnsafeMutablePointer<Int8>.allocate(capacity: bufsize)
			defer {
				buffer.deallocate()
			}
			var pwd = passwd()
			var result: UnsafeMutablePointer<passwd>? = UnsafeMutablePointer<passwd>.allocate(capacity: 1)

			if getpwuid_r(getuid(), &pwd, buffer, bufsize, &result) != 0 {
				return "/bin/bash"
			}
			return String(cString: pwd.pw_shell)
		}
	}
}

extension LocalProcessTerminalView.Coordinator: LocalProcessTerminalViewDelegate {
	func sizeChanged(source: SwiftTerm.LocalProcessTerminalView, newCols: Int, newRows: Int) {
		print("sizeChanged", newCols, newRows)
	}

	func setTerminalTitle(source: SwiftTerm.LocalProcessTerminalView, title: String) {
		print("setTerminalTitle", title)
	}

	func hostCurrentDirectoryUpdate(source: SwiftTerm.TerminalView, directory: String?) {
		print("hostCurrentDirectoryUpdate", directory)
	}

	func processTerminated(source: SwiftTerm.TerminalView, exitCode: Int32?) {
		print("processTerminated", exitCode)
	}
}
