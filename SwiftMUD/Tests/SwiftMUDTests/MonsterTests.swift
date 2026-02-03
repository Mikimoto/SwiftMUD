import XCTest
@testable import SwiftMUD

final class MonsterTests: XCTestCase {

    let wolfTemplate = MonsterTemplate(
        id: "wolf",
        name: "野狼",
        description: "一隻凶猛的野狼",
        level: 3,
        maxHP: 50,
        attack: 8,
        defense: 3,
        magic: 0,
        expReward: 30,
        goldReward: 5...15,
        lootTable: [
            LootEntry(itemId: "wolf_pelt", chance: 0.5, countRange: 1...1),
            LootEntry(itemId: "wolf_fang", chance: 0.2, countRange: 1...2)
        ],
        aggressive: true,
        respawnTime: 60
    )

    func testCreateMonsterFromTemplate() {
        let wolf = Monster(from: wolfTemplate, roomId: "forest_entrance")

        XCTAssertEqual(wolf.name, "野狼")
        XCTAssertEqual(wolf.currentHP, 50)
        XCTAssertEqual(wolf.maxHP, 50)
        XCTAssertEqual(wolf.attack, 8)
        XCTAssertEqual(wolf.currentRoomId, "forest_entrance")
        XCTAssertTrue(wolf.isAlive)
    }

    func testMonsterTakeDamage() {
        var wolf = Monster(from: wolfTemplate, roomId: "forest")

        wolf.takeDamage(20)
        XCTAssertEqual(wolf.currentHP, 30)
        XCTAssertTrue(wolf.isAlive)

        wolf.takeDamage(50)
        XCTAssertEqual(wolf.currentHP, 0)
        XCTAssertFalse(wolf.isAlive)
        XCTAssertNotNil(wolf.diedAt)
    }

    func testMonsterRespawn() {
        var wolf = Monster(from: wolfTemplate, roomId: "forest")
        wolf.takeDamage(100)
        XCTAssertFalse(wolf.isAlive)

        wolf.respawn(template: wolfTemplate)
        XCTAssertTrue(wolf.isAlive)
        XCTAssertEqual(wolf.currentHP, 50)
        XCTAssertNil(wolf.diedAt)
    }
}
