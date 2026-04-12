-- mythic ox bridge : item converter
-- loads all mythic items via the index aggregator and registers them with ox
-- Items.new doesn't exist in ox — we get the ItemList directly via Items() and set on it

local Items    = require 'modules.items.server'
local Inventory = require 'modules.inventory.server'
local ItemList = Items() -- returns the full ItemList table

local function ConvertItem(item)
    if not item.name then return nil end

    local data = {
        name        = item.name,
        label       = item.label,
        description = item.description or nil,
        weight      = item.weight or 0,
        stack       = item.isStackable ~= false and (item.isStackable or true),
        close       = item.closeUi or false,
        decay       = item.isDestroyed or false,
        degrade     = item.durability and math.floor(item.durability / 60) or nil,
        server      = {
            mythicType    = item.type,
            mythicRarity  = item.rarity,
            mythicPrice   = item.price or 0,
            state         = item.state,
            isRemoved     = item.isRemoved or false,
            animConfig    = item.animConfig or nil,
            vehicleBlock  = item.vehicleBlock or nil,
            armourValue   = item.armourValue or nil,
            dispenseItem  = item.dispenseItem or nil,
            drugState     = item.drugState or nil,
        },
        staticMetadata = item.staticMetadata or nil,
    }

    -- type 2: weapons — routed through server.UseItem → Weapons:Client:Use, NOT ox native weapon system
    -- type 9: ammo — routed through server.UseItem → lib.callback addAmmo, NOT ox native ammo system
    if item.type == 2 and item.ammoType then
        -- ammoname → individual bullet item so unloading gives single bullets, not whole boxes
        local bulletMap = {
            AMMO_PISTOL  = 'bullet_pistol',
            AMMO_SMG     = 'bullet_smg',
            AMMO_RIFLE   = 'bullet_rifle',
            AMMO_SHOTGUN = 'bullet_shotgun',
            AMMO_SNIPER  = 'bullet_sniper',
            AMMO_STUNGUN = 'bullet_stungun',
        }
        data.ammoname = bulletMap[item.ammoType]
    end
    if item.type == 9 then
        data.stack = true
        data.server.ammoType   = item.ammoType or nil
        data.server.bulletCount = item.bulletCount or nil
    end
    -- auto-set durability flag for degrading items
    if not data.durability then
        if data.degrade or (data.consume and data.consume ~= 0 and data.consume < 1) then
            data.durability = true
        end
    end
    -- server side doesnt need client data
    data.client = nil
    return data
end

local function registerConsumableUse(item)
    Inventory.Items:RegisterUse(item.name, 'StatusConsumable', function(source, slotData)
        -- use direct ox export so the numeric source hits the in memory player inventory
        exports['ox_inventory']:RemoveItem(source, slotData.Name, 1, nil, slotData.Slot)

        if item.statusChange then
            if item.statusChange.Add then
                for k, v in pairs(item.statusChange.Add) do
                    TriggerClientEvent('Status:Client:updateStatus', source, k, true, v)
                end
            end
            if item.statusChange.Remove then
                for k, v in pairs(item.statusChange.Remove) do
                    TriggerClientEvent('Status:Client:updateStatus', source, k, false, -v)
                end
            end
            if item.statusChange.Ignore then
                for k, v in pairs(item.statusChange.Ignore) do
                    Player(source).state[('ignore%s'):format(k)] = v
                end
            end
        end

        if item.healthModifier then TriggerClientEvent('Inventory:Client:HealthModifier', source, item.healthModifier) end
        if item.armourModifier then TriggerClientEvent('Inventory:Client:ArmourModifier', source, item.armourModifier) end
        if item.stressTicks then Player(source).state.stressTicks = item.stressTicks end
        if item.energyModifier then
            TriggerClientEvent('Inventory:Client:SpeedyBoi', source,
                item.energyModifier.modifier,
                item.energyModifier.duration * 1000,
                item.energyModifier.cooldown * 1000,
                item.energyModifier.skipScreenEffects)
        end
        if item.progressModifier then
            TriggerClientEvent('Execute:Client:Component', source, 'Progress', 'Modifier',
                item.progressModifier.modifier,
                math.random(item.progressModifier.min, item.progressModifier.max) * 60000)
        end

        -- direct armour set (armor/heavyarmor/pdarmor)
        if item.armourValue then
            SetPedArmour(GetPlayerPed(source), item.armourValue)
        end

        -- drug state storage (oxy, weed, etc.) — stored on character for mythic-drugs/police to read
        if item.drugState then
            local Fetch = exports['mythic-base']:FetchComponent('Fetch')
            if Fetch then
                local plyr = Fetch:Source(source)
                if plyr then
                    local char = plyr:GetData('Character')
                    if char then
                        local drugStates = char:GetData('DrugStates') or {}
                        drugStates[item.drugState.type] = {
                            item    = item.name,
                            expires = os.time() + item.drugState.duration,
                        }
                        char:SetData('DrugStates', drugStates)
                    end
                end
            end
        end
    end)
end

local allItems = lib.load('data.mythic-items.index')
if not allItems then
    print('^1[mythic-ox-bridge] failed to load item index^0')
    return
end
local itemCount, callbackCount = 0, 0

