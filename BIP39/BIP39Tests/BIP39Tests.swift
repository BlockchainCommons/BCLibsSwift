//
//  BIP39Tests.swift
//  BIP39Tests
//
//  Created by Wolf McNally on 12/9/20.
//

import XCTest
import BIP39

class BIP39Tests: XCTestCase {

    func testBIP39Word() throws {
        XCTAssertEqual(try BIP39.word(for: 0), "abandon")
        XCTAssertEqual(try BIP39.word(for: 1018), "leg")
        XCTAssertEqual(try BIP39.word(for: 1024), "length")
        XCTAssertEqual(try BIP39.word(for: 2047), "zoo")
        XCTAssertThrowsError(try BIP39.word(for: 2048))
    }

    func testBIP39Index() throws {
        XCTAssertEqual(try BIP39.index(for: "abandon"), 0)
        XCTAssertEqual(try BIP39.index(for: "leg"), 1018)
        XCTAssertEqual(try BIP39.index(for: "length"), 1024)
        XCTAssertEqual(try BIP39.index(for: "zoo"), 2047)
        XCTAssertThrowsError(try BIP39.index(for: "aaa"))
        XCTAssertThrowsError(try BIP39.index(for: "zzz"))
        XCTAssertThrowsError(try BIP39.index(for: "123"))
        XCTAssertThrowsError(try BIP39.index(for: "ley"))
        XCTAssertThrowsError(try BIP39.index(for: "lengthz"))
        XCTAssertThrowsError(try BIP39.index(for: "zoot"))
    }

    func testSeedFromString() {
        let rolls = "123456"
        let refSecret = "8d969eef6ecad3c29a3a629280e686cf".hexData
        XCTAssertEqual(BIP39.seed(for: rolls).dropLast(16), refSecret)
    }

    func testEncode() throws {
        XCTAssertEqual(try BIP39.encode("baadf00dbaadf00d".hexData), "rival hurdle address inspire tenant alone")
        XCTAssertEqual(try BIP39.encode("baadf00dbaadf00dbaadf00dbaadf00d".hexData), "rival hurdle address inspire tenant almost turkey safe asset step lab boy")
        XCTAssertThrowsError(try BIP39.encode("baadf00dbaadf00dbaadf00dbaadf00dff".hexData))
        XCTAssertEqual(try BIP39.encode("7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f".hexData), "legal winner thank year wave sausage worth useful legal winner thank yellow")
    }

    func testDecode() throws {
        XCTAssertEqual(try BIP39.decode("rival hurdle address inspire tenant alone"), "baadf00dbaadf00d".hexData)
        XCTAssertEqual(try BIP39.decode("rival hurdle address inspire tenant almost turkey safe asset step lab boy"), "baadf00dbaadf00dbaadf00dbaadf00d".hexData)
        XCTAssertEqual(try BIP39.decode("legal winner thank year wave sausage worth useful legal winner thank yellow"), "7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f7f".hexData)
    }
}
