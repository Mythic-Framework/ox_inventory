-- mythic ox bridge : server side
-- makes ox_inventory pretend to be mythic inventory so nothing else has to change
-- if something breaks its probably in here, good luck
--
-- REQUIRED in server.cfg or literally none of this loads:
--   set inventory:framework "mythic"

local Inventory = require 'modules.inventory.server'
local Items     = require 'modules.items.server'

-- converts a SID to a live source, returns nil if theyre not online
local function sidToSource(sid)
    local player = exports['mythic-base']:FetchComponent('Fetch'):SID(sid)
    if not player then return nil end
    return player:GetData('Source')
end

-- ox calls this after setPlayerInventory to build the player data table stored on inv.player
-- player here is the PLAIN TABLE we build in the Characters:Spawning middleware below
-- (not a mythic player object - dont call :GetData on it here)
function server.setPlayerData(player)
    if not player.groups then
        print('^3[mythic-ox-bridge] setPlayerData: no groups for ' .. tostring(player.name) .. '^0')
    end
    return {
        source      = player.source,
        name        = player.name,
        groups      = player.groups or {},
        sex         = player.sex or 0,
        dateofbirth = player.dateofbirth or '',
    }
end

-- NOTE: we do NOT define server.setPlayerInventory here
-- ox's server.lua defines it after the bridge loads and it handles DB load + inventory creation
-- we just call it from our Characters:Spawning middleware with a properly formatted table

-- keeps mythic-finance cash in sync with the money item count
-- ox calls this after item add/remove/buy operations, inv.player.source is set by setPlayerData above
function server.syncInventory(inv)
    if not inv?.player then return end
    local player = exports['mythic-base']:FetchComponent('Fetch'):Source(inv.player.source)
    if not player then return end
    local char = player:GetData('Character')
    if not char then return end
    char:SetData('Cash', Inventory.GetItemCount(inv, 'money') or 0)
end

-- group can be a string or a table of { jobname = mingrade } or { jobname = {validgrades} }
-- overrides generic bridge version to add inv?.player nil check
function server.hasGroup(inv, group)
    if not inv?.player then return end

    if type(group) == 'table' then
        for name, requiredRank in pairs(group) do
            local groupRank = inv.player.groups[name]
            if groupRank then
                if type(requiredRank) == 'table' then
                    -- array of valid grade levels e.g. {1,2,3}
                    if lib.table.contains(requiredRank, groupRank) then
                        return name, groupRank
                    end
                else
                    if groupRank >= (requiredRank or 0) then
                        return name, groupRank
                    end
                end
            end
        end
    else
        local groupRank = inv.player.groups[group]
        if groupRank then return group, groupRank end
    end
end

-- checks qualifications (driving license, weapon license etc) on the character
function server.hasLicense(inv, name)
    if not inv?.player then return false end
    local player = exports['mythic-base']:FetchComponent('Fetch'):Source(inv.player.source)
    if not player then return false end
    local char = player:GetData('Character')
    if not char then return false end
    local quals = char:GetData('Qualifications') or {}
    for _, v in ipairs(quals) do
        if v == name then return true end
    end
    return false
end

-- every single mythic resource registers item callbacks through here so this HAS to work
local ItemCallbacks = {}

