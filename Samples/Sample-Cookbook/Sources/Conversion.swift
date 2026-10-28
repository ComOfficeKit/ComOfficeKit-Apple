import Foundation
import DocumentCore
import AppleRender

// docs/guide-batch.md
enum ConversionRecipes {

    /// Folder → PDFs. One licence check up front; per-file failures are
    /// collected, not fatal.
    static func convertFolder(_ folder: URL, to output: URL) throws -> [(URL, Error)] {
        try SDKLicense.checkUnlocked()
        RenderingRecipes.registerFonts()
        var failures: [(URL, Error)] = []
        let files = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
        for file in files where ["docx", "xlsx", "xlsm", "pptx"].contains(file.pathExtension.lowercased()) {
            do {
                let doc = try RenderingRecipes.open(file)
                let pdf = output.appendingPathComponent(file.deletingPathExtension().lastPathComponent + ".pdf")
                try DocumentRenderer.pdfData(of: doc).write(to: pdf)
            } catch {
                failures.append((file, error))
            }
        }
        return failures
    }

    /// Text for a search index — no rendering, no picture decoding.
    static func indexableText(_ url: URL) throws -> String {
        switch url.pathExtension.lowercased() {
        case "docx":
            return DOCXRecipes.plainText(of: try DocumentParser.parse(docxAt: url))
        case "xlsx", "xlsm":
            let workbook = try SpreadsheetParser.parse(xlsxAt: url, rasterizer: nil)
            return workbook.sheets.map { sheet in
                sheet.cells.sorted { $0.reference < $1.reference }
                    .map { ExcelNumberFormat.string(for: $0.value, code: $0.format?.numberFormat) }
                    .joined(separator: " ")
            }.joined(separator: "\n")
        case "pptx":
            return try SlideParser.parse(pptxAt: url).map(PPTXRecipes.text(of:)).joined(separator: "\n\n")
        default:
            return ""
        }
    }

    /// Legacy binaries (.doc/.xls/.ppt) and iWork files are detected, not parsed —
    /// tell the user how to convert instead of failing on the bytes.
    static func legacyHint(_ url: URL) -> String? {
        let head = (try? FileHandle(forReadingFrom: url).readData(ofLength: 8)) ?? Data()
        guard let legacy = LegacyFormatDetector.detect(extension: url.pathExtension, leadingBytes: [UInt8](head))
        else { return nil }
        switch legacy.family {
        case .microsoftBinary: return "Save it as .docx / .xlsx / .pptx from Office first."
        case .iWork: return "Export it to Office format from Pages / Numbers / Keynote first."
        @unknown default: return "Unsupported legacy format."
        }
    }
}
