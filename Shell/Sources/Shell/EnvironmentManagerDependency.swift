import Dependencies
import Foundation
import OSLog
import XCTestDynamicOverlay

public struct EnvironmentChangeError: Error {
	var code: Int
}

public struct EnvironmentManagerDependency: Sendable {
	public var getEnvironment: @Sendable () -> [String: String]

	public var setEnvironment: @Sendable (_ name: String, _ value: String, _ overwrite: Bool) throws -> Void

	public var unsetEnvironment: @Sendable (_ name: String) throws -> Void

	public init(
		getEnvironment: @escaping @Sendable () -> [String: String] = unimplemented(placeholder: [:]),
		setEnvironment: @escaping @Sendable (_ name: String, _ value: String, _ overwrite: Bool) throws -> Void = unimplemented(),
		unsetEnvironment: @escaping @Sendable (_ name: String) throws -> Void = unimplemented()
	) {
		self.getEnvironment = getEnvironment
		self.setEnvironment = setEnvironment
		self.unsetEnvironment = unsetEnvironment
	}

	public var allValues: [String: String] {
		get async {
			self.getEnvironment()
		}
	}

	public subscript(name: String) -> String? {
		self.getEnvironment()[name]
	}

	public func set(name: String, value: String, overwrite: Bool = true) throws {
		try self.setEnvironment(name, value, overwrite)
	}

	public func unset(name: String) throws {
		try self.unsetEnvironment(name)
	}
}

extension EnvironmentManagerDependency: DependencyKey {
	public static let liveValue: EnvironmentManagerDependency = .init(
		getEnvironment: {
			ProcessInfo.processInfo.environment
		},
		setEnvironment: { name, value, overwrite in
			try name.withCString { name in
				try value.withCString { value in
					let result = setenv(name, value, overwrite ? 1 : 0)
					if result != 0 {
						throw EnvironmentChangeError(code: .init(errno))
					}
				}
			}
		},
		unsetEnvironment: { name in
			try name.withCString { name in
				let result = unsetenv(name)
				if result != 0 {
					throw EnvironmentChangeError(code: .init(errno))
				}
			}
		}
	)

	public static var testValue: EnvironmentManagerDependency {
		.init()
	}
}

public extension DependencyValues {
	var environment: EnvironmentManagerDependency {
		get { self[EnvironmentManagerDependency.self] }
		set { self[EnvironmentManagerDependency.self] = newValue }
	}
}
