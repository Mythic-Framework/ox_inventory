-- mythic ox bridge : client side
-- handles client side inv events for mythic compatibility
--
-- TODO: client cached inventory not bridged
-- mythic sends Inventory:Client:Cache with the full inventory array after any change
-- resources read from this cache for local HasItem checks instead of server roundtrips
-- our Check.Player.HasItem calls Search() export which is probably fine latency-wise
-- but if something is checking items every frame it will be slow as hell
-- FIXIT: listen to Inventory:Client:Cache and cache locally, swap Check.Player.* to use cache


-- Mythic Weapons bridge
-- Ports mythic-inventory weapon equip/unequip with draw anims,
-- ammo tracking in metadata, and ammo item type-checking

local _weapItemDefs = {}
do
    local _all = lib.load('data.mythic-items.index') or {}
    for _, item in ipairs(_all) do
        if item.name then _weapItemDefs[item.name] = item end
    end
end

local _equipped     = nil   -- { Name, Slot, Count, MetaData, Owner, invType }
local _equippedData = nil   -- mythic item definition
local _weapLoggedIn = false

local function _loadAnimDict(dict)
    while not HasAnimDictLoaded(dict) do RequestAnimDict(dict) Wait(5) end
end

local function _doHolsterBlockers()
    CreateThread(function()
        while LocalPlayer.state.holstering do
            DisablePlayerFiring(PlayerPedId(), true)
            for _, c in ipairs({ 14,15,16,17,24,25,50,68,91,99,115,142 }) do
                DisableControlAction(0, c, true)
            end
            Wait(0)
        end
    end)
end

local _wAnims = {
    Cop = {
        Holster = function(ped)
            LocalPlayer.state:set('holstering', true, false)
            _doHolsterBlockers()
            local dict = 'reaction@intimidation@cop@unarmed'
            _loadAnimDict(dict)
            TaskPlayAnim(ped, dict, 'intro', 10.0, 2.3, -1, 49, 1, 0, 0, 0)
            Wait(600)
            SetCurrentPedWeapon(ped, GetHashKey('WEAPON_UNARMED'), true)
            RemoveAllPedWeapons(ped)
            ClearPedTasks(ped)
            LocalPlayer.state:set('holstering', false, false)
        end,
        Draw = function(ped, hash, ammoHash, ammo, clip, item, itemData)
            LocalPlayer.state:set('holstering', true, false)
            _doHolsterBlockers()
            RemoveAllPedWeapons(ped)
            local dict = 'reaction@intimidation@cop@unarmed'
            _loadAnimDict(dict)
            TaskPlayAnim(ped, dict, 'intro', 10.0, 2.3, -1, 49, 1, 0, 0, 0)
            Wait(600)
            SetPedAmmoToDrop(ped, 0)
            local actualClip = clip or GetWeaponClipSize(hash)
            local actualReserve = itemData.isThrowable and (item.Count or 1) or (ammo or 0)
            _ghostBullet = (actualClip == 0 and actualReserve == 0)
            -- give at least 1 clip bullet so GTA keeps the weapon in hand when ammo=0
            GiveWeaponToPed(ped, hash, math.max(1, actualClip), true, true)
            SetPedAmmoByType(ped, ammoHash, actualReserve)
            if item.MetaData and item.MetaData.WeaponTint then SetPedWeaponTintIndex(ped, hash, item.MetaData.WeaponTint) end
            if item.MetaData and item.MetaData.WeaponComponents then
                for _, v in pairs(item.MetaData.WeaponComponents) do GiveWeaponComponentToPed(ped, hash, GetHashKey(v.attachment)) end
            end
            SetCurrentPedWeapon(ped, hash, 1)
            -- only restore clip if > 0; restoring to 0 makes GTA auto-switch to unarmed
            if actualClip > 0 then SetAmmoInClip(ped, hash, actualClip) end
            ClearPedTasks(ped)
            LocalPlayer.state:set('holstering', false, false)
        end,
    },
    Holster = {
        OH = function(ped)
            LocalPlayer.state:set('holstering', true, false)
            _doHolsterBlockers()
            local dict, anim = 'reaction@intimidation@1h', 'outro'
            local dur = GetAnimDuration(dict, anim) * 1000
            _loadAnimDict(dict)
            TaskPlayAnim(ped, dict, anim, 1.0, 1.0, -1, 50, 0, 0, 0, 0)
            Wait(dur - 2200)
            SetCurrentPedWeapon(ped, GetHashKey('WEAPON_UNARMED'), true)
            Wait(300)
            RemoveAllPedWeapons(ped)
            ClearPedTasks(ped)
            Wait(800)
            LocalPlayer.state:set('holstering', false, false)
        end,
    },
    Draw = {
        OH = function(ped, hash, ammoHash, ammo, clip, item, itemData)
            LocalPlayer.state:set('holstering', true, false)
            _doHolsterBlockers()
            local dict, anim = 'reaction@intimidation@1h', 'intro'
            RemoveAllPedWeapons(ped)
            local dur = GetAnimDuration(dict, anim) * 1000
            _loadAnimDict(dict)
            TaskPlayAnim(ped, dict, anim, 1.0, 1.0, -1, 50, 0, 0, 0, 0)
            Wait(900)
            SetPedAmmoToDrop(ped, 0)
            local actualClip = clip or GetWeaponClipSize(hash)
            local actualReserve = itemData.isThrowable and (item.Count or 1) or (ammo or 0)
            _ghostBullet = (actualClip == 0 and actualReserve == 0)
            -- give at least 1 clip bullet so GTA keeps the weapon in hand when ammo=0
            GiveWeaponToPed(ped, hash, math.max(1, actualClip), true, true)
            SetPedAmmoByType(ped, ammoHash, actualReserve)
            if item.MetaData and item.MetaData.WeaponTint then SetPedWeaponTintIndex(ped, hash, item.MetaData.WeaponTint) end
            if item.MetaData and item.MetaData.WeaponComponents then
                for _, v in pairs(item.MetaData.WeaponComponents) do GiveWeaponComponentToPed(ped, hash, GetHashKey(v.attachment)) end
            end
            SetCurrentPedWeapon(ped, hash, 1)
            -- only restore clip if > 0; restoring to 0 makes GTA auto-switch to unarmed
            if actualClip > 0 then SetAmmoInClip(ped, hash, actualClip) end
            Wait(500)
            ClearPedTasks(ped)
            Wait(1200)
            LocalPlayer.state:set('holstering', false, false)
        end,
    },
}

