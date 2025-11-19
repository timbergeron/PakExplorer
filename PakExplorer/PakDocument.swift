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
        // For now, we only support reading. 
        // If we wanted to save, we'd return FileWrapper(regularFileWithContents: pakFile?.data ?? Data())
        // But since we don't support editing the PAK structure yet, let's just return the original data if available.
        if let data = pakFile?.data {
            return FileWrapper(regularFileWithContents: data)
        } else {
            throw CocoaError(.fileWriteUnknown)
        }
    }
}
