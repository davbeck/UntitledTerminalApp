import AppKit
import Foundation
import Shell
import STTextView

@MainActor
class PromptTextView: STTextView {
	var shell: Shell?

	var promptHistorySelection: PromptHistorySelection?

	// copied from super because private
	private var scrollView: NSScrollView? {
		guard let result = enclosingScrollView, result.documentView == self else {
			return nil
		}
		return result
	}

	// mostly a copy of super, but with 1 change
	override func sizeToFit() {
		// called because _configureTextContainerSize is private
		super.sizeToFit()

		// this is the biggest change
		// original: `var size = textLayoutManager.usageBoundsForTextContainer.size`
		// NSTextLayoutManager does not seem to shrink it's bounds back down after deleting the last line
		// not sure if that's a bug or a feature, but to get exact sizing, we use the layout fragments to get actual rendered bounds
		var size = CGSize(width: 0, height: 0)
		textLayoutManager.enumerateTextLayoutFragments(
			from: nil,
			options: [.ensuresLayout, .ensuresExtraLineFragment]
		) { fragment in
			size.width = max(size.width, fragment.layoutFragmentFrame.maxX)
			size.height = max(size.height, fragment.layoutFragmentFrame.maxY)
			return true
		}

		var horizontalInsets: CGFloat = 0
		var verticalInsets: CGFloat = 0
		if let clipView = scrollView?.contentView as? NSClipView {
			horizontalInsets = clipView.contentInsets.horizontalInsets
			verticalInsets = clipView.contentInsets.verticalInsets
		}

		if isHorizontallyResizable {
			size.width = max(frame.size.width - horizontalInsets, size.width)
		} else {
			size.width = frame.size.width - horizontalInsets
		}

		if isVerticallyResizable {
			if scrollView == nil {
				// this comment is in the original implimentation, but the check for scrollView isn't
				// we should at least be our frame size if we're not in a clip view
				size.height = max(frame.size.height - verticalInsets, size.height)
			}
		} else {
			size.height = frame.size.height - verticalInsets
		}

		// if we're in a clip view we should at be at least as big as the clip view
		if let clipView = scrollView?.contentView as? NSClipView {
			if size.width < clipView.bounds.size.width - horizontalInsets {
				size.width = clipView.bounds.size.width - horizontalInsets
			}

			if size.height < clipView.bounds.size.height - verticalInsets {
				size.height = clipView.bounds.size.height - verticalInsets
			}
		}

		if !frame.size.isAlmostEqual(to: size) {
			self.setFrameSize(size)
		}
	}

	override func shouldChangeText(in affectedTextRange: NSTextRange, replacementString: String?) -> Bool {
		if replacementString?.count == 1, replacementString?.first?.isNewline == true && !NSEvent.modifierFlags.contains(.shift) {
			let input = self.string
			self.string = ""
			shell?.exec(input: input)

			return false
		}

		return true
	}

	override func keyDown(with event: NSEvent) {
		historyTask = nil

		let text = self.string
		if
			event.specialKey == .upArrow,
			let selectedRange = Range(self.selectedRange(), in: text),
			!text.prefix(upTo: selectedRange.lowerBound).contains(where: \.isNewline)
		{
			self.moveHistoryBack()
		} else if
			event.specialKey == .downArrow,
			promptHistorySelection != nil
		{
			self.moveHistoryForward()
		} else {
			super.keyDown(with: event)
		}
	}

	private var historyTask: Task<Void, Never>? {
		didSet {
			oldValue?.cancel()
		}
	}

	private func moveHistoryBack() {
		guard let shell else { return }

		let query = promptHistorySelection?.query ?? string
		historyTask = Task {
			let item = await shell.historyItemBefore(
				promptHistorySelection?.item,
				query: query
			)

			guard !Task.isCancelled else { return }

			if let item {
				self.string = item.input
				self.promptHistorySelection = .init(query: query, item: item)

				self.selectAndShow(NSRange(location: self.string.utf16.count, length: 0))
			} else {
				// TODO: flash
			}
		}
	}

	private func moveHistoryForward() {
		guard let shell, let promptHistorySelection else { return }

		let query = promptHistorySelection.query
		historyTask = Task {
			let item = await shell.historyItemAfter(
				promptHistorySelection.item,
				query: query
			)

			guard !Task.isCancelled else { return }

			if let item {
				self.string = item.input
				self.promptHistorySelection = .init(query: query, item: item)
			} else {
				self.string = query
				self.promptHistorySelection = nil
			}

			self.selectAndShow(NSRange(location: self.string.utf16.count, length: 0))
		}
	}
}

