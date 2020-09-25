import XCTest
import SSKR

extension SSKRShare: CustomStringConvertible {
    public var description: String {
        return "[\(data.hex)]"
    }
}

func fakeRandom(len: Int) -> Data {
    var b: UInt8 = 0
    var result = Data(count: len)
    for i in 0 ..< len {
        result[i] = b
        b &+= 17
    }
    return result
}

class SSKRTests: XCTestCase {
    func test1() throws {
        let secret = "00112233445566778899aabbccddeeff".hexData
        let groups = [SSKRGroupDescriptor(threshold: 2, count: 3), SSKRGroupDescriptor(threshold: 3, count: 5)]
        let shares = try SSKRGenerate(groupThreshold: 2, groups: groups, secret: secret, randomGenerator: fakeRandom)
        XCTAssertEqual(shares.description, "[[[1100110100bae4b1dda4b58697b3a291802c3d0e1f], [11001101016c0158178e9facbdcddceffe06172435], [11001101020d357852f0e1d2c34f5e6d7c78695a4b]], [[110011120000112233445566778899aabbccddeeff], [1100111201f1a1a2262a3b08193a2b1809a2b38091], [1100111202f0a55798b3a291808a9ba8b93b2a1908], [11001112030115d78dddccffee38291a0b55447766], [1100111204df736b4c1d0c3f2e637241509584b7a6]]]")

        var recoveredShares = shares.flatMap { $0 }
        // 0-0 0-1 0-2  1-0 1-1 1-2 1-3 1-4
        //     ^^^      ^^^         ^^^   Removing these shares
        //
        // 0-0 0-2  1-1 1-2 1-4
        recoveredShares.remove(at: 6)
        recoveredShares.remove(at: 3)
        recoveredShares.remove(at: 1)
        let recoveredSecret = try SSKRCombine(shares: recoveredShares)
        XCTAssertEqual(recoveredSecret, secret)

        // 0-0 0-2  1-1 1-2 1-4
        //              ^^^    Removing this share
        //
        // 0-0 0-2  1-1 1-4
        recoveredShares.remove(at: 3)
        XCTAssertThrowsError(try SSKRCombine(shares: recoveredShares))
    }
}
