import Foundation

public protocol CommandHistoryItem: Sendable {
	var input: String { get }
	
	var start: Date { get }

	var end: Date { get }

	var exitCode: Int { get }
}

extension Item: CommandHistoryItem {
	public var start: Date {
		Date(timeIntervalSince1970: self.startTimestamp)
	}

	public var end: Date {
		Date(timeIntervalSince1970: self.endTimestamp)
	}
}
