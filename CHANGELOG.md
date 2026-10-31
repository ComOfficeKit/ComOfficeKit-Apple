# Changelog

## 1.3.0 — 2026-10-31

Two new table edits, East Asian text laid out in its own font, and Word's
character styles, embedded objects and SmartArt laid out and drawn. There was no
1.2.0 release of these frameworks: its changes ship here, listed after 1.3.0's
own. The API only gains.

- **New: `WordSceneEditor.deleteTable(atParagraph:in:)`.** It deletes the table
  that holds the paragraph, as Word does when Delete Rows takes a table's only
  row, or Delete Columns its only column:
  - it acts on the top-level body table, as the row and column edits do, so a
    paragraph in a nested table takes its outer table;
  - the caret lands at the start of what follows the table, else at the end of
    what comes before it. A table that was the body's only element leaves an
    empty paragraph for it;
  - every other element is written as it was.

  It returns `nil` when the paragraph is not in a cell of a top-level body
  table. `deleteTableRow` and `deleteTableColumn` are unchanged: they still
  return `nil` for a table's only row and only column, and the host decides when
  to delete the table instead.
- **A Word run's East Asian text is laid out in its East Asian font, and theme
  fonts are read.** Word draws a run's Latin text in its ASCII font and its
  Chinese, Japanese and Korean text in its East Asian font, each inherited on its
  own through the styles (ECMA-376 Part 1, §17.3.2.26). Before, a run kept one
  family, and fonts named only through the theme were never read. Such a
  document was laid out in Helvetica Neue, and its CJK text in the system's
  fallback font. Now:
  - each character takes its run's Latin or East Asian font, by its Unicode
    range and the run's `w:hint`;
  - theme fonts are resolved, with the theme's East Asian face, its per-script
    faces and the document's `w:themeFontLang`;
  - a font drawn in place of one the Mac does not have keeps that font's line
    height, for the fonts documents commonly name;
  - a style that sets nothing but its theme fonts keeps them, and character
    styles are read with the theme.
- **A slide table without a table style draws none.** A table with no
  `<a:tableStyleId>`, as Google Slides and WPS write them, was drawn in a
  built-in style, often in the deck's blue. So was a table whose style id the
  file does not define. Both now draw only their cells' own fills and borders.
  A border that is wholly transparent is none.
- `DocumentEngine.version` reads `1.3.0`.

From the engine's 1.2.0:

- **New: `WordSceneEditor.movingTableColumnBorder(rightOfCellContaining:byTwips:in:)`.**
  It moves the border on the right of a table cell, as dragging that border in
  Word does:
  - inside the table, the column on the border's left takes the width the
    column on its right gives, so the table keeps its width;
  - at the table's right edge, the last column changes, and so does the table's
    width when it is fixed or a share of the page;
  - no column becomes narrower than 0.1" (144 twips): a move that would make one
    narrower stops there.

  The grid and the width of every cell over a changed column are rewritten; the
  rest of the table is written as it was. The function returns `nil` outside a
  cell of a top-level table, for a table without a grid, and when the border
  cannot move.
- **`WordSceneEditor.deleteRange` deletes the ranges it returned `nil` for:** a
  range over more than one paragraph of a table cell, a header, a footer or a
  note; a range from one cell into another, or into or out of a table; and a
  range over a table. It deletes the text `selectedText` reads for the range:
  - a table wholly inside the range goes with it;
  - cells and rows stay, and a cell the range empties keeps one paragraph,
    without its text;
  - the range's ends join when they are in the same cell or the same part, and
    not across cells.

  A range inside one paragraph of a header, a footer or a note is deleted too. A
  range from one part into another (the body into a header) is still `nil`, and
  so is `deleteRangeTracked` across cells.
- **Adding or removing a table row or column keeps the table's properties.**
  `insertTableRow`, `deleteTableRow`, `insertTableColumn` and
  `deleteTableColumn` wrote the edited table without its own properties: its
  style, alignment, indent and cell margins, and the borders its style gave it.
  They are now kept. When a column is added or removed, a table of fixed width
  takes the new grid's width; a width given as a share of the page stays a share.
- **A slide's chart is read with the presentation's theme.** A series the chart
  part colours from the theme (`<a:schemeClr>`, as PowerPoint writes it) now has
  that colour; it had none, and the chart fell back to the default palette.
- **A Word document's embedded objects show their picture.** `<w:object>` was
  skipped. Its preview picture is now read: as its run's picture when the object
  is in line, and as a floating picture when its shape is positioned.
- **Word SmartArt and VML shape groups are laid out and drawn.** A SmartArt's
  drawing part and a VML group are read as shapes, each with its outline, fill
  and text. A drawing in line with the text keeps a box on its line, as a
  picture does, and its shapes are laid out in it; the page painters draw them.
  Before, they took no room, and what followed moved up. New public API for a
  host that draws a `WordLayout` itself: `WordLayoutLine.shapes`,
  `WordLayoutShape.geometry` and `WordShapeGeometry`.
- **Word character styles are laid out.** A run's character style
  (`<w:rStyle>`) is laid under the run's own formatting and over its paragraph
  style's, Word's order, in the body, tables, headers, footers, notes and text
  boxes: a hyperlink is blue and underlined. Only paragraph styles were read, so
  links came out black and plain. With it:
  - a table of contents' entries are laid out in their TOC styles, as Word's
    print layout shows them;
  - `<w:color w:val="auto"/>` is a colour: a link written black stays black;
  - a run in a styled paragraph keeps its own character spacing, and a style's
    spacing applies;
  - a table in a text box is styled as a table in the body is.

  A run changed with `WordRunFormatting`'s setters (`settingBold(_:)` and the
  others) keeps its character style and its automatic colour, and the writer
  writes both. `settingColor(_:)` replaces an automatic colour.

## 1.1.0 — 2026-10-29

One new function, and pictures and links in a document's headers, footers and
notes kept on save. The API only gains.