extension NSEdgeInsets {
	var horizontalInsets: CGFloat {
		left + right
	}

	var verticalInsets: CGFloat {
		top + bottom
	}
}

extension CGRect {
	enum Inset {
		case left(CGFloat)
		case right(CGFloat)
		case top(CGFloat)
		case bottom(CGFloat)
	}

	func inset(by edgeInsets: NSEdgeInsets) -> CGRect {
		var result = self
		result.origin.x += edgeInsets.left
		result.origin.y += edgeInsets.top
		result.size.width -= edgeInsets.left + edgeInsets.right
		result.size.height -= edgeInsets.top + edgeInsets.bottom
		return result
	}

	func inset(_ insets: Inset...) -> CGRect {
		var result = self
		for inset in insets {
			switch inset {
			case let .left(value):
				result = self.inset(by: NSEdgeInsets(top: 0, left: value, bottom: 0, right: 0))
			case let .right(value):
				result = self.inset(by: NSEdgeInsets(top: 0, left: 0, bottom: 0, right: value))
			case let .top(value):
				result = self.inset(by: NSEdgeInsets(top: value, left: 0, bottom: 0, right: 0))
			case let .bottom(value):
				result = self.inset(by: NSEdgeInsets(top: 0, left: 0, bottom: value, right: 0))
			}
		}
		return result
	}

	func inset(dx: CGFloat = 0, dy: CGFloat = 0) -> CGRect {
		insetBy(dx: dx, dy: dy)
	}

	func scale(_ scale: CGSize) -> CGRect {
		applying(.init(scaleX: scale.width, y: scale.height))
	}

	func margin(_ margin: CGSize) -> CGRect {
		insetBy(dx: -margin.width / 2, dy: -margin.height / 2)
	}

	func moved(dx: CGFloat = 0, dy: CGFloat = 0) -> CGRect {
		applying(.init(translationX: dx, y: dy))
	}

	func moved(by point: CGPoint) -> CGRect {
		applying(.init(translationX: point.x, y: point.y))
	}

	func margin(top: CGFloat = 0, left: CGFloat = 0, bottom: CGFloat = 0, right: CGFloat = 0) -> CGRect {
		inset(by: .init(top: -top, left: -left, bottom: -bottom, right: -right))
	}
}

extension CGPoint {
	func moved(dx: CGFloat = 0, dy: CGFloat = 0) -> CGPoint {
		applying(.init(translationX: dx, y: dy))
	}

	func moved(by point: CGPoint) -> CGPoint {
		applying(.init(translationX: point.x, y: point.y))
	}
}

extension CGRect {
	func isAlmostEqual(to other: CGRect) -> Bool {
		origin.isAlmostEqual(to: other.origin) && size.isAlmostEqual(to: other.size)
	}
}

extension CGPoint {
	func isAlmostEqual(to other: CGPoint) -> Bool {
		x.isAlmostEqual(to: other.x) && y.isAlmostEqual(to: other.y)
	}
}

extension CGSize {
	func isAlmostEqual(to other: CGSize) -> Bool {
		width.isAlmostEqual(to: other.width) && height.isAlmostEqual(to: other.height)
	}
}

//===--- ApproximateEquality.swift ----------------------------*- swift -*-===//
//
// This source file is part of the Swift Numerics open source project
//
// Copyright (c) 2019 - 2020 Apple Inc. and the Swift Numerics project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
//
//===----------------------------------------------------------------------===//

