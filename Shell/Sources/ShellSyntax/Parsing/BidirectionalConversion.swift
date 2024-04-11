import Foundation
import Parsing

struct BidirectionalConversion<Input, Output>: Conversion {
	var apply: (_ input: Input) throws -> Output

	func apply(_ input: Input) throws -> Output {
		try self.apply(input)
	}

	var unapply: (_ output: Output) throws -> Input?

	func unapply(_ output: Output) throws -> Input {
		if let input = try self.unapply(output) {
			return input
		} else {
			throw InvalidReverseConversion(output: output)
		}
	}
}

extension Parser {
	func map<Input, Output>(
		_ apply: @escaping (_ input: Input) throws -> Output,
		reverse: @escaping (_ output: Output) throws -> Input?
	) -> Parsers.MapConversion<Self, BidirectionalConversion<Input, Output>> {
		self.map(BidirectionalConversion(apply: apply, unapply: reverse))
	}
}

struct InvalidReverseConversion<Output>: Error {
	var output: Output
}