- **New: `WorkbookSceneEditor.insertingChart(of:type:anchor:sheetIndex:in:)`.**
  It inserts a chart of a range at an anchor, made as Excel makes one from a
  selection:
  - the range's first row names the series when it holds no number;
  - its first column labels the categories when it holds none;
  - there is a series for each column, or for each row when the range is wider
    than it is tall;
  - a text or empty cell plots as 0, and a date as its serial number;
  - one named series gives the chart its title.

  The chart holds the cells' values as they are, as an editor's Insert Chart
  does, and it is the sheet's last chart. Every cell of the range is read, so
  give the data's range rather than whole columns. The function returns `nil`
  for a sheet that does not exist, for `.unsupported`, and for a range with no
  number.
- **A picture or a link in a header, a footer, a footnote or an endnote is kept
  on save.**
  - `WordSceneEditor.insertInlineImage` accepts a position in any of these
    parts, but the writer wrote such a picture as an empty run. Each part's
    pictures are now written with that part's own relationships.
  - A link in these parts lost its address on save. That happened to one put
    there with `insertHyperlink`, to one already there once its paragraph was
    edited, and to one in an edited text box. All of these now keep it.
- **A new picture no longer shares a drawing id with one an earlier save
  wrote.** Each save numbered new pictures from the same id, and Word repairs a
  document whose drawings share one. New ids now skip every id the package
  holds.
- **A picture or a link in a footnote or an endnote is read**, through the
  notes' own relationships. A picture there was never shown before, and a link
  had no address.
- `DocumentEngine.version` reads `1.1.0`.

## 1.0.0 — 2026-10-28

The first public release. From this version the API keeps to semantic versioning.
The SDK moves to a new licence format, and its frameworks are dynamic, with the
fonts inside `AppleRender.framework`. **Licences issued for 0.9.44 and earlier
stop working: sales issues replacements.** The API only gains.
[Migration notes](docs/migration/README.md) has the steps.

### Licensing

- **A new licence format.** A licence is still verified on the device, with no
  network. It can now name the platforms, the apps (by bundle identifier), the
  SDK versions and the features it covers. Licences issued for 0.9.44 and
  earlier begin `COK1.`, and this release refuses them with `.invalidKey`.
- **`SDKLicense.activate(licenseFileAt:)`** activates from a licence file: the XML
  licence file, a text file with the licence on a `Sign=` line, or a text file that holds
  only the licence string. `activate(key:)` still takes the licence string.
- **Four new `SDKLicenseError` cases:** `.platformMismatch`, `.bundleIDMismatch`,
  `.featureNotLicensed` and `.versionNotLicensed`. `checkUnlocked()` throws the
  reason a stored licence is refused.
- **A refused licence changes nothing.** A licence activated before stays
  active.
- **A licence stops working when its end date begins**, at 00:00 UTC: the day itself is
  already past it. **An expiry takes effect within an hour** in a running app, with no
  relaunch.
- **`licensedTo` and `licenceExpires` can be `nil`**, when the licence does not
  say.
- **A command-line tool needs a licence that names no app**, because it has no
  bundle identifier. Each release's evaluation licence names none.
- **The licence check writes nothing to the console**, whatever licence it is given.
- **Third-party notices** for the licence check (Crypto++, RapidJSON) ship as
  `THIRD_PARTY_NOTICES.txt` inside `DocumentCore.framework`.

### Integration

- **`DocumentCore.xcframework` and `AppleRender.xcframework` hold dynamic
  frameworks.** Until now they were static. An app embeds them: in Xcode,
  choose *Embed & Sign* where you chose *Do Not Embed*. SwiftPM does this for
  an app target. Xcode signs them with your identity as it embeds them.
- **A command-line tool built in Xcode needs `@executable_path`** in its
  *Runpath Search Paths*, with the two frameworks beside it. Without the run
  path the tool builds, and then cannot load the frameworks. `swift build` and
  `swift run` need nothing.
- **The fonts are inside `AppleRender.framework`.** Delete
  `TruePathCore_AppleRender.bundle` from your app's resources, or from beside
  your tool: nothing reads it any more, and a release no longer attaches it.
  With SwiftPM the fonts now arrive with the binary target, so there is
  nothing to copy.
- **Each framework carries its privacy manifest** (`PrivacyInfo.xcprivacy`):
  no tracking and no collected data. `DocumentCore` declares file timestamps
  (C617.1 and 3B52.1). Your app's privacy report includes both, so you no
  longer declare the SDK in your own manifest.
- **Each slice ships with its dSYM**, so a crash report that passes through the
  SDK's code symbolicates. The dSYMs stay out of your app.
- **Size.** On an iPhone the app carries about 5 MB for `DocumentCore`, 1.3 MB
  for `AppleRender` and 2.9 MB of fonts. Static frameworks let your linker drop
  what you did not use; dynamic ones are whole.

## 0.9.44 — 2026-10-04

Justified Word paragraphs render justified, and DocumentCore compares two Word
documents: `WordDocumentComparer` writes the differences into the revised
document as tracked changes, on top of `TextDiff`, a token diff for any two
texts. Tracked changes now cover paragraph marks and table rows, and resolving
them inside a table is saved. DocumentCore adds 47 public symbols and removes
or changes none; AppleRender's API is unchanged. Licensees on `0.9.41` get all
of it; from `0.9.39` or earlier, read the 0.9.41 notes first.

### Rendering

- **Justified paragraphs paint justified.** Through 0.9.41 the layout
  justified each line, but the painters drew every run again from its text, so
  the stretch lived only in the run's frame: a justified paragraph rendered
  like a left-aligned one, and gaps opened inside a line where two runs met.
  Now the spaces widen and the letters do not, as Word does for `jc="both"`.
  CJK lines and `distribute` spread between characters, as uniform letter
  spacing; right-to-left lines keep CoreText's own justification. Page images
  and PDF export change for justified paragraphs; page counts do not.
- **If you draw `WordLayout` runs yourself, apply the new
  `WordLayoutRun.wordSpacing`.** It is the extra advance after every space, in
  points, on top of `letterSpacing`. `frame` already includes it, so a run laid
  out again without it paints short of its frame. It is 0 on lines that are not
  justified.
- **Drawing justified text costs more.** On a 67-page justified contract, the
  PDF painter took 98.2 ms where it took 53.9 ms; layout took 18.7 ms where it
  took 18.6 ms.

### Comparing documents (new)

