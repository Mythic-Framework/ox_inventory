-- aggregator for all mythic item files
-- returns a flat array of every item across all categories
-- add new item files here when you add them, thats it

local files = {
    'data.mythic-items.misc',
    'data.mythic-items.medical',
    'data.mythic-items.drugs',
    'data.mythic-items.tools',
    'data.mythic-items.labor',
    'data.mythic-items.crafting',
    'data.mythic-items.fishing',
    'data.mythic-items.containers',
    'data.mythic-items.evidence',
    'data.mythic-items.unique',
    'data.mythic-items.loot',
    'data.mythic-items.robbery',
    'data.mythic-items.vehicles',
    'data.mythic-items.dangerous',
    'data.mythic-items.food.food',
    'data.mythic-items.food.alcohol',
    'data.mythic-items.food.bakery',
    'data.mythic-items.food.beanmachine',
    'data.mythic-items.food.burgershot',
    'data.mythic-items.food.ingredients',
    'data.mythic-items.food.noodles',
    'data.mythic-items.food.pizza_this',
    'data.mythic-items.food.prego',
    'data.mythic-items.food.prison',
    'data.mythic-items.food.sandwich',
    'data.mythic-items.food.train',
    'data.mythic-items.food.uwu',
    'data.mythic-items.weapons.base',
    'data.mythic-items.weapons.ammo',
    'data.mythic-items.weapons.attachments',
    'data.mythic-items.weapons.bobcat',
    'data.mythic-items.schematics.base',
    'data.mythic-items.schematics.attachments',
    'data.mythic-items.schematics.weapons',
}

local all = {}
for _, path in ipairs(files) do
    local items = lib.load(path)
    if items then
        for i = 1, #items do
            all[#all + 1] = items[i]
        end
    else
        print('^3[mythic-items] file not found: ' .. path .. '^0')
    end
end

return all
