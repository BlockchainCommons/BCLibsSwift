import XCTest
import BCWally

class BCWallyTests: XCTestCase {
    func testIdentify() {
        XCTAssertEqual(BCWally.identify(), "BCWally")
    }
}
