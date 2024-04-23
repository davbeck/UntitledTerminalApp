/// Adapted from https://github.com/migueldeicaza/SwiftTerm/blob/main/Sources/SwiftTerm/LocalProcess.swift by Miguel de Icaza

import Dependencies
import Foundation

public struct PTYProcess: Sendable {
	let fileHandle: FileHandle
	let pid: pid_t

	private let terminationTask: Task<Int32, Never>

	public func termination() async -> Int32 {
		await terminationTask.value
	}

	static func start(
		executing executable: String,
		arguments: Arguments = [],
		environment: [String: String],
		workingDirectory: URL? = nil,
		windowSize: winsize = winsize()
	) -> Self {
		@Dependency(\.fileManager) var fileManager

		let shellArgs = [arguments.executablePathOverride ?? executable] + arguments.remainingValues
		var size = windowSize

		guard let (shellPid, childfd) = PseudoTerminalHelpers.fork(
			andExec: executable,
			args: shellArgs,
			env: environment.map { "\($0.key)=\($0.value)" },
			workingDirectory: (workingDirectory ?? fileManager.currentDirectory).path(),
			desiredWindowSize: &size
		) else { fatalError() }

		let fileHandle = FileHandle(fileDescriptor: childfd)

		let terminatedTask = Task {
			await withUnsafeContinuation { continuation in
				let childMonitor = DispatchSource.makeProcessSource(
					identifier: shellPid,
					eventMask: .exit,
					queue: nil
				)
				childMonitor.setEventHandler(handler: {
					continuation.resume()
				})
				childMonitor.activate()
			}

			var exitCode: Int32 = 0
			waitpid(shellPid, &exitCode, WNOHANG)
			return exitCode
		}

		return Self(
			fileHandle: fileHandle,
			pid: shellPid,
			terminationTask: terminatedTask
		)
	}

	public func terminate() {
		kill(pid, SIGTERM)
	}
}

extension PTYProcess: PTY {
	public var output: FileHandle.AsyncBytes {
		fileHandle.bytes
	}

	public func send(_ bytes: some DataProtocol) async throws {
		// this isn't async
		// maybe use an actor with writeabilityHandler or DispatchIO.write
		try fileHandle.write(contentsOf: bytes)
	}

	public func setWindowSize(_ windowSize: winsize) {
		var windowSize = windowSize
		_ = ioctl(fileHandle.fileDescriptor, TIOCSWINSZ, &windowSize)
	}
}

// based on https://github.com/apple/swift-foundation/blob/f299bde9dff2b1ab45f360f8a6d8479f96b3bec6/Proposals/0007-swift-subprocess.md#subprocessarguments
struct Arguments: Sendable {
	var executablePathOverride: String?

	var remainingValues: [String]

	public init(_ values: [String]) {
		self.remainingValues = values
	}

	/// Overrides the first arguments (aka the executable path)
	/// with the given value. If `executablePathOverride` is nil,
	/// `Arguments` will automatically use the executable path
	/// as the first argument.
	public init(executablePathOverride: String? = nil, remainingValues: [String]) {
		self.executablePathOverride = executablePathOverride
		self.remainingValues = remainingValues
	}
}

extension Arguments: ExpressibleByArrayLiteral {
	init(arrayLiteral elements: String...) {
		self.init(executablePathOverride: nil, remainingValues: elements)
	}
}