for _, item in ipairs(allItems) do
    local converted = ConvertItem(item)
    if converted then
        local storeKey = (item.name:sub(1, 7):lower() == 'weapon_') and item.name or item.name:lower()
        converted.name = storeKey  -- slot stores item.name; must match the key so ItemList[slot.name] works
        ItemList[storeKey] = converted
        itemCount = itemCount + 1
    end
    if item.type == 1 and (item.statusChange or item.healthModifier or item.armourModifier
        or item.stressTicks or item.energyModifier or item.progressModifier
        or item.armourValue or item.drugState) then
        registerConsumableUse(item)
        callbackCount = callbackCount + 1
    end
    -- dispense-one-per-use items (e.g. cigarette_pack → gives 1 cigarette per use, tracked via metadata Count)
    if item.type == 1 and item.dispenseItem then
        local dispenseItemName = item.dispenseItem
        local defaultCount     = item.dispenseDefault or 1
        local iname            = item.name:lower()
        Inventory.Items:RegisterUse(iname, 'Dispense', function(source, slotData)
            local inv = Inventory(source)
            if not inv then return end
            local slot      = inv.items[slotData.Slot]
            local remaining = (slot and slot.metadata and tonumber(slot.metadata.Count)) or defaultCount
            if remaining > 0 then
                Inventory.AddItem(inv, dispenseItemName, 1, {})
                remaining = remaining - 1
                if remaining <= 0 then
                    Inventory.RemoveItem(inv, iname, 1, slot and slot.metadata or {}, slotData.Slot)
                    TriggerClientEvent('mythic-notify:client:SendAlert', source, { type = 'info', message = ('No more %s in pack'):format(dispenseItemName) })
                else
                    local meta = table.clone(slot.metadata or {})
                    meta.Count = remaining
                    Inventory.SetMetadata(inv, slotData.Slot, meta)
                end
            else
                Inventory.RemoveItem(inv, iname, 1, slot and slot.metadata or {}, slotData.Slot)
                TriggerClientEvent('mythic-notify:client:SendAlert', source, { type = 'error', message = 'Pack is empty' })
            end
        end)
        callbackCount = callbackCount + 1
    end
    -- bullet items: use = load into compatible hotbar weapon, fallback to pack
    if item.type == 1 and item.packInto and item.packCount then
        local packInto  = item.packInto:lower()
        local packCount = item.packCount
        local itemName  = item.name:lower()
        Inventory.Items:RegisterUse(itemName, 'BulletUse', function(source, slotData)
            local inventory = Inventory(source)
            if not inventory then return end
            -- find compatible weapons in hotbar slots 1-5
            local compatWeapons = {}
            for slot = 1, 5 do
                local s = inventory.items[slot]
                if s and s.name then
                    local def = Items(s.name)
                    if def and def.ammoname == itemName then
                        compatWeapons[#compatWeapons + 1] = {
                            slot        = slot,
                            name        = s.name,
                            label       = def.label or s.name,
                            currentAmmo = (s.metadata and s.metadata.ammo) or 0,
                        }
                    end
                end
            end
            local haveCount = exports['ox_inventory']:Search(source, 'count', itemName) or 0
            if #compatWeapons == 0 then
                -- no compatible weapon in hotbar — try pack instead
                if haveCount >= packCount then
                    exports['ox_inventory']:RemoveItem(source, itemName, packCount)
                    exports['ox_inventory']:AddItem(source, packInto, 1)
                    TriggerClientEvent('mythic-notify:client:SendAlert', source, {
                        type = 'success',
                        message = ('Packed %d bullets into 1x %s'):format(packCount, packInto)
                    })
                else
                    TriggerClientEvent('mythic-notify:client:SendAlert', source, {
                        type = 'error',
                        message = 'No compatible weapon in hotbar (slots 1-5)'
                    })
                end
                return
            end
            -- send weapon list to client for menu + count input
            TriggerClientEvent('Inventory:Client:LoadBullets', source, {
                itemName  = itemName,
                packInto  = packInto,
                packCount = packCount,
                haveCount = haveCount,
                weapons   = compatWeapons,
            })
        end)
        callbackCount = callbackCount + 1
    end
end

-- player chose how many bullets to load into a weapon slot
RegisterServerEvent('Inventory:Server:LoadBullets', function(weaponSlot, bulletItemName, count)
    local source    = source
    local inventory = Inventory(source)
    if not inventory then return end
    local have = exports['ox_inventory']:Search(source, 'count', bulletItemName) or 0
    count = math.min(math.floor(count), have)
    if count < 1 then return end
    exports['ox_inventory']:RemoveItem(source, bulletItemName, count)
    -- update weapon metadata so ammo persists
    local weapSlot = inventory.items[weaponSlot]
    if weapSlot and weapSlot.metadata then
        weapSlot.metadata.ammo = (weapSlot.metadata.ammo or 0) + count
        inventory:syncSlotsWithPlayer({ { item = weapSlot } }, inventory.weight)
    end
    -- if weapon is currently equipped on client, add bullets to ped live
    TriggerClientEvent('Inventory:Client:BulletsLoaded', source, weaponSlot, count)
end)

AddEventHandler('Crafting:Client:OpenCrafting', function(ent, data)
    exports['ox_inventory']:openInventory('crafting', { id = data.id, index = 1 })
end)

print(string.format('^2[mythic-ox-bridge] loaded %d items, %d consumable callbacks :)^0', itemCount, callbackCount))