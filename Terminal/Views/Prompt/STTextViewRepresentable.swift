//
//  STTextViewRepresentable.swift
//  Terminal
//
//  Created by David Beck on 4/2/24.
//

import SwiftUI
import STTextView
import AppKit
import Combine

struct STTextViewRepresentable: NSViewRepresentable {
	typealias NSViewType = NSScrollView
	
	@Binding var text: String
	
	func makeCoordinator() -> Coordinator {
		Coordinator(parent: self)
	}
	
	func makeNSView(context: Context) -> NSViewType {
		let scrollView = TextView.scrollableTextView()
		scrollView.hasHorizontalScroller = false
		if let textView = scrollView.documentView as? STTextView {
			textView.delegate = context.coordinator
			textView.widthTracksTextView = false
//			textView.isHorizontallyResizable = false
			textView.heightTracksTextView = true
//			textView.isVerticallyResizable = false
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
		
		return CGSize(width: proposal.width ?? textView.intrinsicContentSize.width, height: maxFragmentY)
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
