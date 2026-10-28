import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import DocumentCore
import AppleRender

// docs/guide-rendering.md
enum RenderingRecipes {

    /// Once per process. Registers the fonts that ship inside
    /// `AppleRender.framework`; without them layout falls back to system fonts.
    static func registerFonts() { _ = FontRegistration.ensure }

    static func open(_ url: URL) throws -> ParsedDocument {
        switch url.pathExtension.lowercased() {
        case "docx": return .word(try DocumentParser.parse(docxAt: url))
        case "xlsx", "xlsm": return .workbook(try SpreadsheetParser.parse(xlsxAt: url))
        case "pptx": return .slides(try SlideParser.parse(pptxAt: url))
        default: throw CocoaError(.fileReadUnsupportedScheme)
        }
    }

    /// One page per DOCX page, per printed XLSX page, per slide.
    static func thumbnails(_ doc: ParsedDocument, into directory: URL) throws {
        let count = try DocumentRenderer.pageCount(of: doc)
        for page in 0..<count {
            let image = try DocumentRenderer.image(of: doc, page: page, scale: 0.5)   // 0.5 → 36 dpi; 2 → Retina
            try writePNG(image, to: directory.appendingPathComponent("page-\(page + 1).png"))
        }
    }

    static func pdf(_ doc: ParsedDocument, to url: URL) throws {
        try DocumentRenderer.pdfData(of: doc).write(to: url)                          // every page
    }

    static func firstThreePagesPDF(_ doc: ParsedDocument) throws -> Data {
        let count = try DocumentRenderer.pageCount(of: doc)
        return try DocumentRenderer.pdfData(of: doc, pages: 0..<min(3, count))
    }

    /// Rendering is synchronous and CPU-bound: keep it off the main thread.
    /// Scenes are values, so several pages can render concurrently.
    static func renderOffMain(_ doc: ParsedDocument, page: Int) async throws -> CGImage {
        try await Task.detached(priority: .userInitiated) {
            try DocumentRenderer.image(of: doc, page: page, scale: 2)
        }.value
    }

    static func writePNG(_ image: CGImage, to url: URL) throws {
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)
        else { throw CocoaError(.fileWriteUnknown) }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { throw CocoaError(.fileWriteUnknown) }
    }
}
