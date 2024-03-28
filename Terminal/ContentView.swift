import SwiftUI

@MainActor
final class PromptCoordinator {
	var onExec: (String) -> Void = { _ in }

	func exec(_ command: String) {
		onExec(command)
	}
}

@MainActor
struct ContentView: View {
	@State private var coordinator = PromptCoordinator()
	@State private var prompt: String = ""

	var body: some View {
		VStack(spacing: 0) {
			LocalProcessTerminalView(promptCoordinator: coordinator)

			HStack(alignment: .firstTextBaseline) {
				Text(">")
					.foregroundStyle(Color.accentColor)

				TextField("Type a command...", text: $prompt, axis: .vertical)
					.textFieldStyle(.plain)
					.onSubmit(of: .text) {
						if NSEvent.modifierFlags.contains(.shift) {
							prompt += "\n"
						} else {
							coordinator.exec(prompt)
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

#Preview {
	ContentView()
}
