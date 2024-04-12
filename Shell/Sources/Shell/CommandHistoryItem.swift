import Foundation

public struct CommandHistoryItem: Sendable {
	public var id: Int

	public var sessionID: UUID

	public var input: String

	public var start: Date
	public var end: Date

	public var exitCode: Int

	public init(
		id: Int,
		sessionID: UUID,
		input: String,
		start: Date,
		end: Date,
		exitCode: Int
	) {
		self.id = id
		self.sessionID = sessionID
		self.input = input
		self.start = start
		self.end = end
		self.exitCode = exitCode
	}
}