-- true when we gave a ghost bullet to hold a 0-ammo weapon in hand
-- must be zeroed before _updateAmmo reads clip so we don't save the phantom round
local _ghostBullet = false

local function _updateAmmo(item, isDiff)
    if not item then return end
    local itemData = _weapItemDefs[item.Name]
    if not itemData or itemData.isThrowable then return end
    local ped = PlayerPedId()
    local _, wep = GetCurrentPedWeapon(ped, true)
    local hash = GetHashKey(itemData.weapon or item.Name)
    if hash ~= wep then return end
    local _, clip = GetAmmoInClip(ped, hash)
    local ammo = GetAmmoInPedWeapon(ped, hash)
    if ammo == (item.MetaData.ammo or 0) and clip == (item.MetaData.clip or 0) then return end
    -- update local cache so next comparison uses current values
    item.MetaData.ammo = ammo
    item.MetaData.clip = clip
    if isDiff then
        TriggerServerEvent('Weapon:Server:UpdateAmmoDiff', item.Slot, ammo, clip)
    else
        TriggerServerEvent('Weapon:Server:UpdateAmmo', item.Slot, ammo, clip)
    end
end

local function _runWeaponThreads()
    CreateThread(function()
        while _equipped ~= nil and _weapLoggedIn do
            _updateAmmo(_equipped)
            Wait(20000)
        end
    end)
end

