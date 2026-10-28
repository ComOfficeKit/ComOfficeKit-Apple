# Getting started

Ten minutes from an empty target to a rendered page.

## 1. Add the package

You received ComOfficeKit as a self-contained folder. Put it beside your
project and depend on it **by path** — nothing is downloaded, there are no
credentials, and no network is touched at build time.

**Swift Package Manager**

```swift
// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "YourApp",
    platforms: [.macOS(.v13)],                 // the SDK requires macOS 13 / iOS 16
    dependencies: [
        .package(path: "../ComOfficeKit"),
    ],
    targets: [
        .executableTarget(name: "YourApp", dependencies: [
            .product(name: "DocumentCore", package: "ComOfficeKit"),
            .product(name: "AppleRender",  package: "ComOfficeKit"),
        ]),
    ]
)
```

## Toolchain

**Build with Xcode 26 or later.** Xcode 16 cannot link these frameworks.

They are built with the macOS 26 SDK, and `_modify` accessors in the licence
storage reference the Swift runtime entry point `_swift_coroFrameAlloc`. The
macOS 15 SDK's `libswiftCore.tbd` does not declare that symbol, so the linker
reports it undefined instead of binding it weakly, and you get:

```
Undefined symbols for architecture arm64:
  "_swift_coroFrameAlloc", referenced from:
    SDKLicensing.KeychainLicenseStorage.firstLaunch.modify …
```

That error names an internal type and reads like a broken release. It is not:
it means the toolchain is below the floor.

Measured, not assumed — every ComOfficeKit release is built by all three
samples on both ends of the supported range:

| Xcode | Swift | macOS SDK | Result |
|---|---|---|---|
| 16.4 | 6.1 | 15 | **fails to link** |
| 26.0.1 | 6.2 | 26.0 | builds |
| 26.6 | 6.3.3 | 26.5 | builds |

There is no Xcode between 16 and 26, so the floor is exactly Xcode 26.0.

**This is a build requirement, not a deployment one.** Your app still runs on
macOS 13 and iOS 16: the reference is weak and every call site is guarded, so
on a system whose runtime lacks the symbol the engine takes its fallback path.
The frameworks' own minimum is `minos 13.0`.

## Two more things that fail the build if missed

- **`platforms`.** Without it the target defaults to macOS 10.13 and SwiftPM
  refuses: *"requires macos 10.13, but depends on the product 'DocumentCore'
  which requires macos 13.0"*.
- **The folder name.** SwiftPM names a path dependency after its directory. If
  your copy is not called `ComOfficeKit` — you cloned it from a repository
  with another name, say — either rename the folder or name the package
  explicitly: `.package(name: "ComOfficeKit", path: "../whatever-it-is-called")`.

`AppleRender` depends on `DocumentCore`; add both even if you only render.

**Xcode project:** *File ▸ Add Package Dependencies… ▸ Add Local…*, pick the
folder, add both products to your app target. The folder name does not matter
here.

**Manual (no SPM):** drag `XCFrameworks/DocumentCore.xcframework` and
`XCFrameworks/AppleRender.xcframework` into *Frameworks, Libraries, and
Embedded Content*. They are dynamic frameworks — choose *Embed & Sign*. Xcode
signs them with your identity as it embeds them.

**Command-line tool:** an app embeds the frameworks in
`Contents/Frameworks`, and `swift build` / `swift run` puts them next to the
executable with a run path that finds them. A command-line tool built in Xcode
gets the frameworks copied beside it but no run path to find them there: add
`@executable_path` to its *Runpath Search Paths*
(`LD_RUNPATH_SEARCH_PATHS = $(inherited) @executable_path`), and ship the two
frameworks next to the tool.

The three projects in `Samples/` consume the same frameworks; `swift build` in
any of them is the quickest proof that the bundle is intact.

## 2. Fonts

Word and slide layout uses two metric-compatible families so documents
authored on Windows paginate identically: **Carlito** (≙ Calibri) and
**Caladea** (≙ Cambria). They ship inside `AppleRender.framework`, so there is
nothing to copy: an app or a tool that loads the framework has them.

- **Register once** before the first render (reading the static does it):

```swift
import AppleRender
_ = FontRegistration.ensure
```

