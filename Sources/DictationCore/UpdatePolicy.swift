import Foundation

public enum UpdatePolicy {
    public static func validConfiguration(feed: String?, publicKey: String?) -> Bool {
        guard let feed, let url = URL(string: feed), url.scheme == "https",
              let host = url.host, !host.isEmpty, url.user == nil, url.password == nil,
              let publicKey, Data(base64Encoded: publicKey)?.count == 32 else { return false }
        return true
    }

    public static func mayRestart(recording: Bool, starting: Bool, busy: Bool,
                                  submitting: Bool, hasUnpastedText: Bool, dashboardActive: Bool) -> Bool {
        !recording && !starting && !busy && !submitting && !hasUnpastedText && !dashboardActive
    }
}