WEAPONS = {
    GetEquippedHash = function(self)
        if not _equipped then return nil end
        local d = _weapItemDefs[_equipped.Name]
        return GetHashKey(d and d.weapon or _equipped.Name)
    end,
    GetEquippedItem = function(self) return _equipped end,
    IsEligible = function(self) return true end,

    Equip = function(self, item)
        local ped = PlayerPedId()
        local itemData = _weapItemDefs[item.Name]
        if not itemData then return end
        local hash = GetHashKey(itemData.weapon or item.Name)
        local ammoHash = GetHashKey(itemData.ammoType or 'AMMO_PISTOL')
        local meta = item.MetaData or {}
        if _equipped then WEAPONS:Unequip(_equipped) end
        -- pre-register BEFORE the animation so the mismatch checker (200ms tick)
        -- doesn't disarm us between SetCurrentPedWeapon and the end of Equip
        client.ignoreweapons[hash] = true
        if LocalPlayer.state.onDuty == 'police' then
            _wAnims.Cop.Draw(ped, hash, ammoHash, meta.ammo or 0, meta.clip or 0, item, itemData)
        else
            _wAnims.Draw.OH(ped, hash, ammoHash, meta.ammo or 0, meta.clip or 0, item, itemData)
        end
        _equipped = item
        _equippedData = itemData
        TriggerEvent('Weapons:Client:SwitchedWeapon', item.Name, item, itemData)
        SetWeaponsNoAutoswap(true)
        _runWeaponThreads()
    end,

    Unequip = function(self, item, diff)
        if not item then return end
        local ped = PlayerPedId()
        local itemData = _weapItemDefs[item.Name]
        if not itemData then return end
        local hash = GetHashKey(itemData.weapon or item.Name)
        -- zero out ghost bullet before reading ammo so we don't save phantom round
        if _ghostBullet then
            SetAmmoInClip(ped, hash, 0)
            _ghostBullet = false
        end
        _updateAmmo(item, diff)
        if LocalPlayer.state.onDuty == 'police' then
            _wAnims.Cop.Holster(ped)
        else
            _wAnims.Holster.OH(ped)
        end
        SetPedAmmoByType(ped, GetHashKey(itemData.ammoType or 'AMMO_PISTOL'), 0)
        if item.MetaData and item.MetaData.WeaponComponents then
            for _, v in pairs(item.MetaData.WeaponComponents) do
                RemoveWeaponComponentFromPed(ped, hash, GetHashKey(v.attachment))
            end
        end
        -- stop ignoring this hash — weapon is holstered
        client.ignoreweapons[hash] = nil
        _equipped = nil
        _equippedData = nil
        TriggerEvent('Weapons:Client:SwitchedWeapon', false)
    end,

    UnequipIfEquipped = function(self)
        if _equipped then WEAPONS:Unequip(_equipped) end
    end,

    UnequipIfEquippedNoAnim = function(self)
        if not _equipped then return end
        local ped = PlayerPedId()
        local itemData = _weapItemDefs[_equipped.Name]
        if itemData then
            local hash = GetHashKey(itemData.weapon or _equipped.Name)
            if _ghostBullet then SetAmmoInClip(ped, hash, 0); _ghostBullet = false end
            _updateAmmo(_equipped)
            SetPedAmmoByType(ped, GetHashKey(itemData.ammoType or 'AMMO_PISTOL'), 0)
            client.ignoreweapons[hash] = nil
        end
        SetCurrentPedWeapon(ped, GetHashKey('WEAPON_UNARMED'), true)
        RemoveAllPedWeapons(ped)
        _equipped = nil
        _equippedData = nil
        TriggerEvent('Weapons:Client:SwitchedWeapon', false)
    end,

    Ammo = {
        Add = function(self, data)
            if not _equipped then return end
            local itemData = _weapItemDefs[_equipped.Name]
            if not itemData then return end
            local ped = PlayerPedId()
            local ammoHash = GetHashKey(itemData.ammoType or 'AMMO_PISTOL')
            local count = data.bulletCount or 10
            SetPedAmmoByType(ped, ammoHash, GetPedAmmoByType(ped, ammoHash) + count)
            _ghostBullet = false
        end,
    },
}

-- ammo box use (type 9): server fires this, client shows progress bar then confirms back
RegisterNetEvent('Inventory:Client:AmmoLoad', function(ammoData)
    local N = exports['mythic-base']:FetchComponent('Notification')
    if not _equipped then
        if N then N:Error('No Weapon Equipped') end
        return
    end
    local itemData = _weapItemDefs[_equipped.Name]
    if not itemData or itemData.ammoType ~= ammoData.ammoType then
        if N then N:Error('Wrong Ammo Type') end
        return
    end
    -- capture before bar — disarm during progress would clear _equipped
    local capturedEquipped = _equipped
    local capturedAmmoType = itemData.ammoType
    local Progress = exports['mythic-base']:FetchComponent('Progress')
    if Progress then
        local p = promise.new()
        Progress:Progress({
            duration  = 3000,
            label     = 'Loading Ammo',
            canCancel = true,
            disarm    = false,
        }, function(cancelled) p:resolve(not cancelled) end)
        if not Citizen.Await(p) then return end
    end
    local ped = PlayerPedId()
    local ammoHash = GetHashKey(capturedAmmoType)
    local count = ammoData.bulletCount or 10
    SetPedAmmoByType(ped, ammoHash, GetPedAmmoByType(ped, ammoHash) + count)
    _ghostBullet = false
    if capturedEquipped.MetaData then
        capturedEquipped.MetaData.ammo = (capturedEquipped.MetaData.ammo or 0) + count
    end
    TriggerServerEvent('Inventory:Server:AmmoLoaded', ammoData.itemName, ammoData.itemSlot, ammoData.itemMeta)
end)

_polyShopRestrictions = {
    ['armory:police'] = 'police',
    ['armory:doc'] = 'corrections'
}

_polyShopTypes = {
    [27] = 'armory:police',
    [37] = 'armory:doc',
}

local CraftingStub = {
    RegisterBench = function() end,
    CanCraft      = function() return false end,
}

local _spawnedBenchEntities = {}
local _pendingBenches       = nil
local _PedInteraction       = nil
local _Targeting            = nil
local _vendingSetup = false

