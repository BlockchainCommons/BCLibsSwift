import Foundation
@_implementationOnly import CBCWally

extension Wally {
    public static func hash160(_ data: Data) -> Data {
        data.withUnsafeByteBuffer { inBytes in
            var result = Data(count: Int(HASH160_LEN))
            result.withUnsafeMutableByteBuffer { outBytes in
                precondition(
                    wally_hash160(
                        inBytes.baseAddress,
                        inBytes.count,
                        outBytes.baseAddress,
                        outBytes.count
                    ) == WALLY_OK
                )
            }
            return result
        }
    }

    public static func hash160<T>(_ input: T) -> Data {
        withUnsafeByteBuffer(of: input) { inBytes in
            var result = Data(repeating: 0, count: Int(HASH160_LEN))
            result.withUnsafeMutableByteBuffer { outBytes in
                precondition(
                    wally_hash160(
                        inBytes.baseAddress,
                        inBytes.count,
                        outBytes.baseAddress,
                        outBytes.count
                    ) == WALLY_OK)
            }
            return result
        }
    }
}

extension Data {
    public var hash160: Data {
        Wally.hash160(self)
    }
}
