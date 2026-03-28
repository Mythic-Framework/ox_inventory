<div align="center">

![Banner](https://r2.fivemanage.com/b8BG4vav9CjKMUdz6iKnY/mythic_banner_old.png)

# ox_inventory

### *Slot-based inventory system with full Mythic Framework compatibility*

**Items • Weapons • Shops • Stashes**

![Lua](https://img.shields.io/badge/-Lua_5.4-2C2D72?style=for-the-badge&logo=lua&logoColor=white)
![FiveM](https://img.shields.io/badge/-FiveM-F40552?style=for-the-badge)
![React](https://img.shields.io/badge/-React-61DAFB?style=for-the-badge&logo=react&logoColor=black)
![Redux](https://img.shields.io/badge/-Redux-764ABC?style=for-the-badge&logo=redux&logoColor=white)
![TypeScript](https://img.shields.io/badge/-TypeScript-3178C6?style=for-the-badge&logo=typescript&logoColor=white)
![Vite](https://img.shields.io/badge/-Vite-646CFF?style=for-the-badge&logo=vite&logoColor=white)

[Features](#-features) • [Bridge](#-mythic-bridge) • [Development](#-development) • [Dependencies](#-dependencies)

</div>

---

## 📖 Overview

A fork of [ox_inventory](https://github.com/communityox/ox_inventory) with a full Mythic Framework compatibility bridge. Other mythic resources — drugs, police, robbery, targeting, finance, admin — require zero code changes. Item definitions, shops, stashes, trunks, gloveboxes, and drops are all handled transparently through the bridge.

---

> **TODO:** Item add/remove notifications currently use ox's built-in notify system. These should be wired through `mythic-notify` so they match the server's notification style. See `modules/bridge/mythic/client.lua` → `Inventory:Client:Changed` handler.

---

> **TODO:** Item use progress bars are not yet bridged. Mythic sends `Inventory:ItemUse` to the client with animation config before firing the use callback — ox skips this round-trip so items fire instantly with no animation. Needs a bridge that reads the item's `pbConfig` and triggers `lib.progressBar`.

---

## ✨ Features

<div align="center">
<table>
<tr>
<td width="50%">

### Inventory
- **Slot-based** — items stored per-slot with customisable metadata
- **Item uniqueness** — metadata supports serial numbers, quality, custom data
- **Durability** — items degrade and can be destroyed over time
- **Containers** — bag/backpack items open their own stash on use
- **Fully synchronised** — multiple players can share the same inventory

</td>
<td width="50%">

### Weapons & Shops
- **Weapons as items** — overrides the default GTA weapon system
- **Attachments & ammo** — full attachment and special ammo support
- **Shops** — group and license restricted, multiple currency types
- **Stashes** — personal, shared, property, evidence, and pd lockers
- **Vehicles** — trunk and glovebox access for any vehicle

</td>
</tr>
</table>
</div>

---

## 🔗 Mythic Bridge

The bridge lives in `modules/bridge/mythic/` and is loaded automatically when `inventory:framework` is set to `mythic`.

**What's bridged:**

| Component | Status |
|-----------|--------|
| `FetchComponent('Inventory')` — all shims | ✅ |
| `Inventory.Items` — RegisterUse, Remove\*, Has, HasAnyItems | ✅ |
| Item database — all mythic item files converted at startup | ✅ |
| Shops — loaded from mythic-inventory config at startup | ✅ |
| Stashes, trunks, gloveboxes, drops | ✅ |
| Character spawn / logout / job update | ✅ |
| Finance sync (cash item ↔ mythic-finance) | ✅ |
| State bag sync (ItemStates, isCuffed, isDead) | ✅ |
| `FetchComponent('Crafting')` — stub, prevents crash | ⚠️ |
| Crafting bench registration | ❌ |
| Client item use progress bar | ❌ |

**Required in `server.cfg`:**
```
set inventory:framework "mythic"
```

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
| `mythic-base` | Core framework (components, middleware, fetch) |
| `mythic-inventory` | Item definitions and shop config |
| `ox_lib` | Utility library (required by ox_inventory) |
| `oxmysql` | Database layer |

---

<div align="center">

[![Made for FiveM](https://img.shields.io/badge/Made_for-FiveM-F40552?style=for-the-badge)](https://fivem.net)
[![Mythic Framework](https://img.shields.io/badge/Mythic-Framework-208692?style=for-the-badge)](https://github.com/mythic-framework)

</div>
