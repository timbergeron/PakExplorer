import SwiftUI

struct ContentView: View {
    @Binding var document: PakDocument
    @StateObject private var model: PakViewModel
    @State private var selectedFileID: PakNode.ID? // Selection in the detail table

    init(document: Binding<PakDocument>) {
        self._document = document
        self._model = StateObject(wrappedValue: PakViewModel(pakFile: document.wrappedValue.pakFile))
    }

    @State private var sortOrder = [KeyPathComparator(\PakNode.name)]

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detailView
        }
    }

    private var sidebar: some View {
        List(selection: $model.currentFolder) {
            if let root = model.pakFile?.root {
                // Root node itself
                NavigationLink(value: root) {
                    Label("/", systemImage: "folder.fill")
                        .foregroundStyle(.yellow)
                }
                
                // Recursive children
                OutlineGroup(root.folderChildren ?? [], children: \.folderChildren) { node in
                    NavigationLink(value: node) {
                        Label(node.name, systemImage: "folder.fill")
                            .foregroundStyle(.yellow)
                    }
                }
            } else {
                Text("Open a Quake .pak file (File → Open PAK…)")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(minWidth: 200)
    }

    private var detailView: some View {
        VStack(spacing: 0) {
            if let folder = model.currentFolder {
                let sortedChildren = (folder.children ?? []).sorted(using: sortOrder)
                
                Table(sortedChildren, selection: $selectedFileID, sortOrder: $sortOrder) {
                    TableColumn("Name", value: \.name) { node in
                        HStack {
                            Image(systemName: node.isFolder ? "folder.fill" : "doc")
                                .foregroundStyle(node.isFolder ? .yellow : .primary)
                            Text(node.name)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture(count: 2) {
                            if node.isFolder {
                                model.currentFolder = node
                            }
                        }
                    }
                    TableColumn("Size", value: \.fileSize) { node in
                        Text(node.isFolder ? "--" : "\(node.fileSize)")
                            .monospacedDigit()
                    }
                    TableColumn("Type", value: \.fileType) { node in
                        Text(node.fileType)
                            .foregroundStyle(.secondary)
                    }
                }
                .onChange(of: selectedFileID) { newValue in
                    // Update model selection for export
                    if let id = newValue {
                        model.selectedFile = folder.children?.first(where: { $0.id == id })
                    } else {
                        model.selectedFile = nil
                    }
                }
            } else {
                Text("Select a folder in the sidebar")
                    .foregroundStyle(.secondary)
            }
        }
    }
}
