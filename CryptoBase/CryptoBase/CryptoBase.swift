import Foundation
import CCryptoBase

public func sha256(data: Data) -> Data {
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

public func sha512(data: Data) -> Data {
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

public func hmacSHA256(key: Data, message: Data) -> Data {
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

public func hmacSHA512(key: Data, message: Data) -> Data {
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

public func pbkdf2HMACSHA256(pass: Data, salt: Data, iterations: Int, keyLen: Int) -> Data {
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

public func crc32(data: Data) -> UInt32 {
    withUnsafeBytes(of: data) {
        let p = $0.bindMemory(to: UInt8.self).baseAddress
        return crc32(p, data.count)
    }
}

public func crc32n(data: Data) -> UInt32 {
    withUnsafeBytes(of: data) {
        let p = $0.bindMemory(to: UInt8.self).baseAddress
        return crc32n(p, data.count)
    }
}
