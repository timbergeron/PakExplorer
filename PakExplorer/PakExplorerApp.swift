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
            ContentView(document: file.$document, fileURL: file.fileURL)
        }
        .commands {
            // No "New" document
            CommandGroup(replacing: .newItem) {}
            PakSaveCommands()
            // "Open" is handled by DocumentGroup automatically
        }
    }
}

struct PakSaveCommands: Commands {
    @FocusedValue(\.pakCommands) private var pakCommands
    
    var body: some Commands {
        CommandGroup(replacing: .saveItem) {
            Button("Save") {
                pakCommands?.save()
            }
            .keyboardShortcut("S")
            .disabled(!(pakCommands?.canSave ?? false))
        }
        CommandGroup(after: .saveItem) {
            Button("Save As…") {
                pakCommands?.saveAs()
            }
            .keyboardShortcut("S", modifiers: [.command, .shift])
            .disabled(pakCommands == nil)
        }
    }
}
