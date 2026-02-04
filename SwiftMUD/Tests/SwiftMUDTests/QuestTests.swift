import XCTest
@testable import SwiftMUD

final class QuestTests: XCTestCase {

    func testCreateQuest() {
        let quest = Quest(
            id: "kill_slimes",
            name: "消滅史萊姆",
            description: "城鎮外的史萊姆太多了，請幫忙清理一下。",
            objectives: [.kill(monsterId: "slime", count: 5)],
            rewards: QuestRewards(exp: 50, gold: 100)
        )

        XCTAssertEqual(quest.id, "kill_slimes")
        XCTAssertEqual(quest.name, "消滅史萊姆")
        XCTAssertEqual(quest.objectives.count, 1)
        XCTAssertEqual(quest.rewards.exp, 50)
        XCTAssertEqual(quest.rewards.gold, 100)
    }

    func testQuestProgress() {
        let quest = Quest(
            id: "test",
            name: "Test",
            description: "Test quest",
            objectives: [.kill(monsterId: "slime", count: 3)],
            rewards: QuestRewards(exp: 10)
        )

        var progress = QuestProgress(quest: quest)

        XCTAssertEqual(progress.status, .active)
        XCTAssertFalse(progress.allObjectivesComplete)

        progress.updateKillProgress(monsterId: "slime", count: 2)
        XCTAssertFalse(progress.allObjectivesComplete)
        XCTAssertEqual(progress.objectives[0].currentCount, 2)

        progress.updateKillProgress(monsterId: "slime", count: 1)
        XCTAssertTrue(progress.allObjectivesComplete)
        XCTAssertEqual(progress.status, .completed)
    }

    func testMultipleObjectives() {
        let quest = Quest(
            id: "test",
            name: "Test",
            description: "Test quest",
            objectives: [
                .kill(monsterId: "wolf", count: 2),
                .collect(itemId: "wolf_pelt", count: 1)
            ],
            rewards: QuestRewards(exp: 50)
        )

        var progress = QuestProgress(quest: quest)

        progress.updateKillProgress(monsterId: "wolf", count: 2)
        XCTAssertFalse(progress.allObjectivesComplete) // 還沒收集物品

        progress.updateCollectProgress(itemId: "wolf_pelt", count: 1)
        XCTAssertTrue(progress.allObjectivesComplete)
        XCTAssertEqual(progress.status, .completed)
    }

    func testQuestRewardsDescription() {
        let rewards = QuestRewards(exp: 100, gold: 50, items: ["health_potion": 2])
        let desc = rewards.description()

        XCTAssertTrue(desc.contains("100 經驗"))
        XCTAssertTrue(desc.contains("50 金幣"))
        XCTAssertTrue(desc.contains("health_potion"))
    }
}
