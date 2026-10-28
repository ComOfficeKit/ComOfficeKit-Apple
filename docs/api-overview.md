# API overview

The map of what is public, which type does what, and the conventions that hold
across the whole surface. Full signatures are in the DocC archives attached to
each release.

## Two modules

![Architecture](images/architecture.svg)


```
DocumentCore  (Foundation + CoreGraphics)        AppleRender  (CoreText + CoreGraphics + ImageIO)
├─ Parsers     DocumentParser · SpreadsheetParser · SlideParser        ├─ DocumentRenderer   pageCount / image / pdfData
├─ Scenes      WordDocumentScene · WorkbookScene · SlideScene          ├─ ParsedDocument     .word / .workbook / .slides
├─ Editors     WordSceneEditor · WorkbookSceneEditor · replacing… helpers   ├─ FontRegistration   the bundled fonts
├─ Writers     DocumentWriter · SpreadsheetWriter · SlideWriter        ├─ WordLayoutEngine   pages, lines, runs (for custom painters)
├─ Formulas    Formula · SceneWorkbookContext · WorkbookRecalc · ExcelNumberFormat   └─ WordLayoutHitTest  caret ↔ point (editors)
├─ Licence     SDKLicense
├─ Extras      WordDocumentSceneJSON · CSVCodec · CSVToWorkbookConverter · LegacyFormatDetector · MiniZip
└─ Convenience DocumentEngine (flat text-level loaders)
```

`DocumentCore` has 169 public top-level types; most are the scene model — the
structs a parsed document is made of. `AppleRender` has six.

## Which type for which task

| I want to… | Use |
|---|---|
| open a `.docx` | `DocumentParser.parse(docxAt:)` → `WordDocumentScene` |
| open a `.xlsx` / `.xlsm` | `SpreadsheetParser.parse(xlsxAt:)` (with `AppleRender`, decodes EMF/WMF pictures) or `parse(xlsxAt:rasterizer:onActiveSheet:)` → `WorkbookScene` |
| open a `.pptx` | `SlideParser.parse(pptxAt:onSlide:)` → `[SlideScene]` |
| get plain text | walk `scene.body` / `sheet.cells` / `slide.shapes` — samples in each guide |
| find and replace in Word | `WordSceneEditor.findMatches` · `replaceAll` |
| type, delete, format, insert in Word | `WordSceneEditor` (positions are `WordScenePosition`; results are `WordSceneEdit` = new scene + caret) |
| comments and tracked changes | `WordDocumentScene.addingComment` · `addingReply` · `replacingComment` · `resolvingRevision` · `resolvingAllRevisions` |
| compare two Word documents | `WordDocumentComparer.compare(original:revised:author:date:)` → `WordDocumentComparison` (the revised scene with tracked changes) · `write(_:revisedPackage:to:)`; any two strings: `TextDiff.diff(old:new:options:)` |
| set a cell without losing its style | `WorkbookSceneEditor.settingCellValue(_:formula:at:sheetIndex:in:)` |
| change fonts, fills, number formats, widths | `WorkbookSceneEditor.setting…` family |
| insert / delete rows and columns, merges, freeze panes, sheets | mutating methods on `WorkbookScene` (`insertRow`, `deleteColumn`, `setMergedRanges`, `setFrozenRows`, `appendSheet`, `removeSheet`) |
| evaluate a formula | `Formula.evaluate(_:in:)` with `SceneWorkbookContext` |
| recalculate what the user typed before saving | `WorkbookRecalc.writingBackUserFormulaValues` |
| format a cell value the way Excel shows it | `ExcelNumberFormat.string(for:code:)` |
| edit slide text or geometry | `SlideShape.replacingContent` · `replacingFrame`; `TextContent` / `Paragraph` / `TextRun` `replacing…` |
| add, duplicate, delete, reorder slides | edit the `[SlideScene]` array; new slides have `sourcePartName == nil` |
| insert or swap a picture on a slide | `PendingPictureInsertion` / `PendingPictureReplacement` passed to `SlideWriter.save` |
| save | `DocumentWriter.save` · `SpreadsheetWriter.save` · `SlideWriter.save` — always against the original file |
| render pages, thumbnails, PDF | `DocumentRenderer` on a `ParsedDocument` |
| register the fonts | `FontRegistration.ensure` |
| activate / check the licence | `SDKLicense` — `activate(key:)` and `activate(licenseFileAt:)` are local and throwing; no network |
| turn CSV into a workbook | `CSVCodec.parse` + `CSVToWorkbookConverter.writeXLSX` |
| recognise `.doc` / `.xls` / `.ppt` / iWork before trying to parse | `LegacyFormatDetector.detect(extension:leadingBytes:)` |
| hand a document's structure to an LLM or a search index | `WordDocumentSceneJSON` (Codable) |

## Conventions

**Scenes are values.** `WordDocumentScene`, `WorkbookScene`, `SlideScene` and
everything inside them are `Sendable` structs. Parse on one thread, render on
another, keep several versions for undo — nothing is shared or mutable behind
your back.

**Editing returns a new scene.** Editors never mutate in place. Word editing
returns `WordSceneEdit?` (the new scene plus where the caret lands); workbook
editing returns `WorkbookScene?`; slide types have `replacing…` methods that
return copies. `nil` means "that position or index does not exist" — nothing
was changed.

**Writers are byte-preserving.** Every scene element carries the XML it was
parsed from (`sourceXML`, `sourceRPrXML`, `sourcePPrXML`, …). On save the
writer copies that verbatim for anything you did not touch and regenerates only
what you changed. Saving always needs the original file — it is the source of
every untouched byte.

**Identity fields.** `id: UUID` on paragraphs, runs, sheets, slides is
per-parse (fresh each time you parse the file) and is what editors address.
`source*` fields (`sourcePartName`, `sourceDrawingPart`, `sourceAnchorIndex`,
`sourceChartRelId`) are the object's identity *on disk*; they are `nil` for
anything created in the editor, which is how the writer knows to synthesise a
part.

**Units.** DOCX measurements are in twips (1/20 pt) exactly as OOXML stores
them, points where the API says `Pt`; XLSX widths are in character units and
row heights in points; drawing anchors are in EMU (12,700 per point); PPTX and
layout output are in points. Colours are 6-character `RRGGBB` hex, uppercase.

**Enums are resilient.** The frameworks are built with library evolution, so a
later release may add cases. Exhaustive `switch`es need `@unknown default`
(Swift 6 makes this an error).

**Errors are typed.** Each parser and writer has its own error enum; the
renderer has `DocumentRenderer.RenderError`; the licence gate throws
`SDKLicense.SDKLicenseError`. The engine never `fatalError`s on document input.

**Licence gate.** Parsers, writers, the renderer and `WordLayoutEngine.layout`
call the gate on entry — every public entry point that produces engine output
does, so any of them can throw `SDKLicense.SDKLicenseError`.
`SDKLicense.checkUnlocked()` lets a batch fail fast before the first document.

## The `DocumentEngine` facade

`DocumentEngine` is a small convenience surface for text-level access:
`loadWorkbook(at:)` → `SpreadsheetWorkbook` (sheets of `[[String]]`),
`loadPresentation(at:)` → `[PresentationSlide]` (title + text),
`loadWordBodyText(at:)`, `evaluateFormula(_:in:)`, `documentKind(forExtension:)`.
It is the right tool when all you need is the words. Everything structural —
formatting, layout, editing that round-trips — lives in the scene APIs above.
