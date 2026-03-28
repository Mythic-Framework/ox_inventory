-- mythic ox bridge : shops
-- reads mythic-inventory shop config and registers everything with ox

-- build a flat name->price lookup from all items
-- lib.load caches so this is free since items.lua already loaded the index
local itemPrices = {}
for _, item in ipairs(lib.load('data.mythic-items.index') or {}) do
    if item.name and item.price then
        itemPrices[item.name] = item.price
    end
end

-- load mythic-inventory config to get ShopItemSets
-- Config and _entityTypes/_shops globals come from executing these files
local configContent = LoadResourceFile('mythic-inventory', 'config.lua')
if not configContent then
    print('^1[mythic-ox-bridge] shops: couldnt load mythic-inventory config.lua, shops wont work^0')
    return
end

local fn, err = load(configContent)
if not fn then
    print('^1[mythic-ox-bridge] shops: failed to compile mythic config.lua: ' .. tostring(err) .. '^0')
    return
end
fn()

-- load entity types so we know which entityId maps to which itemSet
local entityContent = LoadResourceFile('mythic-inventory', 'server/data/entitys.lua')
if not entityContent then
    print('^1[mythic-ox-bridge] shops: couldnt load entitys.lua^0')
    return
end
local fn2, err2 = load(entityContent)
if fn2 then fn2() end

-- build entityId -> itemSet lookup from the loaded _entityTypes table
local entityIdToItemSet = {}
if _entityTypes then
    for _, ent in ipairs(_entityTypes) do
        if ent.shop and ent.itemSet then
            entityIdToItemSet[ent.id] = ent.itemSet
        end
    end
end

-- load the shops list (all 51 locations)
local shopsContent = LoadResourceFile('mythic-inventory', 'server/data/shops.lua')
if not shopsContent then
    print('^1[mythic-ox-bridge] shops: couldnt load shops.lua^0')
    return
end
local fn3, err3 = load(shopsContent)
if fn3 then fn3() end

-- sanity check that we actually got the data we need
if not _shops or not Config or not Config.ShopItemSets then
    print('^1[mythic-ox-bridge] shops: missing shop data after loading configs, bailing out^0')
    return
end

-- register every shop with ox
-- shop identifier matches what OpenSecondary sends: shop:1, shop:2, shop:hunting-supplies etc
local registered = 0
local skipped    = 0

for k, shop in ipairs(_shops) do
    local itemSet = entityIdToItemSet[shop.entityId]

    if not itemSet then
        -- this entityId isnt a shop type (its a stash/trunk/etc), skip it
        skipped = skipped + 1
        goto continue
    end

    local itemNames = Config.ShopItemSets[itemSet]
    if not itemNames or #itemNames == 0 then
        print('^3[mythic-ox-bridge] shops: no items for itemSet ' .. tostring(itemSet) .. ' (shop ' .. tostring(shop.name) .. '), skipping^0')
        skipped = skipped + 1
        goto continue
    end

    do
        local oxItems = {}
        for _, itemName in ipairs(itemNames) do
            table.insert(oxItems, {
                name     = itemName,
                price    = itemPrices[itemName] or 0,
                currency = 'money',
            })
        end

        -- id field takes priority over loop index, matches mythic startup.lua behavior
        local shopId = shop.id or k
        -- ox RegisterShop expects { name, inventory } not just the item array
        exports['ox_inventory']:RegisterShop(('shop:%s'):format(shopId), {
            name      = shop.name or 'Shop',
            inventory = oxItems,
        })
        registered = registered + 1
    end

    ::continue::
end

print(string.format('^2[mythic-ox-bridge] registered %d shops (%d skipped, no itemSet) :)^0', registered, skipped))
