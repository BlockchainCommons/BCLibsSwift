import Foundation
@_implementationOnly import CBCWally

public extension Wally {
    static let ecPublicKeyLen = Int(EC_PUBLIC_KEY_LEN)
    static let ecSignatureDerMaxLowRLen = Int(EC_SIGNATURE_DER_MAX_LOW_R_LEN)
    static let sighashAll = UInt8(WALLY_SIGHASH_ALL)
    static let ecMessageHashLen = Int(EC_MESSAGE_HASH_LEN)
    static let sha256Len = Int(SHA256_LEN)
    
    static func ecPublicKeyFromPrivateKey(data: Data) -> Data {
        data.withUnsafeByteBuffer { inputBytes in
            var result = Data(count: Int(EC_PUBLIC_KEY_LEN))
            result.withUnsafeMutableByteBuffer { outputBytes in
                precondition(
                    wally_ec_public_key_from_private_key(
                        inputBytes.baseAddress,
                        inputBytes.count,
                        outputBytes.baseAddress,
                        outputBytes.count
                    ) == WALLY_OK
                )
            }
            return result
        }
    }

    static func ecPublicKeyDecompress(data: Data) -> Data {
        data.withUnsafeByteBuffer { inputBytes in
            var result = Data(count: Int(EC_PUBLIC_KEY_UNCOMPRESSED_LEN))
            result.withUnsafeMutableByteBuffer { outputBytes in
                precondition(
                    wally_ec_public_key_decompress(
                        inputBytes.baseAddress,
                        inputBytes.count,
                        outputBytes.baseAddress,
                        outputBytes.count
                    ) == WALLY_OK
                )
            }
            return result
        }
    }
    
    func ecPublicKeyCompress(uncompressedKey: Data) -> Data {
        precondition(uncompressedKey.count == 65)
        precondition(uncompressedKey[0] == 0x04)

        let x = uncompressedKey[1...32]
        let y = uncompressedKey[33...64]

        if y.last! % 2 == 0 {
            return Data([0x02]) + x
        } else {
            return Data([0x03]) + x
        }
    }
}

public extension Wally {
    static func ecPrivateKeyVerify(_ privKey: Data) -> Bool {
        privKey.withUnsafeByteBuffer {
            wally_ec_private_key_verify($0.baseAddress, $0.count) == WALLY_OK
        }
    }

    static func ecSigFromBytes(privKey: Data, messageHash: Data) -> Data {
        privKey.withUnsafeByteBuffer { privKeyBytes in
            messageHash.withUnsafeByteBuffer { messageHashBytes in
                var compactSig = [UInt8](repeating: 0, count: Int(EC_SIGNATURE_LEN))
                precondition(wally_ec_sig_from_bytes(privKeyBytes.baseAddress, privKeyBytes.count, messageHashBytes.baseAddress, messageHashBytes.count, UInt32(EC_FLAG_ECDSA | EC_FLAG_GRIND_R), &compactSig, compactSig.count) == WALLY_OK)
                return Data(compactSig)
            }
        }
    }

    static func ecSigVerify(key: WallyExtKey, messageHash: Data, compactSig: Data) -> Bool {
        withUnsafeByteBuffer(of: key.wrapped.pub_key) { pubKeyBytes in
            messageHash.withUnsafeByteBuffer { messageHashBytes in
                compactSig.withUnsafeByteBuffer { compactSigBytes in
                    wally_ec_sig_verify(pubKeyBytes.baseAddress, pubKeyBytes.count, messageHashBytes.baseAddress, messageHashBytes.count, UInt32(EC_FLAG_ECDSA), compactSigBytes.baseAddress, compactSigBytes.count) == WALLY_OK
                }
            }
        }
    }

    static func ecSigNormalize(compactSig: Data) -> Data {
        compactSig.withUnsafeByteBuffer { compactSigBytes in
            var sigNormBytes = [UInt8](repeating: 0, count: Int(EC_SIGNATURE_LEN))
            precondition(wally_ec_sig_normalize(compactSigBytes.baseAddress, compactSigBytes.count, &sigNormBytes, Int(EC_SIGNATURE_LEN)) == WALLY_OK)
            return Data(sigNormBytes)
        }
    }

    static func ecSigToDer(sigNorm: Data) -> Data {
        sigNorm.withUnsafeByteBuffer { sigNormBytes in
            var sig_bytes = [UInt8](repeating: 0, count: Int(EC_SIGNATURE_DER_MAX_LEN))
            var sig_bytes_written = 0
            precondition(wally_ec_sig_to_der(sigNormBytes.baseAddress, sigNormBytes.count, &sig_bytes, Int(EC_SIGNATURE_DER_MAX_LEN), &sig_bytes_written) == WALLY_OK)
            return Data(bytes: sig_bytes, count: sig_bytes_written)
        }
    }
}
