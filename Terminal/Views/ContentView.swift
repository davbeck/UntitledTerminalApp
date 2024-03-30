import SwiftUI

@MainActor
struct ContentView: View {
	@State private var shell = Shell()
	@State private var prompt: String = ""

	var body: some View {
		NavigationSplitView {
			FileNavigationSidebar(directory: shell.workingDirectory)
		} detail: {
			VStack(spacing: 0) {
				LocalProcessTerminalView(shell: shell)

				HStack(alignment: .firstTextBaseline) {
					Text(">")
						.foregroundStyle(Color.accentColor)

					TextField("Type a command...", text: $prompt, axis: .vertical)
						.textFieldStyle(.plain)
						.autocorrectionDisabled(true)
						.onSubmit(of: .text) {
							if NSEvent.modifierFlags.contains(.shift) {
								prompt += "\n"
							} else {
								shell.exec(prompt)
								prompt = ""
							}
						}
				}
				.padding(.vertical, 5)
				.padding(.horizontal, 8)
				.background(Color.accentColor.opacity(0.1))
				.overlay(alignment: .top, content: {
					Divider()
				})
				.monospaced()
			}
		}
	}
}

#Preview {
	ContentView()
}
