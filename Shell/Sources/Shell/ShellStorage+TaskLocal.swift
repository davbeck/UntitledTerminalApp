import Foundation

extension ShellDriver {
	@TaskLocal
	static var currentShellStorage: (any ShellStorage) = ProcessShellStorage()
}