- **`WordDocumentComparer.compare(original:revised:author:date:)`** returns the
  revised document with every difference from the original recorded as a
  tracked change, stamped with `author` and `date`.
  `write(_:revisedPackage:to:)` saves it as a `.docx` that Word shows the same
  way. Both are licence-gated.
  - **What is compared:** the text of body paragraphs and table cells.
    Paragraphs are aligned first. A paragraph on one side only becomes a
    whole-paragraph insertion or deletion, its paragraph mark included; a
    changed paragraph is compared word by word, and character by character in
    scripts written without spaces, such as Chinese and Japanese. Tables with
    the same number of columns are compared row by row and cell by cell;
    otherwise the old table is deleted and the new one inserted.
  - **Not compared:** formatting-only changes, headers, footers, footnotes, text
    boxes, pictures and comments. Deleted text keeps the original's character
    formatting; everything else keeps the revised document's.
  - **Inputs with tracked changes** are compared as they read with those changes
    accepted, and `WordDocumentComparison` says when that happened.
  - **The contract:** accepting every change reads as the revised document,
    rejecting every change reads as the original, and a document compared with
    itself has no changes. It was checked on 500 seeded random pairs, and on 50
    more that went through real `.docx` files.
- **`TextDiff`** is the diff underneath. It is public and, like `Formula`, not
  licence-gated.
  - `TextDiff.diff(old:new:options:)` compares two strings token by token —
    words in space-delimited scripts, one token per character in Han, kana,
    Hangul, Thai and the other scripts written without spaces — and returns
    hunks whose ranges are UTF-16 offsets. `align(_:_:)` aligns any two
    `Hashable` sequences.
  - The result is minimal and the same on every platform. Long, repetitive
    texts such as numbered clauses are compared in linear memory. Two
    replacements separated only by whitespace become one, as Word shows them.
- **`WordDocumentScene.paragraphTexts`** returns the body's text paragraph by
  paragraph, table structure included, and **`WordDocumentScene(plainText:)`**
  makes a scene from plain text, so a `.docx` can be compared with a text file.

### Tracked changes

- **Paragraph marks and table rows carry revisions.**
  `WordParagraph.markRevision` is an inserted or deleted paragraph mark, and
  `WordTableRow.revision` an inserted or deleted row; each has a `with…` copy
  method. The parser reads both. It now also reads tracked changes inside
  hyperlinks, where it used to drop the linked text.
- **Visible to callers:**
  - `trackedChanges` and `hasTrackedChanges` include paragraph-mark and row
    revisions.
  - `resolvingAllRevisions` and `resolvingRevision(id:)` join what is left of a
    paragraph whose mark is removed into the next paragraph, which keeps its
    own properties, as Word does. They drop a removed row, and a table left
    without rows.
- **Fixed.** Each of these was reproduced before it was fixed:
  - a paragraph whose only change was a deleted paragraph mark counted as no
    change, and accepting every change left that deletion in the saved file;
  - resolving a change inside a table was not saved;
  - accepting a deleted whole paragraph left an empty paragraph behind;
  - resolving changes dropped section breaks and floating shapes;
  - rebuilding a scene dropped the document's default tab stop;
  - a table regenerated after a cell edit lost its style, width and repeated
    header row to the writer's defaults.

### Documentation

- **`guide-docx.md`:** a "Compare two documents" section. Like every guide
  example, its code is a function in `Samples/Sample-Cookbook`.
- **`api-overview.md`:** comparison in the "I want to…" table.
- **`limits-and-faq.md`:** what document comparison does not compare.
- **`migration/README.md`:** new 0.9.44 entry.

## 0.9.41 — 2026-10-02

The bundle now builds in Xcode with no extra settings. A typed edit in a Word
paragraph that anchors a text box no longer writes the box twice, and an edit
made with `WordParagraph.replacingRuns` is saved. No declaration is added,
removed or changed. Licensees on `0.9.39` get all of it. From `0.9.28` or
earlier, read the 0.9.39 notes first.

### Integration

- **The XCFrameworks are framework-type, so Xcode finds the modules on its own.**
  Through 0.9.39 they were library-type, with each `.swiftmodule` under
  `Headers/`. Xcode copies that folder to `$(BUILT_PRODUCTS_DIR)/include` but
  does not search it. So three routes failed at `import DocumentCore` with
  `Unable to find module dependency`:
  - adding the bundle to an Xcode project as a local package;
  - linking the XCFrameworks directly, the manual route in
    `getting-started.md`;
  - opening a sample in Xcode.

  `swift build` was not affected.
- **Each XCFramework now holds one static framework per platform**, with its
  module under `Modules/`. Verified with no build settings added:
  - as a local package, on macOS, the iOS simulator and an iPhone;
  - by linking the XCFrameworks directly, on macOS.
- **If you added `$(BUILT_PRODUCTS_DIR)/include` to Import Paths
  (`SWIFT_INCLUDE_PATHS`) to work around this, remove it.** It is no longer
  needed, and leaving it in does no harm.
- **The bundle no longer ships an `OOXMLDOM` module interface.** That module was
  internal to DocumentCore and never part of the API. Its code is still inside
  `DocumentCore`, and nothing that compiled against 0.9.39 used it.
- **An SPM dependency on the repository needs only the new version.** The
  release zips keep their names and the `Package.swift` binary targets are
  unchanged.

### Word

- **A typed edit in a paragraph that anchors a floating text box writes the
  box once.** A paragraph read from a file keeps each text box inside the run
  that anchors it. When an edit regenerated the paragraph, as every
  `WordSceneEditor` text edit does, two things happened:
  - that run was written back unchanged;
  - `DocumentWriter` also wrote the box again from the scene.

  So the saved file held two boxes. On the test corpus, 29 of the 100
  paragraphs that hold text and floating content doubled their boxes on the
  first edit; none do now.
- **Text edited inside a box still saves.** A box whose own text was edited is
  updated in place. Boxes inserted with `WordSceneEditor.insertTextBox` are
  written as before.
- **Visible to callers: an edit made with `WordParagraph.replacingRuns` is
  saved.**
  - **Before:** the copy kept the original paragraph's source XML, which
    `DocumentWriter` writes verbatim. The save succeeded and the old text came
    back.
  - **Now:** when the new runs differ, the copy drops the source XML, so the
    paragraph is regenerated, as for every paragraph `WordSceneEditor` edits.
    With the same runs it keeps it, so the paragraph still round-trips byte for
    byte. No declaration changed.

