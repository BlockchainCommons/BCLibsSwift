import Foundation
import CShamir

struct ShamirError: Error {
    let message: String
    init(_ message: String) { self.message = message }
}

class Wrapper<T> {
    let value: T
    init(_ value: T) { self.value = value }

    var ref: UnsafeMutableRawPointer {
        Unmanaged.passUnretained(self).toOpaque()
    }

    static func get(_ ref: UnsafeMutableRawPointer) -> T {
        let wrapper: Unmanaged<Wrapper<T>> = Unmanaged.fromOpaque(ref)
        let w = wrapper.takeUnretainedValue()
        return w.value
    }
}

public typealias RandomFunc = (Int) -> Data

public struct ShamirShare {
    public let index: Int
    public var data: [UInt8]
}

public func splitSecret(threshold: Int, shareCount: Int, secret: Data, randomGenerator: @escaping RandomFunc) -> [ShamirShare] {
    let wrapper = Wrapper(randomGenerator)

    var result = Data(count: secret.count * shareCount)
    result.withUnsafeMutableBytes { rr in
        secret.withUnsafeBytes { ss in
            let s = ss.bindMemory(to: UInt8.self).baseAddress!
            let r = rr.bindMemory(to: UInt8.self).baseAddress!
            let error = split_secret(UInt8(threshold), UInt8(shareCount), s, UInt32(secret.count), r, wrapper.ref, { p, len, ctx in
                let rng = Wrapper<RandomFunc>.get(ctx!)
                let randomData = rng(len)
                assert(randomData.count == len)
                for i in 0 ..< len {
                    p![i] = randomData[i]
                }
            })
            assert(error == shareCount)
        }
    }
    var shares = [ShamirShare]()
    for index in 0 ..< shareCount {
        let offset = index * secret.count
        let data = Array(result[offset ..< (offset + secret.count)])
        shares.append(ShamirShare(index: index, data: data))
    }
    return shares
}

public func recoverSecret(shares: [ShamirShare]) throws -> Data {
    let shareCount = shares.count
    guard shareCount > 0 else {
        throw ShamirError("No shares provided")
    }

    let shareLengths = Set(shares.map { $0.data.count })
    guard shareLengths.count == 1 else {
        throw ShamirError("Shares don't all have the same length")
    }
    let shareLength = shareLengths.first!

    var indexes = [UInt8](repeating: 0, count: shareCount)
    var shareDataPointers = [UnsafePointer<UInt8>?](repeating: nil, count: shareCount)
    defer {
        for i in 0 ..< shareCount {
            if let d = shareDataPointers[i] {
                d.deallocate()
            }
        }
    }
    for i in 0 ..< shareCount {
        let share = shares[i]
        indexes[i] = UInt8(share.index)
        let shareDataPointer = UnsafeMutablePointer<UInt8>.allocate(capacity: shareLength)
        for j in 0 ..< shareLength {
            shareDataPointer[j] = share.data[j]
        }
        shareDataPointers[i] = UnsafePointer(shareDataPointer)
    }
    var secret = [UInt8](repeating: 0, count: shareLength)
    let error = recover_secret(UInt8(shareCount), &indexes, &shareDataPointers, UInt32(shareLength), &secret)
    guard error == shareLength else {
        throw ShamirError("Shamir decoding error: \(error)")
    }
    return Data(secret)
}
