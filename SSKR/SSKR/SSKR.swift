import Foundation

public func identify() -> String {
    "SSKR"
}

public struct SSKRError: Error {
    public let message: String
    public init(_ message: String) { self.message = message }
    var localizedDescription: String { message }
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

public typealias SSKRGroupDescriptor = sskr_group_descriptor_struct

public func SSKRCountShares(groupThreshold: Int, groups: [SSKRGroupDescriptor]) throws -> Int {
    let result = sskr_count_shards(groupThreshold, groups, groups.count)
    guard result >= 0 else {
        throw SSKRError("SSKR error: \(result)")
    }
    return Int(result)
}

public struct SSKRShare {
    public let data: [UInt8]

    public init(data: [UInt8]) {
        self.data = data
    }
}

public func SSKRGenerate(groupThreshold: Int, groups: [SSKRGroupDescriptor], secret: Data, randomGenerator: @escaping RandomFunc) throws -> [[SSKRShare]] {
    let wrapper = Wrapper(randomGenerator)
    let shareLen = secret.count + 5
    let shareCount = try SSKRCountShares(groupThreshold: groupThreshold, groups: groups)
    let outputLen = shareCount * shareLen
    var output = [UInt8](repeating: 0, count: outputLen)
    var resultShardLen = 0

    let error = secret.withUnsafeBytes { masterSecretBufferPointer -> Int32 in
        let masterSecretPointer = masterSecretBufferPointer.bindMemory(to: UInt8.self).baseAddress!
        return sskr_generate(groupThreshold, groups, groups.count, masterSecretPointer, secret.count, &resultShardLen, &output, outputLen, wrapper.ref, { p, len, ctx in
            let rng = Wrapper<RandomFunc>.get(ctx!)
            let randomData = rng(len)
            assert(randomData.count == len)
            for i in 0 ..< len {
                p![i] = randomData[i]
            }
        })
    }
    guard error == shareCount else {
        throw SSKRError("SSKR encoding error: \(error)")
    }
    var groupShares = [[SSKRShare]]()
    var offset = 0
    for group in groups {
        var shares = [SSKRShare]()
        for _ in 0 ..< group.count {
            let data = Array(output[offset ..< (offset + shareLen)])
            shares.append(SSKRShare(data: data))
            offset += shareLen
        }
        groupShares.append(shares)
    }
    return groupShares
}

public func SSKRCombine(shares: [SSKRShare]) throws -> Data {
    let shareCount = shares.count
    guard shareCount > 0 else {
        throw SSKRError("No shares provided")
    }

    let shareLengths = Set(shares.map { $0.data.count })
    guard shareLengths.count == 1 else {
        throw SSKRError("Shares don't all have the same length")
    }
    let shareLength = shareLengths.first!
    let secretLength = shareLength - 5

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
        let shareDataPointer = UnsafeMutablePointer<UInt8>.allocate(capacity: shareLength)
        for j in 0 ..< shareLength {
            shareDataPointer[j] = share.data[j]
        }
        shareDataPointers[i] = UnsafePointer(shareDataPointer)
    }
    var secret = [UInt8](repeating: 0, count: secretLength)
    let error = sskr_combine(&shareDataPointers, shareLength, shareCount, &secret, secret.count)
    guard error == secretLength else {
        throw SSKRError("SSKR decoding error: \(error)")
    }
    return Data(secret)
}