local function setupVendingMachines()
    if _vendingSetup or not _Targeting then return end
    _vendingSetup = true
    local shops = lib.load('data.shops') or {}
    for key, shop in pairs(shops) do
        if shop.models and shop.icon and shop.text then
            local shopType = key:match('^shop:(.+)$')
            if shopType then
                for _, model in ipairs(shop.models) do
                    _Targeting:AddObject(model, shop.icon, {
                        {
                            text    = shop.text,
                            icon    = shop.icon,
                            event   = 'Shop:Client:OpenShop',
                            data    = shopType,
                            minDist = 3.0,
                        },
                    }, 3.0)
                end
            end
        end
    end
end

local function setupAllBenches()
    if not _pendingBenches or not _PedInteraction or not _Targeting then return end

    setupVendingMachines()

    for _, bench in ipairs(_pendingBenches) do
        -- register in client CraftingBenches so openInventory can find the bench data
        if bench.oxData then
            exports['ox_inventory']:RegisterCraftingBench(bench.id, bench.oxData)
        end

        local id        = bench.id
        local targeting = bench.targeting
        local location  = bench.location

        if not targeting or not location then goto continue end

        local coords, heading
        if type(location) == 'vector3' or type(location) == 'vector4' then
            coords  = vector3(location.x, location.y, location.z)
            heading = 0.0
        elseif type(location) == 'table' and location.x and location.y and location.z then
            coords  = vector3(location.x, location.y, location.z)
            heading = location.h or 0.0
        else
            goto continue
        end

        local menu = {
            {
                icon  = targeting.icon or 'fa-hammer',
                text  = bench.label or 'Craft',
                event = 'Crafting:Client:OpenCrafting',
                data  = { id = id },
            },
        }

        if targeting.ped then
            _PedInteraction:Add(
                id,
                GetHashKey(targeting.ped.model),
                coords,
                heading,
                25.0,
                menu,
                targeting.icon or 'fa-hammer',
                targeting.ped.task
            )
        elseif targeting.model then
            local obj = CreateObject(GetHashKey(targeting.model), coords.x, coords.y, coords.z, false, true, false)
            FreezeEntityPosition(obj, true)
            SetEntityHeading(obj, heading)
            _spawnedBenchEntities[id] = obj
            _Targeting:AddEntity(obj, targeting.icon or 'fa-hammer', menu)
        elseif targeting.poly then
            _Targeting.Zones:AddBox(
                id,
                targeting.icon or 'fa-hammer',
                targeting.poly.coords,
                targeting.poly.w or 2.0,
                targeting.poly.l or 2.0,
                targeting.poly.options,
                menu,
                2.0,
                true
            )
        end

        ::continue::
    end

    _Targeting.Zones:Refresh()
end

-- cache schematic bench oxData so we can build per-player locked states
local _schematicBenchOxData = nil

RegisterNetEvent('ox_inventory:bridge:SetupCraftingBenches', function(benches)
    _pendingBenches = benches
    -- capture schematic bench data for per-player unlock injection
    for _, bench in ipairs(benches) do
        if bench.id == 'crafting-schematics' and bench.oxData then
            _schematicBenchOxData = bench.oxData
            break
        end
    end
    CreateThread(function()
        Wait(2000)
        _PedInteraction = exports['mythic-base']:FetchComponent('PedInteraction')
        _Targeting      = exports['mythic-base']:FetchComponent('Targeting')
        setupAllBenches()
    end)
end)

AddEventHandler('Crafting:Client:OpenCrafting', function(ent, data)
    if data.id == 'crafting-schematics' and _schematicBenchOxData then
        -- apply per-player unlock states before opening
        local unlocked = LocalPlayer.state.unlockedSchematics or {}
        local modifiedItems = {}
        for i, item in ipairs(_schematicBenchOxData.items or {}) do
            local newItem = table.clone(item)
            newItem.metadata = table.clone(item.metadata or {})
            newItem.metadata.locked = not unlocked[newItem.metadata.schematic]
            modifiedItems[i] = newItem
        end
        local modifiedData = table.clone(_schematicBenchOxData)
        modifiedData.items = modifiedItems
        exports['ox_inventory']:RegisterCraftingBench('crafting-schematics', modifiedData)
    end
    exports['ox_inventory']:openInventory('crafting', { id = data.id, index = 1 })
end)


-- Register immediately at load time — other resources fetch these during their RegisterReady handlers
exports['mythic-base']:RegisterComponent('Weapons', WEAPONS)
exports['mythic-base']:RegisterComponent('Crafting', CraftingStub)

-- ============================================================
-- Inventory shim
-- ============================================================

