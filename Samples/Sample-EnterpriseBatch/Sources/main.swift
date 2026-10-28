import Foundation
import DocumentCore
import AppleRender

// Sample-EnterpriseBatch — the headless pipeline shape. Binary-only consumer.
//
//   batch render  <file>            [-o out.pdf]     every page → PDF
//   batch extract <file>                              DOCX → body text · XLSX → TSV per sheet · PPTX → slide count + notes
//   batch convert <dir> --pdf <outdir>                every .docx/.xlsx/.pptx under <dir> → PDF; exit 1 if any failed
//
// Licence: set COMOFFICEKIT_KEY to the licence your contract came with, or
// COMOFFICEKIT_LICENCE_FILE to the licence file, when you received one.
// Verification is local and immediate — nothing is sent anywhere — so this is a
// plain `try`, not an await. Without a licence the SDK build refuses every entry
// point with SDKLicenseError.notActivated (typed, never a crash) and this tool
// reports that as exit code 3.

enum Exit: Int32 { case ok = 0, failed = 1, usage = 2, licence = 3 }

private enum Fmt { static let day: ISO8601DateFormatter = { let f = ISO8601DateFormatter(); f.formatOptions = [.withFullDate]; return f }() }

func fail(_ message: String, _ code: Exit) -> Never { FileHandle.standardError.write(Data((message + "\n").utf8)); exit(code.rawValue) }

// MARK: - Licence

// A tool keeps its licence in memory: the Keychain item belongs to the binary
// that created it, so a tool sharing an app's item would be reading somebody
// else's (see docs/licensing.md).
SDKLicense.configure(SDKLicense.Configuration(), storage: .memory)

let environment = ProcessInfo.processInfo.environment
let licenceFile = environment["COMOFFICEKIT_LICENCE_FILE"].flatMap { $0.isEmpty ? nil : $0 }
let licenceKey = environment["COMOFFICEKIT_KEY"].flatMap { $0.isEmpty ? nil : $0 }
if licenceFile != nil || licenceKey != nil {
    do {
        if let file = licenceFile { try SDKLicense.activate(licenseFileAt: URL(fileURLWithPath: file)) }
        else if let key = licenceKey { try SDKLicense.activate(key: key) }
        // Only what the licence says: it may name no licensee, and the end date is the day
        // it stops working, at 00:00 UTC.
        let to = SDKLicense.licensedTo.map { " to \($0)" } ?? ""
        let until = SDKLicense.licenceExpires.map { ", until \(Fmt.day.string(from: $0)) 00:00 UTC" } ?? ""
        print("licence: active\(to)\(until)")
    } catch { fail("licence: \(error)", .licence) }
} else if SDKLicense.isEnforced {
    print("licence: no COMOFFICEKIT_KEY or COMOFFICEKIT_LICENCE_FILE in the environment — the SDK build will refuse to parse")
}

// MARK: - Parsing helpers

func parse(_ url: URL) throws -> ParsedDocument {
    switch url.pathExtension.lowercased() {
    case "docx": return .word(try DocumentParser.parse(docxAt: url))
    case "xlsx", "xlsm": return .workbook(try SpreadsheetParser.parse(xlsxAt: url, rasterizer: nil))
    case "pptx": return .slides(try SlideParser.parse(pptxAt: url))
    default: throw NSError(domain: "batch", code: 1, userInfo: [NSLocalizedDescriptionKey: "unsupported file type: \(url.lastPathComponent)"])
    }
}

func isLicenceError(_ error: Error) -> Bool { error is SDKLicense.SDKLicenseError }

func renderToPDF(_ url: URL, to out: URL) throws -> Int {
    let doc = try parse(url)
    let pages = try DocumentRenderer.pageCount(of: doc)
    try DocumentRenderer.pdfData(of: doc).write(to: out)
    return pages
}

// MARK: - Commands

let args = Array(CommandLine.arguments.dropFirst())
guard let command = args.first else { fail("usage: batch render|extract|convert …", .usage) }

do {
    switch command {
    case "render":
        guard args.count >= 2 else { fail("usage: batch render <file> [-o out.pdf]", .usage) }
        let url = URL(fileURLWithPath: args[1])
        let out = args.firstIndex(of: "-o").flatMap { args.indices.contains($0 + 1) ? URL(fileURLWithPath: args[$0 + 1]) : nil }
            ?? URL(fileURLWithPath: url.deletingPathExtension().lastPathComponent + ".pdf")
        let pages = try renderToPDF(url, to: out)
        print("\(url.lastPathComponent): \(pages) page(s) → \(out.path)")

    case "extract":
        guard args.count >= 2 else { fail("usage: batch extract <file>", .usage) }
        let url = URL(fileURLWithPath: args[1])
        switch url.pathExtension.lowercased() {
        case "docx":
            let scene = try DocumentParser.parse(docxAt: url)
            print("# \(url.lastPathComponent): \(scene.body.count) body elements, \(scene.sections.count) sections, \(scene.comments.count) comments")
            if let text = try DocumentEngine.loadWordBodyText(at: url) { print(text) }
        case "xlsx", "xlsm":
            let workbook = try DocumentEngine.loadWorkbook(at: url)     // the simple rows-of-strings model
            for sheet in workbook.sheets {
                print("# sheet: \(sheet.name)")
                for row in sheet.rows { print(row.joined(separator: "\t")) }
            }
        case "pptx":
            let slides = try SlideParser.parse(pptxAt: url)
            print("# \(url.lastPathComponent): \(slides.count) slide(s)")
            for slide in slides {
                print("slide \(slide.slideNumber): \(slide.shapes.count) shape(s)" + (slide.notes.map { " — notes: \($0.prefix(80))" } ?? ""))
            }
        default: fail("unsupported file type", .usage)
        }

    case "convert":
        guard args.count >= 2 else { fail("usage: batch convert <dir> --pdf <outdir>", .usage) }
        let dir = URL(fileURLWithPath: args[1])
        let outDir = args.firstIndex(of: "--pdf").flatMap { args.indices.contains($0 + 1) ? URL(fileURLWithPath: args[$0 + 1]) : nil } ?? dir
        try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
        let files = (FileManager.default.enumerator(at: dir, includingPropertiesForKeys: nil)?.allObjects as? [URL] ?? [])
            .filter { ["docx", "xlsx", "xlsm", "pptx"].contains($0.pathExtension.lowercased()) }
        var failed = 0
        for file in files {
            let out = outDir.appendingPathComponent(file.deletingPathExtension().lastPathComponent + ".pdf")
            do {
                let pages = try renderToPDF(file, to: out)
                print("ok   \(file.lastPathComponent) (\(pages) p)")
            } catch {
                if isLicenceError(error) { fail("licence: \(error)", .licence) }
                failed += 1; print("FAIL \(file.lastPathComponent): \(error)")
            }
        }
        print("\(files.count - failed)/\(files.count) converted → \(outDir.path)")
        if failed > 0 { exit(Exit.failed.rawValue) }

    default:
        fail("unknown command \(command)", .usage)
    }
} catch {
    if isLicenceError(error) { fail("licence: \(error)", .licence) }
    fail("error: \(error)", .failed)
}
