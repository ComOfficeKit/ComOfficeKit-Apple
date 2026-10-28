# XLSX

`SpreadsheetParser` turns a `.xlsx` or `.xlsm` into a `WorkbookScene`;
`WorkbookSceneEditor` and the scene's mutating methods derive edited scenes;
`SpreadsheetWriter` writes back over the original, byte-preserving.
`Formula` evaluates against a scene. Samples are functions in
[`Samples/Sample-Cookbook/Sources/XLSX.swift`](../Samples/Sample-Cookbook/Sources/XLSX.swift).

## The model in one screen

```
WorkbookScene   sheets · activeSheetIndex · hasMacros
└─ SheetScene   name · visibility · cells · rows · columns · mergedRanges · frozenRows/Columns
                charts · drawings · tables · pivotRegions · conditionalRules · pageSetup · printArea · rowBreaks · colBreaks
   └─ Cell      reference (CellReference: column, row — 1-based) · value (CellValue) · formula · format (CellFormat)
      CellValue  .empty | .number | .string | .boolean | .date | .error("#DIV/0!")
      CellFormat font · fill · borders · numberFormat · alignment
```

Cells are sparse: only cells with content or formatting exist. References are
1-based like A1 notation (`CellReference(a1: "B7")`, `ref.a1`); ranges are
`CellRange(a1Range: "A1:D10")`.

## Open

```swift
import DocumentCore
import AppleRender   // adds SpreadsheetParser.parse(xlsxAt:) with the EMF/WMF rasteriser

let workbook = try SpreadsheetParser.parse(xlsxAt: url)
```

With `AppleRender` imported, this overload rasterises metafile pictures inside
drawings. `SpreadsheetParser.parse(xlsxAt:rasterizer: nil)` skips them — the
right choice for text extraction and for non-Apple hosts.

Large files: the active sheet arrives first, the rest keeps parsing.

```swift
let workbook = try SpreadsheetParser.parse(xlsxAt: url) { partial in
    print("active sheet ready:", partial.sheets[partial.activeSheetIndex].name)
}
```

## Read cells the way Excel shows them

```swift
for sheet in workbook.sheets {
    print("==", sheet.name, sheet.visibility, sheet.cells.count, "cells,",
          sheet.mergedRanges.count, "merges,", sheet.charts.count, "charts,",
          sheet.tables.count, "tables,", sheet.pivotRegions.count, "pivots,",
          sheet.conditionalRules.count, "CF rules")
    for cell in sheet.cells.sorted(by: { $0.reference < $1.reference }).prefix(20) {
        let shown = ExcelNumberFormat.string(for: cell.value, code: cell.format?.numberFormat)
        print(cell.reference.a1, shown, cell.formula.map { "=\($0)" } ?? "")
    }
}
if workbook.hasMacros { print("macro-enabled workbook: VBA is preserved byte-for-byte, never run") }
```

`ExcelNumberFormat.string(for:code:)` applies the cell's number format —
`#,##0.00`, `0%`, `yyyy-mm-dd`, custom codes — so dates show as dates and
currency as currency. A formula cell's `value` is the cached result the file
carries; `formula` is the expression without the leading `=`.

```swift
guard let ref = CellReference(a1: a1) else { return .empty }
return workbook.sheets[sheet].cells.first { $0.reference == ref }?.value ?? .empty
```

## Edit — values keep their styles

`settingCellValue` changes the value (and optionally the formula) of one cell
and keeps its number format, font, fill and borders. Every `setting…` returns a
new scene, or `nil` when the sheet index is out of range.

```swift
func set(_ wb: WorkbookScene?, _ a1: String, _ value: CellValue, formula: String? = nil) -> WorkbookScene? {
    wb.flatMap { WorkbookSceneEditor.settingCellValue(value, formula: formula, at: CellReference(a1: a1)!,
                                                      sheetIndex: sheet, in: $0) }
}
var wb: WorkbookScene? = workbook
wb = set(wb, "A2", .string("Widget"))
wb = set(wb, "B2", .number(3))
wb = set(wb, "C2", .number(19.99))
wb = set(wb, "D2", .number(59.97), formula: "B2*C2")     // cached value + formula
wb = wb.flatMap { WorkbookSceneEditor.settingNumberFormat("#,##0.00", at: CellReference(a1: "D2")!, sheetIndex: sheet, in: $0) }
wb = wb.flatMap { WorkbookSceneEditor.settingFontTrait(.bold, to: true, at: CellReference(a1: "A1")!, sheetIndex: sheet, in: $0) }
wb = wb.flatMap { WorkbookSceneEditor.settingFillColor("FFF2CC", at: CellReference(a1: "A1")!, sheetIndex: sheet, in: $0) }
wb = wb.flatMap { WorkbookSceneEditor.settingColumnWidth(column: 1, widthChars: 24, sheetIndex: sheet, in: $0) }
```

Also: `settingFontColor`, `settingFontFamily`, `settingFontSize`,
`settingHorizontalAlignment`, `clearingFormat`, `settingFormat(inRange:…)` with
a transform over `CellFormat?`, and `removingCells(at:)`.

Structure — rows, columns, merges, freeze panes, sheet names:

