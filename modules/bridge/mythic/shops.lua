-- mythic ox bridge: shops 
-- reads from local data file 

local data = lib.load('data.mythic-shops')
if not data then
    print('^1[mythic-ox-bridge] shops: couldnt load data/mythic-shops.lua^0')
    return
end

local EntityItemSets = data.EntityItemSets
local ShopItemSets = data.ShopItemSets
local Shops = data.Shops

local itemPrices = {}
for _, item in ipairs(lib.load('data.mythic-items.index') or {}) do
    if item.name and item.price then
        itemPrices[item.name] = item.price
    end
end

local registered = 0
local skipped = 0

for _, shop in ipairs(Shops) do
    local itemSet = EntityItemSets[shop.entityId]

    if not itemSet then
        skipped = skipped + 1
        goto continue
    end

    local itemNames = ShopItemSets[itemSet]
    if not itemNames or #itemNames == 0 then
        print('^3[mythic-ox-bridge] shops: no item for itemSet: ' .. tostring(itemSet) .. ' (shop ' .. tostring(shop.name) .. '), skipping ^0')
        skipped = skipped + 1
        goto continue
    end

    do
        local oxItems = {}
        for _, itemName in ipairs(itemNames) do
            table.insert(oxItems, {
                name = itemName,
                price = itemPrices[itemName] or 0,
                currency = 'money',
            })
        end
        local shopId = shop.id or shop.shopId
        exports['ox_inventory']:RegisterShop(('shop:%s'):format(shopId), {
            name = shop.name or 'Shop',
            inventory = oxItems,
        })
        registered = registered + 1
    end
    ::continue::
end

print(string.format('^2[mythic-ox-bridge] registered %d shops (%d skipped) :)^0', registered, skipped))