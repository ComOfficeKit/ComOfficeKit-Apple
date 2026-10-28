import Foundation
import DocumentCore

// docs/guide-docx.md
enum DOCXRecipes {

    // MARK: Parse and walk

    /// Body text with tables flattened to tab-separated rows. Works on any
    /// element list, so it also serves headers, footers, footnotes and comments.
    static func text(of elements: [WordBodyElement]) -> String {
        elements.map { element -> String in
            switch element {
            case .paragraph(let paragraph):
                return paragraph.runs.map(\.text).joined()
            case .table(let table):
                return table.rows.map { row in
                    row.cells.map { text(of: $0.content) }.joined(separator: "\t")
                }.joined(separator: "\n")
            @unknown default:                      // the SDK's enums are resilient: new cases may arrive
                return ""
            }
        }.joined(separator: "\n")
    }

    static func plainText(of scene: WordDocumentScene) -> String { text(of: scene.body) }

    static func outline(_ url: URL) throws {
        let scene = try DocumentParser.parse(docxAt: url)
        print(scene.body.count, "body elements;", scene.sections.count, "sections;",
              scene.headers.count, "headers;", scene.footers.count, "footers;",
              scene.footnotes.count, "footnotes;", scene.comments.count, "comments")
        for element in scene.body {
            switch element {
            case .paragraph(let paragraph):
                let style = paragraph.style?.styleID ?? "Normal"
                print("¶ [\(style)]", paragraph.runs.map(\.text).joined().prefix(60))
            case .table(let table):
                print("⊞ table", table.rows.count, "×", table.rows.first?.cells.count ?? 0)
            @unknown default:
                print("(new element kind)")
            }
        }
        for section in scene.sections {
            if let size = section.pageSize {
                print("page", Double(size.widthTwips) / 20, "×", Double(size.heightTwips) / 20, "pt")
            }
        }
        for header in scene.headers { print("header \(header.rID):", text(of: header.body).prefix(60)) }
        for note in scene.footnotes { print("footnote", note.id, text(of: note.body).prefix(60)) }
    }

    /// Run-level detail: formatting, links, inline images, tracked changes.
    static func inspectRuns(_ scene: WordDocumentScene) {
        for case .paragraph(let paragraph) in scene.body {
            for run in paragraph.runs {
                if run.formatting?.bold == true { print("bold:", run.text) }
                if let url = run.linkURL { print("link:", run.text, "→", url) }
                if let image = run.image { print("inline image", image.archivePath, image.widthPt ?? 0, "pt wide") }
                if let revision = run.revision {
                    print("tracked \(revision.kind) by \(revision.author ?? "?"):", run.text)
                }
            }
        }
    }

    // MARK: Find, replace, insert, format

    static func findAndReplace(_ scene: WordDocumentScene) -> WordDocumentScene {
        let matches = WordSceneEditor.findMatches(of: "Acme", in: scene, caseSensitive: false)
        print(matches.count, "matches")
        let (replaced, count) = WordSceneEditor.replaceAll("Acme", with: "Contoso", in: scene)
        print("replaced", count)
        return replaced
    }

    /// A position is (paragraph id, run id, UTF-16 offset inside the run).
    static func end(of paragraph: WordParagraph) -> WordScenePosition? {
        guard let last = paragraph.runs.last else { return nil }
        return WordScenePosition(paragraphID: paragraph.id, runID: last.id, charOffset: last.text.utf16.count)
    }

    static func appendToFirstParagraph(_ scene: WordDocumentScene, text: String) -> WordDocumentScene? {
        guard case .paragraph(let paragraph)? = scene.body.first, let position = end(of: paragraph) else { return nil }
        return WordSceneEditor.insert(text, at: position, in: scene)?.scene
    }

    /// Bold the whole first paragraph, keeping every other run attribute.
    /// `sourceRPrXML: nil` tells the writer to regenerate `<w:rPr>` from the
    /// fields instead of re-emitting the captured original.
    static func boldFirstParagraph(_ scene: WordDocumentScene) -> WordDocumentScene? {
        guard case .paragraph(let paragraph)? = scene.body.first,
              let first = paragraph.runs.first, let to = end(of: paragraph) else { return nil }
        let from = WordScenePosition(paragraphID: paragraph.id, runID: first.id, charOffset: 0)
        return WordSceneEditor.applyFormatting(from: from, to: to, in: scene) { f in
            WordRunFormatting(bold: true,
                              italic: f?.italic ?? false, underline: f?.underline ?? false,
                              strikethrough: f?.strikethrough ?? false,
                              fontFamily: f?.fontFamily, sizePt: f?.sizePt, colorHex: f?.colorHex,
                              highlight: f?.highlight, shadingHex: f?.shadingHex,
                              vertAlign: f?.vertAlign, letterSpacingPt: f?.letterSpacingPt,
                              sourceRPrXML: nil)
        }?.scene
    }

