# Cheeto Puff Obby — Game Spec

## Concept
A Roblox obstacle course (obby) with 9 zones of increasing difficulty.
Each zone has a rare collectible Cheeto puff at the end. Platforms are
shaped like Cheeto puffs. Common puffs are scattered throughout each zone.

## Zones & Progression
| Zone | Rare Puff         | New Mechanic              |
|------|-------------------|---------------------------|
| 1    | Normal Puff       | Static platforms          |
| 2    | Bronze Puff       | Moving platforms (linear) |
| 3    | Silver Puff       | Rotating platforms        |
| 4    | Gold Puff         | Disappearing platforms    |
| 5    | Flaming Hot Puff  | Kill zones (lava/fire)    |
| 6    | Mega Flaming Hot  | Shrinking platforms       |
| 7    | Rainbow Hot       | Color-match mechanic      |
| 8    | Galaxy Puff       | Low gravity               |
| 9    | The One Puff      | All mechanics combined    |

## The One Puff — Special Rules
- Only one player in the entire server can hold it at a time
- If another player completes Zone 9, they take it (championship belt mechanic)
- Server-wide announcement when it changes hands
- Visually distinct: white/divine glow, particle effects, BillboardGui

## Tech Stack
- Rojo for file sync (VS Code → Studio)
- Luau scripting
- DataStoreService for persistence

## Data Schema (per player)
```json
{
  "currentZone": 1,
  "totalPuffs": 0,
  "lastCheckpoint": 0,
  "rarePuffs": {
    "normal": false, "bronze": false, "silver": false,
    "gold": false, "flamingHot": false, "megaFlamingHot": false,
    "rainbowHot": false, "galaxy": false, "theOne": false
  }
}
```

## Rojo File Naming Conventions
- `Name.server.luau` → Script (ServerScriptService)
- `Name.client.luau` → LocalScript (StarterPlayerScripts)
- `Name.luau` → ModuleScript (ReplicatedStorage)

## Folder Structure (src/)
- src/server/     → DataManager, ZoneManager, CheckpointManager
- src/client/     → HUDController
- src/shared/     → PlayerData module (shared state), Constants

## RemoteEvents needed (in ReplicatedStorage/Events)
- CollectPuff — server → client, args: (puffType: string, isRare: bool)
- ZoneComplete — server → client, args: (completedZone: number)
- AnnounceOneP — server → all clients, args: (winnerName: string, prevHolder: string?)

## Key Implementation Notes
- Never trust the client — validate all RemoteEvent inputs server-side
- DataStore key format: "player_" .. player.UserId
- Auto-save every 60 seconds + save on PlayerRemoving
- workspace.Gravity is global — use VectorForce for per-player gravity in Zone 8
- Checkpoints every 5-6 platforms per zone
- Platform Touched events: check hit.Parent for Humanoid before processing