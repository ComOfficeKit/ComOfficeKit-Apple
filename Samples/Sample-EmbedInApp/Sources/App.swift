import SwiftUI
import DocumentCore
import AppleRender

// Sample-EmbedInApp — "a viewer app gaining Office tabs". Binary-only consumer.
// Each opened document is a tab in the sidebar; pages come from
// DocumentRenderer.image(of:page:scale:), rendered off the main thread; the
// licence is entered once through the Licence… sheet: pasted, or chosen as a file.

@main
struct EmbedInApp: App {
    var body: some Scene { WindowGroup("ComOfficeKit — EmbedInApp") { ViewerWindow() } }
}

struct OpenDocument: Identifiable {
    let id = UUID()
    let name: String
    let pages: [CGImage]
}

@MainActor
final class ViewerModel: ObservableObject {
    @Published var documents: [OpenDocument] = []
    @Published var selection: OpenDocument.ID?
    @Published var status = "Open a .docx, .xlsx or .pptx"
    @Published var licenceState = SDKLicense.state
    @Published var showLicence = false

    func open() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.init(filenameExtension: "docx")!, .init(filenameExtension: "xlsx")!, .init(filenameExtension: "pptx")!]
        panel.allowsMultipleSelection = true
        guard panel.runModal() == .OK else { return }
        for url in panel.urls { load(url) }
    }

    func load(_ url: URL) {
        status = "Rendering \(url.lastPathComponent)…"
        Task.detached(priority: .userInitiated) {
            do {
                let parsed: ParsedDocument
                switch url.pathExtension.lowercased() {
                case "docx": parsed = .word(try DocumentParser.parse(docxAt: url))
                case "xlsx", "xlsm": parsed = .workbook(try SpreadsheetParser.parse(xlsxAt: url, rasterizer: nil))
                default: parsed = .slides(try SlideParser.parse(pptxAt: url))
                }
                let count = try DocumentRenderer.pageCount(of: parsed)
                let images = try (0..<count).map { try DocumentRenderer.image(of: parsed, page: $0, scale: 2) }
                await MainActor.run {
                    let doc = OpenDocument(name: url.lastPathComponent, pages: images)
                    self.documents.append(doc); self.selection = doc.id
                    self.status = "\(url.lastPathComponent): \(count) page(s)"
                }
            } catch let error as SDKLicense.SDKLicenseError {
                await MainActor.run { self.status = "\(error)"; self.showLicence = true }   // typed: prompt for a licence
            } catch {
                await MainActor.run { self.status = "\(error)" }                               // typed engine error, never a crash
            }
        }
    }

    /// Verification is local: no network, no waiting, no completion handler.
    func activate(_ key: String) {
        activating { try SDKLicense.activate(key: key) }
    }

    /// The licence file sales sends, when you received one.
    func chooseLicenceFile() {
        // Any file: a licence file can be XML or text, under any name and extension.
        let panel = NSOpenPanel()
        guard panel.runModal() == .OK, let url = panel.url else { return }
        activating { try SDKLicense.activate(licenseFileAt: url) }
    }

    private func activating(_ activate: () throws -> Void) {
        do {
            try activate()
            licenceState = SDKLicense.state
            // Only what the licence says: it may name no licensee.
            let day = ISO8601DateFormatter(); day.formatOptions = [.withFullDate]
            let to = SDKLicense.licensedTo.map { " to \($0)" } ?? ""
            let until = SDKLicense.licenceExpires.map { ", until \(day.string(from: $0)) 00:00 UTC" } ?? ""
            status = "Licensed\(to)\(until)"
            showLicence = false
        } catch {
            status = "\(error)"   // a refused licence changes nothing: the one before stays active
        }
    }
}

struct ViewerWindow: View {
    @StateObject private var model = ViewerModel()
    @State private var key = ""

    var body: some View {
        NavigationSplitView {
            List(model.documents, selection: $model.selection) { doc in
                Text(doc.name).tag(doc.id)
            }
            .navigationTitle("Documents")
        } detail: {
            if let doc = model.documents.first(where: { $0.id == model.selection }) {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(Array(doc.pages.enumerated()), id: \.offset) { index, page in
                            Image(decorative: page, scale: 2).resizable().aspectRatio(contentMode: .fit)
                                .frame(maxWidth: 820).shadow(radius: 2)
                                .accessibilityLabel("Page \(index + 1)")
                        }
                    }.padding()
                }
            } else {
                VStack(spacing: 8) {   // (ContentUnavailableView is macOS 14; this sample targets 13)
                    Image(systemName: "doc.richtext").font(.system(size: 40)).foregroundStyle(.secondary)
                    Text("No document").font(.title3)
                    Text(model.status).foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .toolbar {
            Button("Open…") { model.open() }
            Button("Licence…") { model.showLicence = true }
        }
        .safeAreaInset(edge: .bottom) {
            HStack { Text(model.status).font(.callout).foregroundStyle(.secondary); Spacer()
                     Text(SDKLicense.isEnforced ? "gate: \(String(describing: model.licenceState))" : "evaluation build (no gate)").font(.caption).foregroundStyle(.tertiary) }
                .padding(8).background(.bar)
        }
        .sheet(isPresented: $model.showLicence) {
            VStack(alignment: .leading, spacing: 12) {
                Text("ComOfficeKit licence").font(.headline)
                Text("State: \(String(describing: model.licenceState))").foregroundStyle(.secondary)
                TextField("Paste the licence", text: $key).textFieldStyle(.roundedBorder)
                HStack { Button("Choose File…") { model.chooseLicenceFile() }; Spacer(); Button("Cancel") { model.showLicence = false }; Button("Activate") { model.activate(key) }.keyboardShortcut(.defaultAction) }
            }.padding(20).frame(width: 380)
        }
        .frame(minWidth: 760, minHeight: 520)
    }
}
