import XCTest
import Shamir

extension ShamirShare: CustomStringConvertible {
    public var description: String {
        return "[share \(index): \(data.hex)]"
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

class ShamirTests: XCTestCase {
    func test1() throws {
        let secret = "00112233445566778899aabbccddeeff".hexData
        let shares = splitSecret(threshold: 2, shareCount: 3, secret: secret, randomGenerator: fakeRandom)
        XCTAssertEqual(shares.description, "[[share 0: 3dc2ff5b2a3b08193a2b1809a2b38091], [share 1: c7fe6b576e7f4c5df6e7d4c5e6f7c4d5], [share 2: d2bacc43a2b38091b9a89b8a2a3b0819]]")
        var recoveredShares = shares

        recoveredShares.remove(at: 1)
        let recoveredSecret = try recoverSecret(shares: recoveredShares)
        XCTAssertEqual(secret, recoveredSecret)

        recoveredShares.removeFirst()
        let badRecoveredSecret = try recoverSecret(shares: recoveredShares)
        XCTAssertNotEqual(secret, badRecoveredSecret)
    }
}
