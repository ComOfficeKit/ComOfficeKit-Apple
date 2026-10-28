# Structure as JSON

`WordDocumentSceneJSON` is a `Codable` snapshot of a `WordDocumentScene` for
consumers that want structure without the Swift model — LLM agents, search
indexes, diff tools, other languages.

```swift
let encoder = JSONEncoder()
encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
let data = try encoder.encode(WordDocumentSceneJSON(scene: scene))
```

Design: the writer's preservation metadata (`sourceXML` and friends) is
omitted; body elements use a flat discriminated shape (`kind` + the fields of
that kind) so a consumer can branch on `obj["kind"]`; ids are stringified
UUIDs, stable within one parse (re-parsing yields fresh ones); deleted
tracked-change runs are excluded, so `text` is the "final" text.

## Schema

```
{
  "body":      [ BodyElement ],
  "sections":  [ Section ],
  "headers":   [ HeaderFooter ],
  "footers":   [ HeaderFooter ],
  "footnotes": [ Footnote ]
}

BodyElement (kind = "paragraph")
  kind, id, text (all runs joined), runs: [Run], style?: ParagraphStyle, textBoxes?: [TextBox]
BodyElement (kind = "table")
  kind, id, rows: [ { cells: [ { content: [BodyElement] } ] } ]

Run          text, formatting?: { bold?, italic?, underline?, strikethrough?   (true or omitted)
                                   fontFamily?, sizePt?, colorHex?, highlight?, shadingHex? }
ParagraphStyle  styleID?, alignment? ("left"|"center"|"right"|"justify"|"distribute"|"start"|"end"),
                listLevel?: { numID, level }
TextBox      text, widthPt, heightPt
Section      pageSize?: { widthTwips, heightTwips }, pageMargin?: { topTwips, rightTwips, bottomTwips, leftTwips },
             headerRefs: [ { kind ("default"|"first"|"even"), rID } ], footerRefs: [ … ], titlePage
HeaderFooter role ("header"|"footer"), rID, partName, body: [BodyElement]
Footnote     id, body: [BodyElement]
```

Comments and their threads are not in the snapshot; read `scene.comments`
directly ([DOCX guide](guide-docx.md#comments-and-tracked-changes)).

## Example

```json
{
  "body": [
    { "kind": "paragraph", "id": "9B1C…", "text": "Quarterly report",
      "runs": [ { "text": "Quarterly report", "formatting": { "bold": true, "sizePt": 16 } } ],
      "style": { "styleID": "Title" } },
    { "kind": "table", "id": "2F7A…",
      "rows": [ { "cells": [ { "content": [ { "kind": "paragraph", "id": "…", "text": "Region", "runs": [ … ] } ] } ] } ] }
  ],
  "sections": [ { "pageSize": { "widthTwips": 11906, "heightTwips": 16838 },
                  "pageMargin": { "topTwips": 1440, "rightTwips": 1440, "bottomTwips": 1440, "leftTwips": 1440 },
                  "headerRefs": [ { "kind": "default", "rID": "rId7" } ], "footerRefs": [], "titlePage": false } ],
  "headers": [ { "role": "header", "rID": "rId7", "partName": "header1.xml", "body": [ … ] } ],
  "footers": [],
  "footnotes": []
}
```

Workbooks and decks have no JSON DTO yet; their scenes are plain `Codable`-free
structs — walk them with the guides' text functions, or ask for the DTO if your
pipeline needs one.
