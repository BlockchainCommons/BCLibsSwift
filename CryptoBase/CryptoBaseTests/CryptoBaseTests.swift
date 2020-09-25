import XCTest
import CryptoBase

class CryptoBaseTests: XCTestCase {
    func testSHA() {
        let input = "abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq";
        let digest256 = sha256(data: input.utf8)
        XCTAssertEqual(digest256.hex, "248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1")
        let digest512 = sha512(data: input.utf8)
        XCTAssertEqual(digest512.hex, "204a8fc6dda82f0a0ced7beb8e08a41657c16ef468b228a8279be331a703c33596fd15c13b1b07f9aa1d3bea57789ca031ad85c7a71dd70354ec631238ca3445")
    }

    func testHMACSHA() {
        let key = "0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b".hexData
        let message = "Hi There".utf8
        let hmac256 = hmacSHA256(key: key, message: message)
        XCTAssertEqual(hmac256.hex, "b0344c61d8db38535ca8afceaf0bf12b881dc200c9833da726e9376c2e32cff7")
        let hmac512 = hmacSHA512(key: key, message: message)
        XCTAssertEqual(hmac512.hex, "87aa7cdea5ef619d4ff0b4241a1d6cb02379f4e2ce4ec2787ad0b30545e17cdedaa833b7d6b8a702038b274eaea3f4e4be9d914eeb61f1702e696c203a126854")
    }

    func testPBKDF2HMACSHA256() {
        let key = pbkdf2HMACSHA256(pass: "password".utf8, salt: "salt".utf8, iterations: 1, keyLen: 32)
        XCTAssertEqual(key.hex, "120fb6cffcf8b32c43e7225256c4f837a86548c92ccc35480805987cb70be17b")
    }

    func testCRC32() {
        let input = "Hello, world!"
        let checksum = crc32(data: input.utf8)
        XCTAssertEqual(checksum.bigEndian.hex, "e6c6e6eb")
        let checksumN = crc32n(data: input.utf8)
        XCTAssertEqual(checksumN.hex, "e6c6e6eb")
    }
}