extension FloatingPoint {
	/// Test approximate equality with relative tolerance.
	///
	/// Do not use this function to check if a number is approximately
	/// zero; no reasoned relative tolerance can do what you want for
	/// that case. Use `isAlmostZero` instead for that case.
	///
	/// The relation defined by this predicate is symmetric and reflexive
	/// (except for NaN), but *is not* transitive. Because of this, it is
	/// often unsuitable for use for key comparisons, but it can be used
	/// successfully in many other contexts.
	///
	/// The internet is full advice about what not to do when comparing
	/// floating-point values:
	///
	/// - "Never compare floats for equality."
	/// - "Always use an epsilon."
	/// - "Floating-point values are always inexact."
	///
	/// Much of this advice is false, and most of the rest is technically
	/// correct but misleading. Almost none of it provides specific and
	/// correct recommendations for what you *should* do if you need to
	/// compare floating-point numbers.
	///
	/// There is no uniformly correct notion of "approximate equality", and
	/// there is no uniformly correct tolerance that can be applied without
	/// careful analysis. This function considers two values to be almost
	/// equal if the relative difference between them is smaller than the
	/// specified `tolerance`.
	///
	/// The default value of `tolerance` is `sqrt(.ulpOfOne)`; this value
	/// comes from the common numerical analysis wisdom that if you don't
	/// know anything about a computation, you should assume that roughly
	/// half the bits may have been lost to rounding. This is generally a
	/// pretty safe choice of tolerance--if two values that agree to half
	/// their bits but are not meaningfully almost equal, the computation
	/// is likely ill-conditioned and should be reformulated.
	///
	/// For more complete guidance on an appropriate choice of tolerance,
	/// consult with a friendly numerical analyst.
	///
	/// - Parameters:
	///   - other: the value to compare with `self`
	///   - tolerance: the relative tolerance to use for the comparison.
	///     Should be in the range [.ulpOfOne, 1).
	///
	/// - Returns: `true` if `self` is almost equal to `other`; otherwise
	///   `false`.
	@inlinable
	func isAlmostEqual(
		to other: Self,
		tolerance: Self = Self.ulpOfOne.squareRoot()
	) -> Bool {
		// Tolerances outside of [.ulpOfOne, 1) yield well-defined but useless
		// results, so this is enforced by an assert rather than a precondition.
		assert(tolerance >= .ulpOfOne && tolerance < 1, "tolerance should be in [.ulpOfOne, 1).")
		// The simple computation below does not necessarily give sensible
		// results if one of self or other is infinite; we need to rescale
		// the computation in that case.
		guard self.isFinite && other.isFinite else {
			return rescaledAlmostEqual(to: other, tolerance: tolerance)
		}
		// This should eventually be rewritten to use a scaling facility to be
		// defined on FloatingPoint suitable for hypot and scaled sums, but the
		// following is good enough to be useful for now.
		let scale = max(abs(self), abs(other), .leastNormalMagnitude)
		return abs(self - other) < scale * tolerance
	}

	/// Test if this value is nearly zero with a specified `absoluteTolerance`.
	///
	/// This test uses an *absolute*, rather than *relative*, tolerance,
	/// because no number should be equal to zero when a relative tolerance
	/// is used.
	///
	/// Some very rough guidelines for selecting a non-default tolerance for
	/// your computation can be provided:
	///
	/// - If this value is the result of floating-point additions or
	///   subtractions, use a tolerance of `.ulpOfOne * n * scale`, where
	///   `n` is the number of terms that were summed and `scale` is the
	///   magnitude of the largest term in the sum.
	///
	/// - If this value is the result of floating-point multiplications,
	///   consider each term of the product: what is the smallest value that
	///   should be meaningfully distinguished from zero? Multiply those terms
	///   together to get a tolerance.
	///
	/// - More generally, use half of the smallest value that should be
	///   meaningfully distinct from zero for the purposes of your computation.
	///
	/// For more complete guidance on an appropriate choice of tolerance,
	/// consult with a friendly numerical analyst.
	///
	/// - Parameter absoluteTolerance: values with magnitude smaller than
	///   this value will be considered to be zero. Must be greater than
	///   zero.
	///
	/// - Returns: `true` if `abs(self)` is less than `absoluteTolerance`.
	///            `false` otherwise.
	@inlinable
	func isAlmostZero(
		absoluteTolerance tolerance: Self = Self.ulpOfOne.squareRoot()
	) -> Bool {
		assert(tolerance > 0)
		return abs(self) < tolerance
	}

	/// Rescales self and other to give meaningful results when one of them
	/// is infinite. We also handle NaN here so that the fast path doesn't
	/// need to worry about it.
	@usableFromInline
	func rescaledAlmostEqual(to other: Self, tolerance: Self) -> Bool {
		// NaN is considered to be not approximately equal to anything, not even
		// itself.
		if self.isNaN || other.isNaN { return false }
		if self.isInfinite {
			if other.isInfinite { return self == other }
			// Self is infinite and other is finite. Replace self with the binade
			// of the greatestFiniteMagnitude, and reduce the exponent of other by
			// one to compensate.
			let scaledSelf = Self(sign: self.sign,
			                      exponent: Self.greatestFiniteMagnitude.exponent,
			                      significand: 1)
			let scaledOther = Self(sign: .plus,
			                       exponent: -1,
			                       significand: other)
			// Now both values are finite, so re-run the naive comparison.
			return scaledSelf.isAlmostEqual(to: scaledOther, tolerance: tolerance)
		}
		// If self is finite and other is infinite, flip order and use scaling
		// defined above, since this relation is symmetric.
		return other.rescaledAlmostEqual(to: self, tolerance: tolerance)
	}
}
