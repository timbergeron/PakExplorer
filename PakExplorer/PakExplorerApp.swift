import SwiftUI
import AppKit

@main
struct PakExplorerApp: App {
    init() {
        if #available(macOS 10.12, *) {
            NSWindow.allowsAutomaticWindowTabbing = false
        }
    }
    
    var body: some Scene {
        DocumentGroup(newDocument: PakDocument()) { file in
            ContentView(document: file.$document)
        }
        .commands {
            // No "New" document
            CommandGroup(replacing: .newItem) {}
            
            // "Open" is handled by DocumentGroup automatically
        }
    }
}
