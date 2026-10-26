import Foundation
import CryptoKit

func fail(_ message: String) -> Never { fputs(message + "\n", stderr); exit(1) }

final class Feed: NSObject, XMLParserDelegate {
    var enclosures: [[String: String]] = []
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName: String?, attributes: [String: String]) {
        if elementName == "enclosure" { enclosures.append(attributes) }
    }
}

// Verify the exact archive against the public key embedded by the release build.
let env = ProcessInfo.processInfo.environment
guard CommandLine.arguments.count == 3,
      let key = env["SPARKLE_PUBLIC_KEY"].flatMap({ Data(base64Encoded: $0) }),
      let publicKey = try? Curve25519.Signing.PublicKey(rawRepresentation: key),
      let parser = XMLParser(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1])) else {
    fail("Missing appcast, archive, or public key")
}
let feed = Feed(); parser.delegate = feed
guard parser.parse(), feed.enclosures.count == 1 else { fail("Expected one valid update enclosure") }
let item = feed.enclosures[0]
let archive = try Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[2]))
guard let signature = item["sparkle:edSignature"].flatMap({ Data(base64Encoded: $0) }),
      item["length"] == String(archive.count),
      publicKey.isValidSignature(signature, for: archive),
      let download = item["url"].flatMap(URL.init(string:)), download.scheme == "https",
      download.lastPathComponent == URL(fileURLWithPath: CommandLine.arguments[2]).lastPathComponent else {
    fail("Update signature, length, or download URL is invalid; refusing to publish")
}
print("Update archive signature and appcast verified.")
