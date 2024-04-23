import Dependencies
import Foundation
import Observation

public struct ShellContext: Sendable {
	var environment: [String: String]
	var currentDirectory: URL
}

// this protocol is defined using async calls so that we can use MainActor

public protocol ShellStorage: Sendable {
	func getEnvironment() async -> [String: String]

	func setEnvironment(name: String, value: String, overwrite: Bool) async throws

	func unsetEnvironment(name: String) async throws

	func getCurrentDirectory() async -> URL

	func changeCurrentDirectory(_ url: URL) async -> Bool

	// this is used to get all values needed to execute a child process in 1 async call
	var context: ShellContext { get async }
}

@MainActor
@Observable
public class ObservableShellStorage: ShellStorage {
	public var context: ShellContext

	public var environment: [String: String] {
		get {
			context.environment
		}
		set {
			context.environment = newValue
		}
	}

	public func getEnvironment() -> [String: String] {
		environment
	}

	public func setEnvironment(name: String, value: String, overwrite: Bool) {
		if overwrite || environment[name] == nil {
			environment[name] = value
		}
	}

	public func unsetEnvironment(name: String) {
		environment[name] = nil
	}

	public var currentDirectory: URL {
		get {
			context.currentDirectory
		}
		set {
			context.currentDirectory = newValue
		}
	}

	public func getCurrentDirectory() async -> URL {
		currentDirectory
	}

	public func changeCurrentDirectory(_ url: URL) async -> Bool {
		currentDirectory = url
		return true
	}

	public init(context: ShellContext) {
		self.context = context
	}

	public convenience init(environment: [String: String] = [:], currentDirectory: URL) {
		self.init(context: .init(
			environment: environment,
			currentDirectory: currentDirectory
		))
	}
}

public struct ProcessShellStorage: ShellStorage {
	@Dependency(\.fileManager) private var fileManager
	@Dependency(\.environment) private var environment

	public func getEnvironment() -> [String: String] {
		environment.getEnvironment()
	}

	public func setEnvironment(name: String, value: String, overwrite: Bool) throws {
		try environment.set(name: name, value: value, overwrite: overwrite)
	}

	public func unsetEnvironment(name: String) throws {
		try environment.unset(name: name)
	}

	public func getCurrentDirectory() -> URL {
		fileManager.currentDirectory
	}

	public func changeCurrentDirectory(_ url: URL) -> Bool {
		fileManager.changeCurrentDirectory(url)
	}

	public var context: ShellContext {
		get async {
			.init(
				environment: self.getEnvironment(),
				currentDirectory: self.getCurrentDirectory()
			)
		}
	}
}
