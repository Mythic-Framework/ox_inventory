-- mythic ox bridge : item converter
-- loads all mythic items via the index aggregator and registers them with ox

local function ConvertItem(item)
    if not item.name then return nil end

    local converted = {
        label       = item.label,
        description = item.description or nil,
        weight      = item.weight or 0,
        stack       = item.isStackable ~= false and (item.isStackable or true),
        close       = item.closeUi or false,
        decay       = item.isDestroyed or false,
        degrade     = item.durability and math.floor(item.durability / 60) or nil,
        client      = {},
        server      = {
            mythicType   = item.type,
            mythicRarity = item.rarity,
            state        = item.state,
            isRemoved    = item.isRemoved or false,
        },
    }

    if item.type == 2 and item.weapon then
        converted.weapon = true
        converted.model  = item.weapon
    end

    if item.type == 9 then
        converted.ammo  = true
        converted.stack = true
    end

    if item.type == 10 and item.container then
        converted.client.container = item.container
    end

    return converted
end

local Items    = require 'modules.items.server'
local allItems = lib.load('data.mythic-items.index')

if not allItems then
    print('^1[mythic-ox-bridge] failed to load item index, no items registered^0')
    return
end

local count = 0
for _, item in ipairs(allItems) do
    local converted = ConvertItem(item)
    if converted then
        Items.new(item.name, converted)
        count = count + 1
    end
end

print(string.format('^2[mythic-ox-bridge] loaded %d items :)^0', count))
