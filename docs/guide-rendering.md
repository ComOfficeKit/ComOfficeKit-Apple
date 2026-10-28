# Rendering

One entry point for all three formats. Samples are functions in
[`Samples/Sample-Cookbook/Sources/Rendering.swift`](../Samples/Sample-Cookbook/Sources/Rendering.swift).

```swift
import AppleRender

let doc: ParsedDocument = .word(scene)          // or .workbook(workbook) / .slides(slides)

let count = try DocumentRenderer.pageCount(of: doc)
let image = try DocumentRenderer.image(of: doc, page: 0, scale: 2)        // CGImage; scale 1 = 72 dpi
let pdf   = try DocumentRenderer.pdfData(of: doc, pages: nil)             // nil = every page
```

## What a page is

| Format | Page | Comes from |
|---|---|---|
| DOCX | a laid-out page | the CoreText layout engine: sections, margins, floats, tables, text boxes and shapes, headers/footers, footnotes, widow/orphan control, East-Asian document grid, default tab stops |
| XLSX | one printed page of one sheet | print pagination: paper size and orientation, `scale` or fit-to-page, print areas, manual row/column breaks, hidden rows and columns; cells, gridlines and charts are painted (sheet pictures and shapes are not, yet) |
| PPTX | one slide | the slide's own size; hidden slides are rendered (skip them with `isHidden` if you want PowerPoint's slideshow behaviour) |

Page indices are 0-based; `pageOutOfRange` names both the request and the
count.

## Images and thumbnails

`image(of:page:scale:)` returns a `CGImage` in sRGB with premultiplied alpha.
`scale` multiplies the page's point size: 2 for Retina, 0.5 for a 36-dpi
thumbnail grid.

```swift
let count = try DocumentRenderer.pageCount(of: doc)
for page in 0..<count {
    let image = try DocumentRenderer.image(of: doc, page: page, scale: 0.5)
    try writePNG(image, to: directory.appendingPathComponent("page-\(page + 1).png"))
}
```

```swift
guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)
else { throw CocoaError(.fileWriteUnknown) }
CGImageDestinationAddImage(destination, image, nil)
guard CGImageDestinationFinalize(destination) else { throw CocoaError(.fileWriteUnknown) }
```

## PDF

`pdfData` draws each page into a PDF graphics context: the output is vector,
text is real text (selectable, searchable), each page keeps its own media box,
and pictures are embedded rather than re-rasterised into the page.

```swift
try DocumentRenderer.pdfData(of: doc).write(to: url)                       // every page
let firstThree = try DocumentRenderer.pdfData(of: doc, pages: 0..<min(3, count))
```

## Fonts

Layout fidelity depends on metrics. Carlito (≙ Calibri) and Caladea
(≙ Cambria) ship inside `AppleRender.framework`; register them once before the
first render:

```swift
_ = FontRegistration.ensure    // finds them inside AppleRender.framework
```

Other families resolve through the system with a CJK-aware fallback cascade.
Missing fonts degrade to a system face — never a crash — so a document that
looks different from Word on a machine without the bundle is the first thing
to check.

## Threading and cost

Rendering is synchronous and CPU-bound. `ParsedDocument` and the scenes are
`Sendable` values, so several pages of the same document can render
concurrently and none of it needs the main thread:

```swift
static func renderOffMain(_ doc: ParsedDocument, page: Int) async throws -> CGImage {
    try await Task.detached(priority: .userInitiated) {
        try DocumentRenderer.image(of: doc, page: page, scale: 2)
    }.value
}
```

Layout is computed per call: `pageCount` lays the document out, and each
`image` call lays it out again. For a viewer that renders many pages of one
document, keep the `ParsedDocument` and render pages on demand; for DOCX you
can also run `try WordLayoutEngine.layout(scene)` yourself once and paint from
the `WordLayout` it returns — its pages, lines and runs carry frames,
baselines, fonts and colours, so a custom painter draws from geometry rather
than re-laying out. Like every other entry point it is gated, so it throws
`SDKLicense.SDKLicenseError` when no licence is active. More in
[Performance](performance.md).

## Colour

Everything is drawn in sRGB; hex colours in the model are sRGB; output images
carry an sRGB colour space.

## Errors

`DocumentRenderer.RenderError`: `pageOutOfRange(requested:available:)`,
`nothingToRender` (an empty document), `rasterizationFailed(page:)`,
`backendNotImplemented(format:plannedIn:)` — plus the licence errors. See
[Errors and threading](errors-and-threading.md).

## Empty documents

A workbook with no cell content lays out to **zero pages**: `pageCount(of:
.workbook(_))` returns 0 and `pdfData` throws. That is the sheet having no
print area, not a failure — a blank DOCX or PPTX is one page. Put a value in
a cell before you test export.
