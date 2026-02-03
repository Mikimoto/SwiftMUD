import XCTest
@testable import SwiftMUD

final class TypesTests: XCTestCase {

    func testAdminTierComparison() {
        XCTAssertTrue(AdminTier.player < AdminTier.trainee)
        XCTAssertTrue(AdminTier.trainee < AdminTier.gm)
        XCTAssertTrue(AdminTier.gm < AdminTier.superGM)
        XCTAssertTrue(AdminTier.superGM < AdminTier.creator)
    }

    func testDirectionOpposite() {
        XCTAssertEqual(Direction.north.opposite, .south)
        XCTAssertEqual(Direction.south.opposite, .north)
        XCTAssertEqual(Direction.east.opposite, .west)
        XCTAssertEqual(Direction.west.opposite, .east)
        XCTAssertEqual(Direction.up.opposite, .down)
        XCTAssertEqual(Direction.down.opposite, .up)
    }

    func testEquipmentSlotAllCases() {
        XCTAssertEqual(EquipmentSlot.allCases.count, 9)
    }
}
