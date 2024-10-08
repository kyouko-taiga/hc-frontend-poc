import Archivist
import FrontEnd
import XCTest

final class ProgramTests: XCTestCase {

  func testSelectAll() throws {
    let p = Program.test
    XCTAssertEqual(p.select(.all).count, 8)
  }

  func testSelectByModule() throws {
    let p = Program.test
    XCTAssertEqual(p.select(.from("org.hylo.M0")).count, 4)
  }

  func testSelectByKind() throws {
    let p = Program.test
    XCTAssertEqual(p.select(.kind(AssociatedTypeDeclaration.self)).count, 4)
  }

  func testArchiveConsistency() throws {
    let p = Program.test
    let m = p.moduleIdentities.first!

    var w1 = WriteableArchive(BinaryBuffer())
    try p.write(module: m, to: &w1)
    var w2 = WriteableArchive(BinaryBuffer())
    try p.write(module: m, to: &w2)
    XCTAssertEqual(w1.finalize(), w2.finalize())
  }

  func testSerializationRoundTrip() throws {
    let p = Program.test
    let m = p.moduleIdentities.first!
    let a = try p.archive(module: m)

    var q = Program()
    let (loaded, n) = try q.load(module: p[m].name, from: a)

    // Syntax trees should have the same identities.
    XCTAssert(loaded)
    XCTAssertEqual(p[m].name, q[n].name)
    for (l, r) in zip(p.select(.from(p[m].name)), q.select(.from(q[n].name))) {
      assertIsomorphic(l, r)
    }

    /// Asserts that `l` and `r`, which are in `p` and `q` respectively, are equal up to renaming
    /// of tree identities.
    func assertIsomorphic(_ l: AnySyntaxIdentity, _ r: AnySyntaxIdentity) {
      XCTAssert(p[l].equals(q[r]))
    }
  }

  func testSerializationWithDependencies() throws {
    let p = Program.test

    var archives: [(identity: Program.ModuleIdentity, data: BinaryBuffer)] = []
    for m in p.moduleIdentities {
      try archives.append((m, p.archive(module: m)))
    }

    var q = Program()

    // Re-load modules out of order.
    var loaded = false
    (loaded, _) = try q.load(module: p[archives[0].identity].name, from: archives[0].data)
    XCTAssert(loaded)
    (loaded, _) = try q.load(module: p[archives[2].identity].name, from: archives[2].data)
    XCTAssert(loaded)
    (loaded, _) = try q.load(module: p[archives[1].identity].name, from: archives[1].data)
    XCTAssert(loaded)
  }

}