### Documentation

- **`limits-and-faq.md`:** the engine now runs on iPhone hardware, measured on
  this release. The row that said it had not been run is gone.
- **`migration/README.md`:** new 0.9.41 entry.

## 0.9.39 — 2026-09-30

Saving keeps more of what you did not edit in all three formats, XLSX pages
print their charts, Word pages draw letter spacing, and the public API gains
four additions, with no declaration removed or changed. Licensees on `0.9.28`
or `0.9.23` get all of it.

**From `0.9.23`, read the 0.9.24 notes first:** `WordLayoutEngine.layout`
became `throws`, and two licence-storage names were renamed.

**Five changes can affect code written against the old behaviour**, and each is
marked *Visible to callers* below: shapes a slide inherits from its layout or
master have prefixed ids; `saveWordMetadata` leaves sections you do not list
alone, and its `"Wide"` preset changed; `loadWordMetadata` reports three values
differently; XLSX page counts change; `"pages"` maps to `.word`.

### Presentations

- **A save no longer writes a layout's or master's text into a slide.** A
  slide's scene also holds the design shapes it inherits from its layout and
  master, and those parts number their shapes from 1 just as the slide does.
  `SlideWriter` paired scene shapes with the slide's elements by that bare
  number, so a save with no edit could replace a slide shape's text with its
  layout's footer or its master's slide-number field. On a 100-deck sample of
  the test corpus, 10 shapes in 5 decks lost their text this way; after the
  fix none did, on the sample or across the whole corpus (516 decks, 10,006
  slides). Two smaller pairing faults went with it: on a slide that carries an
  id twice, the second shape's text was overwritten by the first's, and shapes
  drawn by SmartArt could pair with slide shapes.
- **Visible to callers: a shape the slide inherits has a prefixed id.**
  Inherited shapes, listed in `SlideScene.shapes` ahead of the slide's own, now
  carry their layout's or master's id behind a `layout:` or `master:` prefix:
  `"layout:2"` where it was `"2"`. The slide's own shapes keep their bare ids.
  Code that looks a shape up by id, or keeps ids between loads, now finds the
  slide's own shape rather than an inherited one with the same number, and
  `Int(shape.id)` is `nil` for an inherited shape. An inherited shape has no
  element in the slide, so `SlideWriter` writes nothing for it: an edit to one
  is not saved (it could previously land in the slide shape that shared its
  number). (`SlideShape.id`; no declaration changed.)
- **A save no longer rebuilds slide shapes you did not edit.** When a shape's
  runs did not line up with its `<a:t>` elements — most often the empty
  slide-number field that Google Slides writes — `SlideWriter` rebuilt its text
  body from the scene, edit or not: the field became empty static text, and
  explicit paragraph properties such as `marL="0"`, `lvl="0"` and `buNone` were
  dropped, so the paragraph took the master's indent instead. Before rebuilding
  a shape, the writer now compares it with the same shape parsed from
  `originalURL` and keeps the file's XML when they are equal. On the same
  sample (1,919 slides), the slides a save with no edit changed went from 25
  to none. The original is parsed lazily — at most once per save, and only
  when a shape is about to be rebuilt — which adds 0.05–0.42 s to the saves
  that need it and nothing to the rest.
- **Emptying a text box or a table survives a save.** A text shape whose text
  you delete entirely, or a table whose cells you all empty, has no runs left,
  and `SlideWriter` skipped every shape with no runs — the rule that keeps
  pictures, charts and empty placeholders byte-identical. The save succeeded
  and the old text came back on reopen. Such a shape is now written when it has
  a text or table body, the file still holds text for it, and it differs from
  what the file parses to; anything else is still skipped. A text body with no
  paragraphs is written with one empty paragraph, as the format requires.
- **Speaker notes are split at every line ending.** The notes text
  `SlideWriter` writes (`SlideScene.notes`) is split into paragraphs at CR and
  CRLF as well as LF. Text with Windows line endings used to leave a stray
  carriage return at the end of every paragraph but the last. Notes read from a
  file already use LF, so a load-and-save round trip is unaffected.

### Word

- **`DocumentEngine.saveWordMetadata` changes only what you changed.** It
  rewrote every section from presets on every call, so saving back the metadata
  a document was loaded with — nothing edited — changed the document: margins
  were reset to a preset (Word's default 1" became 0.75" and the gutter was
  dropped), Letter landscape was saved as A4 portrait, and shown headers and
  footers lost their formatting and pictures, had fields such as page numbers
  frozen into text, or were removed. On the test corpus that round trip changed
  688 of 695 documents and removed a header or footer from 223. It now compares
  each section with what `loadWordMetadata(at:)` reads from the same file and
  writes only the fields that differ, in place: a page-size change keeps the
  orientation, a margin preset keeps the gutter, and a header or footer is
  rewritten only when its own text or visibility changed — in the part its own
  reference names, as plain text. A round trip with no edit leaves the package
  byte-identical: 0 of 695 change. (`WordPackageService.saveMetadata(_:to:)` is
  the same code.)
- **Watermarks, tracked page-setup changes and element order are respected.**
  Clearing a default header's text no longer detaches a watermark it carries; a
  tracked page-setup change (`<w:sectPrChange>`) is neither read nor edited; new
  section properties go in the order the schema requires; and a part with no
  root element to insert into throws `CocoaError(.fileReadCorruptFile)` where it
  used to be written with an element after its root.
- **Visible to callers: `saveWordMetadata` leaves alone the sections you do not
  list, and `"Wide"` means Word's Wide.** A section the metadata does not list
  is no longer touched — it took the last listed section's values — and empty
  metadata changes nothing, where it reset every section to the defaults. The
  `"Wide"` margin preset writes 1" top and bottom and 2" left and right, as Word
  does; it wrote 1" all round, which reads back as `"Normal"`.
- **Visible to callers: `loadWordMetadata` reports three values differently.**
  `pageSizeName` is decided by the short edge, so a Letter page in landscape
  reads `"Letter"` where it read `"A4"`; those are the only two names, so other
  sizes still read as one of them, but a save no longer changes a page size you
  did not change. A header or footer reference is read in either attribute
  order: documents that write `r:id` before `w:type`, as Google Docs does,
  used to read their headers and footers as empty, and the next save removed
  them. And `linkHeaderToPrevious` / `linkFooterToPrevious` are always `false`
  on the first section, which has no previous one; a document without headers
  reported `true` there, so giving it a first header wrote nothing.

