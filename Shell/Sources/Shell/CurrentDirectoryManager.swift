import ConcurrencyExtras
import Dependencies
import Foundation
import XCTestDynamicOverlay

public struct CurrentDirectoryManager: Sendable {
	private var _currentDirectory: @Sendable () async -> URL
	private var _changeCurrentDirectory: @Sendable (_ path: URL) async -> Bool

	public init(
		currentDirectory: @Sendable @escaping () async -> URL,
		changeCurrentDirectory: @Sendable @escaping (_ path: URL) async -> Bool
	) {
		self._currentDirectory = currentDirectory
		self._changeCurrentDirectory = changeCurrentDirectory
	}

	public init(_ fileManager: FileManager) {
		self.init(
			currentDirectory: {
				URL(filePath: fileManager.currentDirectoryPath)
			},
			changeCurrentDirectory: { path in
				fileManager.changeCurrentDirectoryPath(path.path())
			}
		)
	}

	public var currentDirectory: URL {
		get async {
			await _currentDirectory()
		}
	}

	@discardableResult
	public func changeCurrentDirectory(_ path: URL) async -> Bool {
		await _changeCurrentDirectory(path)
	}
}

extension CurrentDirectoryManager: DependencyKey {
	public static let liveValue: CurrentDirectoryManager = .init(.default)

	public static let previewValue: CurrentDirectoryManager = {
		let currentDirectory = ActorIsolated(URL(filePath: "/Users/previews", directoryHint: .isDirectory))
		return .init {
			await currentDirectory.value
		} changeCurrentDirectory: { url in
			await currentDirectory.setValue(url)
			return true
		}
	}()

	public static let testValue: CurrentDirectoryManager = .init(
		currentDirectory: unimplemented(placeholder: URL(fileURLWithPath: "/")),
		changeCurrentDirectory: unimplemented(placeholder: false)
	)
}

extension DependencyValues {
	var currentDirectoryManager: CurrentDirectoryManager {
		get { self[CurrentDirectoryManager.self] }
		set { self[CurrentDirectoryManager.self] = newValue }
	}
}
