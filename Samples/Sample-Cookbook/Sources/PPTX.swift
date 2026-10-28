import Foundation
import CoreGraphics
import DocumentCore

// docs/guide-pptx.md
enum PPTXRecipes {

    // MARK: Open

    /// `onSlide` streams each slide as it is parsed — show the first one early.
    static func open(_ url: URL) throws -> [SlideScene] {
        try SlideParser.parse(pptxAt: url) { index, slide in
            print("slide", index + 1, "ready:", slide.shapes.count, "shapes")
        }
    }

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

    static func outline(_ slides: [SlideScene]) {
        for slide in slides {
            print("-- slide", slide.slideNumber, slide.size, slide.isHidden ? "(hidden)" : "")
            for shape in slide.shapes {
                print("  ", shape.id, shape.kind, shape.frame.integral, shape.presetGeometry ?? "")
            }
            if let notes = slide.notes { print("   notes:", notes.prefix(80)) }
        }
    }

    // MARK: Edit in place — every model type has `replacing…` helpers

    /// Replace the first paragraph's text of one shape; font, size and colour stay.
    static func retitle(_ slide: SlideScene, shapeID: String, to title: String) -> SlideScene {
        let shapes = slide.shapes.map { shape -> SlideShape in
            guard shape.id == shapeID, case .text(let body) = shape.content,
                  let paragraph = body.paragraphs.first, let run = paragraph.runs.first else { return shape }
            let newParagraph = paragraph.replacingRuns([run.replacingText(title)])
            return shape.replacingContent(.text(body.replacingParagraphs([newParagraph] + body.paragraphs.dropFirst())))
        }
        return slide.replacingShapes(shapes)
    }

    static func move(_ slide: SlideScene, shapeID: String, to frame: CGRect) -> SlideScene {
        slide.replacingShapes(slide.shapes.map { $0.id == shapeID ? $0.replacingFrame(frame) : $0 })
    }

    static func setNotes(_ slide: SlideScene, _ notes: String) -> SlideScene {
        slide.replacingNotes(notes)
    }

    // MARK: Pictures

    /// A new picture is a scene shape plus a pending insertion the writer
    /// materialises on save (media part, relationship, content type).
    static func insertPicture(_ slide: SlideScene, png: URL, frame: CGRect) -> (SlideScene, PendingPictureInsertion) {
        let id = SlideShapeCloning.nextShapeID(inUse: Set(slide.shapes.compactMap { Int($0.id) }))
        let shape = SlideShape(id: id, kind: .image, frame: frame,
                               content: .image(ImageContent(mediaURL: png, archivePath: "media/pending-\(id)",
                                                            altText: png.lastPathComponent)))
        let pending = PendingPictureInsertion(shapeID: id, sourceImageURL: png, frame: frame,
                                              altText: png.lastPathComponent)
        return (slide.replacingShapes(slide.shapes + [shape]), pending)
    }

    /// "Change picture": keep the frame, crop and geometry; swap the media.
    static func replacePicture(shapeID: String, with png: URL) -> PendingPictureReplacement {
        PendingPictureReplacement(shapeID: shapeID, newSourceImageURL: png)
    }

    // MARK: Slides — add, duplicate, delete, reorder by editing the array

    static func restructure(_ slides: [SlideScene]) -> [SlideScene] {
        var deck = slides
        let size = deck.first?.size ?? CGSize(width: 960, height: 540)
        deck.append(SlideScene(slideNumber: deck.count + 1, sourcePartName: nil,   // nil: the writer synthesises a part
                               size: size, shapes: [], notes: nil))
        if let first = deck.first { deck.insert(first, at: 1) }                     // duplicate: its part is byte-copied
        if deck.count > 3 { deck.remove(at: 2) }                                    // delete
        deck.swapAt(0, 1)                                                           // reorder
        return deck
    }

    // MARK: Save

    /// Tell the writer which shapes changed how, so it regenerates only those
    /// and copies every other byte from `original`.
    static func save(_ slides: [SlideScene], original: URL, to destination: URL,
                     formattedShapeIDs: Set<String> = [], movedShapeIDs: Set<String> = [],
                     editedNotesSlideNumbers: Set<Int> = [],
                     pictures: [PendingPictureInsertion] = [],
                     replacements: [PendingPictureReplacement] = []) throws {
        _ = try SlideWriter.save(scenes: slides, originalURL: original, destinationURL: destination,
                                 editedNotesSlideNumbers: editedNotesSlideNumbers,
                                 formatEditedShapeIDs: formattedShapeIDs,
                                 geometryEditedShapeIDs: movedShapeIDs,
                                 pictureInsertions: pictures, pictureReplacements: replacements)
    }
}
