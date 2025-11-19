import SwiftUI
import AppKit
import Combine
import UniformTypeIdentifiers

final class PakViewModel: ObservableObject {
    @Published var pakFile: PakFile?
    @Published var currentFolder: PakNode? // Directory shown in right pane
    @Published var selectedFile: PakNode?  // File selected in right pane

    init(pakFile: PakFile?) {
        self.pakFile = pakFile
        self.currentFolder = pakFile?.root
    }


    // Export the currently-selected file
    func exportSelectedFile() {
        guard let pakFile = pakFile,
              let entry = selectedFile?.entry else { return }

        let save = NSSavePanel()
        save.nameFieldStringValue = URL(fileURLWithPath: entry.name).lastPathComponent

        save.begin { response in
            guard response == .OK, let outURL = save.url else { return }
            do {
                let range = entry.offset ..< (entry.offset + entry.length)
                let data = pakFile.data.subdata(in: range)
                try data.write(to: outURL)
            } catch {
                let alert = NSAlert(error: error)
                alert.runModal()
            }
        }
    }
}

