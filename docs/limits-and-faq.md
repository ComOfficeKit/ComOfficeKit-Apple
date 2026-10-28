# Limits and FAQ

Honest edges. Everything here is by design or measured, not guessed.

## Not supported

| | Status |
|---|---|
| Running VBA macros | never — `.xlsm` opens, edits and saves with the VBA project preserved byte for byte, and `WorkbookScene.hasMacros` tells you it is there |
| `.doc` / `.xls` / `.ppt`, iWork | detected (`LegacyFormatDetector`), not parsed; ask the user to convert |
| Password-protected / IRM-protected files | not supported |
| PDF input | out of scope — the SDK reads and writes Office formats and *produces* PDF |
| Dynamic arrays / spill, `LAMBDA`, external links | not evaluated; the cell keeps its cached value; `FormulaTelemetry.unknown` names unsupported functions |
| Area, scatter, bubble, radar, stock, surface and of-pie charts | parsed as `unsupported` and drawn as an empty white area; bar / column, line, pie and doughnut render, and their 3D forms render flat |
| SmartArt | rendered from the cached drawing PowerPoint stores (shapes and labels), not re-laid-out |
| Embedded OLE objects, ActiveX, videos (playback) | preserved on save; a video's poster frame renders, `videoURL` is exposed for your player |
| Theme-colour resolution on every element | resolved for cells, fills and fonts; a few run-level scheme colours fall back to defaults |
| Fonts | only Carlito and Caladea ship; other families resolve through the system with fallbacks |
| Multi-column DOCX sections (`<w:cols>`) | laid out as a single column |
| Pictures and shapes on printed XLSX pages | not painted yet (charts are), and they do not extend the printed range; they are parsed and preserved on save — see [XLSX pages and charts](#xlsx-pages-and-charts) |
| Comparing anything but Word body text | `WordDocumentComparer` compares the text of body paragraphs and table cells; formatting-only changes, headers, footers, footnotes, text boxes, pictures and comments are not compared, and XLSX and PPTX have no comparer |
| PPTX `normAutofit` font scaling | the scale is parsed (`TextBodyProperties.autoFitFontScale`) but the page painter does not yet apply it |

## XLSX pages and charts

`DocumentRenderer` prints an XLSX sheet's range up to the last cell that leaves
ink — a value, a fill or a border — or the last merged range, table or chart,
whichever is further: charts count, as they do in Excel and LibreOffice. Each
chart is drawn where it floats, at its own size, and a page with nothing to
print is left out, as LibreOffice does by default. Measured through
`DocumentRenderer.pageCount(of:)` and `image(of:page:)` on 0.9.39, with
identical results on macOS and on the iOS simulator:

| The sheet holds | What renders |
|---|---|
| a chart inside the cells' range | the chart, in its anchor |
| a chart past the last used cell | the chart, on the page or pages it falls on |
| a chart and no cells | one page, showing the chart |
| a chart that crosses the right or bottom edge of the used range | the chart, at its full size |
| a chart that straddles a page break | the chart at its full size, part on each page |
| text in A1 and Z200 and nothing between | 2 pages — the range spans 15, and the 13 with nothing on them are left out |

A declared print area (`_xlnm.Print_Area`) replaces the used range: a chart
inside it prints, a chart outside it does not, and a page of the area with
nothing on it is still left out. Pictures and shapes neither print nor extend
the range. Every chart and its anchor is in `SheetScene.charts`.

0.9.28 and earlier sized the printed range from cells alone: a chart past the last used
cell did not render, a chart-only sheet had no pages, and a chart crossing the
edge of the range or a page break was squeezed to fit. If you store page
indexes, the [changelog](../CHANGELOG.md) for 0.9.39 has what changed.

## iOS: what has run where

| | |
|---|---|
| iOS simulator | **runs.** 0.9.44 — the binaries in this bundle, consumed through its `Package.swift` — on the iOS 26.3.1 simulator: the licence gate refused before activation and opened after it; a DOCX parsed, laid out, and rendered to an image and to a PDF; an XLSX written, saved, re-read and computed; a PPTX written, saved and re-read; two documents compared and the result written as a `.docx`; XLSX pages with charts paginated and drawn, matching macOS |
| Compile and link | every change to the engine is compiled for the device and the simulator, and a simulator binary is linked against it |
| iPhone | **runs.** 0.9.41, the same checks, in an iOS app built through Xcode with no extra build settings, on an iPhone 14 Pro Max running iOS 26.6.2. 0.9.44 builds and installs on that iPhone the same way |
| iPad | not run; it takes the same `ios-arm64` slice as the iPhone |
| Oldest iOS | 16 is the deployment target the slices are built for; the oldest releases the engine has actually run on are the 26.3.1 simulator and, on hardware, iOS 26.6.2 |

## Byte-preserving — what it means exactly

Parts and elements you did not touch are copied verbatim. Regenerated
elements are valid OOXML that Word, Excel and PowerPoint open without repair,
but they are not byte-identical to what the original application would have
written (attribute order, whitespace, ids may differ). The package is re-zipped
on save, so the archive bytes can differ even when no part changed; the
engine's tests hold that an unmodified DOCX saves byte-identically and that
untouched parts of every format are copied verbatim.

## FAQ

**Does it need a network connection?** No. Licences are signed lines verified
on the device, and documents never leave the process. The SDK makes no network
calls at all.

**Does it work in the macOS sandbox / on the Mac App Store?** Yes. All ZIP and
XML work is in-process, and the licence is verified on the device, so no
network-client entitlement is needed.
See [App Store and distribution](app-store-and-distribution.md).

**Is it thread-safe?** Parsers, writers and the renderer are stateless static
functions; scenes are `Sendable` values; `SDKLicense` is lock-protected. See
[Errors and threading](errors-and-threading.md).

**How big does my app get?** The frameworks are dynamic, so your app carries
them whole. On an iPhone that is about 5 MB for `DocumentCore`, 1.3 MB for
`AppleRender` and 2.9 MB of fonts, before the App Store's compression. The
archives you download are larger, because they carry every slice and the
dSYMs, which stay out of your app.

**Can I render without the bundled fonts?** They are part of
`AppleRender.framework`, so an app that renders has them. If they cannot be
found — a framework copied without its resources, say — layout falls back to
system fonts, and documents set in Calibri or Cambria will paginate differently
from Word.

**How accurate is the rendering?** The engine's nightly CI renders a
568-document corpus and compares it with LibreOffice; regressions block the
release. Word layout honours sections, floats, tables, footnotes and the
East-Asian document grid (multi-column sections are laid out as one column —
see the limits table above); where PowerPoint and LibreOffice disagree, the
engine follows the file format.

**How accurate are formulas?** 91.6% of 232,000 corpus formula cells match
Excel's cached value; 95.0% excluding cells whose cached value is an error.

**Is there a JSON or non-Swift API?** `WordDocumentSceneJSON` for DOCX; other
formats on request. A command-line and an MCP surface exist over the same
engine and are the candidates for a non-Swift API.

**What does a licence error look like in production?** A typed
`SDKLicense.SDKLicenseError` from the first gated call. Catch it before your
generic error path and show the licence prompt. Note `.expired`: a licence ends
on its date with no grace period, so a long-running app should re-read
`SDKLicense.state` rather than trust what it saw at launch.
