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

## HUD Layout (StarterGui/CollectionHUD ScreenGui)

### Element Hierarchy
```
CollectionHUD (ScreenGui)
├── ZoneLabel (TextLabel)          -- top-left
├── PuffCounter (TextLabel)        -- top-right
├── Announcement (TextLabel)       -- top-center, hidden by default
├── CollectToast (TextLabel)       -- center-screen, hidden by default
└── RareSlotsFrame (Frame)         -- bottom-center
    ├── Slot_normal (ImageLabel)
    ├── Slot_bronze (ImageLabel)
    ├── Slot_silver (ImageLabel)
    ├── Slot_gold (ImageLabel)
    ├── Slot_flamingHot (ImageLabel)
    ├── Slot_megaFlamingHot (ImageLabel)
    ├── Slot_rainbowHot (ImageLabel)
    ├── Slot_galaxy (ImageLabel)
    └── Slot_theOne (ImageLabel)
```

### Element Names (must match exactly — HUDController references by name)
| Element          | Type        | Position              | Default state        |
|------------------|-------------|-----------------------|----------------------|
| ZoneLabel        | TextLabel   | Top-left              | "Zone 1 / 9"        |
| PuffCount        | TextLabel   | Top-right             | "Puffs 0"           |
| Announcement     | TextLabel   | Top-center            | Visible = false      |
| CollectToast     | TextLabel   | Center-screen         | Visible = false      |
| RarePuffPanel    | Frame       | Bottom-center         | Always visible       |
| normal           | ImageLabel  | Inside RarePuffPanel  | ImageTransparency = 0.6 |
| bronze           | ImageLabel  | Inside RarePuffPanel  | ImageTransparency = 0.6 |
| silver           | ImageLabel  | Inside RarePuffPanel  | ImageTransparency = 0.6 |
| gold             | ImageLabel  | Inside RarePuffPanel  | ImageTransparency = 0.6 |
| flamingHot       | ImageLabel  | Inside RarePuffPanel  | ImageTransparency = 0.6 |
| megaFlamingHot   | ImageLabel  | Inside RarePuffPanel  | ImageTransparency = 0.6 |
| rainbowHot       | ImageLabel  | Inside RarePuffPanel  | ImageTransparency = 0.6 |
| galaxy           | ImageLabel  | Inside RarePuffPanel  | ImageTransparency = 0.6 |
| theOne           | ImageLabel  | Inside RarePuffPanel  | ImageTransparency = 0.6 |

### HUDController Behavior (src/client/HUDController.client.luau)

#### On CollectPuff event (puffType: string, isRare: bool)
- Increment PuffCounter by 1: "Puffs 0" → "Puffs 1"
- Show CollectToast briefly (tween in, hold 1.5s, tween out):
  - If isRare = false: toast text = "+1 Puff 🧀"
  - If isRare = true: toast text = "🧀 [PuffDisplayName] collected!"
- If isRare = true: set the matching Slot_[puffType] ImageColor3 to full color (uncollected = gray, collected = zone color per table below)

#### On ZoneComplete event (completedZone: number)
- Update ZoneLabel: "Zone [completedZone + 1] / 9"
- Play a brief screen flash or color tween on ZoneLabel

#### On AnnounceOneP event (winnerName: string, prevHolder: string?)
- Set Announcement.Visible = true
- If prevHolder is nil: text = "[winnerName] claimed THE ONE PUFF! 👑"
- If prevHolder is not nil: text = "[winnerName] took THE ONE PUFF from [prevHolder]! 👑"
- Hold for 8 seconds then hide

#### Rare slot colors (ImageColor3 when collected)
| Slot          | Collected color (RGB)      |
|---------------|---------------------------|
| Slot_normal   | 230, 101, 10  (orange)    |
| Slot_bronze   | 180, 120, 40  (bronze)    |
| Slot_silver   | 180, 185, 190 (silver)    |
| Slot_gold     | 220, 170, 20  (gold)      |
| Slot_flamingHot | 200, 40, 10 (red)       |
| Slot_megaFlamingHot | 160, 20, 5 (deep red) |
| Slot_rainbowHot | cycles RGB (use TweenService loop) |
| Slot_galaxy   | 60, 20, 120   (purple)    |
| Slot_theOne   | 255, 255, 255 (white/divine) |

#### Initialization (on script start)
- WaitForChild on CollectionHUD and all named elements before connecting events
- Load initial state from server if possible, or default to zone 1 / 0 puffs
- RareSlotsFrame slots all start gray (ImageColor3 = 150, 150, 150)
- Announcement.Visible = false
- CollectToast.Visible = false

### Studio Setup Requirements for HUD
These must exist in StarterGui before HUDController will work:

1. ScreenGui named exactly `CollectionHUD`
2. All elements named exactly as listed in the hierarchy above
3. RareSlotsFrame must contain all 9 ImageLabel slots named `Slot_[puffType]`
4. Announcement and CollectToast must have Visible = false as their default
5. The mystery white square visible in the current screenshot should be
   identified and removed — it is likely an unnamed placeholder Frame

## Development Tools

### DevReset (src/server/DevReset.server.luau)
- **Development only** — must be deleted before publishing to players
- Automatically resets player data to zone 1 on join for whitelisted usernames
- Only affects accounts listed in `DEV_USERNAMES` — safe if a real player joins a test session
- Syncs via Rojo like any other script, persists across Studio sessions

## Key Implementation Notes
- Never trust the client — validate all RemoteEvent inputs server-side
- DataStore key format: "player_" .. player.UserId
- Auto-save every 60 seconds + save on PlayerRemoving
- workspace.Gravity is global — use VectorForce for per-player gravity in Zone 8
- Checkpoints every 5-6 platforms per zone
- Platform Touched events: check hit.Parent for Humanoid before processing
- HUDController must WaitForChild on all GUI elements — load order not guaranteed
- CollectToast and Announcement use TweenService for show/hide animations
- Slot_rainbowHot cycles colors via a RunService.Heartbeat loop after collection