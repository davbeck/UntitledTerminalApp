import SwiftUI

@MainActor
struct ContentView: View {
	@State private var shell = Shell()

	var body: some View {
		NavigationSplitView {
			FileNavigationSidebar(directory: shell.workingDirectory)
		} detail: {
			VStack(spacing: 0) {
				LocalProcessTerminalView(shell: shell)
					.clipped()

				PromptView(shell: shell)
			}
		}
	}
}

#Preview {
	ContentView()
}
