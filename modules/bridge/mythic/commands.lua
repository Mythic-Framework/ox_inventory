-- mythic ox bridge: admin commands
-- bridges mythic inv admin commands to ox inv

AddEventHandler('Proxy:Shared:RegisterReady', function()
    local Chat = exports['mythic-base']:FetchComponent('Chat')
    if not Chat then
        print('^1[mythic-ox-bridge] Chat component not found, admin commands not registered^0')
        return
    end

    local function getTarget(source, sidArg)
        local Fetch = exports['mythic-base']:FetchComponent('Fetch')
        local sid
        if sidArg == 'me' then
            local player = Fetch:Source(source)
            sid = player and player:GetData('Character') and player:GetData('Character'):GetData('SID')
        else
            sid = tonumber(sidArg)
        end
        if not sid then return nil, nil end
        local player = Fetch:SID(sid)
        if not player then return nil, nil end
        local char = player:GetData('Character')
        return player:GetData('Source'), char
    end

    Chat:RegisterAdminCommand('giveitem', function(source, args)
        local targetSource, char = getTarget(source, args[1])
        if not targetSource then
            TriggerClientEvent('mythic-notify:client:SendAlert', source, { type = 'error', message = 'Player not online' })
            return
        end
        local itemName = args[2]
        local count = tonumber(args[3]) or 1
        if not itemName then return end
        exports['ox_inventory']:AddItem(targetSource, itemName, count)
        TriggerClientEvent('mythic-notify:client:SendAlert', source, { type = 'success', message = ('Gave %dx %s to %s'):format(count, itemName, char:GetData('SID')) })
    end, {
        help = 'Give Item',
        params = {
            { name = 'SID',   help = "Player SID or 'me'" },
            { name = 'Item',  help = 'Item name' },
            { name = 'Count', help = 'Amount' },
        }
    }, 3)

    Chat:RegisterAdminCommand('giveweapon', function(source, args)
        local targetSource, char = getTarget(source, args[1])
        if not targetSource then
            TriggerClientEvent('mythic-notify:client:SendAlert', source, { type = 'error', message = 'Player not online' })
            return
        end
        local weapon = string.upper(args[2] or '')
        local ammo = tonumber(args[3]) or 0
        local scratched = args[4] == '1'
        if weapon == '' then return end
        exports['ox_inventory']:AddItem(targetSource, weapon, 1, { ammo = ammo, clip = 0, Scratched = scratched or nil })
        TriggerClientEvent('mythic-notify:client:SendAlert', source, { type = 'success', message = ('Gave %s to %s'):format(weapon, char:GetData('SID')) })
    end, {
        help = 'Give Weapon',
        params = {
            { name = 'SID',       help = "Player SID or 'me'" },
            { name = 'Weapon',    help = 'Weapon name' },
            { name = 'Ammo',      help = 'Ammo amount' },
            { name = 'Scratched', help = '1 = scratched serial' },
        }
    }, 4)

    Chat:RegisterAdminCommand('clearinventory', function(source, args)
        local targetSource, char = getTarget(source, args[1])
        if not targetSource then
            TriggerClientEvent('mythic-notify:client:SendAlert', source, { type = 'error', message = 'Player not online' })
            return
        end
        exports['ox_inventory']:clearinventory(targetSource)
        TriggerClientEvent('mythic-notify:client:SendAlert', source, { type = 'success', message = ('Cleared inventory of %s'):format(char:GetData('SID')) })
    end, {
        help = 'Clear Player Inventory',
        params = {
            { name = 'SID', help = "Player SID or 'me'" },
        }
    }, 1)
end)
