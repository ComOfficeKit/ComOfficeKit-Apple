import Foundation
import DocumentCore

// docs/licensing.md
enum LicenceRecipes {

    /// Activate the licence string your contract came with. Local and
    /// immediate: the licence's signature, and the product, platform, app,
    /// version and term it covers, are checked on the device, and nothing is
    /// sent anywhere. A licence that is refused changes nothing.
    static func activate(_ licence: String) throws {
        try SDKLicense.activate(key: licence)
    }

    /// Or activate from the licence file sales sends, when you received one.
    static func activate(fileAt url: URL) throws {
        try SDKLicense.activate(licenseFileAt: url)
    }

    /// What an app shows in its About box.
    static func summary() -> String {
        switch SDKLicense.state {
        case .active:
            // Only what the licence says: it may name no licensee. The end date is the day it
            // stops working, at 00:00 UTC, so it is shown in UTC: a local date would read a
            // day early west of Greenwich.
            let day = ISO8601DateFormatter(); day.formatOptions = [.withFullDate]
            let to = SDKLicense.licensedTo.map { " to \($0)" } ?? ""
            let until = SDKLicense.licenceExpires.map { ", until \(day.string(from: $0)) 00:00 UTC" } ?? ""
            return "Licensed\(to)\(until)"
        case .expired:
            return "Licence expired — contact sales to renew"
        case .notActivated:
            return "Not licensed"
        @unknown default:
            return "Not licensed"
        }
    }

    /// Every licence condition is a typed error, never a crash. Catch it
    /// separately from document errors: it is the one failure a healthy file
    /// can produce, and the one your UI answers with a licence prompt.
    static func userMessage(for error: SDKLicense.SDKLicenseError) -> String {
        switch error {
        case .notActivated: return "Enter your ComOfficeKit licence to open Office documents."
        case .invalidKey: return "That licence is not valid. Paste the whole licence from your contract email, or choose the licence file."
        case .wrongProduct: return "That licence was issued for a different product."
        case .expired: return "That licence has expired. Contact sales to renew it."
        case .platformMismatch: return "That licence does not cover this platform. Ask sales for one that includes it."
        case .bundleIDMismatch: return "That licence is for another app. Check this app's bundle identifier with sales."
        case .featureNotLicensed: return "Your licence does not include this. Ask sales to add it."
        case .versionNotLicensed: return "Your licence does not cover this version of ComOfficeKit."
        case .noVerificationKey: return "This build cannot check licences. Contact support."
        @unknown default: return error.description
        }
    }

    /// An expiry takes effect within an hour of its date, in a running process
    /// too, so a long-running one should re-check rather than assume the state
    /// it saw at launch.
    static func stillLicensed() -> Bool { SDKLicense.state == .active }

    /// Moving the seat to another machine.
    static func moveSeat() { SDKLicense.deactivate() }

    /// Fail fast before a long batch instead of on the first document.
    static func preflight() throws { try SDKLicense.checkUnlocked() }

    /// Command-line tools, tests and helpers keep the licence in memory: a
    /// Keychain item belongs to the binary that created it, so an app and a
    /// tool beside it do not share one. A tool has no bundle identifier, so it
    /// also needs a licence that names no app.
    static func configureForTools() {
        SDKLicense.configure(SDKLicense.Configuration(), storage: .memory)
    }

    /// `true` for every binary attached to a release.
    static var enforced: Bool { SDKLicense.isEnforced }
}
