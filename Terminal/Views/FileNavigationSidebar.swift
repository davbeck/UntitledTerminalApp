import SwiftUI

private let resourceKeys: Set<URLResourceKey> = [
	.isDirectoryKey,
	.isSymbolicLinkKey,
	.isRegularFileKey,
	.isHiddenKey,
]

struct FileNavigationSidebar: View {
	var directory: URL

	@State private var contents: [URL] = []
	@State private var error: Swift.Error?

	var sortedContent: [URL] {
		contents
			.filter { (try? $0.resourceValues(forKeys: resourceKeys).isHidden) == false }
			.sorted(using: KeyPathComparator(\.lastPathComponent))
	}

	var body: some View {
		List {
			if let error {
				Label(
					title: { Text(error.localizedDescription) },
					icon: { Image(systemName: "42.circle") }
				)
				.foregroundStyle(Color.red)
			}

			ForEach(sortedContent, id: \.self) { url in
				let resourceValues = try? url.resourceValues(forKeys: resourceKeys)
				if resourceValues?.isDirectory == true {
					FileNavigationDirectory(directory: url)
				} else {
					Text(url.lastPathComponent)
				}
			}
		}
		.listStyle(.sidebar)
		.task(id: directory) {
			print("starting", directory)
			do {
				contents = try FileManager.default.contentsOfDirectory(
					at: directory.standardizedFileURL,
					includingPropertiesForKeys: .init(resourceKeys)
				)
				print("done", directory, contents)
				self.error = nil
			} catch {
				print(error, directory)
				self.error = error
			}
		}
	}
}

struct FileNavigationDirectory: View {
	var directory: URL

	@State private var contents: [URL] = []
	@State private var error: Swift.Error?
	@State private var showContent = false

	var body: some View {
		DisclosureGroup(
			directory.lastPathComponent,
			isExpanded: $showContent
		) {
			if let error {
				Label(
					title: { Text(error.localizedDescription) },
					icon: { Image(systemName: "42.circle") }
				)
				.foregroundStyle(Color.red)
			}

			ForEach(contents, id: \.self) { url in
				let resourceValues = try? url.resourceValues(forKeys: resourceKeys)
				if resourceValues?.isDirectory == true {
					FileNavigationDirectory(directory: url)
				} else {
					Text(url.lastPathComponent)
				}
			}
		}
		.task(id: directory) {
			do {
				contents = try FileManager.default.contentsOfDirectory(
					at: directory,
					includingPropertiesForKeys: .init(resourceKeys),
					options: [.producesRelativePathURLs]
				)
				self.error = nil
			} catch {
				self.error = error
			}
		}
	}
}

// #Preview {
//	FileNavigationSidebar()
// }
