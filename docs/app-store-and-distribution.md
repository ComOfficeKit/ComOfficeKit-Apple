# App Store and distribution

## Embedding

- Both `.xcframework`s contain **dynamic frameworks** with Swift module
  interfaces. Add them to *Frameworks, Libraries, and Embedded Content* as
  *Embed & Sign* (SPM does this for an app target). Xcode signs them with your
  identity as it embeds them.
- The metric-compatible fonts and each framework's privacy manifest are inside
  the frameworks. Nothing goes into *Copy Bundle Resources*.
- Each slice ships with its **dSYM** inside the XCFramework, so a crash report
  that passes through the SDK's code symbolicates. The dSYMs stay out of your
  app.
- A command-line tool built in Xcode needs `@executable_path` in its *Runpath
  Search Paths*, with the frameworks beside it
  ([Getting started](getting-started.md)). An app needs nothing extra.
- The frameworks are built with library evolution: a newer Swift toolchain
  consumes them without a rebuild.
- Bitcode is not used (Apple retired it). The iOS slices are arm64 device and
  arm64/x86_64 simulator.

## Entitlements (macOS sandbox)

| Entitlement | Why |
|---|---|
| *(none for the SDK itself)* | licences are verified on the device; the SDK makes no network calls |
| `com.apple.security.files.user-selected.read-write` (or bookmarks) | so *your* app can read the document and write the saved copy; the SDK opens nothing on its own |

The Keychain works in the sandbox without an entitlement. Nothing else is
required: no temporary-exception entitlements, no helper processes.

## Privacy

- The SDK sends **nothing** off-device. Licences are signed lines verified
  locally; there is no licence server, no document content leaves the process,
  and there is no telemetry.
- **Privacy manifest.** Each framework carries its own
  `PrivacyInfo.xcprivacy`: no tracking, no tracking domains and no collected
  data. `DocumentCore` declares the file-timestamp API, for two reasons:
  C617.1, its media cache inside your app's container, and 3B52.1, the
  documents your user opens. Xcode includes both manifests in your app's
  privacy report, so you do not repeat them in your own.

## App Review notes

- Documents are processed on-device; there is no server component to describe.
- The licence check is an activation of a key your customer already holds; it
  is not an in-app purchase and does not gate App Store features (it gates the
  SDK's own engine inside your app). If your app sells document features,
  those go through StoreKit as usual.

## Updating the SDK

Replace the `ComOfficeKit` folder with the new version's. The folder name
carries no version on purpose, so nothing in your `Package.swift` changes and
SwiftPM re-resolves the path dependency on the next build. Each version's
`CHANGELOG.md` lists the engine tag and any API change;
[Migration notes](migration/README.md) has the policy.
