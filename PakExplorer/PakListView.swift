import SwiftUI
import AppKit
import Foundation

// Custom table view so we can intercept key events and implement our own
// Finder-style type-to-select behavior without triggering system beeps.
private final class PakListTableView: NSTableView {
    var onHandledKeyDown: ((NSEvent) -> Bool)?

    override func keyDown(with event: NSEvent) {
        if let handler = onHandledKeyDown, handler(event) {
            // Event was handled (or intentionally consumed) by our coordinator.
            return
        }
        super.keyDown(with: event)
    }
}

struct PakListView: NSViewRepresentable {
    var nodes: [PakNode]
    @Binding var selection: Set<PakNode.ID>
    @Binding var sortOrder: [KeyPathComparator<PakNode>]
    var viewModel: PakViewModel
    var onOpenFolder: (PakNode) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let tableView = PakListTableView()
        tableView.usesAlternatingRowBackgroundColors = true
        tableView.allowsMultipleSelection = true
        tableView.rowSizeStyle = .medium
        tableView.delegate = context.coordinator
        tableView.dataSource = context.coordinator
        tableView.action = #selector(Coordinator.tableViewSingleClicked(_:))
        tableView.doubleAction = #selector(Coordinator.tableViewDoubleClicked(_:))
        tableView.target = context.coordinator
        tableView.setDraggingSourceOperationMask(.copy, forLocal: false)

