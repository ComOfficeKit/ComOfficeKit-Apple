import Foundation
import DocumentCore
import AppleRender

// `cookbook <file>` — runs the read-only recipes against one file.
// Licence from COMOFFICEKIT_KEY (the string) or COMOFFICEKIT_LICENCE_FILE (the file):
// the SDK build refuses to parse without one.
// Verification is local, so this is a plain `try` and needs no network.
let arguments = CommandLine.arguments.dropFirst()
guard let path = arguments.first else {
    print("usage: cookbook <file.docx|.xlsx|.xlsm|.pptx>   (licence in COMOFFICEKIT_KEY or COMOFFICEKIT_LICENCE_FILE)")
    exit(2)
}
let url = URL(fileURLWithPath: path)

// A command-line tool: keep the key in memory for this process. The default
// `.persistent` storage is for apps — on Apple platforms that is the Keychain,
// and the item belongs to the binary that created it, so a tool beside an app
// does not inherit the app's licence and would look unlicensed. (It does not
// hang: since 0.9.17 another binary's item is treated as absent rather than
// prompting.) Activate per run instead.
SDKLicense.configure(SDKLicense.Configuration(), storage: .memory)

let environment = ProcessInfo.processInfo.environment
if SDKLicense.state != .active {
    do {
        if let file = environment["COMOFFICEKIT_LICENCE_FILE"] { try LicenceRecipes.activate(fileAt: URL(fileURLWithPath: file)) }
        else if let key = environment["COMOFFICEKIT_KEY"] { try LicenceRecipes.activate(key) }
    } catch let error as SDKLicense.SDKLicenseError { print("licence:", error.description); exit(3) }
    catch { print("licence file:", error.localizedDescription); exit(3) }   // the file could not be read
}

if let hint = ConversionRecipes.legacyHint(url) { print(hint); exit(1) }

do {
    RenderingRecipes.registerFonts()
    switch url.pathExtension.lowercased() {
    case "docx":
        try DOCXRecipes.outline(url)
        let scene = try DocumentParser.parse(docxAt: url)
        DOCXRecipes.inspectRuns(scene)
        DOCXRecipes.listComments(scene)
        print(String(decoding: try DOCXRecipes.json(scene).prefix(400), as: UTF8.self))
    case "xlsx", "xlsm":
        let workbook = try XLSXRecipes.open(url)
        XLSXRecipes.dump(workbook)
        XLSXRecipes.evaluate(workbook)
        workbook.sheets.forEach(XLSXRecipes.extras)
    case "pptx":
        PPTXRecipes.outline(try PPTXRecipes.open(url))
    default:
        print("unsupported extension"); exit(2)
    }
    let document = try RenderingRecipes.open(url)
    print("pages:", try DocumentRenderer.pageCount(of: document))
} catch let error as SDKLicense.SDKLicenseError {
    print("licence:", error.description); exit(3)
} catch {
    print("error:", error); exit(1)
}
