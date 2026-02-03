import XCTest
@testable import SwiftMUD

final class SkillTests: XCTestCase {

    func testCreateActiveSkill() {
        let fireball = Skill(
            id: "fireball",
            name: "火球術",
            description: "發射一顆火球造成魔法傷害",
            type: .active,
            mpCost: 20,
            castTime: 1.5,
            cooldown: 8,
            effects: [.damage(base: 50, scaling: 1.5, stat: .magic)],
            maxLevel: 5
        )

        XCTAssertEqual(fireball.id, "fireball")
        XCTAssertEqual(fireball.type, .active)
        XCTAssertEqual(fireball.mpCost, 20)
        XCTAssertEqual(fireball.castTime, 1.5)
        XCTAssertEqual(fireball.cooldown, 8)
    }

    func testCreatePassiveSkill() {
        let toughness = Skill(
            id: "toughness",
            name: "強壯體魄",
            description: "永久提升最大生命值",
            type: .passive,
            statBonus: [.maxHP: 10],
            maxLevel: 3
        )

        XCTAssertEqual(toughness.type, .passive)
        XCTAssertEqual(toughness.statBonus[.maxHP], 10)
    }

    func testMpCostScaling() {
        let skill = Skill(
            id: "test",
            name: "Test",
            description: "Test",
            type: .active,
            mpCost: 20,
            maxLevel: 5
        )

        XCTAssertEqual(skill.mpCostAtLevel(1), 20)
        XCTAssertEqual(skill.mpCostAtLevel(2), 25)
        XCTAssertEqual(skill.mpCostAtLevel(5), 40)
    }

    func testEffectMultiplier() {
        let skill = Skill(
            id: "test",
            name: "Test",
            description: "Test",
            type: .active,
            maxLevel: 5
        )

        XCTAssertEqual(skill.effectMultiplier(at: 1), 1.0)
        XCTAssertEqual(skill.effectMultiplier(at: 2), 1.15, accuracy: 0.01)
        XCTAssertEqual(skill.effectMultiplier(at: 5), 1.6, accuracy: 0.01)
    }

    func testCooldownState() {
        var state = SkillCooldownState()

        XCTAssertFalse(state.isOnCooldown("fireball"))

        state.startCooldown("fireball", duration: 5)
        XCTAssertTrue(state.isOnCooldown("fireball"))
        XCTAssertTrue(state.remainingCooldown("fireball") > 4)
    }

    func testCastingState() {
        var state = SkillCooldownState()

        XCTAssertFalse(state.isCasting)

        state.startCasting("fireball", castTime: 1.5)
        XCTAssertTrue(state.isCasting)
        XCTAssertEqual(state.casting?.skillId, "fireball")

        state.finishCasting()
        XCTAssertFalse(state.isCasting)
    }
}