        let nameColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
        nameColumn.title = "Name"
        nameColumn.minWidth = 200
        nameColumn.isEditable = true
        nameColumn.sortDescriptorPrototype = NSSortDescriptor(
            key: "name",
            ascending: true,
            selector: #selector(NSString.localizedStandardCompare(_:))
        )
        let sizeColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("size"))
        sizeColumn.title = "Size"
        sizeColumn.minWidth = 80
        sizeColumn.sortDescriptorPrototype = NSSortDescriptor(key: "size", ascending: true)
        let typeColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("type"))
        typeColumn.title = "Type"
        typeColumn.minWidth = 120
        typeColumn.sortDescriptorPrototype = NSSortDescriptor(
            key: "type",
            ascending: true,
            selector: #selector(NSString.localizedStandardCompare(_:))
        )

        tableView.addTableColumn(nameColumn)
        tableView.addTableColumn(sizeColumn)
        tableView.addTableColumn(typeColumn)
        tableView.headerView = NSTableHeaderView()
        tableView.onHandledKeyDown = { [weak coordinator = context.coordinator] event in
            coordinator?.handleKeyDown(event) ?? false
        }

        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.documentView = tableView

        context.coordinator.tableView = tableView
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        context.coordinator.parent = self
        guard let tableView = context.coordinator.tableView else { return }
        tableView.reloadData()

        // Apply selection from SwiftUI to NSTableView
        let ids = selection
        let indexes = IndexSet(nodes.enumerated().compactMap { index, node in
            ids.contains(node.id) ? index : nil
        })
        if tableView.selectedRowIndexes != indexes {
            context.coordinator.cancelPendingRename()
            tableView.selectRowIndexes(indexes, byExtendingSelection: false)
            context.coordinator.lastSelectionChange = Date()
        } else {
            tableView.selectRowIndexes(indexes, byExtendingSelection: false)
        }
    }

    final class Coordinator: NSObject, NSTableViewDataSource, NSTableViewDelegate {
        var parent: PakListView
        weak var tableView: NSTableView?
        private var renameWorkItem: DispatchWorkItem?
        var lastSelectionChange = Date.distantPast
        private let nameColumnIdentifier = NSUserInterfaceItemIdentifier("name")
        private let typeSelectionResetInterval: TimeInterval = 1.0
        private var typeSelectionBuffer = ""
        private var lastTypeSelectionDate = Date.distantPast

        init(parent: PakListView) {
            self.parent = parent
        }

        func numberOfRows(in tableView: NSTableView) -> Int {
            parent.nodes.count
        }

        func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
            guard row >= 0 && row < parent.nodes.count else { return nil }
            let node = parent.nodes[row]
            let identifier = tableColumn?.identifier.rawValue ?? ""

            let cellIdentifier = NSUserInterfaceItemIdentifier("\(identifier)Cell")
            let cell: NSTableCellView
            if let existing = tableView.makeView(withIdentifier: cellIdentifier, owner: self) as? NSTableCellView {
                cell = existing
            } else {
                cell = NSTableCellView()
                cell.identifier = cellIdentifier
                let textField: NSTextField
                if identifier == "name" {
                    textField = NSTextField(string: "")
                    textField.isBordered = false
                    textField.isBezeled = false
                    textField.drawsBackground = false
                    textField.isEditable = true
                    textField.isSelectable = true
                    textField.lineBreakMode = .byTruncatingMiddle
                    textField.target = self
                    textField.action = #selector(nameFieldEdited(_:))
                } else {
                    textField = NSTextField(labelWithString: "")
                }
                textField.translatesAutoresizingMaskIntoConstraints = false
                cell.textField = textField
                cell.addSubview(textField)

                if identifier == "name" {
                    let imageView = NSImageView()
                    imageView.translatesAutoresizingMaskIntoConstraints = false
                    cell.imageView = imageView
                    cell.addSubview(imageView)
                    NSLayoutConstraint.activate([
                        imageView.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 4),
                        imageView.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
                        imageView.widthAnchor.constraint(equalToConstant: 16),
                        imageView.heightAnchor.constraint(equalToConstant: 16),

                        textField.leadingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: 4),
                        textField.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -4),
                        textField.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
                    ])
                } else {
                    NSLayoutConstraint.activate([
                        textField.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 4),
                        textField.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -4),
                        textField.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
                    ])
                }
            }

            if identifier == "name" {
                cell.textField?.stringValue = node.name
                cell.imageView?.image = iconImage(for: node)
            } else if identifier == "size" {
                cell.textField?.stringValue = node.formattedFileSize
            } else if identifier == "type" {
                cell.textField?.stringValue = node.fileType
            }

            return cell
        }

        private func iconImage(for node: PakNode) -> NSImage? {
            if node.isFolder {
                return NSImage(systemSymbolName: "folder.fill", accessibilityDescription: nil)
            }
            if let preview = parent.viewModel.previewImage(for: node) {
                return preview
            }
            return NSImage(systemSymbolName: "doc", accessibilityDescription: nil)
        }

        @objc private func nameFieldEdited(_ sender: NSTextField) {
            guard let tableView = tableView else { return }
            let row = tableView.row(for: sender)
            guard row >= 0, row < parent.nodes.count else { return }
            let node = parent.nodes[row]
            parent.viewModel.rename(node: node, to: sender.stringValue)
        }

        func tableViewSelectionDidChange(_ notification: Notification) {
            cancelPendingRename()
            lastSelectionChange = Date()
            guard let tableView = tableView else { return }
            let indexes = tableView.selectedRowIndexes
            var ids = Set<PakNode.ID>()
            for index in indexes {
                if index >= 0 && index < parent.nodes.count {
                    ids.insert(parent.nodes[index].id)
                }
            }
            parent.selection = ids
        }

        func tableView(_ tableView: NSTableView, shouldEdit tableColumn: NSTableColumn?, row: Int) -> Bool {
            tableColumn?.identifier == nameColumnIdentifier
        }

        func tableView(_ tableView: NSTableView, pasteboardWriterForRow row: Int) -> NSPasteboardWriting? {
            guard row >= 0 && row < parent.nodes.count else { return nil }
            let node = parent.nodes[row]
            do {
                let url = try parent.viewModel.exportToTemporaryLocation(node: node)
                return url as NSURL
            } catch {
                return nil
            }
        }

        func tableView(_ tableView: NSTableView, sortDescriptorsDidChange oldDescriptors: [NSSortDescriptor]) {
            guard let descriptor = tableView.sortDescriptors.first,
                  let key = descriptor.key else { return }

            let ascending = descriptor.ascending
            switch key {
            case "name":
                parent.sortOrder = [KeyPathComparator(\PakNode.name, order: ascending ? .forward : .reverse)]
            case "size":
                parent.sortOrder = [KeyPathComparator(\PakNode.fileSize, order: ascending ? .forward : .reverse)]
            case "type":
                parent.sortOrder = [KeyPathComparator(\PakNode.fileType, order: ascending ? .forward : .reverse)]
            default:
                break
            }
        }
        // MARK: - Type-to-select handling

        func handleKeyDown(_ event: NSEvent) -> Bool {
            guard let tableView = tableView else { return false }

            // Ignore Command/Option/Control-modified keys so shortcuts keep working.
            let modifiers = event.modifierFlags.intersection([.command, .option, .control])
            guard modifiers.isEmpty else { return false }

            guard let characters = event.charactersIgnoringModifiers, !characters.isEmpty else {
                return false
            }

            // Filter to printable ASCII characters; ignore control keys like arrows, etc.
            let scalars = characters.unicodeScalars.filter { scalar in
                guard scalar.isASCII else { return false }
                if CharacterSet.controlCharacters.contains(scalar) { return false }
                return scalar.value >= 0x20
            }
            guard !scalars.isEmpty else { return false }

            cancelPendingRename()

            let input = String(String.UnicodeScalarView(scalars)).lowercased()
            updateTypeSelectionBuffer(with: input)

            guard let match = findMatch(for: typeSelectionBuffer, in: tableView) else {
                // No match – consume the event so we don't get the system beep.
                return true
            }

            tableView.selectRowIndexes(IndexSet(integer: match), byExtendingSelection: false)
            tableView.scrollRowToVisible(match)
            return true
        }

        private func updateTypeSelectionBuffer(with input: String) {
            let now = Date()
            if now.timeIntervalSince(lastTypeSelectionDate) > typeSelectionResetInterval {
                // Too much time has passed – start a new sequence.
                typeSelectionBuffer = ""
            } else if typeSelectionBuffer.count == 1, typeSelectionBuffer == input {
                // Repeatedly pressing the same key within the interval should
                // cycle through items starting with that letter, not build a
                // longer prefix like "aa".
                typeSelectionBuffer = ""
            }

            typeSelectionBuffer += input
            lastTypeSelectionDate = now
        }

        private func findMatch(for prefix: String, in tableView: NSTableView) -> Int? {
            guard !prefix.isEmpty, !parent.nodes.isEmpty else { return nil }
            let lowerPrefix = prefix.lowercased()

            let start = max(tableView.selectedRow + 1, 0)
            if let result = search(prefix: lowerPrefix, range: start ..< parent.nodes.count) {
                return result
            }
            if start > 0, let wrapResult = search(prefix: lowerPrefix, range: 0 ..< start) {
                return wrapResult
            }
            return nil
        }

        private func search(prefix: String, range: Range<Int>) -> Int? {
            for index in range {
                if parent.nodes[index].name.lowercased().hasPrefix(prefix) {
                    return index
                }
            }
            return nil
        }

        @objc func tableViewSingleClicked(_ sender: NSTableView) {
            cancelPendingRename()

            let event = NSApp.currentEvent
            let modifiers = event?.modifierFlags ?? []
            if modifiers.contains(.command) ||
                modifiers.contains(.shift) ||
                modifiers.contains(.option) ||
                modifiers.contains(.control) {
                return
            }

            let row = sender.clickedRow
            let column = sender.clickedColumn
            let nameColumnIndex = sender.column(withIdentifier: nameColumnIdentifier)
            guard row >= 0,
                  row < parent.nodes.count,
                  nameColumnIndex != -1,
                  column == nameColumnIndex,
                  sender.selectedRowIndexes.contains(row),
                  sender.selectedRowIndexes.count == 1 else { return }

            let workItem = DispatchWorkItem { [weak self] in
                guard let self = self, let tableView = self.tableView else { return }
                guard row >= 0,
                      row < self.parent.nodes.count,
                      tableView.selectedRowIndexes.contains(row) else { return }
                let nameColumn = tableView.column(withIdentifier: self.nameColumnIdentifier)
                guard nameColumn != -1 else { return }

                if let cell = tableView.view(atColumn: nameColumn, row: row, makeIfNecessary: false) as? NSTableCellView,
                   let textField = cell.textField {
                    tableView.window?.makeFirstResponder(textField)
                    textField.selectText(nil)
                } else {
                    tableView.editColumn(nameColumn, row: row, with: event, select: true)
                }
            }
            renameWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: workItem)
        }

        @objc func tableViewDoubleClicked(_ sender: Any?) {
            cancelPendingRename()
            guard let tableView = tableView else { return }
            let row = tableView.clickedRow
            guard row >= 0 && row < parent.nodes.count else { return }
            let node = parent.nodes[row]
            if node.isFolder {
                parent.onOpenFolder(node)
            }
        }

        func cancelPendingRename() {
            renameWorkItem?.cancel()
            renameWorkItem = nil
        }
    }
}
