# Licensing

ComOfficeKit is licensed annually per product, quoted and delivered by a
sales team. There is no store and no self-serve purchase, so there is nothing
to activate against: **your licence comes with your contract, as a licence
string or as a licence file that carries one, and the SDK verifies it on the
device.** Samples are functions in
[`Samples/Sample-Cookbook/Sources/Licence.swift`](../Samples/Sample-Cookbook/Sources/Licence.swift).

## Activate

```swift
try SDKLicense.activate(key: licence)                   // the licence string
try SDKLicense.activate(licenseFileAt: licenceFileURL)   // or the licence file
```

A licence file can take any of the forms a licence is delivered in: the XML licence file, a
text file with the licence on a `Sign=` line, or a text file that holds only the licence
string. Only the licence is read from it.

Both are local, synchronous and throwing. They check the licence's signature,
then that it covers this product, this platform, this app and this version of
the SDK, and store it. A licence that is refused changes nothing: one activated
before stays active. **No network, at activation or ever.** That is why the SDK
can say a document never leaves the process with no asterisk for the licence
check, and why a sandboxed app needs no network-client entitlement for
licensing.

The licence string is long. Paste it whole, and keep it out of source code you
share: read it from your app's configuration, or for a tool from an environment
variable.

## What a licence covers

A licence names what it is for, and the SDK checks each part on the device:

- **The features.** Every parse, save and render entry point checks that the
  licence includes what it does, and throws `.featureNotLicensed` when it does
  not.
- **The platforms.** A licence covers iOS, macOS or both. On a platform it does
  not cover, activation throws `.platformMismatch`.
- **The apps.** A licence may name the apps it is for, by bundle identifier,
  and then throws `.bundleIDMismatch` anywhere else. **A command-line tool has
  no bundle identifier**, so a tool, a test runner or a build machine needs a
  licence that names no app. Ask for one when you order licences for them.
- **The SDK's versions.** A licence may cover releases up to a version, and
  throws `.versionNotLicensed` in a later one.
- **Its term.** A licence stops working when its end date begins, at 00:00 UTC, and then
  throws `.expired`.

## What an app shows

```swift
switch SDKLicense.state {
case .active:
    let day = ISO8601DateFormatter(); day.formatOptions = [.withFullDate]   // in UTC
    let to = SDKLicense.licensedTo.map { " to \($0)" } ?? ""              // when the licence names one
    let until = SDKLicense.licenceExpires.map { ", until \(day.string(from: $0)) 00:00 UTC" } ?? ""
    print("Licensed\(to)\(until)")                                       // "Licensed, until 2027-10-20 00:00 UTC"
case .expired:
    print("Licence expired — renew with sales; nothing else changes")
case .notActivated:
    print("No licence in this process — show the activation field")
@unknown default:
    break
}
```

`licensedTo` and `licenceExpires` describe the active licence when the licence
says. Either can be `nil`, so show only what is there, not an error; licences
issued today name no licensee. The end date is the day the licence stops
working, at 00:00 UTC, so show it in UTC: a local date reads a day early west of
Greenwich.

## Two things to design around

**A licence cannot be revoked.** It is verified offline, so nothing can reach
out and withdraw it: whoever holds it keeps it working until it ends. The
contract, not the SDK, is what a breach is argued from.

**A licence ends when its end date begins, and a running app notices.** The date
counts in UTC, and the day itself is already past the licence. While your app runs,
an expiry takes effect within the hour, with no relaunch.
There is no grace period and no warning beyond the date on the contract, so an
app that runs for weeks should re-read `SDKLicense.state` rather than trust
what it saw at launch.

## Errors

Every failure is a typed `SDKLicense.SDKLicenseError`:

| Case | Meaning | What to show |
|---|---|---|
| `.notActivated` | no licence active in this process or storage scope | your licence entry UI |
| `.invalidKey` | not a ComOfficeKit licence, or altered since it was issued | "paste the whole licence from your contract email, or choose the licence file" |
| `.wrongProduct` | a valid licence for another product | "check the licence" |
| `.expired` | the licence's date has passed | "contact sales to renew" |
| `.platformMismatch` | the licence does not cover this platform | "ask sales for a licence that includes it" |
| `.bundleIDMismatch` | the licence names other apps, not this one | "check the app's bundle identifier"; a tool needs a licence that names no app |
| `.featureNotLicensed` | the licence does not include what this call does | "ask sales to add it" |
| `.versionNotLicensed` | the licence does not cover this version of the SDK | "use the version your licence covers, or ask sales to extend it" |
| `.noVerificationKey` | this build carries nothing to verify a licence with | "contact support" — you should never see it in a release |

`activate(licenseFileAt:)` also throws the file system's own error when the
file cannot be read; a file that holds no licence throws `.invalidKey`.

Catch it separately from document errors. It is the one failure a perfectly
healthy file can produce, and the one your UI should answer with a licence
prompt rather than "could not open":

```swift
do { … } catch let error as SDKLicense.SDKLicenseError { showLicenceSheet(error) }
```

`SDKLicense.checkUnlocked()` throws the reason a stored licence is refused, so
a licence entry screen can say why rather than only that it was refused.

## Fail fast

```swift
try SDKLicense.checkUnlocked()      // before a long batch, not on the first document
```

## Moving a seat

```swift
SDKLicense.deactivate()             // forgets the stored licence on this machine
```

## Storage: persistent or memory

By default (`.persistent`) the licence survives relaunches; on Apple platforms
that store is the Keychain. The case names the guarantee rather than the
mechanism, because the same enum has to mean the same thing on a platform with
no Keychain. For command-line tools, tests, previews and helper processes, keep
it in memory instead:

```swift
SDKLicense.configure(SDKLicense.Configuration(), storage: .memory)
```

On macOS a Keychain item belongs to the binary that created it. A second,
differently signed binary — a CLI next to your app, a test runner, a helper —
cannot read it, and the SDK never asks the user to allow it: every Keychain
call is non-interactive, and an unreadable item is treated as absent for that
process. So a tool beside a licensed app is simply "not licensed here" and
should activate from its own environment variable each run, or set a distinct
`storageIdentifier` (on Apple platforms that is the Keychain service string).
Remember that a tool also needs a licence that names no app.

## Licences from an earlier release

Licences issued for release 0.9.44 and earlier begin with `COK1.`. This release
does not accept them, and `activate(key:)` throws `.invalidKey`. Sales issues a
replacement; the [migration notes](migration/README.md) have the rest of the
change.

## Evaluation and enforcement

`SDKLicense.isEnforced` is `true` for every binary attached to a release, so a
build you received is always gated. Each release publishes an evaluation
licence in its README, which names no app, so it also works in tools and test
runners.