```swift
var wb = workbook
wb.insertRow(afterRow: 1, inSheet: 0)                                   // formulas shift with it
wb.setFrozenRows(1, inSheet: 0)
wb.setMergedRanges([CellRange(a1Range: "A1:D1")!], inSheet: 0)
if let renamed = WorkbookSceneEditor.renamingSheet(at: 0, to: "Invoice", in: wb) {
    wb = renamed.scene                                                  // cross-sheet formulas rewritten
    print(renamed.rewrittenFormulas.count, "formulas rewritten")
}
```

`deleteRow`, `insertColumns(_:afterColumn:)`, `deleteColumn`, `reorderRows`,
`appendSheet`, `removeSheet` complete the set. Inserting and deleting rows and
columns shifts every formula reference in the workbook.

Tables (Excel's *Format as Table*):

```swift
WorkbookSceneEditor.insertingTable(named: "Lines", over: CellRange(a1Range: "A1:D10")!, sheetIndex: 0,
                                   style: WorkbookSceneEditor.defaultAuthoredTableStyle(), in: workbook)
```

Charts and drawings: `insertingChart`, `movingChart`, `movingDrawing`,
`removingChart`, `removingDrawing`; conditional formatting:
`sheet.replacingConditionalRules(_:)`.

## Formulas

The engine evaluates ≈105 functions — arithmetic, logical, lookup (`VLOOKUP` /
`HLOOKUP`, `INDEX` / `MATCH`), text, date, statistical and financial — with
Excel's error semantics: a cell error is a *value* (`CellValue.error("#DIV/0!")`),
not a thrown error.

```swift
let context = SceneWorkbookContext(scene: workbook, homeSheetIndex: 0)   // reads cached values
let total = Formula.evaluate("=SUM(D2:D10)", in: context)
print("total:", ExcelNumberFormat.string(for: total, code: "#,##0.00"))
if case .error(let code) = Formula.evaluate("=1/0", in: context) { print("cell error value:", code) }
let telemetry = FormulaTelemetry()
_ = Formula.evaluate("=IFERROR(VLOOKUP(\"x\",A:B,2,FALSE),\"n/a\")", in: context, telemetry: telemetry)
print("functions used:", telemetry.used, "not supported:", telemetry.unknown)
```

`FormulaTelemetry.unknown` tells you when a workbook uses a function the engine
does not implement (the result is `#NAME?`). `Formula.evaluateThrowing` throws
`ExcelError` instead of returning it.

Before saving a workbook where the user typed formulas, give them cached
values so Excel, Numbers and Quick Look show results instead of formula text.
Formulas that came from the file keep the cached value Excel wrote:

```swift
let ready = WorkbookRecalc.writingBackUserFormulaValues(workbook)
```

Accuracy is measured cell by cell against Excel's own cached values over 569
workbooks and 232,000 formula cells: 91.6% match overall, 95.0% of the cells
whose cached value is not an error. Dynamic arrays (spill) are not supported.

## Save

```swift
_ = try SpreadsheetWriter.save(workbook: workbook, originalURL: url, destinationURL: out)
```

Untouched worksheets, styles, shared formulas, drawings, charts, pivots and the
VBA project of an `.xlsm` are copied verbatim; edited cells get new `<c>`
elements and, when their format changed, a new style record. The writer refuses
(typed error) rather than guess when a sheet names a part that is missing or
when every sheet was deleted.

Insert a picture on save:

```swift
let picture = PicturePartSynthesizer.InsertedPicture(
    imageData: try Data(contentsOf: png), fileExtension: "png",
    anchor: DrawingAnchor(fromColumn: 5, fromRow: 1, toColumn: 9, toRow: 12))   // 0-based: F2 … J13
let report = PictureInsertionReport()
_ = try SpreadsheetWriter.save(workbook: workbook, originalURL: original, destinationURL: destination,
                               pictureInsertions: [(picture: picture, sheetIndex: 0)], report: report)
print("picture written:", report.wasWritten(0))
```

## CSV in

```swift
let text = try String(contentsOf: csv, encoding: .utf8)
let rows = CSVCodec.parse(text, delimiter: CSVCodec.delimiter(forExtension: csv.pathExtension))
try CSVToWorkbookConverter.writeXLSX(rows: rows, to: destination, emptyGridMessage: "The CSV has no cells.")
```

## Read-only structures

```swift
for table in sheet.tables { print("table", table.displayName, table.range.a1Range) }
for chart in sheet.charts { print("chart", chart.content.type, chart.content.series.count, "series") }
for pivot in sheet.pivotRegions { print("pivot", pivot.name, pivot.range.a1Range) }
for rule in sheet.conditionalRules { print("CF rule", rule.priority, rule.ranges.map(\.a1Range)) }
if let setup = sheet.pageSetup { print("print:", setup.landscape ? "landscape" : "portrait", "scale", setup.scale) }
```

Charts carry their cached series values and categories (`ChartContent`),
pivots their output range and row outline, conditional rules their typed body
(`cellIs`, `text`, `duplicates`, `colorScale`, `dataBar`, `iconSet`) with
`ConditionalFormatEvaluator` to resolve the format of any cell.

## Rendering and errors

`ParsedDocument.workbook(workbook)` paginates each sheet for print — page
setup, fit-to-page, print areas and manual breaks are honoured —
[Rendering](guide-rendering.md). Errors: `SpreadsheetParserError`,
`SpreadsheetWriterError`, `ExcelError` (cell content, not a failure) —
[Errors and threading](errors-and-threading.md).