-- every mythic resource gets Inventory via FetchComponent('Inventory') not a global
-- we build the client shim table and register it as the Inventory component
local ClientInventory = {
    -- mythic-targeting gates interactions behind these item checks
    Check = {
        Player = {
            HasItem = function(self, item, count)
                return (exports['ox_inventory']:Search('count', item) or 0) >= (count or 1)
            end,

            -- all items must be present
            HasItems = function(self, items)
                for _, v in ipairs(items) do
                    if (exports['ox_inventory']:Search('count', v.item or v.name) or 0) < (v.count or 1) then
                        return false
                    end
                end
                return true
            end,

            -- at least one item from the list
            HasAnyItems = function(self, items)
                for _, v in ipairs(items) do
                    if (exports['ox_inventory']:Search('count', v.item or v.name) or 0) >= (v.count or 1) then
                        return true
                    end
                end
                return false
            end,
        }
    },

    -- mythic-laptop calls this after ItemsLoaded fires to populate its item list
    Items = {
        GetData = function(self)
            return exports['ox_inventory']:Items() or {}
        end,

        GetCount = function(self, item)
            return exports['ox_inventory']:Search('count', item) or 0
        end,

        Has = function(self, item, count)
            return self:GetCount(item) >= (count or 1)
        end,

        -- mythic-ped calls this to check if the player has a cosmetic item equipped
        -- searches item definitions for staticMetadata matching ped appearance
        -- our items don't carry staticMetadata so we always return nil (safe — means "not catalogued item")
        GetWithStaticMetadata = function(self, masterKey, mainIdName, textureIdName, gender, data)
            return nil
        end,
    },

    Search = {
        Character = function(self, serverId)
            exports['ox_inventory']:openInventory('player', serverId)
        end,
    },

    -- mythic-phone calls Inventory.Close:All() before opening
    Close = {
        All = function(self)
            exports['ox_inventory']:closeInventory()
        end,
    },
    -- TODO rename functions when others updated otherwise errors
    Container = {
        Open = function(self, data)
            local Callbacks = exports['mythic-base']:FetchComponent('Callbacks')
            Callbacks:ServerCallback('Inventory:Server:Open', data, function(state)
                -- state is true on success; ox handles the actual UI open server-side
            end)
        end,
    },

    StaticTooltip = {
        Open = function(self, item)
            SendNUIMessage({ action = 'OPEN_STATIC_TOOLTIP', data = { item = item } })
        end,
        Close = function(self)
            SendNUIMessage({ action = 'CLOSE_STATIC_TOOLTIP', data = {} })
        end,
    },
}

-- register with mythic-base so every resource that calls FetchComponent('Inventory') gets our shim
AddEventHandler('Proxy:Shared:RegisterReady', function()
    exports['mythic-base']:RegisterComponent('Inventory', ClientInventory)

    local Callbacks = exports['mythic-base']:FetchComponent('Callbacks')
    local Progress = exports['mythic-base']:FetchComponent('Progress')

    if Callbacks and Progress then
        Callbacks:RegisterClientCallback('Inventory:ItemUse', function(data, cb)
            local Anims = exports['mythic-base']:FetchComponent('Animations')

            if data.anim and (not data.pbConfig or not data.pbConfig.animation) then
                if Anims and Anims.Emotes then
                    Anims.Emotes:Play(data.anim, false, data.time, true)
                end
            end

            if data.pbConfig then
                Progress:Progress({
                    name = data.pbConfig.name,
                    duration = data.time,
                    label = data.pbConfig.label,
                    useWhileDead = data.pbConfig.useWhileDead,
                    canCancel = data.pbConfig.canCancel,
                    vehicle = data.pbConfig.vehicle,
                    disarm = data.pbConfig.disarm,
                    ignoreModifier = data.pbConfig.ignoreModifier or true,
                    animation = data.pbConfig.animation or false,
                    controlDisables = {
                        disableMovement = data.pbConfig.disableMovement,
                        disableCarMovement = data.pbConfig.disableCarMovement,
                        disableMouse = data.pbConfig.disableMouse,
                        disableCombat = data.pbConfig.disableCombat,
                    },
                }, function(cancelled)
                    pcall(function()
                        if Anims and Anims.Emotes then Anims.Emotes:ForceCancel() end
                    end)
                    cb(not cancelled)
                end)
            else
                cb(true)
            end
        end)
        Callbacks:RegisterClientCallback('Inventory:Compartment:Open', function(data, cb)
            exports['ox_inventory']:closeInventory()
            cb(true)
        end)
    end
end)

-- force close when logging out, save weapon ammo
RegisterNetEvent('Characters:Client:Logout')
AddEventHandler('Characters:Client:Logout', function()
    exports['ox_inventory']:closeInventory()
    if _equipped then WEAPONS:UnequipIfEquippedNoAnim() end
    _weapLoggedIn = false
end)

-- enable everything on spawn
RegisterNetEvent('Characters:Client:Spawned')
AddEventHandler('Characters:Client:Spawned', function()
    _weapLoggedIn = true
    LocalPlayer.state:set('invBusy', false, true)
    LocalPlayer.state:set('invHotKeys', true, false)
    LocalPlayer.state:set('canUseWeapons', true, false)
    TriggerEvent('Inventory:Client:ItemsLoaded')
end)

