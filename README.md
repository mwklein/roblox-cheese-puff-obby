# 🧀 Cheeto Puff Obby

A Roblox obstacle course (obby) featuring 9 progressive zones, each themed around a rare Cheeto puff collectible. Common puffs are scattered throughout each zone. Only one player server-wide can hold **The One Puff** at a time — a championship belt mechanic that transfers on every Zone 9 completion.

Built with [Rojo](https://rojo.space) for VS Code file sync, Luau scripting, and developed with [Claude Code](https://claude.ai/code).

---

## Game Overview

### Zones & Progression

| Zone | Rare Puff | New Mechanic |
|------|-----------|--------------|
| 1 | Normal Puff | Static platforms |
| 2 | Bronze Puff | Moving platforms (linear) |
| 3 | Silver Puff | Rotating platforms |
| 4 | Gold Puff | Disappearing platforms |
| 5 | Flaming Hot Puff | Kill zones (lava / fire) |
| 6 | Mega Flaming Hot | Shrinking platforms |
| 7 | Rainbow Hot | Color-match mechanic |
| 8 | Galaxy Puff | Low gravity (per-player VectorForce) |
| 9 | The One Puff | Full gauntlet — all mechanics combined |

### The One Puff

- Only one player in the entire server holds it at a time
- Completing Zone 9 transfers it from the previous holder
- Server-wide announcement fires to all clients on every transfer
- Visually distinct: divine glow, particle effects, BillboardGui crown

---

## Architecture

### Tech Stack

- **Rojo** — syncs `src/` folder to Roblox Studio live
- **Luau** — typed superset of Lua 5.1 (Roblox's scripting language)
- **DataStoreService** — persistent player progress across sessions
- **CollectionService** — tag-based part wiring (no scripts inside parts)
- **Claude Code** — AI-assisted development

### Client / Server Model

Roblox runs a strict client-server architecture. All game logic is server-authoritative:

```
Server                          Client
──────                          ──────
DataManager.server.luau         HUDController.client.luau
ZoneManager.server.luau
DataManagerAPI.luau (shared API bridge)

ReplicatedStorage/Events
  CollectPuff   (server → client)
  ZoneComplete  (server → client)
  AnnounceOneP  (server → all clients)
```

The client never mutates game state — it only receives events and updates the HUD display locally.

### Folder Structure

```
roblox-cheese-puff-obby/
├── default.project.json        # Rojo project config
├── README.md
└── src/
    ├── server/                 # ServerScriptService
    │   ├── DataManager.server.luau     # DataStore load/save, session cache
    │   ├── DataManagerAPI.luau         # Shared API bridge (ModuleScript)
    │   ├── ZoneManager.server.luau     # Touch wiring, zone logic, One Puff
    │   └── DevReset.server.luau       # DEV ONLY — auto-resets data on join
    ├── client/                 # StarterPlayerScripts
    │   └── HUDController.client.luau   # HUD updates, zone transitions
    ├── shared/                 # ReplicatedStorage
    │   └── PlayerData.luau             # Schema, constants, sanitisation
    └── tests/                  # ServerScriptService/Server/Tests
        ├── DataManagerLogic.spec.luau
        ├── PlayerData.spec.luau
        └── TestRunner.server.luau
```

### Data Schema

```json
{
  "currentZone": 1,
  "totalPuffs": 0,
  "lastCheckpoint": 0,
  "rarePuffs": {
    "normal": false,
    "bronze": false,
    "silver": false,
    "gold": false,
    "flamingHot": false,
    "megaFlamingHot": false,
    "rainbowHot": false,
    "galaxy": false,
    "theOne": false
  }
}
```

Data is loaded on `PlayerAdded`, saved on `PlayerRemoving`, and auto-saved every 60 seconds. A sanitisation pass fills in missing fields for backward compatibility with old saves.

---

## Dev Setup

### Prerequisites

- [Roblox Studio](https://create.roblox.com) (free)
- [VS Code](https://code.visualstudio.com)
- [Rojo CLI](https://github.com/rojo-rbx/rojo/releases) — match version to the Studio plugin
- [Rojo VS Code extension](https://marketplace.visualstudio.com/items?itemName=evaera.vscode-rojo)
- [Rojo Studio plugin](https://create.roblox.com/store/asset/13916111004) — must match CLI version

### Install

```bash
git clone https://github.com/your-username/roblox-cheese-puff-obby.git
cd roblox-cheese-puff-obby
```

### Serve to Studio

```bash
rojo serve
```

Then in Roblox Studio:
1. Open the place file (`cheese-puff-obby.rbxl`)
2. Click **Plugins** tab → **Rojo** → **Connect**
3. Confirm scripts appear under `ServerScriptService/Server/` in the Explorer

### Enable DataStore in Studio

Required for local playtesting:
1. **Home** tab → **Game Settings** → **Security**
2. Toggle **Enable Studio Access to API Services** → ON

This only applies to Studio. Published games have DataStore access by default.

---

## Studio Setup

The objects below must exist in the place file for scripts to function. `ReplicatedStorage/Shared` and `ReplicatedStorage/Events` are synced by Rojo via `default.project.json`. The `Workspace/Zones`, `Workspace/Lobby`, and `StarterGui` objects are **not** synced — they must be built manually in the `.rbxl` file.

### ReplicatedStorage

```
ReplicatedStorage/
├── Shared/
│   └── PlayerData          (ModuleScript — synced by Rojo)
└── Events/                 (synced by Rojo)
    ├── CollectPuff          (RemoteEvent)
    ├── ZoneComplete         (RemoteEvent)
    └── AnnounceOneP         (RemoteEvent)
```

### Workspace

```
Workspace/
├── Zones/
│   ├── Zone1/
│   │   ├── CheetoPuffPlatform1..N   (Union parts, UsePartColor = true, Anchored = true)
│   │   ├── CommonPuff1..N           (Sphere, tagged "CommonPuff")
│   │   ├── RarePuff_Normal          (Sphere, tagged "RarePuff_Z1", IsRare attribute = true)
│   │   ├── SpawnPad                 (Part, Transparency = 1, CanCollide = false)
│   │   ├── Checkpoint_1..N          (Parts, tagged "Checkpoint_N")
│   │   └── ZoneEnd                  (Part)
│   ├── Zone2/ ... Zone9/            (same structure, zone-specific tags)
└── Lobby/
```

### StarterGui

```
StarterGui/
└── ObbyHUD                  (ScreenGui)
    ├── ZoneLabel            (TextLabel — "Zone 1 / 9")
    ├── PuffCount            (TextLabel — "Puffs 0")
    ├── Announcement         (TextLabel — Visible = false)
    ├── CollectToast         (TextLabel — Visible = false)
    └── RarePuffPanel        (Frame)
        ├── normal           (ImageLabel — ImageTransparency = 0.6)
        ├── bronze           (ImageLabel — ImageTransparency = 0.6)
        ├── silver           (ImageLabel — ImageTransparency = 0.6)
        ├── gold             (ImageLabel — ImageTransparency = 0.6)
        ├── flamingHot       (ImageLabel — ImageTransparency = 0.6)
        ├── megaFlamingHot   (ImageLabel — ImageTransparency = 0.6)
        ├── rainbowHot       (ImageLabel — ImageTransparency = 0.6)
        ├── galaxy           (ImageLabel — ImageTransparency = 0.6)
        └── theOne           (ImageLabel — ImageTransparency = 0.6)
```

### CollectionService Tags

Applied via Studio's Tag Editor (View → Tag Editor):

| Tag | Applied to |
|-----|-----------|
| `CommonPuff` | Every common puff collectible part |
| `RarePuff_Z1` through `RarePuff_Z9` | The rare puff at the end of each zone |
| `Checkpoint_1`, `Checkpoint_2`, ... | Checkpoint platforms (global sequential index) |
| `KillZone` | Lava / fire / void parts (Zone 5+) |
| `Zone8Entry` | Invisible trigger part at Zone 8 entrance |
| `Zone8Exit` | Invisible trigger part at Zone 8 exit |

---

## Key Implementation Notes

### Security
- The client never writes game state — all mutations go through server functions
- Every `RemoteEvent` input is validated server-side before processing
- Duplicate collection is guarded by a per-player `BoolValue` flag on each part

### DataStore
- Key format: `player_` + `player.UserId`
- Store name: `CheesePuffObby_v1` (increment version to wipe all saves)
- 3 retry attempts with 2s delay on both read and write
- Falls back to default data if all retries fail — player can still play

### Zone 8 Gravity
- `workspace.Gravity` is global — changing it affects all players
- Zone 8 uses a `VectorForce` attachment on each player's `HumanoidRootPart`
- Applied on `Zone8Entry` touch, removed on `Zone8Exit` touch and on respawn

### The One Puff Transfer
- Server holds `onePuffHolder: Player?` in ZoneManager memory
- On Zone 9 completion: previous holder's `rarePuffs.theOne` set to `false`, new holder set to `true`
- `AnnounceOneP` fires to all clients with winner name and previous holder name

### Platform Unions
- All puff platforms are Unions of multiple Sphere parts
- **`UsePartColor` must be `true`** on each Union or color changes have no effect
- Set on the master template in ReplicatedStorage before duplicating

---

## Testing

The project includes a unit test suite covering DataManagerLogic and PlayerData:

```
67 passed, 0 failed, 0 skipped
```

Tests run automatically on server start and print results to the Studio Output panel. No external test runner required.

---

## Publishing

> **Warning:** `src/server/DevReset.server.luau` must be deleted before publishing to players. It resets player data on every join for whitelisted dev usernames.

1. **File → Publish to Roblox As** — required before DataStore works in Studio
2. Set game name, description, and thumbnail in the publish dialog
3. Under **Audience**, set to Public when ready to launch
4. Monitor analytics at [create.roblox.com](https://create.roblox.com)

### Game Description (Roblox listing)

> Jump through 9 increasingly insane zones and collect rare Cheeto Puffs along the way — from the humble Normal Puff to the legendary Galaxy Puff.
>
> But only the greatest obbyers can claim The One Puff. There's only one. In the whole server. And someone else probably already has it.

---

## Rojo File Naming Conventions

| Filename suffix | Studio type |
|----------------|-------------|
| `Name.server.luau` | Script (runs on server) |
| `Name.client.luau` | LocalScript (runs on client) |
| `Name.luau` | ModuleScript (required by either) |

---

## License

Apache 2.0