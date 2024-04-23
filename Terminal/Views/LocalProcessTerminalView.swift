import AppKit
import Foundation
import Shell
import SwiftTerm
import SwiftUI

struct LocalProcessTerminalView: NSViewRepresentable {
	@Environment(SessionCoordinator.self) private var sessionCoordinator

	func makeNSView(context: Context) -> ShellTerminalView {
		let view = ShellTerminalView()

		let terminal = view.getTerminal()
		terminal.setCursorStyle(.steadyBlock)
		terminal.hideCursor()

		return view
	}

	func updateNSView(_ view: ShellTerminalView, context: Context) {
		view.shell = sessionCoordinator.shell
	}
}

final class ShellTerminalView: TerminalView {
	private var shellTask: Task<Void, Error>?
	var shell: ShellDriver? {
		didSet {
			guard shell !== oldValue else { return }

			shellTask?.cancel()
			guard let shell else { return }

			let size = getWindowSize()
			shellTask = Task {
				await shell.setWindowSize(size)

				for try await byte in shell.output {
					self.feed(byteArray: [byte])
				}
			}
		}
	}

	init() {
		super.init(frame: .zero, font: .monospacedSystemFont(ofSize: 14, weight: .regular))

		terminalDelegate = self
	}

	@available(*, unavailable)
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	// MARK: - Window size

	/**
	 * This method is invoked to notify the client of the new columsn and rows that have been set by the UI
	 */
	public func sizeChanged(source: TerminalView, newCols: Int, newRows: Int) {
		var size = getWindowSize()
		Task { [shell] in
			await shell?.setWindowSize(size)
		}
	}

	/**
	 * Implements the LocalProcessDelegate.getWindowSize method
	 */
	func getWindowSize() -> winsize {
		let f: CGRect = self.frame
		return winsize(ws_row: UInt16(terminal.rows), ws_col: UInt16(terminal.cols), ws_xpixel: UInt16(f.width), ws_ypixel: UInt16(f.height))
	}

	// MARK: -

	public func clipboardCopy(source: TerminalView, content: Data) {
		if let str = String(bytes: content, encoding: .utf8) {
			let pasteBoard = NSPasteboard.general
			pasteBoard.clearContents()
			pasteBoard.writeObjects([str as NSString])
		}
	}
}

extension ShellTerminalView: TerminalViewDelegate {
	func scrolled(source: SwiftTerm.TerminalView, position: Double) {}

	func setTerminalTitle(source: SwiftTerm.TerminalView, title: String) {}

	func hostCurrentDirectoryUpdate(source: SwiftTerm.TerminalView, directory: String?) {}

	func rangeChanged(source: SwiftTerm.TerminalView, startY: Int, endY: Int) {}

	/**
	 * This method is invoked when input from the user needs to be sent to the client
	 * Implementation of the TerminalViewDelegate method
	 */
	func send(source: TerminalView, data: ArraySlice<UInt8>) {
		Task { [shell] in
			try await shell?.send(data)
		}
	}
}
