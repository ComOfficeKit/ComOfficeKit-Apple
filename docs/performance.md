# Performance

What costs what, and the switches that avoid paying for what you do not need.

## Parsing

- **Stream what the user sees first.** `SlideParser.parse(pptxAt:onSlide:)`
  hands over each slide as it is parsed; `SpreadsheetParser.parse(xlsxAt:onActiveSheet:)`
  hands over the active sheet before the rest of the workbook. Show those,
  keep parsing in the background.
- **Skip picture decoding when you only want data.** `SpreadsheetParser.parse(xlsxAt:rasterizer: nil)`
  leaves EMF/WMF metafiles undecoded; text extraction and indexing never need
  them.
- **Parse once, keep the value.** Scenes are `Sendable` structs. A viewer keeps
  the `ParsedDocument`; an editor keeps a stack of scenes for undo — copies
  share storage until mutated.
- **XML work is libxml2 in-process**, ZIP work is in-process too: no
  subprocess, no temp-file round trips beyond the package extraction, which is
  removed after parsing.

## Rendering

- **Scale is the lever.** Thumbnails at `scale: 0.5` cost a quarter of the
  pixels of `scale: 1` and a sixteenth of Retina. Render the visible page at
  2× and the rest at what the grid shows.
- **Layout is per call.** `pageCount` lays the document out; each `image` call
  does too. For DOCX viewers that paint many pages of one document, run
  `try WordLayoutEngine.layout(scene)` once and paint from the `WordLayout`;
  for workbooks and decks the per-page cost is small.
- **PDF is one pass** for every page — prefer `pdfData(of:)` over rendering
  page images and assembling a PDF yourself.
- **Off the main thread, in parallel.** Rendering is synchronous and CPU-bound;
  `ParsedDocument` is a value, so pages render concurrently.

## Editing

Every edit returns a new scene; the cost is proportional to the edited element,
not the document, and the writer regenerates only edited elements on save.
Batch many `WorkbookSceneEditor.setting…` calls before saving rather than
saving after each.

## Saving

Byte-preserving saves copy untouched parts from the original file — the cost is
I/O on the package size plus regeneration of what changed. Saving always reads
the original, so keep it reachable (security-scoped access on macOS sandboxed
apps).

## Memory

Scenes hold text and structure, not pixels; pictures live on disk in the media
cache and are decoded when painted. Rendered `CGImage`s are yours to cache or
drop — the SDK keeps none.