Inventory.Items = {
    RegisterUse = function(self, itemName, id, cb)
        if not ItemCallbacks[itemName] then
            ItemCallbacks[itemName] = {}
        end
        ItemCallbacks[itemName][id] = cb
    end,

    -- used EVERYWHERE (150+ calls), removes a specific slot
    -- owner = SID for players, stash/container ID for everything else
    RemoveSlot = function(self, owner, name, count, slot, invType)
        invType = invType or 1
        count   = count or 1
        if invType == 1 then
            local source = sidToSource(owner)
            if not source then return false end
            return exports['ox_inventory']:RemoveItem(source, name, count, nil, slot)
        end
        return exports['ox_inventory']:RemoveItem(owner, name, count, nil, slot)
    end,

    -- removes by slot object reference, robbery and police use this a lot
    -- slot is the mythic slot object with .Owner .Name .Slot .invType fields
    RemoveId = function(self, owner, invType, slot)
        invType = invType or 1
        local itemName = slot.Name or slot.name
        local slotNum  = slot.Slot or slot.slot
        if invType == 1 then
            local source = sidToSource(owner)
            if not source then return false end
            return exports['ox_inventory']:RemoveItem(source, itemName, 1, nil, slotNum)
        end
        return exports['ox_inventory']:RemoveItem(owner, itemName, 1, nil, slotNum)
    end,

    -- plain remove by item name and count, no slot targeting
    Remove = function(self, owner, invType, item, count)
        invType = invType or 1
        count   = count or 1
        if invType == 1 then
            local source = sidToSource(owner)
            if not source then return false end
            return exports['ox_inventory']:RemoveItem(source, item, count)
        end
        return exports['ox_inventory']:RemoveItem(owner, item, count)
    end,

    -- nukes every stack of an item, robbery uses this to clear access codes etc
    RemoveAll = function(self, owner, invType, itemName)
        invType = invType or 1
        if invType == 1 then
            local source = sidToSource(owner)
            if not source then return false end
            local count = exports['ox_inventory']:Search('count', itemName, source) or 0
            if count > 0 then return exports['ox_inventory']:RemoveItem(source, itemName, count) end
            return true
        end
        local count = exports['ox_inventory']:Search('count', itemName, owner) or 0
        if count > 0 then return exports['ox_inventory']:RemoveItem(owner, itemName, count) end
        return true
    end,

    -- removes a list of items in one call, weed and drugs use this for multi-ingredient recipes
    -- items = {{ name = 'thing', count = 1 }, ...}
    RemoveList = function(self, owner, invType, items)
        for _, v in ipairs(items) do
            Inventory.Items:Remove(owner, invType, v.name, v.count or 1)
        end
    end,

    -- police handcuffs calls this on Items not on Inventory directly
    HasAnyItems = function(self, source, items)
        for _, v in ipairs(items) do
            local key = v.item or v.name
            if (exports['ox_inventory']:Search('count', key, source) or 0) >= (v.count or 1) then
                return true
            end
        end
        return false
    end,

    -- crafting uses this for ingredient checks: Items:Has(source, itemName, count)
    -- same as HasItem basically, just on the Items sub-table instead of Inventory
    Has = function(self, source, itemName, count)
        return (exports['ox_inventory']:Search('count', itemName, source) or 0) >= (count or 1)
    end,
}

-- ox calls this when someone uses a non-weapon item with no consume set
-- translates ox slot data back into the mythic item format that callbacks expect
function server.UseItem(source, itemName, data)
    local callbacks = ItemCallbacks[itemName]

    local mythicItem = {
        Name     = data.name,
        Slot     = data.slot,
        Count    = data.count,
        Metadata = data.metadata or {},
        Quality  = data.metadata and data.metadata.quality or 100,
    }

    local itemDef = Items(itemName)

    if callbacks then
        for _, cb in pairs(callbacks) do
            cb(source, mythicItem, itemDef)
        end
    end

    -- auto remove if flagged as consumed but only if a callback didnt already pull it
    if itemDef and itemDef.server and itemDef.server.isRemoved then
        local stillThere = Inventory.GetSlot(source, data.slot)
        if stillThere and stillThere.name == itemName then
            exports['ox_inventory']:RemoveItem(source, itemName, 1, data.metadata, data.slot)
        end
    end
end

-- the shims that make FetchComponent('Inventory') work without changing any other resource

-- invType 1 = player (SID), anything else = stash/trunk/etc by owner ID
Inventory.AddItem = function(self, sid, name, count, metadata, invType)
    invType = invType or 1
    count   = count or 1
    if invType == 1 then
        local source = sidToSource(sid)
        if not source then
            print('^1[mythic-ox-bridge] AddItem: no online player for SID ' .. tostring(sid) .. '^0')
            return false
        end
        return exports['ox_inventory']:AddItem(source, name, count, metadata or {})
    end
    return exports['ox_inventory']:AddItem(sid, name, count, metadata or {})
end

Inventory.RemoveItem = function(self, sid, name, count, metadata, invType)
    invType = invType or 1
    count   = count or 1
    if invType == 1 then
        local source = sidToSource(sid)
        if not source then return false end
        return exports['ox_inventory']:RemoveItem(source, name, count, metadata)
    end
    return exports['ox_inventory']:RemoveItem(sid, name, count, metadata)
end

-- all items must be present
Inventory.HasItems = function(self, source, items)
    for _, v in ipairs(items) do
        if (exports['ox_inventory']:Search('count', v.item, source) or 0) < (v.count or 1) then
            return false
        end
    end
    return true
end

-- at least one item from the list must be present
Inventory.HasAnyItems = function(self, source, items)
    for _, v in ipairs(items) do
        if (exports['ox_inventory']:Search('count', v.item, source) or 0) >= (v.count or 1) then
            return true
        end
    end
    return false
end

-- mythic-admin expects name/label/type/rarity/weight/price/isStackable/description
-- ox returns its own format so we remap
-- TODO: price is always 0, ox doesnt store price on item defs
Inventory.GetItemsDatabase = function(self)
    local oxItems = exports['ox_inventory']:Items()
    local result  = {}
    for name, def in pairs(oxItems) do
        result[name] = {
            name        = name,
            label       = def.label,
            type        = def.server and def.server.mythicType or 1,
            rarity      = def.server and def.server.mythicRarity or 1,
            weight      = def.weight or 0,
            price       = 0,
            isStackable  = def.stack ~= false,
            description = def.description,
        }
    end
    return result
