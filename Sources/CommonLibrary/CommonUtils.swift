import CommonCrypto
import Foundation

func sha256Hash(_ string: String) -> String {
  let data = Data(string.utf8)
  var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
  data.withUnsafeBytes {
    _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &hash)
  }
  let hexString = hash.map { String(format: "%02x", $0) }.joined()
  return hexString
}
