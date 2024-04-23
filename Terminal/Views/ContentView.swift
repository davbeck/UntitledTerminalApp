import Shell
import SwiftUI

@MainActor
struct ContentView: View {
	@State private var session = SessionCoordinator()

	var body: some View {
		NavigationSplitView {
			FileNavigationSidebar(directory: session.storage.currentDirectory)
		} detail: {
			VStack(spacing: 0) {
				LocalProcessTerminalView()
					.clipped()

				PromptView()
			}
		}
		.environment(session)
	}
}

#Preview {
	ContentView()
}