end

Inventory.DoesItemExist = function(self, name)
    return Items(name) ~= nil
end

-- crafting calls this to know if theres space before adding output items
-- ox doesnt have a direct export for this so we dig into the inventory object
-- returns a list of free slot numbers (1-indexed, matching mythic expectation)
Inventory.GetFreeSlotNumbers = function(self, source)
    local inv = Inventory(source)
    if not inv then return {} end
    local free = {}
    for i = 1, inv.slots do
        if not inv.items[i] or not inv.items[i].name then
            free[#free + 1] = i
        end
    end
    return free
end

-- robbery calls this to track durability on thermite etc
-- ox uses per-item-def degrade minutes not per-slot create dates so this cant map 1:1
-- FIXME: slot.id in mythic is a DB row id which doesnt exist in ox
Inventory.SetItemCreateDate = function(self, slotId, value)
    -- stub, prevents crash, durability wont actually track until this is solved
end

-- handles opening stashes, trunks, gloveboxes, drops, shops
-- registers stashes with ox on first open so we dont have to preregister every single one
local registeredStashes = {}

local invTypeToOxType = {
    [3]  = 'stash', -- police weapon rack (pdrack:VIN)
    [4]  = 'trunk',
    [5]  = 'glovebox',
    [10] = 'drop',
    [11] = 'shop',
    [13] = 'stash',
    [44] = 'stash', -- evidence case locker
    [45] = 'stash', -- personal pd/ems locker
}

Inventory.OpenSecondary = function(self, source, invType, owner, vehClass, vehModel, isRaid, nameOverride, slotOverride, capacityOverride)
    if not source or not invType or not owner then return end

    local oxType  = invTypeToOxType[invType]
    local isStash = oxType == 'stash' or invType >= 1000

    if isStash then
        if not registeredStashes[owner] then
            exports['ox_inventory']:RegisterStash(
                owner,
                nameOverride or owner,
                slotOverride or 50,
                capacityOverride or 100000
            )
            registeredStashes[owner] = true
        end
        TriggerClientEvent('Inventory:Client:Load', source, { invType = invType, owner = owner })
    elseif invType == 11 then
        -- TODO: shops need ox-format definitions before this actually works
        TriggerClientEvent('Inventory:Client:Load', source, { invType = 11, owner = owner })
    elseif invType == 4 or invType == 5 then
        -- client needs to find the vehicle entity by VIN to get the netid
        -- passed as vinOwner so client knows to do the entity lookup
        TriggerClientEvent('Inventory:Client:Load', source, {
            invType  = invType,
            owner    = owner,
            vehClass = vehClass or false,
            vehModel = vehModel or false,
        })
    elseif invType == 10 then
        TriggerClientEvent('Inventory:Client:Load', source, { invType = 10, owner = owner })
    end
end

-- state bag sync, items with a state field in their def auto-set that state on the character
-- skips SCRIPT_ and ACCESS_ prefixes, those are handled elsewhere
local function UpdateCharacterItemStates(source, itemName, adding)
    local itemDef = Items(itemName)
    if not itemDef or not itemDef.server or not itemDef.server.state then return end

    local state = itemDef.server.state
    if state:sub(1, 7) == 'SCRIPT_' or state:sub(1, 7) == 'ACCESS_' then return end

    local charState = Player(source).state
    local states    = charState.ItemStates or {}
    states[state]   = adding and true or nil
    charState:set('ItemStates', states, true)
end

exports['ox_inventory']:registerHook('addItem', function(payload)
    UpdateCharacterItemStates(payload.source, payload.item, true)
end)

exports['ox_inventory']:registerHook('removeItem', function(payload)
    UpdateCharacterItemStates(payload.source, payload.item, false)
end)

-- openInventory hook fires when ox opens any secondary inventory
-- mythic-labor coke job listens to Inventory:Server:Opened(source, owner, invType) to track trunk opens
-- payload.inventoryId for trunks is 'trunk'..VIN so we strip the prefix for the mythic event
exports['ox_inventory']:registerHook('openInventory', function(payload)
    local oxType     = payload.inventoryType
    local invTypeNum = ({ trunk=4, glovebox=5, drop=10, shop=11, stash=13 })[oxType] or 13
    local owner      = payload.inventoryId

    -- strip the 'trunk'/'glove' prefix ox adds so mythic resources get the raw VIN/plate
    if oxType == 'trunk' and owner:sub(1, 5) == 'trunk' then
        owner = owner:sub(6)
    elseif oxType == 'glovebox' and owner:sub(1, 5) == 'glove' then
        owner = owner:sub(6)
    end

    TriggerEvent('Inventory:Server:Opened', payload.source, owner, invTypeNum)
end)

-- TODO: crafting system is NOT bridged
-- mythic-crafting uses:
--   Inventory.Items:Has(source, name, count)       <- shimmed above
--   Inventory.Items:Remove(owner, invType, name, count, skipUpdate) <- skipUpdate flag ignored, should be fine
--   Inventory:GetFreeSlotNumbers(source)           <- shimmed above
--   Inventory:AddItem(source, name, count, meta)   <- shimmed above
--   Crafting:RegisterBench(id, config)             <- NOT shimmed, mythic-crafting registers benches via FetchComponent('Crafting')
--   crafting_cooldowns DB table in MySQL           <- doesnt exist in ox db, will error on first craft
-- FIXIT: either bridge mythic-crafting's RegisterBench into ox's RegisterCraft system,
--        or port mythic-crafting to call exports['ox_inventory'] directly
--        for now the stub below prevents crash-on-nil but crafting wont actually work

-- stub crafting component so resources dont explode on FetchComponent('Crafting')
-- everything returns false/nil, nothing will actually craft
-- FIXIT: replace this with real logic when you get around to it
local CraftingStub = {
    RegisterBench = function(self, id, config)
        print('^3[mythic-ox-bridge] Crafting:RegisterBench called for bench "' .. tostring(id) .. '" - crafting not bridged yet, ignoring^0')
    end,
    CanCraft = function(self, ...) return false end,
    StartCraft = function(self, ...) return false end,
}

-- TODO: loot component is NOT bridged
-- mythic-loot/server.lua registers as FetchComponent('_LOOT')
-- resources call Loot:CustomWeightedSet(items) which internally calls Inventory:AddItem
-- since Inventory:AddItem IS shimmed, loot adding items should work IF we register the component
-- but _LOOT itself isnt a component we control, mythic-loot registers it itself
-- as long as mythic-loot loads and calls FetchComponent('Inventory') for its AddItem calls it should be fine
-- FIXIT: verify mythic-loot actually loads and registers its _LOOT component in the mythic-base proxy

-- mythic lifecycle hooks
AddEventHandler('Proxy:Shared:RegisterReady', function()
    local Middleware = exports['mythic-base']:FetchComponent('Middleware')
    local Fetch      = exports['mythic-base']:FetchComponent('Fetch')
    local Config     = exports['mythic-base']:FetchComponent('Config')

    -- on character spawn we build the plain table ox expects and call its setPlayerInventory
    -- ox then loads the DB inventory, creates the inv object, and calls our server.setPlayerData
    Middleware:Add('Characters:Spawning', function(source)
        local player = Fetch:Source(source)
        if not player then return end
        local char = player:GetData('Character')
        if not char then return end

        local jobs   = char:GetData('Jobs') or {}
        local groups = {}
        for _, v in ipairs(jobs) do
            groups[v.Id] = v.Grade and v.Grade.Level or 0
        end

        server.setPlayerInventory({
            source      = source,
            name        = player:GetData('Name'),
            identifier  = char:GetData('SID'),
            groups      = groups,
            sex         = char:GetData('Gender') or 0,
            dateofbirth = char:GetData('DOB') or '',
        })
    end, 5)

    -- close and remove inventory on character logout
    -- note: playerDropped is handled by ox's generic bridge/server.lua already
    Middleware:Add('Characters:Logout', function(source)
        local inv = Inventory(source)
        if inv and inv.player then
            inv:closeInventory()
            Inventory.Remove(inv)
        end
        return true
    end, 5)

    -- give new characters their starter items
    Middleware:Add('Characters:Created', function(source)
        local startItems = Config:GetData('StartItems') or {}
        for slot, item in ipairs(startItems) do
            exports['ox_inventory']:AddItem(source, item.name, item.count, {}, slot)
        end
        return true
    end, 5)

    exports['mythic-base']:RegisterComponent('Inventory', Inventory)
    exports['mythic-base']:RegisterComponent('Crafting', CraftingStub)
end)

-- rebuild groups when someones job changes
AddEventHandler('Jobs:Server:JobUpdate', function(source)
    local inv = Inventory(source)
    if not inv or not inv.player then return end

    local player = exports['mythic-base']:FetchComponent('Fetch'):Source(source)
    if not player then return end
    local char = player:GetData('Character')
    if not char then return end

    local groups = {}
    for _, v in ipairs(char:GetData('Jobs') or {}) do
        groups[v.Id] = v.Grade and v.Grade.Level or 0
    end
    inv.player.groups = groups
end)
