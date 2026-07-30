import SwiftUI

@main
struct ProResQCInspectorApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About Media QC Inspector") {
                    AboutPanelController.shared.show()
                }
            }
        }
    }
}
