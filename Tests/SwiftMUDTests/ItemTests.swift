import XCTest
@testable import SwiftMUD

final class ItemTests: XCTestCase {

    func testCreateItemTemplate() {
        let sword = ItemTemplate(
            id: "iron_sword",
            name: "鐵劍",
            description: "一把普通的鐵劍",
            type: .weapon,
            equipSlot: .mainHand,
            statBonus: [.attack: 10],
            levelRequired: 1,
            basePrice: 100
        )

        XCTAssertEqual(sword.id, "iron_sword")
        XCTAssertEqual(sword.name, "鐵劍")
        XCTAssertEqual(sword.type, .weapon)
        XCTAssertEqual(sword.equipSlot, .mainHand)
        XCTAssertEqual(sword.statBonus[.attack], 10)
    }

    func testInventoryAddItem() {
        var inventory = Inventory(maxSlots: 5)

        let success = inventory.addItem("iron_sword", stackable: false)
        XCTAssertTrue(success)
        XCTAssertEqual(inventory.usedSlots, 1)
    }

    func testInventoryStackable() {
        var inventory = Inventory(maxSlots: 5)

        _ = inventory.addItem("health_potion", count: 5, stackable: true)
        _ = inventory.addItem("health_potion", count: 3, stackable: true)

        XCTAssertEqual(inventory.usedSlots, 1) // 應該堆疊
        XCTAssertEqual(inventory.countOf("health_potion"), 8)
    }

    func testInventoryFull() {
        var inventory = Inventory(maxSlots: 2)

        _ = inventory.addItem("item1", stackable: false)
        _ = inventory.addItem("item2", stackable: false)
        let success = inventory.addItem("item3", stackable: false)

        XCTAssertFalse(success)
        XCTAssertTrue(inventory.isFull)
    }

    func testInventoryRemoveItem() {
        var inventory = Inventory(maxSlots: 5)

        _ = inventory.addItem("health_potion", count: 5, stackable: true)

        let success = inventory.removeItem("health_potion", count: 3)
        XCTAssertTrue(success)
        XCTAssertEqual(inventory.countOf("health_potion"), 2)

        _ = inventory.removeItem("health_potion", count: 2)
        XCTAssertEqual(inventory.countOf("health_potion"), 0)
        XCTAssertEqual(inventory.usedSlots, 0)
    }

    func testInventoryRemoveMoreThanAvailable() {
        var inventory = Inventory(maxSlots: 5)

        _ = inventory.addItem("health_potion", count: 3, stackable: true)

        // Trying to remove more than available should fail
        let success = inventory.removeItem("health_potion", count: 5)
        XCTAssertFalse(success)
        // Item count should remain unchanged
        XCTAssertEqual(inventory.countOf("health_potion"), 3)
    }
}
