local Framework = nil

local function GetDatabase()
    if GetResourceState('oxmysql') == 'started' then
        return 'oxmysql'
    end

    if GetResourceState('ghmattimysql') == 'started' then
        return 'ghmattimysql'
    end

    if MySQL and MySQL.Async then
        return 'mysql-async'
    end

    return nil
end

local function DbFetch(query, params, cb)
    local database = GetDatabase()

    if database == 'oxmysql' then
        exports.oxmysql:execute(query, params, cb)
    elseif database == 'ghmattimysql' then
        exports.ghmattimysql:execute(query, params, cb)
    elseif database == 'mysql-async' then
        MySQL.Async.fetchAll(query, params, cb)
    else
        print('[es-garage] No supported database resource started.')
        cb({})
    end
end

local function DbExecute(query, params, cb)
    local database = GetDatabase()

    if database == 'oxmysql' then
        exports.oxmysql:execute(query, params, cb)
    elseif database == 'ghmattimysql' then
        exports.ghmattimysql:execute(query, params, cb)
    elseif database == 'mysql-async' then
        MySQL.Async.execute(query, params, cb)
    else
        print('[es-garage] No supported database resource started.')
        if cb then cb(0) end
    end
end

local function GetFrameworkObject()
    if Framework then
        return Framework
    end

    if Customize.Framework == 'ESX' then
        TriggerEvent('esx:getSharedObject', function(obj) Framework = obj end)
    elseif Customize.Framework == 'NewESX' then
        Framework = exports['es_extended']:getSharedObject()
    elseif Customize.Framework == 'OLDQBCore' then
        TriggerEvent('QBCore:GetObject', function(obj) Framework = obj end)
    else
        Framework = exports['qb-core']:GetCoreObject()
    end

    return Framework
end

local function GetPlayer(source)
    local framework = GetFrameworkObject()
    if not framework then return nil end

    if Customize.Framework == 'ESX' or Customize.Framework == 'NewESX' then
        return framework.GetPlayerFromId(source)
    end

    return framework.Functions.GetPlayer(source)
end

local function GetPlayerIdentifier(Player)
    if not Player then return nil end

    if Customize.Framework == 'ESX' or Customize.Framework == 'NewESX' then
        return Player.identifier
    end

    return Player.PlayerData and Player.PlayerData.citizenid or nil
end

local function GetVehicleTable()
    if Customize.Framework == 'ESX' or Customize.Framework == 'NewESX' then
        return 'owned_vehicles', 'owner'
    end

    return 'player_vehicles', 'citizenid'
end

local function IsValidPlate(plate)
    return type(plate) == 'string' and plate ~= '' and #plate <= 12
end

local function DoesPlayerOwnPlate(source, plate, cb)
    if not IsValidPlate(plate) then
        cb(false)
        return
    end

    local Player = GetPlayer(source)
    local identifier = GetPlayerIdentifier(Player)

    if not identifier then
        cb(false)
        return
    end

    local tableName, ownerColumn = GetVehicleTable()

    DbFetch(('SELECT plate FROM %s WHERE plate = ? AND %s = ? LIMIT 1'):format(tableName, ownerColumn), {
        plate,
        identifier
    }, function(result)
        cb(result and result[1] ~= nil)
    end)
end

local function UpdateOwnedVehicle(source, plate, column, value)
    DoesPlayerOwnPlate(source, plate, function(owned)
        if not owned then return end

        local tableName, ownerColumn = GetVehicleTable()
        local Player = GetPlayer(source)
        local identifier = GetPlayerIdentifier(Player)

        DbExecute(('UPDATE %s SET %s = ? WHERE plate = ? AND %s = ?'):format(tableName, column, ownerColumn), {
            value,
            plate,
            identifier
        })
    end)
end

local function RegisterCallbacks()
    local framework = GetFrameworkObject()
    if not framework and not lib then return end

    if lib and lib.callback then
        lib.callback.register('es-garage:server:IsVehOwned', function(source, plate)
            local result = promise.new()
            DoesPlayerOwnPlate(source, plate, function(owned)
                result:resolve(owned)
            end)
            return Citizen.Await(result)
        end)

        lib.callback.register('es-garage:server:GetVehicles', function(source)
            local Player = GetPlayer(source)
            local identifier = GetPlayerIdentifier(Player)
            local result = promise.new()

            if not identifier then
                return {}
            end

            local tableName, ownerColumn = GetVehicleTable()
            DbFetch(('SELECT * FROM %s WHERE %s = ?'):format(tableName, ownerColumn), { identifier }, function(vehicles)
                result:resolve(vehicles or {})
            end)

            return Citizen.Await(result)
        end)
    end

    if not framework then return end

    if Customize.Framework == 'ESX' or Customize.Framework == 'NewESX' then
        framework.RegisterServerCallback('es-garage:server:IsPrice', function(source, cb)
            local Player = GetPlayer(source)
            if not Player then
                cb(false)
                return
            end

            if Player.getMoney() >= Customize.GaragesPrice then
                Player.removeMoney(Customize.GaragesPrice)
                cb(true)
                return
            end

            cb(false)
        end)

        framework.RegisterServerCallback('es-garage:server:IsVehOwned', function(source, cb, plate)
            DoesPlayerOwnPlate(source, plate, cb)
        end)

        framework.RegisterServerCallback('es-garage:server:GetVehicles', function(source, cb)
            local Player = GetPlayer(source)
            local identifier = GetPlayerIdentifier(Player)

            if not identifier then
                cb({})
                return
            end

            DbFetch('SELECT * FROM owned_vehicles WHERE owner = ?', { identifier }, cb)
        end)
    elseif framework.Functions then
        framework.Functions.CreateCallback('es-garage:server:IsPrice', function(source, cb)
            local Player = GetPlayer(source)
            if not Player or not Player.Functions then
                cb(false)
                return
            end

            cb(Player.Functions.RemoveMoney(Customize.PriceType, Customize.GaragesPrice, 'garage-fee') == true)
        end)

        framework.Functions.CreateCallback('es-garage:server:IsVehOwned', function(source, cb, plate)
            DoesPlayerOwnPlate(source, plate, cb)
        end)

        framework.Functions.CreateCallback('es-garage:server:GetVehicles', function(source, cb)
            local Player = GetPlayer(source)
            local identifier = GetPlayerIdentifier(Player)

            if not identifier then
                cb({})
                return
            end

            DbFetch('SELECT * FROM player_vehicles WHERE citizenid = ?', { identifier }, cb)
        end)
    end
end

CreateThread(function()
    while not GetFrameworkObject() do
        Wait(200)
    end

    RegisterCallbacks()
end)

RegisterNetEvent('es-garage:server:Record', function(plate, damage)
    local src = source

    if type(damage) ~= 'table' then return end
    UpdateOwnedVehicle(src, plate, 'damage', json.encode(damage))
end)

RegisterNetEvent('es-garage:server:SetState', function(state, plate)
    local src = source
    state = tonumber(state)

    if state ~= 0 and state ~= 1 then return end
    UpdateOwnedVehicle(src, plate, 'state', state)
end)

AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end

    Wait(1000)

    local tableName = GetVehicleTable()
    DbExecute(('UPDATE %s SET state = 1 WHERE state = 0'):format(tableName), {})
end)