### Word rendering

- **Letter-spaced text is drawn at the width it was laid out with.**
  `WordLayoutEngine` has always laid `<w:spacing>` letter spacing out — run
  frames include it — but drawing a run's text again did not apply it: on the
  page a condensed run painted into the next one, an expanded run fell short of
  it, and carets drifted off the glyphs. `DocumentRenderer` now draws each run
  with its spacing, so page images and PDF export match the layout, and
  `WordLayoutHitTest` places carets with it. Layout geometry is unchanged.
- **If you draw `WordLayout` runs yourself, use the two new `WordLayoutRun`
  properties.** `letterSpacing` is the spacing in points; apply it as a
  CoreText kern only when it is non-zero, because an explicit kern of 0 also
  switches off the font's own pair kerning. `glyphOriginX` is the page x of the
  run's first glyph — usually `frame.minX`, but not after a letter-spaced
  character: frames are measured from caret offsets, and CoreText puts a caret
  in the middle of the preceding character's spacing. Carets and hit areas use
  `frame`; glyphs start at `glyphOriginX`.

### Spreadsheets

- **XLSX pages print their charts.** A chart now counts toward the sheet's
  printed range, as it does in Excel and LibreOffice, and is positioned in
  sheet space and clipped to each page. A chart past the last used cell is
  printed; a sheet that holds only a chart has pages; a chart that crosses the
  edge of the used range is drawn at its true size instead of squeezed to end
  there; and a chart that straddles a page break is drawn partly on each page
  instead of squeezed into the first. Pictures and shapes still do not count,
  and are still not painted on pages. (`SpreadsheetPaginator`;
  `DocumentRenderer` output, so page images and PDF export equally.)
- **Visible to callers: XLSX page counts change.** A page with nothing to print
  is no longer emitted, which is LibreOffice Calc's default. With charts
  counted as well, `DocumentRenderer.pageCount(of:)` and
  `SpreadsheetPaginator.paginate(_:)` return different pages for sheets with
  charts or sparse content, so a page index you stored may now name a
  different page. Against LibreOffice's page counts for 662 test workbooks,
  exact agreement rose from 36.7% to 45.0%, and from 7.1% to 43.4% for the 99
  with charts.
- **A save leaves unedited columns and frozen panes alone.** `SpreadsheetWriter`
  rebuilt `<cols>` and `<pane>` from the scene on every save. The scene models
  only width and hidden per column, and a frozen row and column count, so a
  save — including one with no edit — dropped whole-column styles, column groups
  (`outlineLevel` / `collapsed`), `bestFit` and style-only columns, cut widths
  to six significant digits, reset the pane's scroll position (`topLeftCell`),
  turned `frozenSplit` into `frozen` and deleted a split pane that was not
  frozen. 96 of 100 test workbooks changed this way. Both elements are now left
  untouched when the scene holds exactly what the parser reads from them.
  `DocumentEngine.saveWorkbook` writes through `SpreadsheetWriter` and gets the
  same fix. **Not fixed:** a sheet whose columns you do change — resize, hide,
  insert or delete — still loses those column attributes.
- **A formula without a cached result no longer reads as 0 to the formulas that
  use it.** A workbook written without cached results — some generators omit
  `<v>` — gave `SceneWorkbookContext` nothing to read, so over uncached totals
  `B6` and `C6`, `=B6-C6` evaluated to 0 instead of 3301. A formula cell with
  no cached value is now computed when first read and remembered for that
  context; a cached value is still read as stored and never recomputed, and a
  cell in a cycle reads `#CIRCULAR!`. This reaches `Formula.evaluate` with a
  `SceneWorkbookContext`, `WorkbookRecalc.writingBackUserFormulaValues(_:)` and
  `WorkbookSaveSync.committedCellEdit(s)`. A workbook whose formulas all carry
  cached values pays nothing for it.

### Opening files

- **Visible to callers: `"pages"` maps to `.word`.**
  `DocumentKind.fromExtension(_:)` and `DocumentEngine.documentKind(forExtension:)`
  return `.word` for a Pages file, as they return `.presentation` for Keynote
  and `.spreadsheet` for Numbers; they returned `.unknown`, so a gate on
  `kind != .unknown` dropped Pages files before `LegacyFormatDetector`, which
  recognises them, could ask for a conversion. The engine parses none of these
  formats: call `LegacyFormatDetector.detect(extension:leadingBytes:)` before
  handing a file to a parser, as for `.doc`, `.xls` and `.ppt`.

### API additions

All in DocumentCore and all additive: 34 public symbols added, none removed or
changed. AppleRender's API is unchanged.

- **`Formula.inspect(_:)` reads a formula without evaluating it.** It returns a
  `FormulaInspection` — the functions it calls (`Call`: `name`,
  `argumentCount`), the cells and ranges it reads (`Reference`: `sheet`,
  `start`, `end`) and its number literals — or `nil` when the formula does not
  parse. Each list is in written order, and a call comes before the calls
  inside it. Nothing is looked up, so a formula that would evaluate to an error
  is still inspected. A sheet-qualified name that is not a cell address
  (`Sheet1!Total`) is not a reference and is left out, and a sign or percent is
  an operator, so `-3+15%` lists the numbers 3 and 15.
- **`WorkbookSaveSync.cellEditRecalculation(text:at:sheetIndex:in:)` and
  `cellEditsRecalculation(_:sheetIndex:in:)`** commit a cell edit, or a batch,
  as `committedCellEdit(s)` do, and also report every formula cell the
  recalculation rewrote: a `WorkbookRecalc.Recalculation` holding the new
  `scene` and `recomputed`, a list of `WorkbookRecalc.RecomputedCell` (sheet
  index, reference, formula, value). A host that shows formula results from its
  own copy of the values can refresh exactly those cells; without the list,
  formulas over an edited cell kept showing their pre-edit results until that
  copy was rebuilt. `committedCellEdit(s)` are unchanged.
