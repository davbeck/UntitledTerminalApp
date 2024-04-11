import Foundation
import Parsing

public enum WordToken: ParserPrinterSyntax {
	case unquoted(UnquotedWordToken)
	case doubleQuoted(DoubleQuotedWordToken)
	
	var unquoted: UnquotedWordToken? {
		switch self {
		case let .unquoted(word):
			word
		default:
			nil
		}
	}
	
	var doubleQuoted: DoubleQuotedWordToken? {
		switch self {
		case let .doubleQuoted(word):
			word
		default:
			nil
		}
	}
	
	static var parser: any ParserPrinter<ParserView, WordToken> {
		WordTokenParser()
	}
}

struct WordTokenParser: ParserPrinter {
	var body: some ParserPrinter<ParserView, WordToken> {
		OneOf {
			UnquotedWordTokenParser()
				.map {
					WordToken.unquoted($0)
				} reverse: {
					$0.unquoted
				}
			DoubleQuotedWordTokenParser()
				.map {
					WordToken.doubleQuoted($0)
				} reverse: {
					$0.doubleQuoted
				}
		}
	}
}

private extension UTF8.CodeUnit {
	var isUnescapedUnquotedWordStringByte: Bool {
		self != .init(ascii: #"""#) && self != .init(ascii: #"\"#) && self > .init(ascii: " ")
	}
}