    static func centerFirstParagraph(_ scene: WordDocumentScene) -> WordDocumentScene? {
        guard case .paragraph(let paragraph)? = scene.body.first, let first = paragraph.runs.first else { return nil }
        let caret = WordScenePosition(paragraphID: paragraph.id, runID: first.id, charOffset: 0)
        return WordSceneEditor.setAlignment(.center, paragraphID: paragraph.id, caret: caret, in: scene)?.scene
    }

    static func insertTableAfterFirstParagraph(_ scene: WordDocumentScene) -> WordDocumentScene? {
        guard case .paragraph(let paragraph)? = scene.body.first else { return nil }
        return WordSceneEditor.insertTable(rows: 3, columns: 4, afterParagraph: paragraph.id, in: scene)?.scene
    }

    /// The writer copies the file at `mediaURL` into the package on save.
    static func insertImageAtEnd(_ scene: WordDocumentScene, png: URL) -> WordDocumentScene? {
        guard case .paragraph(let paragraph)? = scene.body.last, let position = end(of: paragraph) else { return nil }
        let image = WordImage(mediaURL: png, archivePath: "media/\(png.lastPathComponent)",
                              widthPt: 240, heightPt: 160, altText: "Chart")
        return WordSceneEditor.insertInlineImage(image, at: position, in: scene)?.scene
    }

    static func insertLink(_ scene: WordDocumentScene) -> WordDocumentScene? {
        guard case .paragraph(let paragraph)? = scene.body.first, let position = end(of: paragraph) else { return nil }
        return WordSceneEditor.insertHyperlink(url: "https://example.com", title: "example.com",
                                               at: position, in: scene)?.scene
    }

    // MARK: Review — comments and tracked changes

    static func listComments(_ scene: WordDocumentScene) {
        for comment in scene.comments where comment.parentParaId == nil {
            print(comment.author ?? "?", comment.resolved ? "(resolved)" : "", comment.text)
            for reply in scene.comments where reply.parentParaId != nil && reply.parentParaId == comment.paraId {
                print("  ↳", reply.author ?? "?", reply.text)
            }
        }
    }

    static func review(_ scene: WordDocumentScene) -> WordDocumentScene {
        var edited = scene
        if let first = scene.comments.first {                        // resolve a thread
            edited = edited.replacingComment(first.settingResolved(true))
        }
        if case .paragraph(let paragraph)? = scene.body.first, let run = paragraph.runs.first {
            edited = edited.addingComment(id: "42", author: "Reviewer",  // comment on the first run
                                          date: ISO8601DateFormatter().string(from: Date()),
                                          bodyText: "Please check this figure.",
                                          coveringRunIDs: [run.id], referenceAfterRunID: run.id)
        }
        return edited.resolvingAllRevisions(.accept)                 // accept every tracked change
    }

    static func rejectOne(_ scene: WordDocumentScene, revisionID: String) -> WordDocumentScene {
        scene.resolvingRevision(id: revisionID, .reject)
    }

    // MARK: Compare

    static func compare(originalURL: URL, revisedURL: URL, outputURL: URL) throws {
        let original = try DocumentParser.parse(docxAt: originalURL)
        let revised = try DocumentParser.parse(docxAt: revisedURL)
        let comparison = try WordDocumentComparer.compare(original: original, revised: revised,
                                                          author: "Compare", date: Date())
        print(comparison.isIdentical ? "no differences"
              : "\(comparison.insertionCount) insertions, \(comparison.deletionCount) deletions")
        try WordDocumentComparer.write(comparison, revisedPackage: revisedURL, to: outputURL)
    }

    static func diffText() {
        let old = "Payment is due within 30 days of the invoice."
        let new = "Payment is due within 45 days of delivery."
        for hunk in TextDiff.diff(old: old, new: new) where hunk.kind != .equal {
            let removed = (old as NSString).substring(with: NSRange(location: hunk.old.lowerBound, length: hunk.old.count))
            let added = (new as NSString).substring(with: NSRange(location: hunk.new.lowerBound, length: hunk.new.count))
            print(hunk.kind, removed.debugDescription, added.debugDescription)  // ranges are UTF-16 offsets
        }
    }

    // MARK: Save

    /// Byte-preserving: paragraphs, tables and parts you did not touch are
    /// copied from `original` verbatim; edited ones are regenerated.
    static func save(_ scene: WordDocumentScene, original: URL, to destination: URL) throws {
        try DocumentWriter.save(document: scene, originalURL: original, destinationURL: destination)
    }

    static func newBlank(at url: URL) throws {
        try DocumentWriter.writeBlankDocument(to: url)
    }

    // MARK: JSON snapshot — for agents, indexes, diffs

    static func json(_ scene: WordDocumentScene) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(WordDocumentSceneJSON(scene: scene))
    }
}
