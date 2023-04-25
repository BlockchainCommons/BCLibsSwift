import Foundation
@_implementationOnly import CBCWally

extension Wally {
    public static func bip39Encode(data: Data) -> String {
        data.withUnsafeByteBuffer { bytes in
            var output: UnsafeMutablePointer<CChar>! = nil
            defer {
                wally_free_string(output)
            }
            precondition(bip39_mnemonic_from_bytes(nil, bytes.baseAddress, bytes.count, &output) == WALLY_OK)
            return String(cString: output)
        }
    }

    public static func bip39Decode(mnemonic: String) -> Data? {
        mnemonic.withCString { chars in
            var output = [UInt8](repeating: 0, count: mnemonic.count)
            var written = 0
            guard bip39_mnemonic_to_bytes(nil, chars, &output, output.count, &written) == WALLY_OK else {
                return nil
            }
            precondition((0...output.count).contains(written))
            return Data(bytes: output, count: written)
        }
    }

    public static func bip39AllWords() -> [String] {
        var words: [String] = []
        var WL: OpaquePointer?
        precondition(bip39_get_wordlist(nil, &WL) == WALLY_OK)
        for i in 0..<BIP39_WORDLIST_LEN {
            var word: UnsafeMutablePointer<Int8>?
            defer {
                wally_free_string(word)
            }
            precondition(bip39_get_word(WL, Int(i), &word) == WALLY_OK)
            words.append(String(cString: word!))
        }
        return words
    }
}
