import STTextView
import STTextViewUI
import SwiftUI
import Shell

struct PromptView: View {
	@State var shell = Shell()

	var body: some View {
		PromptTextViewRepresentable(
			text: $shell.input,
			onSubmit: {
				shell.exec()
			}
		)
		.background(Color.accentColor.opacity(0.1))
		.overlay(alignment: .top, content: {
			Divider()
		})

//		HStack(alignment: .firstTextBaseline) {
//			Text(">")
//				.foregroundStyle(Color.accentColor)
//
//			TextField("Type a command...", text: $prompt, axis: .vertical)
//				.textFieldStyle(.plain)
//				.autocorrectionDisabled(true)
//				.onSubmit(of: .text) {
//					if NSEvent.modifierFlags.contains(.shift) {
//						prompt += "\n"
//					} else {
//						shell.exec(prompt)
//						prompt = ""
//					}
//				}
//		}
//		.padding(.vertical, 5)
//		.padding(.horizontal, 8)
//		.background(Color.accentColor.opacity(0.1))
//		.overlay(alignment: .top, content: {
//			Divider()
//		})
//		.monospaced()
	}
}

#Preview {
	PromptView()
}
