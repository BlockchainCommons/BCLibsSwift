import Foundation
import CBIP39

public struct BIP39Error: Error {
    public let message: String
    init(_ message: String) { self.message = message }
    var localizedDescription: String { message }
}

public enum BIP39 {
    public static func word(for index: Int) throws -> String {
        guard (0..<2048).contains(index) else {
            throw BIP39Error("BIP39 word index out of range.")
        }
        var word = [UInt8](repeating: 0, count: 20)
        word.withUnsafeMutableBytes {
            bip39_mnemonic_from_word(UInt16(index), $0.bindMemory(to: Int8.self).baseAddress)
        }
        return String(cString: word)
    }

    public static func index(for word: String) throws -> Int {
        let result = Int(bip39_word_from_mnemonic(word.cString(using: .utf8)))
        guard result != -1 else {
            throw BIP39Error("Invalid BIP39 word.")
        }
        return result
    }

    public static func seed(for string: String) -> Data {
        var bytes = [UInt8](repeating: 0, count: Int(BIP39_SEED_LEN))
        bip39_seed_from_string(string.cString(using: .utf8), &bytes)
        return Data(bytes)
    }

    public static func encode(_ data: Data) throws -> String {
        try data.withUnsafeBytes { dataBytes in
            let maxMnemonicsCount = 300
            var mnemonics = [UInt8](repeating: 0, count: maxMnemonicsCount)
            let len = mnemonics.withUnsafeMutableBytes { mnemonicsBytes in
                bip39_mnemonics_from_secret(dataBytes.bindMemory(to: UInt8.self).baseAddress, data.count, mnemonicsBytes.bindMemory(to: Int8.self).baseAddress, maxMnemonicsCount)
            }
            guard len != 0 else {
                throw BIP39Error("BIP39 encoding only works on 8, 12, 16, 20, 24, 28, or 32 bytes.")
            }
            return String(cString: mnemonics)
        }
    }

    public static func decode(_ words: String) throws -> Data {
        let maxSecretCount = 32
        var secret = [UInt8](repeating: 0, count: maxSecretCount)
        let len = secret.withUnsafeMutableBytes {
            bip39_secret_from_mnemonics(words.cString(using: .utf8), $0.bindMemory(to: UInt8.self).baseAddress, maxSecretCount)
        }
        guard len != 0 else {
            throw BIP39Error("Invalid BIP39 words.")
        }
        return Data(secret[0..<len])
    }
}
