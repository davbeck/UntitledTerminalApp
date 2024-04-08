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
		terminal.setCursorStyle(.steadyBlock)
		terminal.hideCursor()

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
	}

	final class Coordinator {}
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
