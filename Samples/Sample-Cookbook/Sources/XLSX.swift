import Foundation
import DocumentCore
import AppleRender   // adds SpreadsheetParser.parse(xlsxAt:) with the EMF/WMF rasteriser

// docs/guide-xlsx.md
enum XLSXRecipes {

    // MARK: Open

    /// With `AppleRender` imported this overload rasterises metafile pictures;
    /// `SpreadsheetParser.parse(xlsxAt:rasterizer: nil)` skips them.
    static func open(_ url: URL) throws -> WorkbookScene {
        try SpreadsheetParser.parse(xlsxAt: url)
    }

    /// Large files: the active sheet arrives first, the rest keeps parsing.
    static func openShowingActiveSheetFirst(_ url: URL) throws -> WorkbookScene {
        try SpreadsheetParser.parse(xlsxAt: url) { partial in
            print("active sheet ready:", partial.sheets[partial.activeSheetIndex].name)
        }
    }

    static func dump(_ workbook: WorkbookScene) {
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
    }

    /// Cells are sparse: a missing cell is `.empty`.
    static func value(_ workbook: WorkbookScene, sheet: Int, a1: String) -> CellValue {
        guard let ref = CellReference(a1: a1) else { return .empty }
        return workbook.sheets[sheet].cells.first { $0.reference == ref }?.value ?? .empty
    }

    // MARK: Edit — values keep their styles

    static func fillInvoiceLine(_ workbook: WorkbookScene) -> WorkbookScene? {
        let sheet = 0
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
        return wb
    }

    static func restructure(_ workbook: WorkbookScene) -> WorkbookScene {
        var wb = workbook
        wb.insertRow(afterRow: 1, inSheet: 0)                                   // formulas shift with it
        wb.setFrozenRows(1, inSheet: 0)
        wb.setMergedRanges([CellRange(a1Range: "A1:D1")!], inSheet: 0)
        if let renamed = WorkbookSceneEditor.renamingSheet(at: 0, to: "Invoice", in: wb) {
            wb = renamed.scene                                                  // cross-sheet formulas rewritten
            print(renamed.rewrittenFormulas.count, "formulas rewritten")
        }
        return wb
    }

    static func addTable(_ workbook: WorkbookScene) -> WorkbookScene? {
        WorkbookSceneEditor.insertingTable(named: "Lines", over: CellRange(a1Range: "A1:D10")!, sheetIndex: 0,
                                           style: WorkbookSceneEditor.defaultAuthoredTableStyle(), in: workbook)
    }

    // MARK: Formulas

    static func evaluate(_ workbook: WorkbookScene) {
        let context = SceneWorkbookContext(scene: workbook, homeSheetIndex: 0)   // reads cached values
        let total = Formula.evaluate("=SUM(D2:D10)", in: context)
        print("total:", ExcelNumberFormat.string(for: total, code: "#,##0.00"))
        if case .error(let code) = Formula.evaluate("=1/0", in: context) { print("cell error value:", code) }
        let telemetry = FormulaTelemetry()
        _ = Formula.evaluate("=IFERROR(VLOOKUP(\"x\",A:B,2,FALSE),\"n/a\")", in: context, telemetry: telemetry)
        print("functions used:", telemetry.used, "not supported:", telemetry.unknown)
    }

    /// Before saving: give every formula the user typed a computed cached value,
    /// so Excel, Numbers and Quick Look show the result rather than the text.
    /// Formulas that came from the file keep the cached value Excel wrote.
    static func recalculateTyped(_ workbook: WorkbookScene) -> WorkbookScene {
        WorkbookRecalc.writingBackUserFormulaValues(workbook)
    }

    // MARK: Save

    static func save(_ workbook: WorkbookScene, original: URL, to destination: URL) throws {
        _ = try SpreadsheetWriter.save(workbook: workbook, originalURL: original, destinationURL: destination)
    }

    static func saveWithPicture(_ workbook: WorkbookScene, png: URL, original: URL, to destination: URL) throws {
        let picture = PicturePartSynthesizer.InsertedPicture(
            imageData: try Data(contentsOf: png), fileExtension: "png",
            anchor: DrawingAnchor(fromColumn: 5, fromRow: 1, toColumn: 9, toRow: 12))   // 0-based: F2 … J13
        let report = PictureInsertionReport()
        _ = try SpreadsheetWriter.save(workbook: workbook, originalURL: original, destinationURL: destination,
                                       pictureInsertions: [(picture: picture, sheetIndex: 0)], report: report)
        print("picture written:", report.wasWritten(0))
    }

    // MARK: CSV in

    static func csvToXLSX(_ csv: URL, to destination: URL) throws {
        let text = try String(contentsOf: csv, encoding: .utf8)
        let rows = CSVCodec.parse(text, delimiter: CSVCodec.delimiter(forExtension: csv.pathExtension))
        try CSVToWorkbookConverter.writeXLSX(rows: rows, to: destination, emptyGridMessage: "The CSV has no cells.")
    }

    // MARK: Read-only structures

    static func extras(_ sheet: SheetScene) {
        for table in sheet.tables { print("table", table.displayName, table.range.a1Range) }
        for chart in sheet.charts { print("chart", chart.content.type, chart.content.series.count, "series") }
        for pivot in sheet.pivotRegions { print("pivot", pivot.name, pivot.range.a1Range) }
        for rule in sheet.conditionalRules { print("CF rule", rule.priority, rule.ranges.map(\.a1Range)) }
        if let setup = sheet.pageSetup { print("print:", setup.landscape ? "landscape" : "portrait", "scale", setup.scale) }
    }
}
