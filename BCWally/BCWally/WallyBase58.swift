import Foundation
@_implementationOnly import CBCWally

extension Wally {
    public static func base58(from key: WallyExtKey, isPrivate: Bool) -> String? {
        guard
            !Data(of: key.wrapped.chain_code).isAllZero,
            key.wrapped.version != 0
        else {
            return nil
        }

        let flags = UInt32(isPrivate ? BIP32_FLAG_KEY_PRIVATE : BIP32_FLAG_KEY_PUBLIC)
        var output: UnsafeMutablePointer<Int8>?
        defer {
            wally_free_string(output)
        }
        return withUnsafePointer(to: key.wrapped) {
            guard bip32_key_to_base58($0, flags, &output) == WALLY_OK else {
                return nil
            }
            return String(cString: output!)
        }
    }
    
    public static func base58(data: Data, isCheck: Bool) -> String {
        data.withUnsafeByteBuffer { p in
            var result: UnsafeMutablePointer<CChar>?
            precondition(
                wally_base58_from_bytes(
                    p.baseAddress,
                    p.count,
                    isCheck ? UInt32(BASE58_FLAG_CHECKSUM) : 0,
                    &result
                ) == WALLY_OK
            )
            let s = String(cString: result!)
            wally_free_string(result)
            return s
        }
    }
    
    public static func decodeBase58(_ s: String, isCheck: Bool) -> Data? {
        var output = [UInt8](repeating: 0, count: s.count)
        var written = 0
        guard wally_base58_to_bytes(s, isCheck ? UInt32(BASE58_FLAG_CHECKSUM) : 0, &output, output.count, &written) == WALLY_OK else {
            return nil
        }
        return Data(bytes: output, count: written)
    }
}