- **`WordCommentIDAllocator` gives a new comment an id nothing in the document
  still uses.** A `.docx` carries a comment's id in the comments part and also
  in the range and reference markers in the body, headers, footers and
  footnotes (`WordRun.commentIDs`), and word processors leave markers behind
  for comments that are gone. An id taken as "highest in the comments part,
  plus one" can be one an orphaned range still claims, and the new comment then
  silently attaches to that text. `idsInUse(in:)` collects both;
  `nextCommentID(in:)` and `nextCommentID(avoiding:)` — for ids you also issued
  earlier in a session — return the next free id; `uniqueParaID(avoiding:)`
  returns a free `w14:paraId`. If you allocate comment ids yourself, use this.
- **`WordLayoutRun.letterSpacing` and `WordLayoutRun.glyphOriginX`** — see
  *Word rendering*.

### Storage

- **The media cache moves into your app's own folder.** Media extracted from
  `.pptx`, `.docx` and `.xlsx` files is now kept under Application Support in
  `<your bundle identifier>/DocumentCore/MediaCache` — inside your app's
  container on iOS and for sandboxed Mac apps. A process with no bundle
  identifier, such as a command-line tool, uses `DocumentCore/MediaCache`
  directly under Application Support. It used to be `TruePathCore/MediaCache`:
  an unrelated name on your customers' disks and, for Mac apps outside the
  sandbox, one folder shared by every app that embeds ComOfficeKit — so one app
  trimming the cache could remove media another app was still displaying.
  (`MediaCache`; the public API is unchanged.)
- **The old folder is neither migrated nor removed.** Media is extracted again
  the first time each document is opened, so nothing is lost. Where an earlier
  build ran, `Application Support/TruePathCore/MediaCache` no longer grows and
  nothing reads it; it is safe to delete.
- **Scratch files in the temporary directory no longer carry a product
  prefix:** `csv-convert-…`, `blank-docx-…`, `blank-pptx-…`. They are deleted
  after use, as before.

### Resources

- **The fonts bundle's `CFBundleIdentifier` is now
  `com.comofficekit.AppleRender.resources`** (was
  `com.comofficekit.TruePathCore.AppleRender.resources`). Its file name,
  `TruePathCore_AppleRender.bundle`, is unchanged, and nothing locates it by
  identifier: replace the bundle with the one from this release and nothing
  else changes.

### Documentation

- **89 engineering notes are gone from the API reference.** They sat on 70 of
  its pages, written for the engine's developers — test statistics, the content
  of specific test files, internal review and process tags, dates and an old
  product name. Documentation comments are also what Xcode's Quick Help shows
  from the XCFrameworks. The notes now sit in plain comments that do not ship.
- **Five pages opened with another declaration's description:**
  `TextDirection`, `WordStyleDefaults.defaultRunFormatting`,
  `WorkbookSaveSync.committedCellEdit`, `WorkbookSceneEditor.settingColumnWidth`
  and `SheetScene.replacingRemovedAnchors`. Each now opens with its own.
- **Descriptions the engine had outgrown were corrected against the code.**
  Among them: `SlideShape.presetGeometry` takes effect for every preset in
  `PresetGeometry.supported`, not only ellipses and rounded rectangles;
  `SlideShape.fill` reads solid, gradient, pattern and picture fills and the
  theme fill a shape's style points at; `SlideScene.background` falls back from
  the slide to its layout to its master; `ChartContent` parses 3D bar, line and
  pie charts as their flat counterparts; `WordDocumentScene` models comments,
  tracked changes and fields, and they can be added and edited (bookmarks are
  not modelled); `ImageContent.videoURL` — a page shows the poster frame, and
  playback is up to your app.
- **`SpreadsheetWriter`'s reference said cell deletion was not supported. It
  is:** a source cell that had a value or formula and is absent from the scene
  is removed. A cell that carries only a style never is, so a save cannot
  silently drop formatting.
- **`DocumentEngine.saveWorkbook` now documents its fallback.** When the
  destination cannot be read structurally, it rebuilds each sheet's
  `<sheetData>` from the text: formulas, merged ranges and drawing references
  survive; cell formatting, cached formula results and shared-string typing do
  not.
- **`limits-and-faq.md` listed 3D charts as unsupported.** 3D bar, line and
  pie charts are drawn, flat, and have been since the first release. The chart
  types parsed as `unsupported`, and drawn as an empty white area, are area,
  scatter, bubble, radar, stock, surface and of-pie. Its *XLSX pages and
  charts* section now describes this release, and its iOS table records that
  this release's own binaries ran on the iOS 26.3 simulator; both were
  measured on macOS and on the simulator with identical results.
- **The licensing article named a property that no longer exists:**
  `SDKLicense.Configuration.keychainService`, which 0.9.24 renamed
  `storageIdentifier`.
- **DocC identifiers are `doc://com.comofficekit.DocumentCore/…` and
  `doc://com.comofficekit.AppleRender/…`.** They were derived from the name of
  the folder the engine happened to be built in. Page paths and every page's
  visible content are unchanged, so only a link written with a `doc://`
  identifier needs the new prefix. The shipped `.swiftinterface` files no
  longer carry `-package-name` either: they declare no `package` API, so
  nothing that compiled against them used it.

## 0.9.28 — 2026-09-22

Four engine fixes. Licensees on `0.9.24` get all of them.

### Word rendering

- **Shapes anchored inside a table cell are drawn.** They were parsed and then
  dropped: of 238 floating shape leaves across the test corpus only 123 reached
  a page, and the missing 115 were exactly the in-table ones. Flowcharts and
  diagrams laid out inside a table — a common structure in process and
  procedure documents — rendered as blank space. (`WordLayoutEngine`; affects
  `DocumentRenderer` output, so page images and PDF export equally.)
- **`positionV/@relativeFrom="margin"` is measured from the page's top margin.**
  It was never implemented and fell through to the paragraph-relative branch,
  so a drawing declaring "226pt below the top margin" was placed 226pt below
  whichever paragraph carried its anchor — up to 172pt out of position. Only
  the fix above made this visible.

### Spreadsheet

- **`DocumentEngine.saveWorkbook` preserves what the caller did not mention.**
  It rebuilt `<sheetData>` from the flat strings it was handed, so a save
  discarded everything that text cannot describe — **including a save that
  changed nothing**. Measured on a no-op load/save round trip: cell style
  indices, cached formula results and shared-string typing were all lost, and
  an untouched workbook came back unformatted. It now reads the destination
  into a `WorkbookScene` and writes back only the cells that genuinely differ.
