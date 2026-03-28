-- Mythic ox bridge : Database migration - lord help me ..............
-- runs once to migrate mythic inventory code

RegisterCommand('migrateinventory', function (source)
    -- server console only
    if source ~= 0 then
        print('^1[mythic-inv-migration] This command can only be run from the server console^0')
        return
    end

    print('^3[mythic-inv-migration] Checking database state....^0')

    -- check if migration was ran or some shit
    local existing = MySQL.scalar.await('SELECT COUNT(*) FROM ox_inventory')
    if existing and existing > 0 then
        print('^1[mythic-inv-migration] ox_inventory already has data, skipping migration^0')
        print('^1[mythic-inv-migration] If you want to force a re-migration, manually clear ox_inventory first^0')
        return
    end

    local mythicCount = MySQL.scalar.await('SELECT COUNT(*) FROM inventory')
    if not mythicCount or mythicCount == 0 then
        print('^3[mythic-inv-migration] No mythic inventory data found, nothing to migrate^0')
        return
    end

    print('^3[mythic-inv-migration] Found ' .. mythicCount .. ' rows to migrate. Starting....^0')
    print('^1[mythic-inv-migration] DO NOT RESTART THE SERVER UNTIL COMPLETE^0')

    -- Fetch all unique inv names from mythic
    local inventories = MySQL.query.await('SELECT DISTINCT name FROM inventory WHERE dropped = 0')

    if not inventories or #inventories == 0 then
        print('^3[mythic-inv-migration] No inventories found^0')
        return
    end

    print('^3[mythic-inv-migration] Found ' .. #inventories .. ' inventories to process...^0')

    local successCount = 0
    local failCount    = 0
    local skipCount    = 0

    for _, inv in ipairs(inventories) do
        local invName = inv.name

        -- parse owner sid and inventory type from mythic name format "SID-invType"
        local sid, invType = invName:match('^(.+)-(%d+)$')
        invType = tonumber(invType)

        if not sid or not invType then
            print('^1[mythic-inv-migration] Could not parse inventory name: ' .. invName .. ', skipping^0')
            skipCount = skipCount + 1
            goto continue
        end

        -- only migrate player inventories (type 1) and stashes (type 13)
        if invType ~= 1 and invType ~= 13 then
            skipCount = skipCount + 1
            goto continue
        end

        do
            local items = MySQL.query.await(
                'SELECT id, item_id, slot, quality, information, creationData, expiryDate FROM inventory WHERE name = ? AND dropped = 0 ORDER BY slot ASC',
                { invName }
            )

            if not items or #items == 0 then
                skipCount = skipCount + 1
                goto continue
            end

            -- build ox inventory json blob
            local oxItems = {}
            local slotMap = {}

            for _, row in ipairs(items) do
                -- parse metadata from mythic information column
                local metadata = {}
                if row.information and row.information ~= 0 and row.information ~= '' then
                    local ok, parsed = pcall(json.decode, row.information)
                    if ok and parsed then
                        metadata = parsed
                    end
                end

                -- carry over quality
                if row.quality and row.quality > 0 then
                    metadata.quality = row.quality
                end

                -- carry over expiry
                if row.expiryDate and row.expiryDate ~= -1 then
                    metadata.expiryDate = row.expiryDate
                end

                -- stack items sharing the same slot
                if slotMap[row.slot] then
                    slotMap[row.slot].count = slotMap[row.slot].count + 1
                else
                    slotMap[row.slot] = {
                        slot     = row.slot,
                        name     = row.item_id,
                        count    = 1,
                        metadata = metadata,
                    }
                    table.insert(oxItems, slotMap[row.slot])
                end
            end

            -- write to ox_inventory table
            local owner = invType == 1 and sid or ''
            local name  = invType == 1 and 'inventory' or ('stash-' .. sid)

            local ok, err = pcall(function()
                MySQL.insert.await(
                    'INSERT INTO ox_inventory (owner, name, data) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE data = VALUES(data)',
                    { owner, name, json.encode(oxItems) }
                )
            end)

            if ok then
                successCount = successCount + 1
                if successCount % 100 == 0 then
                    print('^2[mythic-inv-migration] Migrated ' .. successCount .. ' inventories so far....^0')
                end
            else
                print('^1[mythic-inv-migration] Failed to migrate ' .. invName .. ': ' .. tostring(err) .. '^0')
                failCount = failCount + 1
            end
        end

        ::continue::
    end

    print('')
    print('^2[mythic-inv-migration] ====================================^0')
    print('^2[mythic-inv-migration] Migration Complete!^0')
    print('^2[mythic-inv-migration] Successfully Migrated: ' .. successCount .. ' inventories^0')
    print('^2[mythic-inv-migration] Skipped (trunks/drops/shops etc): ' .. skipCount .. ' inventories^0')
    print('^2[mythic-inv-migration] Failed: ' .. failCount .. ' inventories^0')
    print('^2[mythic-inv-migration] ====================================^0')

    if failCount > 0 then
        print('^1[mythic-inv-migration] WARNING: Some inventories failed to migrate, check logs^0')
    else
        print('^2[mythic-inv-migration] All inventories successfully migrated!^0')
        print('^2[mythic-inv-migration] You can now safely disable mythic-inventory^0')
    end
end, true)
