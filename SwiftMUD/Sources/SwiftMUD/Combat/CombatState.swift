import Foundation

/// 戰鬥參與者類型
enum CombatantType {
    case player(UUID)
    case monster(UUID)
}

/// 單場戰鬥的狀態
struct CombatState {
    let id: UUID
    let roomId: String
    var participants: [CombatantType]
    var turnOrder: [CombatantType]
    var currentTurnIndex: Int
    let startedAt: Date

    var isActive: Bool {
        participants.count >= 2
    }

    init(roomId: String) {
        self.id = UUID()
        self.roomId = roomId
        self.participants = []
        self.turnOrder = []
        self.currentTurnIndex = 0
        self.startedAt = Date()
    }

    mutating func addParticipant(_ participant: CombatantType) {
        if !participants.contains(where: { $0.id == participant.id }) {
            participants.append(participant)
            recalculateTurnOrder()
        }
    }

    mutating func removeParticipant(_ participantId: UUID) {
        participants.removeAll { $0.id == participantId }
        turnOrder.removeAll { $0.id == participantId }
        if currentTurnIndex >= turnOrder.count {
            currentTurnIndex = 0
        }
    }

    mutating func nextTurn() {
        guard !turnOrder.isEmpty else { return }
        currentTurnIndex = (currentTurnIndex + 1) % turnOrder.count
    }

    var currentCombatant: CombatantType? {
        guard currentTurnIndex < turnOrder.count else { return nil }
        return turnOrder[currentTurnIndex]
    }

    private mutating func recalculateTurnOrder() {
        turnOrder = participants
    }
}

extension CombatantType {
    var id: UUID {
        switch self {
        case .player(let id): return id
        case .monster(let id): return id
        }
    }
}

extension CombatantType: Equatable {}
