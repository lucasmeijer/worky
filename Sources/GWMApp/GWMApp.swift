import SwiftUI

@main
struct GWMApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: AppDependencies.makeViewModel())
        }
        .windowStyle(.hiddenTitleBar)
    }
}
