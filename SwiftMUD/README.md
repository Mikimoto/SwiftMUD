# SwiftMUD

以 Swift 和 SwiftNIO 建構的 MUD（Multi-User Dungeon）遊戲伺服器。

## 專案簡介

SwiftMUD 是一個現代化的文字冒險遊戲伺服器，採用 Swift 語言開發，並使用 Apple 的 SwiftNIO 框架提供高效能的非同步網路處理能力。玩家可以透過 Telnet 或其他支援的客戶端連接伺服器，在文字世界中探索、戰鬥、完成任務並與其他玩家互動。

## 功能列表

### 核心功能
- **TCP 伺服器**：基於 SwiftNIO 的高效能非同步網路伺服器
- **Session 管理**：支援多玩家同時連線
- **指令解析系統**：靈活的指令解析器，支援別名與快捷鍵

### 遊戲系統
- **世界系統**：多房間地圖，支援六方向移動（東、西、南、北、上、下）
- **玩家系統**：角色創建、等級成長、屬性系統
- **戰鬥系統**：回合制戰鬥、技能系統、傷害計算
- **任務系統**：支援主線、支線、日常任務
- **商店系統**：NPC 商店、物品買賣
- **背包系統**：物品管理、裝備穿戴
- **技能系統**：主動技能與被動技能

### 管理功能
- **多層級管理權限**：玩家、見習GM、GM、超級GM、創世神
- **管理員指令**：踢人、封禁、禁言、傳送等
- **玩家資料持久化**：JSON 檔案儲存

## 系統需求

- macOS 13.0 或更高版本
- Swift 5.9 或更高版本
- Xcode 15.0 或更高版本（用於開發）

## 安裝與編譯

### 克隆專案

```bash
git clone <repository-url>
cd SwiftMUD
```

### 編譯專案

使用 Swift Package Manager 編譯：

```bash
swift build
```

若要編譯發行版本：

```bash
swift build -c release
```

### 執行測試

```bash
swift test
```

## 執行方式

### 啟動伺服器

預設在 0.0.0.0:4000 啟動：

```bash
swift run SwiftMUD
```

指定主機和埠號：

```bash
swift run SwiftMUD --host 127.0.0.1 --port 4000
```

或使用簡短參數：

```bash
swift run SwiftMUD -h 127.0.0.1 -p 4000
```

### 使用測試客戶端

專案內建測試客戶端：

```bash
swift run MUDClient
```

或使用 Telnet 連接：

```bash
telnet localhost 4000
```

## 可用指令列表

### 移動指令
| 指令 | 別名 | 說明 |
|------|------|------|
| `move <方向>` | `go`, `m` | 往指定方向移動 |
| `n`, `s`, `e`, `w`, `u`, `d` | - | 方向快捷鍵 |

### 查看指令
| 指令 | 別名 | 說明 |
|------|------|------|
| `look` | `l`, `看` | 查看當前房間 |
| `status` | `st`, `狀態` | 查看角色狀態 |
| `who` | `線上` | 查看線上玩家 |
| `inventory` | `inv`, `i`, `背包` | 查看背包物品 |

### 通訊指令
| 指令 | 別名 | 說明 |
|------|------|------|
| `say <訊息>` | `說` | 在房間內說話 |
| `yell <訊息>` | `喊`, `大喊` | 大喊（跨房間） |

### 戰鬥指令
| 指令 | 別名 | 說明 |
|------|------|------|
| `attack <目標>` | `atk`, `攻擊`, `打` | 攻擊目標 |
| `flee` | `逃跑`, `逃` | 逃離戰鬥 |

### 任務指令
| 指令 | 別名 | 說明 |
|------|------|------|
| `quest` | `任務` | 查看任務列表 |
| `accept <任務ID>` | `接受` | 接受任務 |
| `complete <任務ID>` | `完成` | 完成任務 |
| `abandon <任務ID>` | `放棄` | 放棄任務 |

### 商店指令
| 指令 | 別名 | 說明 |
|------|------|------|
| `shop` | `商店` | 查看商店物品 |
| `buy <物品> [數量]` | `購買` | 購買物品 |
| `sell <物品> [數量]` | `賣`, `販賣` | 出售物品 |

### 裝備指令
| 指令 | 別名 | 說明 |
|------|------|------|
| `use <物品>` | `使用` | 使用物品 |
| `equip <物品>` | `裝備`, `穿` | 裝備物品 |
| `unequip <部位>` | `卸下`, `脫` | 卸下裝備 |

### 系統指令
| 指令 | 別名 | 說明 |
|------|------|------|
| `help [指令]` | `h`, `?`, `幫助` | 顯示說明 |
| `quit` | `離開`, `登出` | 離開遊戲 |

