local EntityItemSets = {
      [6]    = 18, -- Liquor Store
      [7]    = 2,  -- Hardware Store
      [11]   = 1,  -- General Store (24/7 / LTD)
      [12]   = 4,  -- Ammunation
      [26]   = 7,  -- Medical Supply (EMS, free)
      [27]   = 6,  -- PD Armory (police, free)
      [28]   = 8,  -- Hunting Supplies
      [37]   = 9,  -- DOC Armory (prison, free)
      [38]   = 10, -- Water Vending
      [39]   = 11, -- Coffee Vending
      [40]   = 12, -- Drinks Vending
      [41]   = 13, -- Food Vending
      [42]   = 14, -- Pharmacy
      [43]   = 15, -- Fuel Pump
      [61]   = 16, -- Food Wholesaler
      [62]   = 17, -- Smoke on the Water
      [74]   = 5,  -- Digital Den (Electronics)
      [76]   = 19, -- Winery
      [99]   = 20, -- Fishing Supplies
      [112]  = 21, -- Advanced Fishing Supplies
      [115]  = 22, -- DOJ Shop
      [5005] = 23, -- Hospital Café
}

-- itemSet --> item names
local ShopItemSets = {
      [1] = { -- General Store
          "sandwich", "sandwich_egg", "water", "bandage", "cigarette_pack",
          "coffee", "soda", "energy_pepe", "chocolate_bar", "donut", "crisp", "rolling_paper",
      },
      [2] = { -- Hardware Store
          "screwdriver", "WEAPON_HAMMER", "WEAPON_CROWBAR", "WEAPON_GOLFCLUB",
          "repairkit", "fertilizer_nitrogen", "fertilizer_phosphorus", "fertilizer_potassium",
          "camping_chair", "beanbag", "plastic_wrap", "baggy", "binoculars",
          "WEAPON_SHOVEL", "cloth", "pipe", "nails", "drill",
      },
      [3] = { "cup", "bun", "patty", "pickle" },
      [4] = { "armor", "heavyarmor", "WEAPON_PISTOL", "WEAPON_FNX", "AMMO_PISTOL", "WEAPON_BAT" },
      [5] = { "phone", "radio_shitty", "camera", "electronics_kit" },
      [6] = { -- Police Armory
          "pdarmor", "ifak", "pdhandcuffs", "spikes", "WEAPON_FLASHLIGHT", "WEAPON_TASER",
          "WEAPON_BEANBAG", "WEAPON_G17", "WEAPON_HKUMP", "WEAPON_HK416B",
          "AMMO_PISTOL_PD", "AMMO_SHOTGUN_PD", "AMMO_SMG_PD", "AMMO_RIFLE_PD", "AMMO_STUNGUN",
          "radio", "binoculars", "camera", "phone", "WEAPON_FLASHBANG", "WEAPON_SMOKEGRENADE",
      },
      [7] = { "traumakit", "medicalkit", "firstaid", "bandage", "morphine", "radio", "phone", "scuba_gear"
  },
      [8] = { "WEAPON_SNIPERRIFLE2", "AMMO_SNIPER", "WEAPON_KNIFE", "hunting_bait" },
      [9] = {
          "pdarmor", "traumakit", "ifak", "pdhandcuffs",
          "WEAPON_TASER", "WEAPON_G17",
          "AMMO_PISTOL_PD", "AMMO_RIFLE_PD", "AMMO_SHOTGUN_PD", "AMMO_STUNGUN",
          "radio", "phone",
      },
      [10] = { "water" },
      [11] = { "coffee" },
      [12] = { "water", "soda", "energy_pepe" },
      [13] = { "chocolate_bar", "donut", "crisp" },
      [14] = { "firstaid", "bandage", "water", "sandwich_blt" },
      [15] = { "WEAPON_PETROLCAN" },
      [16] = {
          "dough", "eggs", "loaf", "sugar", "flour", "rice", "icing", "milk_can",
          "tea_leaf", "plastic_cup", "coffee_beans", "coffee_holder", "foodbag",
          "cardboard_box", "paper_bag", "burgershot_bag", "burgershot_cup", "bun",
          "water", "cheese", "jaeger", "raspberry_liqueur", "sparkling_wine", "rum",
          "whiskey", "tequila", "pineapple", "raspberry", "peach_juice", "coconut_milk",
          "bento_box", "keg",
      },
      [17] = { "weed_joint", "rolling_paper" },
      [18] = {
          "vodka", "beer", "water", "bandage", "cigarette_pack", "coffee",
          "soda", "energy_pepe", "chocolate_bar", "donut", "crisp", "rolling_paper",
      },
      [19] = { "wine_bottle" },
      [20] = { "fishing_rod", "fishing_bait_worm", "fishing_bait_lugworm", "WEAPON_KNIFE" },
      [21] = { "fishing_rod", "fishing_net", "fishing_bait_worm", "fishing_bait_lugworm", "WEAPON_KNIFE" },
      [22] = { "personal_plates" },
      [23] = { "firstaid", "bandage", "water", "sandwich_blt", "coffee" },
}

