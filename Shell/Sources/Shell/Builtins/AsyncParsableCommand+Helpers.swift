import ArgumentParser
import Foundation

extension AsyncParsableCommand {
	static func run(_ arguments: [String]) async throws {
		var command = try self.parse(arguments)
		try await command.run()
	}
}