If the fonts cannot be found, the engine falls back to system fonts — a fidelity loss on
Calibri/Cambria documents, never a crash.

## 3. Activate the licence

```swift
import DocumentCore

// The licence string from your contract, or the licence file that carries it.
// Verified on the device: no network, no waiting. Stored in the Keychain.
try SDKLicense.activate(key: licence)
// try SDKLicense.activate(licenseFileAt: licenceFileURL)
```

Every parse, save and render entry point checks the licence. It throws
`SDKLicense.SDKLicenseError.notActivated` until one is active, and otherwise
the reason the licence does not cover the call, such as `.featureNotLicensed`.
Command-line tools and tests keep the licence in memory instead of the
Keychain, and need a licence that names no app — see [Licensing](licensing.md)
for why, and for what an expiry does.

## 4. Parse, inspect, render

```swift
import DocumentCore
import AppleRender

let scene = try DocumentParser.parse(docxAt: url)
print(scene.body.count, "body elements (paragraphs and tables)")

let doc = ParsedDocument.word(scene)
let pageCount = try DocumentRenderer.pageCount(of: doc)
let firstPage = try DocumentRenderer.image(of: doc, page: 0, scale: 2)   // CGImage, 2× (Retina)
let pdf = try DocumentRenderer.pdfData(of: doc, pages: 0..<pageCount)      // vector PDF
```

The same three lines work for a workbook (`SpreadsheetParser.parse(xlsxAt:)` →
`ParsedDocument.workbook`) and a deck (`SlideParser.parse(pptxAt:)` →
`ParsedDocument.slides`). Rendering is synchronous and CPU-bound — call it off
the main thread ([Rendering](guide-rendering.md)).

## 5. Project checklist

- [ ] Both products linked; `import DocumentCore` and `import AppleRender` compile.
- [ ] Both frameworks embedded (*Embed & Sign*); a command-line tool built in Xcode has `@executable_path` in its *Runpath Search Paths* and the frameworks beside it.
- [ ] `SDKLicense.activate(key:)` or `activate(licenseFileAt:)` wired to your licence entry; `SDKLicense.state` re-read rather than cached in a long-running app.
- [ ] Licence errors handled as `SDKLicense.SDKLicenseError` (they are typed, and they are the only errors a healthy document can throw).
- [ ] Rendering and parsing of large files off the main thread.
- [ ] Sandboxed macOS apps: no entitlement needed for licensing — the SDK makes no network calls at all ([App Store and distribution](app-store-and-distribution.md)).

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `Undefined symbols … "_swift_coroFrameAlloc"` when linking | the toolchain is below the floor — Xcode 16's SDK does not declare that runtime symbol | build with **Xcode 26 or later** ([Toolchain](#toolchain)). Nothing is wrong with the release or with your code |
| `SDKLicenseError.notActivated` on every call | no licence activated in this process / Keychain scope | call `activate(key:)` or `activate(licenseFileAt:)`; for tools, `SDKLicense.configure(.init(), storage: .memory)` first |
| `SDKLicenseError.bundleIDMismatch` in a command-line tool or a test runner | the licence names apps by bundle identifier, and a tool has none | use a licence that names no app ([Licensing](licensing.md)) |
| `SDKLicenseError.invalidKey` with a licence that begins `COK1.` | it was issued for release 0.9.44 or earlier, and this release does not accept it | ask sales for a replacement ([Migration notes](migration/README.md)) |
| A tool next to your app reports `.notActivated` although the app activated | each binary owns its own Keychain item; another binary's item is treated as absent (never read, changed or deleted) | tools use `storage: .memory` and activate per run from an environment variable, or set a distinct `storageIdentifier` ([Licensing](licensing.md)) |
| Calibri/Cambria documents paginate differently from Word | the fonts inside `AppleRender.framework` were not found: the framework was copied without its resources, or a tool runs without the frameworks beside it | embed the whole framework (*Embed & Sign*), and read `FontRegistration.ensure` before rendering |
| `DocumentRenderer.RenderError.pageOutOfRange` | page index ≥ `pageCount` | page indices are 0-based |

Next: [API overview](api-overview.md) for the map of the two modules, then the
guide for your format.