- **Number formatting rounds the way Excel rounds.** `printf` rounds half to
  even; Excel rounds half away from zero. Against Excel's rule over 10,000
  boundary values at two decimals, the old path was right 6,092 times and the
  new one 10,000: `2.675` in a `0.00` cell now reads `2.68`, as Excel shows it.
  Ordinary two-decimal money is unaffected (0 of 200,000 values differ).

### Portability

- **Saving a workbook over its own file works on Linux.** `replaceItemAt`
  neither replaces nor throws on swift-corelibs, so the existing fallback never
  ran and an in-place save silently did nothing. The swap is now verified
  against the destination rather than trusted. macOS behaviour is unchanged.

## 0.9.24 — 2026-09-20

Engine tag `0.9.24` (`c48b347`).

**The toolchain requirement is now stated, and it was stated wrongly before.**
The README's requirements table said "Xcode 16 / Swift 5.9 or later" — the one
toolchain that *cannot* link these frameworks. Building against ComOfficeKit
needs **Xcode 26 or later**; Xcode 16's SDK does not declare
`_swift_coroFrameAlloc`, which the licence storage's `_modify` accessors
reference, so the link fails with an error naming an internal type. This is a
BUILD requirement only — your app still runs on macOS 13 and iOS 16, because
the reference is weak and every call site is guarded.

Measured on both ends of the range rather than asserted: Xcode 16.4 fails,
26.0.1 builds, 26.6 builds, and there is no Xcode between 16 and 26.

**The release acceptance test runs on every published release.** The three
samples were a `workflow_dispatch`-only job, and it was red for two releases
without anyone seeing it — because it ran on an image whose Xcode is below the
floor, so it was testing an unsupported configuration and reporting the
mismatch as a broken release. It now triggers on `release: published`, builds
on both the floor Xcode and the current one, and checks the SDK for the symbol
first so a toolchain problem says so instead of arriving as a link error.

**The licence check is now total, including the one entry point that was not
throwing.** 0.9.23 put the gate on every public *throwing* entry point. That
phrasing hid a hole: `WordLayoutEngine.layout` produces engine output and was
not throwing, so it could not carry the gate without changing shape. It now
does, and **it is `throws`** — source-breaking at every call site:

```swift
let layout = try WordLayoutEngine.layout(scene)     // was: WordLayoutEngine.layout(scene)
```

It throws `SDKLicense.SDKLicenseError` for the same reasons every other entry
point does. If you render through `DocumentRenderer` you are unaffected: those
methods were already throwing and their signatures are unchanged.

**Licence storage is named by what it guarantees, not by how one platform does
it.** `Storage.keychain` → `Storage.persistent`, and
`Configuration.keychainService` → `Configuration.storageIdentifier` (the
property and the `init` label). On Apple platforms that store is still the
Keychain and the behaviour is unchanged.

**The stored value is unchanged**, so this is a source rename and nothing more:
the default is still `com.comofficekit.license`, and a licence already
activated stays activated. Nobody re-activates.

**`DocumentEngine.version` reports the version you are running.** It was a
hardcoded `"1.0.0"` — unrelated to any tag, and wrong in every release that
shipped it. It now tracks the engine tag, and a test fails the engine's build
if the two disagree. If you print it in an About box or a bug report, the
number changes from `1.0.0` to the real one.

## 0.9.23 — 2026-09-18

Engine tag `0.9.23`. **Public API unchanged since 0.9.18.**

**The licence check is now total.** Twelve public entry points — the legacy
`ArchiveEditingService` loaders and savers, `WordPackageService`, the CSV
converter and both blank-file writers — accepted calls with no licence active.
Every public throwing entry point now opens with the same check the parsers,
scene writers and renderer already had, and an audit in the engine's test
suite fails the build if a new one is added without it. If you have a licence,
nothing changes for you.

**The samples ship.** `Samples/` holds the three projects every guide cites —
the cookbook, an app embedding, a batch tool. They consume the frameworks from
`../../XCFrameworks`, which is this folder's layout, so `swift build` in any
of them works as delivered. The seven guide links that pointed at them now
resolve, and `LICENSE.md`'s evaluation clause names something you can do.

**The getting-started guide describes the install you actually perform** — a
path dependency — and names the two omissions that fail the build:
`platforms: [.macOS(.v13)]`, and the folder name (SwiftPM names a path
dependency after its directory; a clone from a repository is not called
`ComOfficeKit`, so use `.package(name:path:)`). The README's manifest gains
the same two.

**Smaller corrections.** The state-machine sample in the licensing guide
compiles (its cases were empty); updating is "replace the folder", not a
manifest bump; the type counts and two workbook property names match the
shipped interface; an empty workbook lays out to zero pages and the rendering
guide says so before you hit it.

**Font notices.** The bundled `Fonts/LICENSE.md` now carries each family's own
copyright holder as recorded in the font files, and the full Apache 2.0 text
that Caladea's licence requires. The top-level `LICENSE.md` no longer says
Caladea is under the SIL OFL.

## 0.9.22 — 2026-09-16

Engine tag `0.9.22`. **Public API unchanged since 0.9.18.**

**The API reference cited material that was not ours to cite.** Documentation
comments named specific presentations and workbooks that had been used as test
fixtures, and doc
comments are rendered into the reference you receive. They are gone. So are a
personal name, a dozen host-application view types, internal planning
documents, and internal issue numbers. The engineering content each comment
carried is kept, restated in terms of roles rather than of whoever happened to
be calling: "a host's formatting UI", "a corpus deck".

**The module landing page — the first page Xcode's documentation window shows —
had a sample that does not compile.** It awaited `activate(key:)`, which is
synchronous, and used a key prefix the verifier does not accept. 0.9.21 fixed
the article beside it and missed this one.

## 0.9.21 — 2026-09-16

Engine tag `0.9.21`. **Public API unchanged since 0.9.18.** This release fixes
the documentation you receive, which 0.9.20 shipped unchanged from the
engine's own tree.

