import AppKit
import Combine
import Shell
import STTextView
import SwiftUI

struct PromptTextViewRepresentable: NSViewRepresentable {
	typealias NSViewType = NSScrollView

	@Environment(SessionCoordinator.self) private var sessionCoordinator

	func makeCoordinator() -> Coordinator {
		Coordinator(parent: self)
	}

	func makeNSView(context: Context) -> NSViewType {
		let scrollView = PromptTextView.scrollableTextView()

		scrollView.automaticallyAdjustsContentInsets = false
		scrollView.contentInsets = .init(top: 5, left: 8, bottom: 5, right: 8)

		scrollView.hasHorizontalScroller = false
		if let textView = scrollView.documentView as? STTextView {
			textView.widthTracksTextView = false
			textView.heightTracksTextView = true

			textView.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
		}

		return scrollView
	}

	func updateNSView(_ scrollView: NSViewType, context: Context) {
		context.coordinator.parent = self

		guard let textView = scrollView.documentView as? PromptTextView else { return }

		textView.shell = sessionCoordinator.shell
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
