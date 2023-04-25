import Foundation

@inlinable func withUnsafeByteBuffer<T, ResultType>(of value: T, _ body: (UnsafeBufferPointer<UInt8>) throws -> ResultType) rethrows -> ResultType {
    try withUnsafeBytes(of: value) { rawBuf in
        try body(rawBuf.bindMemory(to: UInt8.self))
    }
}

@inlinable func withUnsafeMutableByteBuffer<T, ResultType>(of value: inout T, _ body: (UnsafeMutableBufferPointer<UInt8>) throws -> ResultType) rethrows -> ResultType {
    try withUnsafeMutableBytes(of: &value) { rawBuf in
        try body(rawBuf.bindMemory(to: UInt8.self))
    }
}

extension Data {
    @inlinable func withUnsafeByteBuffer<ResultType>(_ body: (UnsafeBufferPointer<UInt8>) throws -> ResultType) rethrows -> ResultType {
        try withUnsafeBytes { rawBuf in
            try body(rawBuf.bindMemory(to: UInt8.self))
        }
    }

    @inlinable mutating func withUnsafeMutableByteBuffer<ResultType>(_ body: (UnsafeMutableBufferPointer<UInt8>) throws -> ResultType) rethrows -> ResultType {
        try withUnsafeMutableBytes { rawBuf in
            try body(rawBuf.bindMemory(to: UInt8.self))
        }
    }
}

extension Data {
    init<A>(of a: A) {
        let d = Swift.withUnsafeBytes(of: a) {
            Data($0)
        }
        self = d
    }
    
    func store<A>(into a: inout A) {
        precondition(MemoryLayout<A>.size >= count)
        withUnsafeMutablePointer(to: &a) {
            $0.withMemoryRebound(to: UInt8.self, capacity: count) {
                self.copyBytes(to: $0, count: count)
            }
        }
    }
}

extension Data {
    var hex: String {
        toHex(data: self)
    }
}

func toHex(byte: UInt8) -> String {
    String(format: "%02x", byte)
}

func toHex(data: Data) -> String {
    data.reduce(into: "") {
        $0 += toHex(byte: $1)
    }
}

extension Collection where Element: BinaryInteger {
    var isAllZero: Bool {
        allSatisfy { $0 == 0 }
    }
}

protocol Serializable {
    var serialized: Data { get }
}

extension UInt32: Serializable {
    var serialized: Data {
        serialize(self)
    }
}

func serialize<I>(_ n: I, littleEndian: Bool = false) -> Data where I: FixedWidthInteger {
    let count = MemoryLayout<I>.size
    var d = Data(repeating: 0, count: count)
    d.withUnsafeMutableBytes {
        $0.bindMemory(to: I.self).baseAddress!.pointee = littleEndian ? n.littleEndian : n.bigEndian
    }
    return d
}

public func deserialize<T, D>(_ t: T.Type, _ data: D, littleEndian: Bool = false) -> T? where T: FixedWidthInteger, D : DataProtocol {
    let size = MemoryLayout<T>.size
    guard data.count >= size else {
        return nil
    }

    var dataBytes = [UInt8](repeating: 0, count: size)
    return dataBytes.withUnsafeMutableBytes {
        data.copyBytes(to: $0, count: size)
        let a = $0.bindMemory(to: T.self).baseAddress!.pointee
        return littleEndian ? T(littleEndian: a) : T(bigEndian: a)
    }
}