**The API reference described a licensing model that no longer exists.** Its
licensing article still said activation "contacts the licence server", and
documented a background re-check, a 14-day offline-grace window and
server-driven revocation — all removed in 0.9.18. Every other document, and
this file, tell you there are no network calls at all. The article even
contradicted itself, carrying both claims on one page. It is now written
against the interface the framework actually exposes:
`activate(key:)` is throwing and synchronous, the states are
`.notActivated` / `.active` / `.expired`, and there is no re-check because
there is nothing to re-check against.

**The getting-started article documented API that does not compile** — an
`await` on a synchronous call, a function that no longer exists, a package
version never released, and a key format the verifier does not accept.

**The delivery README's first code sample did not compile.** It mixed a loader's
return type with a renderer's parameter type, and referenced an undefined
variable. Replaced with a sample compiled verbatim against this release's own
bundle.

**Documentation comments named things that are not yours to see** — internal
repositories, first-party application types, sibling products, and the
reasoning behind this SDK's own naming. They reached you because they are
rendered into the API reference. Removed; the engineering content they carried
is kept.

Two identifiers compiled into the libraries were renamed or dropped for the
same reason.

The guard that is supposed to prevent all of this was widened and one of its
parts repaired: it had been reading source files but not the reference
articles, and its comment handling silently discarded every documentation
comment it was meant to inspect.

## 0.9.20 — 2026-09-16

Engine tag `0.9.20`. **Public API unchanged since 0.9.18** — the declarations,
their behaviour and the api-digest are identical. What changed is what the
shipped artefacts SAY.

**Nothing you receive is branded with anything but ComOfficeKit.** Three
identifiers still carried an unrelated prefix, in places a documentation pass
cannot reach because they are compiled in:

- `SDKLicense.Configuration`'s default `keychainService` is now
  `com.comofficekit.license`. This is the Keychain item your app creates, so it
  is visible in your own Keychain Access and your customers'.
- Its default `contactURL` is now `https://comofficekit.com`. Nothing reads
  this value; it is API surface.
- `TruePathCore_AppleRender.bundle`'s `CFBundleIdentifier` is now
  `com.comofficekit.TruePathCore.AppleRender.resources` — an identifier that
  lands inside your app bundle. The bundle's file NAME is unchanged, and
  nothing locates it by identifier.

**If you passed either `Configuration` value explicitly, nothing changes for
you.** If you relied on the defaults and already have a key stored, it was
stored under the previous service name and this build will not find it:
activate once more. To clear the stale item, search your Keychain for
`comofficekit` and remove the entry whose service is not
`com.comofficekit.license`.

In practice this reaches nobody: no release before 0.9.18 could be unlocked at
all, and 0.9.18 was never delivered.

There is no 0.9.19 release. That engine tag fixed the two `Configuration`
defaults; re-scanning its artefacts byte-wise found the bundle identifier, so it
was superseded before it shipped.

A guard now fails the engine's build if an unrelated name reaches a licensee
again — through a string literal or a `///` comment in any module compiled into
these XCFrameworks, or through a file that writes text into them without being
compiled in, which is the category the bundle identifier belonged to.

## 0.9.18 — 2026-09-14

Engine tag `0.9.18` (`6d52088`).

**Licensing is offline and signed, and this is a breaking change.**
ComOfficeKit is quoted and delivered by sales, never sold self-serve, so there
is no store to activate against — and the gate in 0.9.16/0.9.17 could only
verify a key against one, which means **neither of those releases could be
unlocked by anybody**. A licence is now a signed line issued with your
contract, verified on the device.

- `activate(key:)` is throwing and synchronous; `revalidate` is gone.
- `State.revoked` → `.expired`; errors `.network` / `.malformedResponse` →
  `.expired` / `.noVerificationKey`; `Configuration` loses `storeID`,
  `offlineGraceDays` and `buyURL`, gains `contactURL`; `licensedTo` and
  `licenceExpires` are new.
- **No network calls at all.** A sandboxed macOS app needs no entitlement for
  licensing, and "documents never leave the process" now has no asterisk.
- A licence **cannot be revoked** and **expires on its date, inclusively**
  (`2027-09-14` works through the whole of the 14th, UTC). No grace period.

See [Licensing](docs/licensing.md); the samples show the new calls.

## 0.9.17 — 2026-09-14

Engine tag `0.9.17` (`d60c3a6`). Public API unchanged
(surface and digest identical to 0.9.16). Re-cut for the two findings from the
first release:

- **Licence storage never blocks.** A differently signed
  binary reading another binary's licence item used to hang on the macOS Keychain
  prompt; now every Keychain call is non-interactive, an item this binary cannot
  read is treated as "not activated here" for the process (never read,
  overwritten or deleted), and the not-activated path performs no storage I/O.
- **Clean archives**: line tables only, no host
  paths, no clang-module breadcrumbs. `DocumentCore.xcframework.zip` 24.1 MB,
  `AppleRender.xcframework.zip` 3.6 MB (were 30.3 MB and 4.6 MB); a consumer's
  debug relink prints no `.pcm` warnings.
- Documentation: architecture diagram; the two troubleshooting rows those
  findings needed are gone.

- Documentation rewritten for licensees: README with the capability matrix,
  requirements and footprint; `docs/` guides for DOCX, XLSX, PPTX, rendering,
  licensing, batch use, performance, the JSON snapshot schema, limits and FAQ,
  App Store and distribution; an API overview. Every code sample is a function
  in the new `Samples/Sample-Cookbook`, compiled against the release frameworks.

## 0.9.16 — 2026-09-13

First release. Engine tag `0.9.16`, binaries from the engine's
XCFrameworks workflow on that tag, licence gate on.

- `DocumentCore.xcframework` + `AppleRender.xcframework` — macOS arm64/x86_64,
  iOS arm64, iOS Simulator arm64/x86_64 — and the `TruePathCore_AppleRender`
  fonts bundle.
- DocC archives for both modules; every public declaration is documented as of
  this engine tag.
- `Package.swift` generated for this release (checksums of the attached zips).
- Not yet: the EULA text (LICENSE.md is a placeholder), iOS
  validation on a simulator runtime.

- Samples: `Sample-EmbedInApp` (tabbed SwiftUI viewer + licence sheet) and
  `Sample-EnterpriseBatch` (`render` / `extract` / `convert`, licence via
  `COMOFFICEKIT_KEY`, exit codes 0/1/2/3).
