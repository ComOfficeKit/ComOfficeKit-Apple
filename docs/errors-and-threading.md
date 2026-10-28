# Errors and threading

## Errors are typed

| Thrown by | Type |
|---|---|
| `DocumentParser` / `DocumentWriter` | `DocumentParserError`, `DocumentWriterError` |
| `SpreadsheetParser` / `SpreadsheetWriter` | `SpreadsheetParserError`, `SpreadsheetWriterError` |
| `SlideParser` / `SlideWriter` | `SlideParserError`, `SlideWriterError` |
| `DocumentRenderer` | `DocumentRenderer.RenderError` |
| every entry point | `SDKLicense.SDKLicenseError` — `.notActivated`, `.invalidKey`, `.wrongProduct`, `.expired`, `.platformMismatch`, `.bundleIDMismatch`, `.featureNotLicensed`, `.versionNotLicensed`, `.noVerificationKey` ([Licensing](licensing.md)) |

Cell errors in spreadsheets (`#DIV/0!`, `#REF!`, `#VALUE!` …) are **values**, not
thrown errors: `ExcelError` converts to and from cell content.

The engine never calls `fatalError` on document input. A file it cannot read
produces a typed error naming the part and the reason.

## Threading

- Scenes (`WordDocumentScene`, `WorkbookScene`, `SlideScene`) are `Sendable`
  value types. Parse on any thread, hand the value to any other.
- Parsers, writers and the renderer are stateless static functions; they are
  safe to call concurrently on different documents. Rendering is CPU-heavy —
  keep it off the main thread.
- `SDKLicense` is thread-safe. `activate(key:)` and `activate(licenseFileAt:)`
  verify the licence on the device and return; they contact nothing.
- The frameworks are built with library evolution: their enums may gain cases in
  a later release, so exhaustive `switch`es need `@unknown default` (an error in
  Swift 6 language mode without it).

## Catch order

```swift
do {
    let scene = try DocumentParser.parse(docxAt: url)
} catch let error as SDKLicense.SDKLicenseError {
    // the one error a healthy document can throw — answer with the licence prompt
} catch let error as DocumentParserError {
    // the file: extraction failed, a part is missing, or a part's XML is invalid (named)
} catch {
    // I/O and everything else
}
```
