import Dependencies
import Foundation
import XCTestDynamicOverlay

public enum FilePresence: Sendable {
	case none
	case file
	case directory
}

public extension FileManager {
	// @DependencyClient was causing issues
	struct Value: Sendable {
		init(
			getCurrentDirectory: @Sendable @escaping () -> URL = unimplemented(placeholder: URL(fileURLWithPath: "/")),
			changeCurrentDirectory: @Sendable @escaping (_: URL) -> Bool = unimplemented(placeholder: false),
			createDirectory: @Sendable @escaping (_ at: URL, _ withIntermediateDirectories: Bool, _ attributes: [FileAttributeKey: any Sendable]?) async throws -> Void = unimplemented(),
			fileExists: @Sendable @escaping (_ at: URL) async -> FilePresence = unimplemented(placeholder: FilePresence.none),
			getHomeDirectoryForCurrentUser: @Sendable @escaping () -> URL = unimplemented(placeholder: URL(fileURLWithPath: "/"))
		) {
			self.getCurrentDirectory = getCurrentDirectory
			self.changeCurrentDirectory = changeCurrentDirectory
			self.createDirectory = createDirectory
			self.fileExists = fileExists
			self.getHomeDirectoryForCurrentUser = getHomeDirectoryForCurrentUser
		}

		@available(swift, deprecated: 9999, message: "This property has a method equivalent that is preferred for autocomplete via this deprecation. It is perfectly fine to use for overriding and accessing via '@Dependency'.")
		public var getCurrentDirectory: @Sendable () -> URL

		public var currentDirectory: URL {
			getCurrentDirectory()
		}

		@available(swift, deprecated: 9999, message: "This property has a method equivalent that is preferred for autocomplete via this deprecation. It is perfectly fine to use for overriding and accessing via '@Dependency'.")
		public var changeCurrentDirectory: @Sendable (_ path: URL) -> Bool

		public func changeCurrentDirectory(_ path: URL) -> Bool {
			self.changeCurrentDirectory(path)
		}

		@available(swift, deprecated: 9999, message: "This property has a method equivalent that is preferred for autocomplete via this deprecation. It is perfectly fine to use for overriding and accessing via '@Dependency'.")
		public var createDirectory: @Sendable (_ at: URL, _ withIntermediateDirectories: Bool, _ attributes: [FileAttributeKey: any Sendable]?) async throws -> Void

		public func createDirectory(
			at url: URL,
			withIntermediateDirectories createIntermediates: Bool,
			attributes: [FileAttributeKey: any Sendable]? = nil
		) async throws {
			try await self.createDirectory(url, createIntermediates, attributes)
		}

		@available(swift, deprecated: 9999, message: "This property has a method equivalent that is preferred for autocomplete via this deprecation. It is perfectly fine to use for overriding and accessing via '@Dependency'.")
		public var fileExists: @Sendable (_ at: URL) async -> FilePresence

		public func fileExists(at url: URL) async -> FilePresence {
			await self.fileExists(url)
		}

		@available(swift, deprecated: 9999, message: "This property has a method equivalent that is preferred for autocomplete via this deprecation. It is perfectly fine to use for overriding and accessing via '@Dependency'.")
		public var getHomeDirectoryForCurrentUser: @Sendable () -> URL

		public var homeDirectoryForCurrentUser: URL {
			getHomeDirectoryForCurrentUser()
		}
	}
}

// we want to use async wrappers on FileManager because io is inherently blocking
// we don't want to block the cooperative thread pool (the async/await runners) so we dispatch to .global
// FileManager is not sendable because it may have a delegate which isn't sendable, which makes it difficult to generalize these wrappers

extension FileManager.Value: DependencyKey {
	public static let liveValue: FileManager.Value = .init(
		getCurrentDirectory: {
			URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
		},
		changeCurrentDirectory: { directory in
			FileManager.default.changeCurrentDirectoryPath(directory.path())
		},
		createDirectory: { url, createIntermediates, attributes in
			try await withCheckedThrowingContinuation { continuation in
				DispatchQueue.global().async {
					do {
						try FileManager.default.createDirectory(
							at: url,
							withIntermediateDirectories: createIntermediates,
							attributes: attributes
						)
						continuation.resume()
					} catch {
						continuation.resume(throwing: error)
					}
				}
			}
		},
		fileExists: { url in
			await withCheckedContinuation { continuation in
				DispatchQueue.global().async {
					var isDirectory: ObjCBool = false
					let exists = FileManager.default.fileExists(atPath: url.path(), isDirectory: &isDirectory)
					if exists {
						if isDirectory.boolValue {
							continuation.resume(returning: .directory)
						} else {
							continuation.resume(returning: .file)
						}
					} else {
						continuation.resume(returning: .none)
					}
				}
			}
		},
		getHomeDirectoryForCurrentUser: {
			FileManager.default.homeDirectoryForCurrentUser
		}
	)

	public static let testValue: FileManager.Value = .init()
}

public extension DependencyValues {
	var fileManager: FileManager.Value {
		get { self[FileManager.Value.self] }
		set { self[FileManager.Value.self] = newValue }
	}
}
