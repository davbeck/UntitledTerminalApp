import Foundation
import Parsing

public struct CommandSyntax: ParserPrinterSyntax {
	public private(set) var executable: WordToken

	public private(set) var arguments: [WordToken]
	
	static var parser: any ParserPrinter<ParserView, CommandSyntax> {
		CommandSyntaxParser()
	}
}

struct CommandSyntaxParser: ParserPrinter {
	var body: some ParserPrinter<ParserView, CommandSyntax> {
		Parse {
			WordTokenParser()
			
			Whitespace()

			Many {
				WordTokenParser()
			} separator: {
				Whitespace()
			}
		}
		.map {
			CommandSyntax(
				executable: $0,
				arguments: $1
			)
		} reverse: {
			($0.executable, $0.arguments)
		}
	}
}