-- disable weapons on death, save ammo state
AddEventHandler('Ped:Client:Died', function()
    exports['ox_inventory']:closeInventory()
    LocalPlayer.state:set('canUseWeapons', false, false)
    if _equipped then WEAPONS:UnequipIfEquippedNoAnim() end
end)

-- old mythic open request, just pass it through
RegisterNetEvent('Inventory:Client:Open', function(data)
    exports['ox_inventory']:openInventory('player', data)
end)

-- secondary inventory opens, this one was a pain in the ass to figure out
RegisterNetEvent('Inventory:Client:Load', function(data)
    -- trunk/glovebox (invtype 4/5) handled server-side via forceOpenInventory
    if data.invType == 10 then
        exports['ox_inventory']:openInventory('drop', { id = data.owner })
    elseif data.invType == 11 then
        exports['ox_inventory']:openInventory('shop', { type = data.owner })
    else
        -- everything else (13, 25, 44, 45, 81, etc.) is a registered stash
        exports['ox_inventory']:openInventory('stash', { id = data.owner })
    end
end)

-- server said close it
RegisterNetEvent('Inventory:CloseUI', function()
    exports['ox_inventory']:closeInventory()
end)

-- item added/removed notifications
RegisterNetEvent('Inventory:Client:Changed', function(data)
    if data.added then
        exports['ox_inventory']:notify({
            id          = 'item_added',
            title       = data.label,
            description = 'x' .. data.count,
            icon        = 'circle-plus',
            iconColor   = '#4CAF50',
            duration    = 3000,
        })
    else
        exports['ox_inventory']:notify({
            id          = 'item_removed',
            title       = data.label,
            description = 'x' .. data.count,
            icon        = 'circle-minus',
            iconColor   = '#F44336',
            duration    = 3000,
        })
    end
end)

-- weapon equip/unequip toggle from server
RegisterNetEvent('Weapons:Client:Use', function(data)
    if not data then return end
    if _equipped and _equipped.Slot == data.Slot then
        WEAPONS:Unequip(data)
    else
        WEAPONS:Equip(data)
    end
end)

-- force unequip (arrest, disarm, admin, etc.)
RegisterNetEvent('Weapons:Client:ForceUnequip', function()
    if _equipped then WEAPONS:UnequipIfEquippedNoAnim() end
    TriggerEvent('ox_inventory:disarm', true)
end)

-- server updated ammo count in our slot (e.g. after confiscation)
RegisterNetEvent('Weapons:Client:UpdateCount', function(slot, count)
    if _equipped and _equipped.Slot == slot then
        local itemData = _weapItemDefs[_equipped.Name]
        if itemData then SetPedAmmoByType(PlayerPedId(), GetHashKey(itemData.ammoType or 'AMMO_PISTOL'), count) end
    end
end)

RegisterNetEvent('Weapons:Client:UpdateAttachments', function(components)
    if not _equipped then return end
    local itemData = _weapItemDefs[_equipped.Name]
    local hash = GetHashKey(itemData and itemData.weapon or _equipped.Name)
    local ped = PlayerPedId()
    for k, v in pairs(_equipped.MetaData and _equipped.MetaData.WeaponComponents or {}) do
        if not components[k] then RemoveWeaponComponentFromPed(ped, hash, GetHashKey(v.attachment)) end
    end
    for k, v in pairs(components) do
        GiveWeaponComponentToPed(ped, hash, GetHashKey(v.attachment))
    end
    if _equipped.MetaData then _equipped.MetaData.WeaponComponents = components end
end)

-- bullet loading: server found compatible weapons, show weapon picker + count input
RegisterNetEvent('Inventory:Client:LoadBullets', function(data)
    local function loadInto(weapon)
        local input = lib.inputDialog(('Load into %s'):format(weapon.label), {
            {
                type    = 'number',
                label   = ('Bullets to load (have %d)'):format(data.haveCount),
                default = data.haveCount,
                min     = 1,
                max     = data.haveCount,
            }
        })
        if not input or not input[1] then return end
        local count = math.floor(tonumber(input[1]) or 0)
        if count < 1 then return end
        local Progress = exports['mythic-base']:FetchComponent('Progress')
        if Progress then
            local p = promise.new()
            Progress:Progress({
                duration  = 3000,
                label     = 'Loading Ammo',
                canCancel = true,
                disarm    = false,
            }, function(cancelled) p:resolve(not cancelled) end)
            if not Citizen.Await(p) then return end
        end
        TriggerServerEvent('Inventory:Server:LoadBullets', weapon.slot, data.itemName, count)
    end

    if #data.weapons == 1 then
        loadInto(data.weapons[1])
    else
        local options = {}
        for _, w in ipairs(data.weapons) do
            local weapon = w
            options[#options + 1] = {
                title       = ('Slot %d — %s'):format(weapon.slot, weapon.label),
                description = ('Reserve: %d bullets'):format(weapon.currentAmmo),
                onSelect    = function() loadInto(weapon) end,
            }
        end
        lib.registerContext({ id = 'bullet_load_pick', title = 'Load Bullets — Pick Weapon', options = options })
        lib.showContext('bullet_load_pick')
    end
end)

