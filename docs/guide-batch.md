# Batch and server-side use

The pipeline shape: a headless process converts, extracts or validates many
documents. Samples are functions in
[`Samples/Sample-Cookbook/Sources/Conversion.swift`](../Samples/Sample-Cookbook/Sources/Conversion.swift);
[`Sample-EnterpriseBatch`](../Samples/Sample-EnterpriseBatch) is a complete tool.

## Setup for a tool

```swift
SDKLicense.configure(SDKLicense.Configuration(), storage: .memory)   // tools: no Keychain (see Licensing)
try SDKLicense.activate(key: ProcessInfo.processInfo.environment["COMOFFICEKIT_KEY"] ?? "")
try SDKLicense.checkUnlocked()                                       // fail fast, before the first file
_ = FontRegistration.ensure                                          // the fonts inside AppleRender.framework
```

## Folder → PDFs

```swift
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
```

Per-file failures are collected, not fatal: a corrupt document produces a typed
parser error naming the part; the batch continues.

## Text for a search index

No rendering, no picture decoding (`rasterizer: nil`):

```swift
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
```

For DOCX pipelines that need structure rather than a string, encode
`WordDocumentSceneJSON` — [Structure as JSON](structure-json.md).

## Legacy formats

`.doc`, `.xls`, `.ppt` and iWork files are detected, not parsed; tell the user
how to convert instead of failing on the bytes. The detector also catches a
`.docx` whose bytes are really an old binary file.

```swift
let head = (try? FileHandle(forReadingFrom: url).readData(ofLength: 8)) ?? Data()
guard let legacy = LegacyFormatDetector.detect(extension: url.pathExtension, leadingBytes: [UInt8](head))
else { return nil }
switch legacy.family {
case .microsoftBinary: return "Save it as .docx / .xlsx / .pptx from Office first."
case .iWork: return "Export it to Office format from Pages / Numbers / Keynote first."
@unknown default: return "Unsupported legacy format."
}
```

## Exit codes and errors

`Sample-EnterpriseBatch` uses: `0` success · `1` any document failed · `2`
usage · `3` licence. Licence errors are worth their own code — they mean
"configure the machine", not "the file is bad".

## Concurrency

Parsers, writers and the renderer are stateless static functions over value
types: run them on several documents at once from a `TaskGroup` or
`DispatchQueue.concurrentPerform`. Rendering is CPU-bound, so size the
parallelism to cores, not to files. Keep one `SDKLicense` activation per
process.

## Where documents go

Nothing leaves the process. Parsing extracts the package to a temporary
directory it removes afterwards; pictures are cached under a per-document
directory (`MediaCache.directory(namespace:source:)`) so a scene's
`mediaURL`s stay valid after parsing. The SDK makes no network calls at all —
the licence is verified on the device.
