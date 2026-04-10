-- Individual bullet items — given back when unloading a weapon
-- Right-click to pack them back into a full ammo box once you have enough
return {
    {
        name       = 'bullet_pistol',
        label      = 'Pistol Bullet',
        weight     = 0.025,
        isStackable = true,
        type       = 1,
        rarity     = 1,
        -- pack: 30 bullets → 1x ammo_pistol
        packInto   = 'ammo_pistol',
        packCount  = 30,
    },
    {
        name       = 'bullet_smg',
        label      = 'SMG Bullet',
        weight     = 0.015,
        isStackable = true,
        type       = 1,
        rarity     = 1,
        -- pack: 60 bullets → 1x ammo_smg
        packInto   = 'ammo_smg',
        packCount  = 60,
    },
    {
        name       = 'bullet_rifle',
        label      = 'Rifle Bullet',
        weight     = 0.017,
        isStackable = true,
        type       = 1,
        rarity     = 1,
        -- pack: 60 bullets → 1x ammo_rifle
        packInto   = 'ammo_rifle',
        packCount  = 60,
    },
    {
        name       = 'bullet_shotgun',
        label      = 'Shotgun Shell',
        weight     = 0.04,
        isStackable = true,
        type       = 1,
        rarity     = 1,
        -- pack: 12 shells → 1x ammo_shotgun
        packInto   = 'ammo_shotgun',
        packCount  = 12,
    },
    {
        name       = 'bullet_sniper',
        label      = 'Sniper Round',
        weight     = 0.1,
        isStackable = true,
        type       = 1,
        rarity     = 1,
        -- pack: 10 rounds → 1x ammo_sniper
        packInto   = 'ammo_sniper',
        packCount  = 10,
    },
    {
        name       = 'bullet_stungun',
        label      = 'Taser Cartridge',
        weight     = 0.04,
        isStackable = true,
        type       = 1,
        rarity     = 1,
        -- pack: 12 cartridges → 1x ammo_stungun
        packInto   = 'ammo_stungun',
        packCount  = 12,
    },
}
