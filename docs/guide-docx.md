# DOCX

`DocumentParser` turns a `.docx` into a `WordDocumentScene`; `WordSceneEditor`
and the scene's own `…ing` methods derive edited scenes; `DocumentWriter` writes
one back over the original, byte-preserving. Every sample below is a function
in [`Samples/Sample-Cookbook/Sources/DOCX.swift`](../Samples/Sample-Cookbook/Sources/DOCX.swift).

## The model in one screen

```
WordDocumentScene
├─ body: [WordBodyElement]            .paragraph(WordParagraph) | .table(WordTable)
│   ├─ WordParagraph  runs · style (WordParagraphStyle) · floatingImages · floatingTextBoxes · floatingShapes
│   │   └─ WordRun    text · formatting (WordRunFormatting) · image · linkURL · revision · commentIDs · field
│   └─ WordTable      rows → cells → content: [WordBodyElement]   (tables nest)
├─ sections: [WordSection]            pageSize · pageMargin · headerRefs / footerRefs · titlePage · docGrid
├─ headers / footers: [WordHeaderFooter]   role · rID · body
├─ footnotes: [WordFootnote]          id · body
├─ comments: [WordComment]            id · author · date · body · resolved · parentParaId (replies)
├─ numbering: WordNumbering?          list definitions
└─ styleDefaults: WordStyleDefaults?  document defaults and named-style spacing
```

## Parse and walk

```swift
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
```

Plain text, with tables flattened to tab-separated rows — the same function
serves headers, footers, footnotes and comment bodies because they are all
`[WordBodyElement]`:

```swift
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
```

Run-level detail — formatting, links, inline images, tracked changes:

```swift
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
```

## Positions

Every Word edit is addressed by a `WordScenePosition`: the paragraph id, the
run id, and a UTF-16 offset inside that run's text. The end of a paragraph is
the end of its last run:

```swift
static func end(of paragraph: WordParagraph) -> WordScenePosition? {
    guard let last = paragraph.runs.last else { return nil }
    return WordScenePosition(paragraphID: paragraph.id, runID: last.id, charOffset: last.text.utf16.count)
}
```

Edits return a `WordSceneEdit?` — the new scene plus where the caret lands
(`edit.scene`, `edit.caret`). `nil` means the position did not resolve; the
scene is unchanged.

## Find, replace, insert, format

```swift
let matches = WordSceneEditor.findMatches(of: "Acme", in: scene, caseSensitive: false)
let (replaced, count) = WordSceneEditor.replaceAll("Acme", with: "Contoso", in: scene)
```

Append text at the end of the first paragraph:

```swift
guard case .paragraph(let paragraph)? = scene.body.first, let position = end(of: paragraph) else { return nil }
return WordSceneEditor.insert(text, at: position, in: scene)?.scene
```

Bold a range, keeping every other run attribute. `sourceRPrXML: nil` tells the
writer to regenerate `<w:rPr>` from the fields instead of re-emitting the
captured original:

```swift
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
```

Paragraph-level operations take the paragraph id plus a caret to preserve:
`setAlignment(.center, …)`, `setParagraphStyle("Heading1", …)`,
`toggleList(bullet:)`, `adjustLeftIndent(byTwips:)`, `setLineSpacing(multiple:)`,
`setSpacingBefore(twips:)` / `setSpacingAfter(twips:)`, `addTabStop`,
`setParagraphShading`, `setParagraphBorder`:

```swift
let caret = WordScenePosition(paragraphID: paragraph.id, runID: first.id, charOffset: 0)
return WordSceneEditor.setAlignment(.center, paragraphID: paragraph.id, caret: caret, in: scene)?.scene
```

Tables, images, links, text boxes, section breaks:

