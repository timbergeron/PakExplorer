import SwiftUI
import UniformTypeIdentifiers

struct PakDocument: FileDocument {
    var pakFile: PakFile?

    static var readableContentTypes: [UTType] {
        if let pakType = UTType(filenameExtension: "pak") {
            return [pakType]
        }
        return []
    }

    init(pakFile: PakFile? = nil) {
        self.pakFile = pakFile
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        let filename = configuration.file.filename ?? "Untitled.pak"
        self.pakFile = try PakLoader.load(data: data, name: filename)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        guard let root = pakFile?.root else {
            throw CocoaError(.fileWriteUnknown)
        }

        let result = PakWriter.write(root: root, originalData: pakFile?.data)
        pakFile?.data = result.data
        pakFile?.entries = result.entries
        pakFile?.version = UUID()

        return FileWrapper(regularFileWithContents: result.data)
    }
}
