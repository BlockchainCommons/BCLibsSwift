import Foundation

private func shim_crc32(bytes: UnsafePointer<UInt8>!, len: Int) -> UInt32 {
    crc32(bytes, len)
}

private func shim_crc32n(bytes: UnsafePointer<UInt8>!, len: Int) -> UInt32 {
    crc32n(bytes, len)
}

public enum CryptoBase {
    public static func identify() -> String {
        "CryptoBase"
    }

    public static func sha256(data: Data) -> Data {
        var output = Data(repeating: 0, count: 32)
        output.withUnsafeMutableBytes { oo in
            data.withUnsafeBytes { pp in
                let o = oo.bindMemory(to: UInt8.self).baseAddress!
                let p = pp.bindMemory(to: UInt8.self).baseAddress!
                sha256_Raw(p, data.count, o)
            }
        }
        return output
    }

    public static func sha512(data: Data) -> Data {
        var output = Data(repeating: 0, count: 64)
        output.withUnsafeMutableBytes { oo in
            data.withUnsafeBytes { pp in
                let o = oo.bindMemory(to: UInt8.self).baseAddress!
                let p = pp.bindMemory(to: UInt8.self).baseAddress!
                sha512_Raw(p, data.count, o)
            }
        }
        return output
    }

    public static func hmacSHA256(key: Data, message: Data) -> Data {
        var output = Data(repeating: 0, count: 32)
        output.withUnsafeMutableBytes { oo in
            key.withUnsafeBytes { kk in
                message.withUnsafeBytes { mm in
                    let o = oo.bindMemory(to: UInt8.self).baseAddress!
                    let k = kk.bindMemory(to: UInt8.self).baseAddress!
                    let m = mm.bindMemory(to: UInt8.self).baseAddress!
                    hmac_sha256(k, UInt32(key.count), m, UInt32(message.count), o)
                }
            }
        }
        return output
    }

    public static func hmacSHA512(key: Data, message: Data) -> Data {
        var output = Data(repeating: 0, count: 64)
        output.withUnsafeMutableBytes { oo in
            key.withUnsafeBytes { kk in
                message.withUnsafeBytes { mm in
                    let o = oo.bindMemory(to: UInt8.self).baseAddress!
                    let k = kk.bindMemory(to: UInt8.self).baseAddress!
                    let m = mm.bindMemory(to: UInt8.self).baseAddress!
                    hmac_sha512(k, UInt32(key.count), m, UInt32(message.count), o)
                }
            }
        }
        return output
    }

    public static func pbkdf2HMACSHA256(pass: Data, salt: Data, iterations: Int, keyLen: Int) -> Data {
        var key = Data(repeating: 0, count: keyLen)
        key.withUnsafeMutableBytes { kk in
            pass.withUnsafeBytes { pp in
                salt.withUnsafeBytes { ss in
                    let k = kk.bindMemory(to: UInt8.self).baseAddress!
                    let p = pp.bindMemory(to: UInt8.self).baseAddress!
                    let s = ss.bindMemory(to: UInt8.self).baseAddress!
                    pbkdf2_hmac_sha256(p, Int32(pass.count), s, Int32(salt.count), UInt32(iterations), k, Int32(keyLen))
                }
            }
        }
        return key
    }

    public static func crc32(data: Data) -> UInt32 {
        withUnsafeBytes(of: data) {
            let p = $0.bindMemory(to: UInt8.self).baseAddress
            return shim_crc32(bytes: p, len: data.count)
        }
    }

    public static func crc32n(data: Data) -> UInt32 {
        withUnsafeBytes(of: data) {
            let p = $0.bindMemory(to: UInt8.self).baseAddress
            return shim_crc32n(bytes: p, len: data.count)
        }
    }

}