-- server confirmed load — add bullets to ped if this weapon is equipped
RegisterNetEvent('Inventory:Client:BulletsLoaded', function(weaponSlot, count)
    if not _equipped or _equipped.Slot ~= weaponSlot then return end
    local itemData = _equippedData
    if not itemData then return end
    local ped = PlayerPedId()
    local ammoHash = GetHashKey(itemData.ammoType or 'AMMO_PISTOL')
    SetPedAmmoByType(ped, ammoHash, GetPedAmmoByType(ped, ammoHash) + count)
    _ghostBullet = false
    _equipped.MetaData.ammo = (_equipped.MetaData.ammo or 0) + count
end)

-- prevents using items while already mid-use
RegisterNetEvent('Inventory:Client:InUse', function(state)
    LocalPlayer.state:set('invBusy', state, true)
end)

-- lock inventory and disarm when cuffed
AddStateBagChangeHandler('isCuffed', ('player:%s'):format(cache.serverId), function(_, _, value)
    LocalPlayer.state:set('invBusy', value or false, false)
    if value then
        exports['ox_inventory']:closeInventory()
        if _equipped then WEAPONS:UnequipIfEquippedNoAnim() end
        TriggerEvent('ox_inventory:disarm', true)
    end
end)

-- same thing on death
AddStateBagChangeHandler('isDead', ('player:%s'):format(cache.serverId), function(_, _, value)
    LocalPlayer.state:set('invBusy', value or false, false)
    if value then
        exports['ox_inventory']:closeInventory()
        if _equipped then WEAPONS:UnequipIfEquippedNoAnim() end
        TriggerEvent('ox_inventory:disarm', true)
    end
end)

AddStateBagChangeHandler('doingAction', ('player:%s'):format(cache.serverId), function(_, _, value)
    LocalPlayer.state:set('invBusy', value or false, false)
end)

local ClientItems = require 'modules.items.shared'
local allItems = lib.load('data.mythic-items.index')

if allItems then
    local count = 0
    for _, item in ipairs(allItems) do
        if item.name then
            -- normalize key same as server: weapons stay uppercase, everything else lowercase
            local storeKey = (item.name:sub(1, 7):lower() == 'weapon_') and item.name or item.name:lower()
            -- type 2 (weapons) and type 9 (ammo) must always overwrite ox's data/weapons.lua entries
            -- ox sets weapon=true/ammo=true on those which hijacks useSlot into native paths
            local forceOverwrite = item.type == 2 or item.type == 9
            if forceOverwrite or not ClientItems[storeKey] then
                local entry = {
                    name = storeKey,  -- must match slot.name so Items[slot.name] resolves
                    label = item.label or item.name,
                    description = item.description or nil,
                    weight = item.weight or 0,
                    stack = item.isStackable ~= false and (item.isStackable or true),
                    close = item.closeUi or true,
                    count = 0,
                }
                -- type 9 ammo: export path bypasses the currentWeapon gate in useSlot
                if item.type == 9 then
                    entry.client = {}
                    entry.export = function(itemData, slotData)
                        TriggerServerEvent('ox_inventory:bridge:useAmmo', slotData.slot, slotData.name, slotData.metadata)
                    end
                end
                ClientItems[storeKey] = entry
                count = count + 1
            end
        end
    end
    print(string.format('^2[mythic-ox-bridge] registered %d items client-side^0', count))
end

local mythicItemCache = {}

AddEventHandler('ox_inventory:updateInventory', function()
    mythicItemCache = {}
    local idx = 0
    for slot, slotData in pairs (PlayerData.inventory or {}) do
        if slotData and slotData.name then
            idx = idx + 1
            mythicItemCache[idx] = {
                Name = slotData.name,
                Label = slotData.label or slotData.name,
                Slot = slot,
                Count = slotData.count or 0,
                Quality = (slotData.metadata or {}).quality or 100,
                MetaData = slotData.metadata or {},
                Owner = tostring(cache.serverId),
                invType = 1,
            }
        end
    end
    TriggerEvent('Inventory:Client:Cache', mythicItemCache)
end)

-- swap has item checks to use local cache (avoid server roundtrip per frame)
ClientInventory.Check.Player.HasItem = function(self, item, count)
    if next(mythicItemCache) then
        local total = 0
        for _, slot in pairs(mythicItemCache) do
            if slot.Name == item then total = total + (slot.Count or 0) end
        end
        return total >= (count or 1)
    end
    return (exports['ox_inventory']:Search('count', item) or 0) >= (count or 1)
