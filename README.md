<div align="center">

![Banner](https://r2.fivemanage.com/b8BG4vav9CjKMUdz6iKnY/mythic_banner_old.png)

# ox_inventory

### *Slot-based inventory system with full Mythic Framework compatibility*

**Items • Weapons • Shops • Stashes • Crafting**

![Lua](https://img.shields.io/badge/-Lua_5.4-2C2D72?style=for-the-badge&logo=lua&logoColor=white)
![FiveM](https://img.shields.io/badge/-FiveM-F40552?style=for-the-badge)
![React](https://img.shields.io/badge/-React-61DAFB?style=for-the-badge&logo=react&logoColor=black)
![Redux](https://img.shields.io/badge/-Redux-764ABC?style=for-the-badge&logo=redux&logoColor=white)
![TypeScript](https://img.shields.io/badge/-TypeScript-3178C6?style=for-the-badge&logo=typescript&logoColor=white)
![Vite](https://img.shields.io/badge/-Vite-646CFF?style=for-the-badge&logo=vite&logoColor=white)

[Bridge](#-mythic-bridge) • [Pending](#-pending) • [Development](#-development) • [Dependencies](#-dependencies)

</div>

---

> [!WARNING]
> This is a **custom fork** of [ox_inventory](https://github.com/communityox/ox_inventory) — do not update from upstream without reviewing bridge compatibility.

> [!NOTE]
> **Working end-to-end:** Items, weapons, shops, stashes, trunks/gloveboxes, drops, crafting benches (ped spawn + targeting + open), cash sync (bidirectional with mythic-finance), character lifecycle, job group restrictions, item metadata (staticMetadata + type-based auto-generation), starter items with character data, item use with emotes + progress bars via mythic Progress component.
>
> **Pending:** Crafting UI (ox slot grid works but needs mythic-style panel), schematics per-player unlock + DB storage, notifications via mythic-notify.

---

## 📖 Overview

A fork of [ox_inventory](https://github.com/communityox/ox_inventory) with a full Mythic Framework compatibility bridge. Other mythic resources — drugs, police, robbery, targeting, finance, admin — require zero code changes. Item definitions, shops, stashes, trunks, gloveboxes, drops, and crafting benches are all handled transparently through the bridge.

Item definitions and crafting configs are **bundled directly** into this resource under `data/mythic-items/` and `data/mythic-crafting/`. `mythic-inventory` does not need to be running.

---

## 🔗 Mythic Bridge

The bridge lives in `modules/bridge/mythic/` and is loaded automatically when `inventory:framework` is set to `mythic`.

**What's bridged:**

| Component | Status |
|-----------|--------|
| `FetchComponent('Inventory')` server + client shims | ✅ |
| `Inventory.Items` — RegisterUse, RemoveSlot, RemoveId, RemoveAll, RemoveList, Remove | ✅ |
| `Inventory.Items` — GetCount, GetFirst, GetAll, GetData, Has, HasAnyItems | ✅ |
| `Inventory.Items` — GetCounts, GetWeights, GetAllOfType | ❌ Not bridged |
| `Inventory` — AddItem, GetSlot, GetFreeSlotNumbers, HasItems, HasAnyItems | ✅ |
| `Inventory` — UpdateMetaData, SetMetadataKey | ✅ |
| `Inventory` — AddSlot, SetMetaDataKey (name mismatch), IsEnabled, ForceClose, CloseSecondary | ❌ Not bridged |
| `Inventory.OpenSecondary` — stashes, shops, trunks, gloveboxes | ✅ |
| Item database — all mythic item files converted at startup | ✅ |
| Item metadata — `staticMetadata`, type-based auto-generation, character data | ✅ |
| Item tooltip — dynamic metadata display (all keys auto-rendered) | ✅ |
| Client item cache — `Inventory:Client:Cache`, `HasItem`, `HasItems`, `GetCount`, `Has` | ✅ |
| Client `Items` — GetCounts, GetTypeCounts, HasType, GetAllOfType | ❌ Not bridged |
| Client `Inventory` — Enable, Disable, IsEnabled | ❌ Not bridged |
| Shops — bundled from mythic-inventory config, location + programmatic | ✅ |
| Stashes, trunks, gloveboxes, drops | ✅ |
| Character spawn / logout / job update | ✅ |
| Finance sync (cash item ↔ mythic-finance, bidirectional) | ✅ |
| State bag sync (ItemStates, isCuffed, isDead) | ✅ |
| `FetchComponent('Crafting')` — RegisterBench, full bench pipeline | ✅ |
| Crafting bench ped/model/zone spawning (client) | ✅ |
| Crafting bench open (targeting → ox crafting UI) | ✅ |
| Crafting UI — mythic-style panel | ⏳ Planned |
| Schematics — per-player unlock + DB storage | ⏳ Planned |
| Item use — emotes + progress bar via mythic Progress component | ✅ |
| Notifications via mythic-notify | ⏳ Planned |

**Required in `server.cfg`:**
```
set inventory:framework "mythic"
```

---

## ⏳ Pending

### Missing Inventory Shims
Several lower-traffic server and client shims are not yet implemented. Server-side: `Inventory.Items.GetCounts` (all item counts as table), `Inventory.Items.GetWeights` (current/max weight), `Inventory.Items.GetAllOfType` (items by mythic type), `Inventory.AddSlot` (add to exact slot), `Inventory.SetMetaDataKey` (naming mismatch — we expose `SetMetadataKey`), `Inventory.IsEnabled`, `Inventory.ForceClose`, `Inventory.CloseSecondary`. Client-side: `Items.GetCounts`, `Items.GetTypeCounts`, `Items.HasType`, `Items.GetAllOfType`, `Inventory.Enable/Disable/IsEnabled`. These are rarely called but may cause nil-call crashes in scripts that use them.

### Crafting UI
The current crafting UI is ox's default — a slot grid where hovering a slot shows ingredients. A mythic-style panel (recipe list left, detail + ingredients + craft button right, search, craftable filter) is planned using Mantine once installed.

### Schematics
Schematic recipes are registered as a `crafting-schematics` bench at startup. What's missing is per-player unlock storage (ox MySQL, keyed on player SID + bench ID), a schematic item use handler to trigger the unlock, and merging unlocked schematics into the bench on open. See `modules/bridge/mythic/crafting_server.lua`.

### Notifications
Item add/remove notifications use ox's built-in notify. Should route through `mythic-notify` to match the server's notification style. See `modules/bridge/mythic/client.lua` → `Inventory:Client:Changed` handler.

---

## 👨‍💻 Development

```bash
cd web
bun install
bun run dev      # dev server with hot reload
bun run build    # production build
```

---

## 📦 Dependencies

| Resource | Why |
|----------|-----|
| `mythic-base` | Core framework (components, middleware, fetch, callbacks) |
| `ox_lib` | Utility library (points, callbacks, notify, keybinds) |
| `oxmysql` | Database layer |

> [!NOTE]
> `mythic-inventory` does **not** need to be running. Item definitions are bundled under `data/mythic-items/` and crafting configs under `data/mythic-crafting/`.

---

<div align="center">

[![Made for FiveM](https://img.shields.io/badge/Made_for-FiveM-F40552?style=for-the-badge)](https://fivem.net)
[![Mythic Framework](https://img.shields.io/badge/Mythic-Framework-208692?style=for-the-badge)](https://github.com/mythic-framework)

</div>
