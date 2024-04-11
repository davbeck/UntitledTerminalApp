import AppKit
import Combine
import STTextView
import SwiftUI

struct PromptTextViewRepresentable: NSViewRepresentable {
	typealias NSViewType = NSScrollView

	@Binding var text: String

	var onSubmit: () -> Void = {}

	func makeCoordinator() -> Coordinator {
		Coordinator(parent: self)
	}

	func makeNSView(context: Context) -> NSViewType {
		let scrollView = PromptTextView.scrollableTextView()

		scrollView.automaticallyAdjustsContentInsets = false
		scrollView.contentInsets = .init(top: 5, left: 8, bottom: 5, right: 8)

		scrollView.hasHorizontalScroller = false
		if let textView = scrollView.documentView as? STTextView {
			textView.delegate = context.coordinator
			textView.widthTracksTextView = false
			textView.heightTracksTextView = true

			textView.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
		}

		return scrollView
	}

	func updateNSView(_ scrollView: NSViewType, context: Context) {
		context.coordinator.parent = self

		guard let textView = scrollView.documentView as? STTextView else { return }

		if textView.string != text {
			textView.string = text
		}
	}

	func sizeThatFits(_ proposal: ProposedViewSize, nsView scrollView: NSViewType, context: Context) -> CGSize? {
		guard let textView = scrollView.documentView as? STTextView else { return nil }

		var maxFragmentY: CGFloat = 0
		textView.textLayoutManager.enumerateTextLayoutFragments(
			from: nil,
			options: [.ensuresLayout, .ensuresExtraLineFragment]
		) { fragment in
			maxFragmentY = max(maxFragmentY, fragment.layoutFragmentFrame.maxY)
			return true
		}

		return CGSize(
			width: proposal.width ?? textView.intrinsicContentSize.width,
			height: scrollView.contentInsets.top + maxFragmentY + scrollView.contentInsets.bottom
		)
	}

	@MainActor
	class Coordinator {
		var parent: PromptTextViewRepresentable

		init(parent: PromptTextViewRepresentable) {
			self.parent = parent
		}
	}
}

extension PromptTextViewRepresentable.Coordinator: STTextViewDelegate {
	nonisolated func textViewDidChangeText(_ notification: Notification) {
		MainActor.assumeIsolated {
			guard let textView = notification.object as? STTextView else {
				return
			}

			if self.parent.text != textView.string {
				self.parent.text = textView.string
			}
		}
	}

	nonisolated func textView(
		_ textView: STTextView,
		shouldChangeTextIn affectedCharRange: NSTextRange,
		replacementString: String?
	) -> Bool {
		if replacementString?.count == 1, replacementString?.first?.isNewline == true && !NSEvent.modifierFlags.contains(.shift) {
			MainActor.assumeIsolated {
				parent.onSubmit()
			}

			return false
		}

		return true
	}
}

#Preview {
	PromptTextViewRepresentable(text: .constant("ls -a"))
}