local Shops = {
    { shopId = 1,  name = 'General Store',            entityId = 11 },
    { shopId = 2,  name = 'General Store',            entityId = 11 },
    { shopId = 3,  name = 'General Store',            entityId = 11 },
    { shopId = 4,  name = 'General Store',            entityId = 11 },
    { shopId = 5,  name = 'General Store',            entityId = 11 },
    { shopId = 6,  name = 'General Store',            entityId = 11 },
    { shopId = 7,  name = 'General Store',            entityId = 11 },
    { shopId = 8,  name = 'General Store',            entityId = 11 },
    { shopId = 9,  name = 'General Store',            entityId = 11 },
    { shopId = 10, name = 'General Store',            entityId = 11 },
    { shopId = 11, name = 'General Store',            entityId = 11 },
    { shopId = 12, name = 'General Store',            entityId = 11 },
    { shopId = 13, name = 'General Store',            entityId = 11 },
    { shopId = 14, name = 'General Store',            entityId = 11 },
    { shopId = 15, name = 'General Store',            entityId = 11 },
    { shopId = 16, name = 'General Store',            entityId = 11 },
    { shopId = 17, name = 'Hospital Café',            entityId = 5005 },
    { shopId = 19, name = 'Liquor Store',             entityId = 6 },
    { shopId = 20, name = 'Liquor Store',             entityId = 6 },
    { shopId = 21, name = 'Liquor Store',             entityId = 6 },
    { shopId = 22, name = 'Liquor Store',             entityId = 6 },
    { shopId = 23, name = 'Ammunation',               entityId = 12 },
    { shopId = 24, name = 'Ammunation',               entityId = 12 },
    { shopId = 25, name = 'Ammunation',               entityId = 12 },
    { shopId = 26, name = 'Ammunation',               entityId = 12 },
    { shopId = 27, name = 'Ammunation',               entityId = 12 },
    { shopId = 28, name = 'Ammunation',               entityId = 12 },
    { shopId = 29, name = 'Ammunation',               entityId = 12 },
    { shopId = 30, name = 'Ammunation',               entityId = 12 },
    { shopId = 31, name = 'Ammunation',               entityId = 12 },
    { shopId = 32, name = 'Ammunation',               entityId = 12 },
    { shopId = 33, name = 'Ammunation',               entityId = 12 },
    { shopId = 34, name = 'Hardware Store',           entityId = 7 },
    { shopId = 35, name = 'Hardware Store',           entityId = 7 },
    { shopId = 36, name = 'Medical Supplies',         entityId = 26 },
    { shopId = 37, name = 'Medical Supplies',         entityId = 26 },
    { shopId = 38, name = 'Pharmacy',                 entityId = 42 },
    { shopId = 39, id = 'hunting-supplies',           name = 'Hunting Supplies',          entityId = 28 },
    { shopId = 40, id = 'fishing-supplies',           name = 'Fishing Supplies',          entityId = 99 },
    { shopId = 41, id = 'fishing-supplies-advanced',  name = 'Advanced Fishing Supplies', entityId = 112 },
    { shopId = 42, id = 'doj-shop',                   name = 'DOJ Shop',                  entityId = 115 },
    { shopId = 43, id = 'vending-water',              name = 'Water Machine',             entityId = 38 },
    { shopId = 44, id = 'vending-coffee',             name = 'Coffee Machine',            entityId = 39 },
    { shopId = 45, id = 'vending-drinks',             name = 'Drinks Vending Machine',    entityId = 40 },
    { shopId = 46, id = 'vending-food',               name = 'Food Vending Machine',      entityId = 41 },
    { shopId = 47, id = 'fuel-pump',                  name = 'Fuel Pump',                 entityId = 43 },
    { shopId = 48, name = 'Food Wholesaler',          entityId = 61 },
    { shopId = 49, name = 'Smoke on the Water',       entityId = 62 },
    { shopId = 50, name = 'Digital Den',              entityId = 74 },
    { shopId = 51, name = 'Winery',                   entityId = 76 },
}

return {
    EntityItemSets = EntityItemSets,
    ShopItemSets = ShopItemSets,
    Shops = Shops,
}