### 管理員指令
| 指令 | 權限需求 | 說明 |
|------|----------|------|
| `kick <玩家>` | 見習GM | 踢出玩家 |
| `mute <玩家> [時間]` | 見習GM | 禁言玩家 |
| `unmute <玩家>` | 見習GM | 解除禁言 |
| `ban <玩家> [時間]` | GM | 封禁玩家 |
| `teleport <玩家> <房間>` | GM | 傳送玩家 |
| `goto <房間>` | GM | 傳送自己 |
| `spawn <怪物ID>` | GM | 生成怪物 |
| `setadmin <玩家> <等級>` | 超級GM | 設定管理權限 |
| `adminlist` | 見習GM | 查看管理員列表 |
| `announce <訊息>` | GM | 全服公告 |
| `whois <玩家>` | 見習GM | 查看玩家詳細資訊 |

## 專案結構

```
SwiftMUD/
├── Package.swift              # Swift Package 配置檔
├── README.md                  # 專案說明文件
├── docs/
│   └── ARCHITECTURE.md        # 架構文件
├── Sources/
│   ├── SwiftMUD/              # 主要遊戲伺服器
│   │   ├── main.swift         # 程式進入點
│   │   ├── Core/              # 核心模組
│   │   │   └── MUDError.swift # 錯誤定義
│   │   ├── Server/            # 伺服器模組
│   │   │   ├── MUDServer.swift      # TCP 伺服器
│   │   │   ├── ClientHandler.swift  # 連線處理器
│   │   │   ├── Session.swift        # 玩家連線 Session
│   │   │   └── SessionManager.swift # Session 管理器
│   │   ├── Game/              # 遊戲邏輯模組
│   │   │   ├── Types.swift    # 基礎類型定義
│   │   │   ├── Player.swift   # 玩家資料結構
│   │   │   ├── Room.swift     # 房間資料結構
│   │   │   ├── Item.swift     # 物品系統
│   │   │   ├── Monster.swift  # 怪物系統
│   │   │   └── Skill.swift    # 技能系統
│   │   ├── World/             # 世界狀態模組
│   │   │   └── World.swift    # 遊戲世界管理器
│   │   ├── Commands/          # 指令模組
│   │   │   ├── Command.swift        # 指令協定
│   │   │   ├── CommandParser.swift  # 指令解析器
│   │   │   ├── MoveCommand.swift    # 移動指令
│   │   │   ├── LookCommand.swift    # 查看指令
│   │   │   ├── ...                  # 其他指令
│   │   │   └── Admin/               # 管理員指令
│   │   │       ├── KickCommand.swift
│   │   │       ├── BanCommand.swift
│   │   │       └── ...
│   │   ├── Combat/            # 戰鬥模組
│   │   │   ├── CombatManager.swift  # 戰鬥管理器
│   │   │   └── CombatState.swift    # 戰鬥狀態
│   │   ├── Quest/             # 任務模組
│   │   │   ├── Quest.swift          # 任務定義
│   │   │   ├── QuestProgress.swift  # 任務進度
│   │   │   └── QuestManager.swift   # 任務管理器
│   │   ├── Shop/              # 商店模組
│   │   │   ├── Shop.swift     # 商店定義
│   │   │   ├── NPC.swift      # NPC 定義
│   │   │   └── ShopManager.swift    # 商店管理器
│   │   └── Persistence/       # 持久化模組
│   │       ├── Repository.swift     # 儲存庫協定
│   │       ├── JSONFileStorage.swift      # JSON 檔案儲存
│   │       ├── PlayerRepository.swift     # 玩家儲存庫協定
│   │       └── JSONPlayerRepository.swift # JSON 玩家儲存庫
│   └── MUDClient/             # 測試客戶端
│       └── main.swift
└── Tests/
    └── SwiftMUDTests/         # 單元測試
        ├── PlayerTests.swift
        ├── RoomTests.swift
        ├── ItemTests.swift
        ├── MonsterTests.swift
        ├── SkillTests.swift
        ├── QuestTests.swift
        ├── TypesTests.swift
        └── PersistenceTests.swift
```

## 依賴套件

- [SwiftNIO](https://github.com/apple/swift-nio) - 高效能非同步網路框架
- [Swift Argument Parser](https://github.com/apple/swift-argument-parser) - 命令列參數解析
- [Swift Crypto](https://github.com/apple/swift-crypto) - 密碼雜湊加密
- [Swift Log](https://github.com/apple/swift-log) - 日誌記錄框架

## 授權

本專案採用 MIT 授權條款。詳見 LICENSE 檔案。

## 貢獻

歡迎提交 Issue 和 Pull Request！

---

*SwiftMUD - 用現代 Swift 打造的經典 MUD 體驗*