end

ClientInventory.Check.Player.HasItems = function(self, items)
    for _,v in ipairs(items) do
        local name = v.item or v.name
        local needed = v.count or 1
        local total = 0
        for _, slot in pairs(mythicItemCache) do
            if slot.Name == name then total = total + (slot.Count or 0) end
        end
        if total < needed then return false end
    end
    return true
end

ClientInventory.Check.Player.HasAnyItems = function(self, items)
    for _, v in ipairs(items) do
        local name = v.item or v.name
        local needed = v.count or 1
        local total = 0
        for _, slot in pairs(mythicItemCache) do
            if slot.Name == name then total = total + (slot.Count or 0) end
        end
        if total >= needed then return true end
    end
    return false
end

ClientInventory.Items.GetCount = function(self, item)
    local total = 0
    for _, slot in pairs(mythicItemCache) do
        if slot.Name == item then total = total + (slot.Count or 0) end
    end
    return total
end

ClientInventory.Items.Has = function(self, item, count)
    return ClientInventory.Items:GetCount(item) >= (count or 1)
end

ClientInventory.Shop = {
    Open = function(self, shopId)
       TriggerServerEvent('ox_inventory:bridge:openShop', shopId) 
    end,
}

AddEventHandler('Inventory:Client:Trunk', function(entity)
    TriggerServerEvent('ox_inventory:bridge:openTrunk', NetworkGetNetworkIdFromEntity(entity.entity))    
end)

AddEventHandler('Characters:Client:Spawn', function()
    TriggerServerEvent('ox_inventory:bridge:getShops')
end)

RegisterNetEvent('ox_inventory:bridge:receiveShops', function(shops)
    local PedInteraction = exports['mythic-base']:FetchComponent('PedInteraction')
    local Blips = exports['mythic-base']:FetchComponent('Blips')
    if not shops or not PedInteraction then return end
    for _, v in ipairs(shops) do
        PedInteraction:Add(
            'shop-' .. v.id,
            GetHashKey(v.npc),
            vector3(v.coords.x, v.coords.y, v.coords.z),
            v.coords.h,
            25.0,
            {{
                icon = 'sack-dollar',
                text = v.name or 'Shop',
                event = 'Shop:Client:OpenShop',
                data = { shopType = v.shopType, locId = v.locId },
            }},
            'shop'
        )
        if v.blip and Blips then
            Blips:Add(
                'inventory_shop_' .. v.id,
                v.name, 
                vector3(v.coords.x, v.coords.y, v.coords.z),
                v.blip.id,
                v.blip.colour,
                v.blip.scale
            )
        end
    end
end)

AddEventHandler('Shop:Client:OpenShop', function(obj, data)
    if type(data) == 'string' then
        -- vending machines / direct shop type strings (e.g. "vending-coffee")
        exports['ox_inventory']:openInventory('shop', { type = 'shop:' .. data })
    else
        -- NPC shops with shopType + locId table
        exports['ox_inventory']:openInventory('shop', { type = data.shopType, id = data.locId })
    end
end)

_inInvPoly = nil

RegisterNetEvent('Inventory:Client:PolySetup', function(locs)
    local Polyzone = exports['mythic-base']:FetchComponent('Polyzone')
    if not Polyzone or not locs then return end
    for _, id in ipairs(locs) do
        local data = GlobalState[('Inventory:%s'):format(id)]
        if data then
            if data.data then
                data.data.isInventory = true
                data.data.name = data.name
            end
            if data.type == 'box' then
                Polyzone.Create:Box(data.id, data.coords, data.length, data.width, data.options, data.data)
            elseif data.type == 'poly' then
                Polyzone.Create:Poly(data.id, data.points, data.options, data.data)
            else
                Polyzone.Create:Circle(data.id, data.coords, data.radius, data.options, data.data)
            end
        end
    end
end)

AddEventHandler('Polyzone:Enter', function(id, testedPoint, insideZones, data)
    if not data or not data.isInventory then return end
    local Action = exports['mythic-base']:FetchComponent('Action')
    if Action then Action:Show('Open '.. (data.name or 'Storage')) end
    _inInvPoly = data
    LocalPlayer.state:set('_inInvPoly', data, false)
end)

AddEventHandler('Polyzone:Exit', function(id, testedPoint, insideZones, data)
    if not data or not data.isInventory then return end
    local Action = exports['mythic-base']:FetchComponent('Action')
    if Action then Action:Hide() end
    if LocalPlayer.state.inventoryOpen then
        client.closeInventory()
    end
    _inInvPoly = nil
    LocalPlayer.state:set('_inInvPoly', nil, false)
end)