```swift
WordSceneEditor.insertTable(rows: 3, columns: 4, afterParagraph: paragraph.id, in: scene)?.scene
WordSceneEditor.insertTableRow(atParagraph: cellParagraphID, below: true, in: scene)
WordSceneEditor.insertTableColumn(atParagraph: cellParagraphID, after: true, in: scene)

let image = WordImage(mediaURL: png, archivePath: "media/\(png.lastPathComponent)",
                      widthPt: 240, heightPt: 160, altText: "Chart")
WordSceneEditor.insertInlineImage(image, at: position, in: scene)?.scene     // the writer copies the file in

WordSceneEditor.insertHyperlink(url: "https://example.com", title: "example.com", at: position, in: scene)
WordSceneEditor.insertTextBox(afterParagraph: paragraph.id, hOffsetPt: 72, vOffsetPt: 72, in: scene)
WordSceneEditor.insertSectionBreak(afterParagraph: paragraph.id, in: scene)
WordSceneEditor.deleteRange(from: a, to: b, in: scene)
WordSceneEditor.splitParagraph(at: position, in: scene)                        // Enter
```

## Comments and tracked changes

Comments are a flat list; a reply carries `parentParaId` pointing at its
parent's `paraId`.

```swift
for comment in scene.comments where comment.parentParaId == nil {
    print(comment.author ?? "?", comment.resolved ? "(resolved)" : "", comment.text)
    for reply in scene.comments where reply.parentParaId != nil && reply.parentParaId == comment.paraId {
        print("  ↳", reply.author ?? "?", reply.text)
    }
}
```

Resolve, add, reply, remove; accept or reject tracked changes:

```swift
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
```

`addingReply(toCommentID:replyID:author:date:bodyText:replyParaId:)`,
`removingComment(id:)`, `comment.editingText(_:)` and
`resolvingRevision(id:, .reject)` complete the set. Insertions and deletions are
`WordRevision` values on the runs they cover, so a "final" view is
`runs.filter { $0.revision?.kind != .deletion }`.

## Compare two documents

`WordDocumentComparer` records the differences between two documents as tracked
changes in the revised one, which is what Word's *Compare* produces. Accept
every change and you read the revised document; reject every change and you
read the original.

```swift
let original = try DocumentParser.parse(docxAt: originalURL)
let revised = try DocumentParser.parse(docxAt: revisedURL)
let comparison = try WordDocumentComparer.compare(original: original, revised: revised,
                                                  author: "Compare", date: Date())
print(comparison.isIdentical ? "no differences"
      : "\(comparison.insertionCount) insertions, \(comparison.deletionCount) deletions")
try WordDocumentComparer.write(comparison, revisedPackage: revisedURL, to: outputURL)
```

Body paragraphs and table cells are compared — word by word, and character by
character in scripts written without spaces. Formatting-only changes, headers,
footers, footnotes, text boxes, pictures and comments are not compared. To
compare against plain text, make the scene with `WordDocumentScene(plainText:)`
and pass `revisedPackage: nil`.

`TextDiff` is the diff underneath, for any two strings. It is not
licence-gated:

```swift
let old = "Payment is due within 30 days of the invoice."
let new = "Payment is due within 45 days of delivery."
for hunk in TextDiff.diff(old: old, new: new) where hunk.kind != .equal {
    let removed = (old as NSString).substring(with: NSRange(location: hunk.old.lowerBound, length: hunk.old.count))
    let added = (new as NSString).substring(with: NSRange(location: hunk.new.lowerBound, length: hunk.new.count))
    print(hunk.kind, removed.debugDescription, added.debugDescription)  // ranges are UTF-16 offsets
}
```

## Save

```swift
try DocumentWriter.save(document: edited, originalURL: url, destinationURL: out)
try DocumentWriter.writeBlankDocument(to: newURL)          // an empty A4 document to start from
```

The writer copies every untouched paragraph, table, header, footer, footnote
and part from `originalURL` byte for byte and regenerates only the elements you
changed (an edited run's `<w:rPr>`, an inserted table, a new media part with
its relationship and content type). Save always needs the original file.

## Snapshot as JSON

```swift
let encoder = JSONEncoder()
encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
let data = try encoder.encode(WordDocumentSceneJSON(scene: scene))
```

Body, sections, headers, footers and footnotes, without the writer's
preservation metadata — the schema is in [Structure as JSON](structure-json.md).

## Rendering and errors

`ParsedDocument.word(scene)` → [Rendering](guide-rendering.md). Errors:
`DocumentParserError` (extraction, missing `word/document.xml`, invalid XML
naming the part), `DocumentWriterError`, plus the licence errors —
[Errors and threading](errors-and-threading.md).
