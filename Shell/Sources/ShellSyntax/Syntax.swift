import Foundation
import Parsing

public protocol Syntax: Equatable {
	static func parse(_ input: String) throws -> Self
	func print() throws -> String
}

protocol ParserPrinterSyntax: Syntax {
	static var parser: any ParserPrinter<ParserView, Self> { get }
}

extension ParserPrinterSyntax {
	public static func parse(_ input: String) throws -> Self {
		try parser.parse(input)
	}

	public func print() throws -> String {
		let view = try Self.parser.print(self)
		return String(Substring(view))
	}
}
