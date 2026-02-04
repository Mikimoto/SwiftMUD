import XCTest
@testable import SwiftMUD

final class PlayerTests: XCTestCase {

    func testCreateNewPlayer() {
        let player = Player.create(name: "TestPlayer", passwordHash: "hash123")

        XCTAssertEqual(player.name, "TestPlayer")
        XCTAssertEqual(player.level, 1)
        XCTAssertEqual(player.gold, 100)
        XCTAssertEqual(player.currentHP, 100)
        XCTAssertEqual(player.maxHP, 100)
        XCTAssertEqual(player.adminLevel, .player)
        XCTAssertEqual(player.currentRoomId, "town_square")
    }

    func testExpToNextLevel() {
        var player = Player.create(name: "Test", passwordHash: "hash")
        XCTAssertEqual(player.expToNextLevel(), 100) // level 1 = 100 exp

        player.level = 5
        XCTAssertEqual(player.expToNextLevel(), 500) // level 5 = 500 exp
    }

    func testGainExpAndLevelUp() {
        var player = Player.create(name: "Test", passwordHash: "hash")
        let initialMaxHP = player.maxHP

        let leveledUp = player.gainExp(150)

        XCTAssertTrue(leveledUp)
        XCTAssertEqual(player.level, 2)
        XCTAssertEqual(player.exp, 50) // 150 - 100 = 50
        XCTAssertEqual(player.maxHP, initialMaxHP + 10)
    }

    func testTakeDamageAndHeal() {
        var player = Player.create(name: "Test", passwordHash: "hash")

        player.takeDamage(30)
        XCTAssertEqual(player.currentHP, 70)
        XCTAssertTrue(player.isAlive)

        player.heal(20)
        XCTAssertEqual(player.currentHP, 90)

        player.heal(100) // 不應超過 maxHP
        XCTAssertEqual(player.currentHP, 100)

        player.takeDamage(200) // 不應低於 0
        XCTAssertEqual(player.currentHP, 0)
        XCTAssertFalse(player.isAlive)
    }
}
