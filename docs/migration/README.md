# Migration notes

ComOfficeKit follows semantic versioning.

- **0.9.x** — pre-release. The public surface is frozen by tooling (a symbol
  inventory and a signature-level digest are both gated in the engine's CI),
  but 0.9 → 1.0 may still remove or rename API; each such change is listed here
  with a note.
- **1.0** — the deprecation policy starts: a deprecated symbol stays for one
  minor release with a `@available(*, deprecated)` message naming the
  replacement, then goes in the next major.

## 1.0.0

**Licences issued for 0.9.44 and earlier stop working; ask sales for a
replacement before you move.** The API only gains: one activation call and four
licence errors. Two integration changes come with it: the frameworks are
dynamic, and the fonts moved inside `AppleRender.framework`. The
[changelog](../../CHANGELOG.md) has the detail.

- **Raise your package requirement to `from: "1.0.0"`.** SwiftPM reads
  `from: "0.9.23"` as "up to the next major version", so it never offers 1.0.0.
- **Replace your licence.** A licence that begins `COK1.` is refused with
  `.invalidKey`. The replacement may come as a licence string or as a licence
  file: pass the string to `activate(key:)`, or the file's URL to
  `activate(licenseFileAt:)`.
- **Four new licence errors:** `.platformMismatch`, `.bundleIDMismatch`,
  `.featureNotLicensed` and `.versionNotLicensed`. A `switch` over
  `SDKLicenseError` already needs `@unknown default`, so nothing fails to
  compile; add cases where your UI words them differently
  ([Licensing](../licensing.md)).
- **Tools and test runners need a licence that names no app.** A licence can now
  name the apps it is for, by bundle identifier, and a command-line tool has
  none.

- **Embed the frameworks.** In *Frameworks, Libraries, and Embedded Content*,
  change both from *Do Not Embed* to *Embed & Sign*. SwiftPM does this for an
  app target.
- **Delete `TruePathCore_AppleRender.bundle`** from *Copy Bundle Resources*,
  or from beside your tool. The fonts are in `AppleRender.framework` now.
- **A command-line tool built in Xcode:** add `@executable_path` to its
  *Runpath Search Paths*, and ship the two frameworks next to the tool.
- **Your privacy manifest:** if your app's own manifest declares the SDK's use
  of file timestamps, the frameworks' manifests now cover it. Keeping your
  entry does no harm.

## 0.9.44

Engine `0.9.44` (`0278bef`). **No breaking change:** DocumentCore adds 47
public symbols — document comparison, `TextDiff`, paragraph-mark and row
revisions, `WordLayoutRun.wordSpacing` — and removes or changes none;
AppleRender's API is unchanged.

Three behaviour changes can affect code written against 0.9.41. The
[changelog](../../CHANGELOG.md) has the detail.

- **Justified paragraphs render justified.** Page images and PDF export change
  for them; page counts do not. If you draw `WordLayout` runs yourself, add
  `WordLayoutRun.wordSpacing` to the advance of every space, or a justified line
  paints short of its frame.
- **`trackedChanges` and `hasTrackedChanges` include paragraph-mark and row
  revisions**, so a document can report more changes than before.
- **Resolving a revised paragraph mark joins the paragraph into the next one**,
  and resolving removes rows, and a table left without rows. Code that counts
  or indexes `body` across `resolvingAllRevisions` / `resolvingRevision(id:)`
  can see fewer elements.

## 0.9.41

Engine `0.9.41` (`9e0af75`). **No breaking change and no API change**: no
declaration is added, removed or changed in DocumentCore or AppleRender.

- **Xcode builds the bundle as delivered.** The XCFrameworks are now
  framework-type. If you added `$(BUILT_PRODUCTS_DIR)/include` to Import Paths
  (`SWIFT_INCLUDE_PATHS`) to make 0.9.39 build in Xcode, remove it.
- **Visible to callers: `WordParagraph.replacingRuns`.** An edit made through
  it is now saved; before, it was silently dropped. When the runs differ, the
  returned copy has `sourceXML == nil`.
- **A typed edit in a paragraph that anchors a floating text box no longer
  writes the box twice.** This was fixed in engine 0.9.40, which shipped no
  separate bundle.

## 0.9.39

Engine `0.9.39` (`781915e`). **No breaking change:** DocumentCore adds 34
public symbols and removes or changes none; AppleRender's API is unchanged.
Coming from 0.9.23 or earlier, read the 0.9.24 entry below first.

Five behaviour changes can still affect code written against 0.9.28. The
[changelog](../../CHANGELOG.md) has the detail and the measurements.

- **Shapes a slide inherits have prefixed ids.** In `SlideScene.shapes`, the
  shapes from the slide's layout and master come first and are now
  `"layout:<id>"` and `"master:<id>"`, so `Int(shape.id)` is `nil` for them. A
  lookup by id finds the slide's own shape. An edit to an inherited shape is
  not saved: the slide has no element to write it to.
- **`DocumentEngine.saveWordMetadata` changes only what differs.** A section
  the metadata does not list is left alone (it took the last listed section's
  values), empty metadata changes nothing (it reset every section), and the
  `"Wide"` margin preset is Word's: 1" top and bottom, 2" left and right.
- **`DocumentEngine.loadWordMetadata` reports three values differently.**
  `pageSizeName` is decided by the short edge, so Letter landscape reads
  `"Letter"`, not `"A4"`; a header or footer reference that writes `r:id`
  before `w:type` is read, where it read as empty; and
  `linkHeaderToPrevious` / `linkFooterToPrevious` are always `false` on the
  first section.
- **XLSX page counts change.** Charts extend the printed range and a page with
  nothing to print is left out, so `DocumentRenderer.pageCount(of:)` and
  `SpreadsheetPaginator.paginate(_:)` can return a different number of pages,
  and a page index you stored can name a different page. See
  [XLSX pages and charts](../limits-and-faq.md#xlsx-pages-and-charts).
- **A Pages file is `.word`.** `DocumentKind.fromExtension(_:)` and
  `DocumentEngine.documentKind(forExtension:)` return `.word` for `"pages"`, as
  they already returned `.presentation` for Keynote and `.spreadsheet` for
  Numbers. The engine still parses none of the three: call
  `LegacyFormatDetector.detect(extension:leadingBytes:)` before a parser, as
  for `.doc`.

Not API, but on your users' disks: the media cache moved into your app's own
Application Support folder, and the old one is neither migrated nor removed.
The changelog's *Storage* section names both paths.

## 0.9.28

**No public API change** in DocumentCore or AppleRender. Two behaviour changes
a caller can see: `DocumentEngine.saveWorkbook` writes back only the cells that
differ instead of rebuilding every sheet from text, and number formats round
half away from zero, as Excel does (`2.675` in a `0.00` cell reads `2.68`).

## 0.9.24 — breaking

Engine `0.9.24` (`c48b347`).

- `WordLayoutEngine.layout(_:options:)` is **`throws`**. It is the last public
  entry point that produced engine output without carrying the licence gate,
  and gating it required the signature. Add `try`; catch
  `SDKLicense.SDKLicenseError` where you already catch the parsers'. Code that
  renders through `DocumentRenderer` needs no change — those methods were
  already throwing.
- `SDKLicense.Storage.keychain` → `.persistent`.
- `SDKLicense.Configuration.keychainService` → `storageIdentifier`, including
  the `init(productID:storageIdentifier:contactURL:)` label.
  **The stored value does not change** (`com.comofficekit.license` by default),
  so no licence is orphaned and nobody re-activates — this is a rename in
  source only. On Apple platforms the store is still the Keychain; the name
  moved off one platform's mechanism because the same case has to mean the same
  thing where there is no Keychain.
- Not breaking, but visible: `DocumentEngine.version` stops reporting a
  hardcoded `"1.0.0"` and reports the engine tag.

## 0.9.19 through 0.9.23

**No public API change.** Each of those releases states it in the changelog
("Public API unchanged since 0.9.18"); they corrected the documentation you
receive, shipped the samples, and fixed the font licence notices. 0.9.19 was
never released — its engine tag was superseded before it shipped. Recorded here
because silence and "nothing changed" look identical in a file organised by
version.

## 0.9.18 — breaking

Licensing moved from store activation to offline signed licences, so the
licence API changed shape: `activate(key:)` is throwing and synchronous,
`revalidate` is gone, `State.revoked` became `.expired`, the `.network` and
`.malformedResponse` errors became `.expired` and `.noVerificationKey`, and
`Configuration` lost `storeID` / `offlineGraceDays` / `buyURL` and gained
`contactURL`. `licensedTo` and `licenceExpires` are new.

Nothing else in the sold API changed. Releases 0.9.16 and 0.9.17 could not be
unlocked at all (they verified against a store that does not exist), so there
is no working deployment to migrate from.

## 0.9.17

No API change (surface and digest identical to 0.9.16). Behaviour: the licence
storage never blocks on the macOS Keychain prompt — another binary's item is
treated as absent for the process — and the not-activated path performs no
storage I/O. Archives are smaller (line tables only) and a consumer's relink
prints no `.pcm` warnings.

## 0.9.16 (first release)

Engine 0.9.16 (`d185f90`). Compared with the
never-published engine builds before it:

- The convenience facade is `DocumentEngine`; it was renamed before the first
  release, so no published version used the old name.
- The page painters (`SlidePagePainter`, `WordPagePainter`,
  `SpreadsheetPagePainter`, `ChartPainter`, `EMFRenderer`) are not public;
  render through `DocumentRenderer`.
- Every public declaration in both modules carries a doc comment; the DocC
  archives attached to the release are complete.
- The enums are resilient (library evolution): exhaustive `switch`es need
  `@unknown default`.
