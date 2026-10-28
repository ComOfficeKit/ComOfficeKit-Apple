# PPTX

`SlideParser` turns a `.pptx` into `[SlideScene]`, one per slide, streaming
them as they parse; the scene types have `replacing…` methods for edits;
`SlideWriter` writes back over the original, byte-preserving per slide.
Samples are functions in
[`Samples/Sample-Cookbook/Sources/PPTX.swift`](../Samples/Sample-Cookbook/Sources/PPTX.swift).

## The model in one screen

```
SlideScene    slideNumber · sourcePartName · size (points) · shapes (z-order) · notes · background · isHidden
└─ SlideShape id · kind · frame · rotationDegrees · content · fill · strokeHex · shadow · presetGeometry · customGeometry
   content:   .text(TextContent) | .image(ImageContent) | .table(TableContent) | .chart(ChartContent) | .empty
   TextContent   paragraphs → runs (TextRun: text · fontFamily · fontSizePt · bold · italic · colorHex · hyperlink …)
                 bodyProperties (wrap · anchor · insets · autofit)
   ImageContent  mediaURL (cached file) · archivePath · crop · hyperlink · videoURL
   TableContent  columnWidthsPt · rowHeightsPt · rows → cells (paragraphs, spans, fill, borders)
   ChartContent  type · title · series · categories · grouping · overlaySeries
```

Coordinates are points with the origin at the slide's top-left; `size` is
typically 960 × 540 (16:9) or 720 × 540 (4:3).

## Open

```swift
let slides = try SlideParser.parse(pptxAt: url) { index, slide in
    print("slide", index + 1, "ready:", slide.shapes.count, "shapes")   // streams as it parses
}
```

## Text and structure

```swift
static func text(of slide: SlideScene) -> String {
    slide.shapes.compactMap { shape -> String? in
        switch shape.content {
        case .text(let body):
            return body.paragraphs.map { $0.runs.map(\.text).joined() }.joined(separator: "\n")
        case .table(let table):
            return table.rows.map { row in
                row.cells.map { cell in cell.paragraphs.map { $0.runs.map(\.text).joined() }.joined(separator: " ") }
                    .joined(separator: "\t")
            }.joined(separator: "\n")
        case .chart(let chart): return chart.title
        case .image(let image): return image.altText
        case .empty: return nil
        @unknown default: return nil
        }
    }.joined(separator: "\n")
}
```

```swift
for slide in slides {
    print("-- slide", slide.slideNumber, slide.size, slide.isHidden ? "(hidden)" : "")
    for shape in slide.shapes {
        print("  ", shape.id, shape.kind, shape.frame.integral, shape.presetGeometry ?? "")
    }
    if let notes = slide.notes { print("   notes:", notes.prefix(80)) }
}
```

`shape.id` is the slide's `<p:cNvPr id>` — stable across saves, and the key
you hand back to the writer when a shape changed.

## Edit in place

Every model type returns copies: `SlideScene.replacingShapes` / `replacingNotes`,
`SlideShape.replacingContent` / `replacingFrame` / `replacingStyle`,
`TextContent.replacingParagraphs`, `Paragraph.replacingRuns`, `TextRun.replacingText`.
Replacing a run's text keeps its font, size and colour:

```swift
let shapes = slide.shapes.map { shape -> SlideShape in
    guard shape.id == shapeID, case .text(let body) = shape.content,
          let paragraph = body.paragraphs.first, let run = paragraph.runs.first else { return shape }
    let newParagraph = paragraph.replacingRuns([run.replacingText(title)])
    return shape.replacingContent(.text(body.replacingParagraphs([newParagraph] + body.paragraphs.dropFirst())))
}
return slide.replacingShapes(shapes)
```

```swift
slide.replacingShapes(slide.shapes.map { $0.id == shapeID ? $0.replacingFrame(frame) : $0 })   // move / resize
slide.replacingNotes("Speaker notes for this slide")
```

## Pictures

A new picture is a scene shape plus a `PendingPictureInsertion` that the writer
materialises on save (media part, relationship, content type):

```swift
let id = SlideShapeCloning.nextShapeID(inUse: Set(slide.shapes.compactMap { Int($0.id) }))
let shape = SlideShape(id: id, kind: .image, frame: frame,
                       content: .image(ImageContent(mediaURL: png, archivePath: "media/pending-\(id)",
                                                    altText: png.lastPathComponent)))
let pending = PendingPictureInsertion(shapeID: id, sourceImageURL: png, frame: frame,
                                      altText: png.lastPathComponent)
return (slide.replacingShapes(slide.shapes + [shape]), pending)
```

"Change picture" keeps the frame, crop and geometry and swaps only the media:

```swift
PendingPictureReplacement(shapeID: shapeID, newSourceImageURL: png)
```

## Slides: add, duplicate, delete, reorder

Slide identity is `sourcePartName` (`"slides/slide3.xml"`), not
`slideNumber`. Edit the array; the writer reconciles the package's slide list
against it in one pass:

```swift
var deck = slides
let size = deck.first?.size ?? CGSize(width: 960, height: 540)
deck.append(SlideScene(slideNumber: deck.count + 1, sourcePartName: nil,   // nil: the writer synthesises a part
                       size: size, shapes: [], notes: nil))
if let first = deck.first { deck.insert(first, at: 1) }                     // duplicate: its part is byte-copied
if deck.count > 3 { deck.remove(at: 2) }                                    // delete
deck.swapAt(0, 1)                                                           // reorder
```

## Save

Tell the writer which shapes changed how; it regenerates only those and copies
every other byte from the original:

```swift
_ = try SlideWriter.save(scenes: slides, originalURL: original, destinationURL: destination,
                         editedNotesSlideNumbers: editedNotesSlideNumbers,
                         formatEditedShapeIDs: formattedShapeIDs,      // run formatting changed
                         geometryEditedShapeIDs: movedShapeIDs,        // frame / rotation changed
                         pictureInsertions: pictures, pictureReplacements: replacements)
```

Text-only edits are detected by comparing runs, so they need no id set.
`deletedShapeIDs`, `insertedShapeIDs` (new text boxes and shapes) and
`styleEditedShapeIDs` (fill / line) cover the rest. The writer throws
`SlideWriterError` rather than fall back when a scene names a slide part that
is missing or when no slides remain.

## Rendering and errors

`ParsedDocument.slides(slides)` — one page per slide, hidden slides included —
[Rendering](guide-rendering.md). Errors: `SlideParserError`, `SlideWriterError`
— [Errors and threading](errors-and-threading.md).
