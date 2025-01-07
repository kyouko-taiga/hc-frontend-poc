import Utilities
import XCTest

final class CollectionTests: XCTestCase {

  func testUniqueElement() {
    XCTAssertNil(([] as [Int]).uniqueElement)
    XCTAssertNil([1, 2].uniqueElement)
    XCTAssertEqual([1].uniqueElement, 1)
  }

  func testHeadAndTail() throws {
    let a0: [Int] = []
    XCTAssertNil(a0.headAndTail)

    let a1 = [1]
    let (h1, t1) = try XCTUnwrap(a1.headAndTail)
    XCTAssertEqual(h1, 1)
    XCTAssert(t1.isEmpty)

    let a2 = [1, 2, 3]
    let (h2, t2) = try XCTUnwrap(a2.headAndTail)
    XCTAssertEqual(h2, 1)
    XCTAssertEqual(Array(t2), [2, 3])
  }

}