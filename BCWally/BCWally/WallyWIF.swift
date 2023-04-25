import Foundation
@_implementationOnly import CBCWally

extension Wally {
    public static func encodeWIF(key: Data, network: Network, isPublicKeyCompressed: Bool) -> String {
        var output: UnsafeMutablePointer<Int8>!
        defer {
            wally_free_string(output)
        }
        key.withUnsafeByteBuffer { buf in
            precondition(wally_wif_from_bytes(buf.baseAddress, buf.count, network.wifPrefix, UInt32(isPublicKeyCompressed ? WALLY_WIF_FLAG_COMPRESSED : WALLY_WIF_FLAG_UNCOMPRESSED), &output) == WALLY_OK)
        }
        return String(cString: output)
    }
}
