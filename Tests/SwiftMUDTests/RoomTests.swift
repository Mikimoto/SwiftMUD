import XCTest
@testable import SwiftMUD

final class RoomTests: XCTestCase {

    func testCreateRoom() {
        let room = Room(
            id: "town_square",
            name: "城鎮廣場",
            description: "一個繁忙的城鎮廣場，四周圍繞著商店和民宅。",
            exits: [.north: "temple", .east: "market"],
            isSafeZone: true
        )

        XCTAssertEqual(room.id, "town_square")
        XCTAssertEqual(room.name, "城鎮廣場")
        XCTAssertTrue(room.isSafeZone)
        XCTAssertEqual(room.exits.count, 2)
    }

    func testExitsDescription() {
        let room = Room(
            id: "test",
            name: "Test",
            description: "Test room",
            exits: [.north: "a", .south: "b", .east: "c"]
        )

        let desc = room.exitsDescription()
        XCTAssertTrue(desc.contains("北"))
        XCTAssertTrue(desc.contains("南"))
        XCTAssertTrue(desc.contains("東"))
    }

    func testEmptyExitsDescription() {
        let room = Room(id: "test", name: "Test", description: "Test")
        XCTAssertEqual(room.exitsDescription(), "這裡沒有明顯的出口。")
    }

    func testFullDescription() {
        let room = Room(
            id: "test",
            name: "測試房間",
            description: "這是一個測試房間。",
            exits: [.north: "other"]
        )

        let desc = room.fullDescription(playerNames: ["Alice", "Bob"], monsterNames: ["哥布林"])

        XCTAssertTrue(desc.contains("【測試房間】"))
        XCTAssertTrue(desc.contains("這是一個測試房間。"))
        XCTAssertTrue(desc.contains("出口：北"))
        XCTAssertTrue(desc.contains("玩家：Alice、Bob"))
        XCTAssertTrue(desc.contains("怪物：哥布林"))
    }
}
