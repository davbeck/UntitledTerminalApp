import Foundation

public protocol PTY {
	var output: FileHandle.AsyncBytes { get }

	func send(_ bytes: some DataProtocol & Sendable) async throws

	func setWindowSize(_ windowSize: winsize) async
}
