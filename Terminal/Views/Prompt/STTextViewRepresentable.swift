import AppKit
import Combine
import STTextView
import SwiftUI

struct STTextViewRepresentable: NSViewRepresentable {
	typealias NSViewType = NSScrollView

	@Binding var text: String

	func makeCoordinator() -> Coordinator {
		Coordinator(parent: self)
	}

	func makeNSView(context: Context) -> NSViewType {
		let scrollView = TextView.scrollableTextView()

		scrollView.automaticallyAdjustsContentInsets = false
		scrollView.contentInsets = .init(top: 5, left: 8, bottom: 5, right: 8)

		scrollView.hasHorizontalScroller = false
		if let textView = scrollView.documentView as? STTextView {
			textView.delegate = context.coordinator
			textView.widthTracksTextView = false
			textView.heightTracksTextView = true
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
		var parent: STTextViewRepresentable

		init(parent: STTextViewRepresentable) {
			self.parent = parent
		}
	}
}

extension STTextViewRepresentable.Coordinator: STTextViewDelegate {
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
}

#Preview {
	STTextViewRepresentable(text: .constant("ls -a"))
}
