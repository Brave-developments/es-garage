Framework = nil
local SetVehProperties = nil
local GetVehProperties = nil

CreateThread(function()
    while Framework == nil do 
        Framework = GetFramework()
        Wait(500) 
    end
    Wait(2500)
    if Customize.Framework == "ESX" or Customize.Framework == "NewESX" then
        SetVehProperties = Framework.Game.SetVehicleProperties
        GetVehProperties = Framework.Game.GetVehicleProperties
    elseif Framework.Functions then
        SetVehProperties = Framework.Functions.SetVehicleProperties
        GetVehProperties = Framework.Functions.GetVehicleProperties
    end
end)

LastCamera, currentVeh, PlayerJob, vehCam = nil, nil, nil, nil
newData = {}
local inGarage = 0

local function TriggerGarageCallback(name, cb, ...)
    if Customize.Framework == "ESX" or Customize.Framework == "NewESX" then
        if Framework and Framework.TriggerServerCallback then
            Framework.TriggerServerCallback(name, cb, ...)
            return
        end
    elseif Framework and Framework.Functions and Framework.Functions.TriggerCallback then
        Framework.Functions.TriggerCallback(name, cb, ...)
        return
    end

    if lib and lib.callback then
        lib.callback(name, false, cb, ...)
        return
    end

    print(('[es-garage] Callback %s failed: framework callback bridge is not ready.'):format(name))
    cb(nil)
end

local function SetGarageVehicleProperties(vehicle, props)
    if SetVehProperties then
        SetVehProperties(vehicle, props)
        return
    end

    if Framework and Framework.Functions and Framework.Functions.SetVehicleProperties then
        Framework.Functions.SetVehicleProperties(vehicle, props)
        return
    end

    if Framework and Framework.Game and Framework.Game.SetVehicleProperties then
        Framework.Game.SetVehicleProperties(vehicle, props)
    end
end

CreateThread(function()
    while true do 
        local sleep = 1000
        local getPed = PlayerPedId()
        local entity = GetEntityCoords(getPed)
        local InVeh = GetVehiclePedIsIn(getPed)
        
        for n, text in pairs(Customize.Garages) do
            local dist = #(entity - text.Npc.Pos)
            local park = #(entity - text.VehPutPos)
            
            if dist <= 5.0 then
                sleep = 0
                HandleGarageProximity(dist, text, getPed)
            end
            
            if IsPedInAnyVehicle(getPed, false) then
                HandleVehicleProximity(park, text, InVeh, getPed)
                if park <= 12.0 then
                    sleep = 0
                end
            end
        end

        Wait(sleep)
    end
end)

function HandleGarageProximity(dist, text, getPed)
    if dist <= 2.0 then
        Draw3DText(text.Npc.Pos.x, text.Npc.Pos.y, text.Npc.Pos.z + 0.98, "[E] GARAGE")
        if IsControlJustPressed(0, 38) then
            TriggerGarageCallback('es-garage:server:GetVehicles', function(vehicles)
                ProcessVehicles(vehicles, text)
            end)
        end
    end
end

function ProcessVehicles(vehicles, text)
    if vehicles then 
        local data = {}
        local impound = {}
        for k, v in pairs(vehicles) do
            local class = GetVehicleClassFromName(v.vehicle)
            v.mods = type(v.mods) == 'string' and json.decode(v.mods) or v.mods or {}
            v.damage = type(v.damage) == 'string' and json.decode(v.damage) or v.damage or {}
            v.model = GetDisplayNameFromVehicleModel(v.vehicle)
            v.title = GetLabelText(v.model)
            v.location = text.UIName
            if v.state == 1 then
                CategorizeVehicle(v, text.Type, class, data)
                LastSpawnPos = text.VehSpawnPos
                LastCamera = text.Camera
            elseif v.state == 0 then 
                table.insert(impound, v)
            end
        end
        
        if next(data) ~= nil then
            SendNUIMessage({
                data = "GARAGE",
                car = data,
                impound = #impound,
                name = UI
            })
            SetNuiFocus(true, true)
            SetClockTime(21, 0, 0)  
            SetWeatherTypePersist("EXTRASUNNY")  
            SetWeatherTypeNowPersist("EXTRASUNNY")
            NetworkOverrideClockTime(21, 0, 0) 
            DisplayRadar(false)
            Camera()  -- Only call Camera if there are vehicles
        else
            -- No vehicles available in the garage, notify the user
            TriggerEvent('chat:addMessage', {
                args = { '^1No vehicles available in the garage.' }
            })
        end
    else
        print("No vehicles found in the database.")
    end
end

function Camera()
    if vehCam then
        DestroyCam(vehCam, false)
    end
    vehCam = CreateCameraWithParams('DEFAULT_SCRIPTED_CAMERA', LastCamera.location.posX, LastCamera.location.posY, LastCamera.location.posZ, LastCamera.location.rotX, LastCamera.location.rotY, LastCamera.location.rotZ, LastCamera.location.fov, false, 2)
    SetCamActive(vehCam, true)
    RenderScriptCams(true, true, 2000, true, false, false)
    SetFocusPosAndVel(LastCamera.location.posX, LastCamera.location.posY, LastCamera.location.posZ, 0.0, 0.0, 0.0)
    DoScreenFadeIn(1000)
    PlaySoundFrontend(-1, "SELECT", "HUD_FRONTEND_DEFAULT_SOUNDSET", false)
end

function CategorizeVehicle(vehicle, type, class, data)
    if type == 'car' and class ~= 14 and class ~= 15 and class ~= 16 then
        table.insert(data, vehicle)
    elseif type == 'air' and (class == 15 or class == 16) then
        table.insert(data, vehicle)
    elseif type == 'sea' and class == 14 then
        table.insert(data, vehicle)
    end
end

function HandleVehicleProximity(park, text, InVeh, getPed)
    if park <= 12.0 then
        DrawMarker(2, text.VehPutPos.x, text.VehPutPos.y, text.VehPutPos.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.3, 0.2, 0.15, 255, 255, 255, 255, false, false, false, true, false, false, false)
        if park <= 4.0 and IsControlJustReleased(0, 38) and GetVehicleNumberOfPassengers(InVeh) == 0 then
            HandleVehicleCheck(InVeh, getPed)
        end
    end
end

function HandleVehicleCheck(InVeh, getPed)
    local plate = GetPlate(InVeh)

    TriggerGarageCallback('es-garage:server:IsVehOwned', function(owned)
        if owned then
            RecordVehicleState(InVeh, plate)
            Wait(200)
            EYESDeleteVehicle(InVeh, plate)
        end
    end, plate, '')
end

RegisterNUICallback('Parked', function(plate, cb)
    TriggerServerEvent('es-garage:server:SetState', 1, plate)
    if cb then cb({ ok = true }) end
end)

function RecordVehicleState(InVeh, plate)
    TriggerServerEvent('es-garage:server:Record', plate, {
        Door = GetVehicleDoorStatus(InVeh),
        HalfWheel = GetVehicleTyreStatus(InVeh, false),
        FullWheel = GetVehicleTyreStatus(InVeh, true),
        Dirt = GetVehicleDirtLevel(InVeh),
        BodyHealth = GetVehicleBodyHealth(InVeh),
        PetrolTank = Round(GetVehiclePetrolTankHealth(InVeh), 0.1),
        EngineHealth = Round(GetVehicleEngineHealth(InVeh), 0.1),
        DoorLock = GetVehicleDoorLockStatus(InVeh),
        EngineOn = GetIsVehicleEngineRunning(InVeh)
    })
    TriggerServerEvent('es-garage:server:SetState', 1, plate)
end

function GetVehicleDoorStatus(InVeh)
    return {
        ["0"] = IsVehicleDoorDamaged(InVeh, 0),
        ["1"] = IsVehicleDoorDamaged(InVeh, 1),
        ["2"] = IsVehicleDoorDamaged(InVeh, 2),
        ["3"] = IsVehicleDoorDamaged(InVeh, 3),
        ["4"] = IsVehicleDoorDamaged(InVeh, 4),
        ["5"] = IsVehicleDoorDamaged(InVeh, 5)
    }
end

function GetVehicleTyreStatus(InVeh, burstType)
    return {
        ["0"] = IsVehicleTyreBurst(InVeh, 0, burstType),
        ["1"] = IsVehicleTyreBurst(InVeh, 1, burstType),
        ["2"] = IsVehicleTyreBurst(InVeh, 2, burstType),
        ["3"] = IsVehicleTyreBurst(InVeh, 3, burstType),
        ["4"] = IsVehicleTyreBurst(InVeh, 4, burstType),
        ["5"] = IsVehicleTyreBurst(InVeh, 5, burstType)
    }
end

local cameraZoomLevel = 1.0
local minZoomLevel = 0.5
local maxZoomLevel = 3.0

RegisterNUICallback("rotateright", function(_, cb)
    if currentVeh then
        SetEntityHeading(currentVeh, GetEntityHeading(currentVeh) - 2)
    end
    if cb then cb({ ok = true }) end
end)

RegisterNUICallback("rotateleft", function(_, cb)
    if currentVeh then
        SetEntityHeading(currentVeh, GetEntityHeading(currentVeh) + 2)
    end
    if cb then cb({ ok = true }) end
end)

RegisterNUICallback("zoomIn", function(_, cb)
    if vehCam and cameraZoomLevel > minZoomLevel then
        cameraZoomLevel = cameraZoomLevel - 0.1
        SetCamFov(vehCam, 50 / cameraZoomLevel)
    end
    if cb then cb({ ok = true }) end
end)

RegisterNUICallback("zoomOut", function(_, cb)
    if vehCam and cameraZoomLevel < maxZoomLevel then
        cameraZoomLevel = cameraZoomLevel + 0.1
        SetCamFov(vehCam, 50 / cameraZoomLevel)
    end
    if cb then cb({ ok = true }) end
end)

RegisterNUICallback('VehicleInfo', function(data, cb)
    print(data.data.vehicle, json.encode(data.data.mods))
    local vehicleData = (Customize.Framework == "ESX" or Customize.Framework == "NewESX") and json.decode(data.data.vehicle) or data.data.mods
    local model = (Customize.Framework == "ESX" or Customize.Framework == "NewESX") and vehicleData.model or GetHashKey(data.data.vehicle)
    RequestModel(model)
    while not HasModelLoaded(model) do
        Wait(7)
    end
    if currentVeh then
        DeleteVehicle(currentVeh)
    end
    currentVeh = CreateVehicle(model, LastCamera.vehSpawn.x, LastCamera.vehSpawn.y, LastCamera.vehSpawn.z, LastCamera.vehSpawn.w, false, true)
    SetVehicleEngineOn(currentVeh, true, true, false)
    print("Vehicle Mods: " .. json.encode(vehicleData))
    SetGarageVehicleProperties(currentVeh, vehicleData)
    Camera()
    PointCamAtEntity(vehCam, currentVeh)
    RenderScriptCams(true, false, 0, true, true)
    local fuel = Customize.GetVehFuel(currentVeh)
    local speed = GetVehicleEstimatedMaxSpeed(currentVeh)
    local traction = GetVehicleMaxTraction(currentVeh)
    local acceleration = GetVehicleAcceleration(currentVeh)
    cb({
        Fuel = fuel,
        Speed = speed,
        Traction = traction,
        Acceleration = acceleration
    })
end)

RegisterNUICallback('SpawnVehicle', function(data, cb)
    print(json.encode(data))
    local vehicleData = (Customize.Framework == "ESX" or Customize.Framework == "NewESX") and json.decode(data.vehicle) or data.vehicle
    local model = (Customize.Framework == "ESX" or Customize.Framework == "NewESX") and vehicleData.model or GetHashKey(data.vehicle)
    local Mods = (Customize.Framework == "ESX" or Customize.Framework == "NewESX") and vehicleData or data.mods
    -- print("Vehicle Data: " .. json.encode(vehicleData))
    -- print("Model: " .. model)
    -- print("Mods: " .. json.encode(Mods))
    if not Mods then
        Mods = {}
        print("Mods data was nil, setting it to an empty table.")
    end
    TriggerGarageCallback('es-garage:server:IsVehOwned', function(owned)
        if not owned then
            if cb then cb({ ok = false }) end
            return
        end

        EYESSpawnVehicle(model, function(Veh)
            SetNetworkIdAlwaysExistsForPlayer(NetworkGetNetworkIdFromEntity(Veh), PlayerPedId(), true)
            SetVehicleNumberPlateText(Veh, data.plate)
            SetEntityHeading(Veh, LastSpawnPos.w)
            Customize.SetVehFuel(Veh, data.fuel or 100.0)
            SetEntityAsMissionEntity(Veh, true, true)
            TaskWarpPedIntoVehicle(PlayerPedId(), Veh, -1)
            SetVehicleEngineOn(Veh, true, false)
            SetVehicleUndriveable(Veh, false)
            SendNUIMessage({data = "CLOSE"})
            TriggerServerEvent('es-garage:server:SetState', 0, data.plate)
            Customize.Carkeys(GetVehicleNumberPlateText(Veh))
            print("Setting Vehicle Properties for Vehicle: " .. json.encode(Mods))
            SetGarageVehicleProperties(Veh, Mods)
            ApplyVehicleDamage(Veh, data.damage)
            DoScreenFadeIn(1000)
            if cb then cb({ ok = true }) end
        end, LastSpawnPos, true)
    end, data.plate, '')
end)

function SetVehicleProperties(vehicle, props)
    if Framework and Framework.Functions and Framework.Functions.SetVehicleProperties then
        Framework.Functions.SetVehicleProperties(vehicle, props)
    elseif Framework and Framework.Game and Framework.Game.SetVehicleProperties then
        Framework.Game.SetVehicleProperties(vehicle, props)
    else
        print("Error: SetVehicleProperties function not found in Framework.")
    end
end

function GetVehicleProperties(vehicle)
    if Framework and Framework.Functions and Framework.Functions.GetVehicleProperties then
        return Framework.Functions.GetVehicleProperties(vehicle)
    elseif Framework and Framework.Game and Framework.Game.GetVehicleProperties then
        return Framework.Game.GetVehicleProperties(vehicle)
    else
        print("Error: GetVehicleProperties function not found in Framework.")
        return {}
    end
end

function ApplyVehicleDamage(vehicle, damage)
    if type(damage) ~= 'table' then return end

    if damage.Door then
        for door, broken in pairs(damage.Door) do
            if broken then
                SetVehicleDoorBroken(vehicle, tonumber(door), true)
            end
        end
    end

    if damage.FullWheel then
        for tyre, burst in pairs(damage.FullWheel) do
            if burst then
                SetVehicleTyreBurst(vehicle, tonumber(tyre), true, 1000.0)
            end
        end
    end

    if damage.HalfWheel then
        for tyre, burst in pairs(damage.HalfWheel) do
            if burst then
                SetVehicleTyreBurst(vehicle, tonumber(tyre), false, 1000.0)
            end
        end
    end

    if damage.Dirt then SetVehicleDirtLevel(vehicle, damage.Dirt + 0.0) end
    if damage.BodyHealth then SetVehicleBodyHealth(vehicle, damage.BodyHealth + 0.0) end
    if damage.PetrolTank then SetVehiclePetrolTankHealth(vehicle, damage.PetrolTank + 0.0) end
    if damage.EngineHealth then SetVehicleEngineHealth(vehicle, damage.EngineHealth + 0.0) end
    if damage.DoorLock then SetVehicleDoorsLocked(vehicle, damage.DoorLock) end
    if damage.EngineOn ~= nil then SetVehicleEngineOn(vehicle, damage.EngineOn == true, true, false) end
end

local display = false

RegisterNUICallback("exit", function(data, cb)
    if currentVeh ~= nil then EYESDeleteVehicle(currentVeh) end
    LastCamera = nil
    currentVeh = nil
    DestroyAllCams(true)
    RenderScriptCams(false, true, 1700, true, false, false)
    SetFocusEntity(GetPlayerPed(PlayerId()))
    SetDisplay(false, false)
    DisplayRadar(true)
    if cb then cb({ ok = true }) end
end)

function SetDisplay(bool)
    display = bool
    SetNuiFocus(bool, bool)
end

CreateThread(function()
    for index, eyes in pairs(Customize.Garages) do
        NPCLoad(eyes)
        MapBlip(eyes)
    end
end)

function MapBlip(eyes)
    local blip = AddBlipForCoord(eyes.Blips.Position)
    SetBlipSprite(blip, eyes.Blips.Sprite)
    SetBlipDisplay(blip, eyes.Blips.Display)
    SetBlipScale(blip, eyes.Blips.Scale)
    SetBlipColour(blip, eyes.Blips.Color)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString(eyes.Blips.Label)
    EndTextCommandSetBlipName(blip)
end

function NPCLoad(eyes)
    RequestModel(eyes.Npc.Hash)
    while not HasModelLoaded(eyes.Npc.Hash) do Wait(1) end
    local NpcPed = CreatePed(4, eyes.Npc.Hash, eyes.Npc.Pos.x, eyes.Npc.Pos.y, eyes.Npc.Pos.z - 1, eyes.Npc.Heading, false, true)
    SetEntityHeading(NpcPed, eyes.Npc.Heading)
    FreezeEntityPosition(NpcPed, true)
    SetEntityInvincible(NpcPed, true)
    SetBlockingOfNonTemporaryEvents(NpcPed, true)
end

function Draw3DText(x, y, z, text)
    local onScreen, _x, _y = World3dToScreen2d(x, y, z)
    local px, py, pz = table.unpack(GetGameplayCamCoords())
    if onScreen then
        SetTextScale(0.35, 0.35)
        SetTextFont(4)
        SetTextProportional(1)
        SetTextColour(255, 255, 255, 215)
        SetTextDropShadow(0, 0, 0, 55)
        SetTextEdge(0, 0, 0, 150)
        SetTextDropShadow()
        SetTextOutline()
        SetTextEntry("STRING")
        SetTextCentre(1)
        AddTextComponentString(text)
        DrawText(_x, _y)
    end
end

function Round(value, numDecimalPlaces)
    if not numDecimalPlaces then return math.floor(value + 0.5) end
    local power = 10 ^ numDecimalPlaces
    return math.floor((value * power) + 0.5) / (power)
end

function GetPlate(vehicle)
    if vehicle == 0 then return end
    return Trim(GetVehicleNumberPlateText(vehicle))
end

function Trim(value)
    if not value then return nil end
    return (string.gsub(value, '^%s*(.-)%s*$', '%1'))
end

function EYESDeleteVehicle(vehicle)
    SetEntityAsMissionEntity(vehicle, true, true)
    DeleteVehicle(vehicle)
end

function EYESSpawnVehicle(model, cb, coords, isnetworked, teleportInto)
    local ped = PlayerPedId()
    model = type(model) == 'string' and GetHashKey(model) or model
    if not IsModelInCdimage(model) then return end
    local heading = coords and coords.w or GetEntityHeading(ped)
    coords = coords and vec3(coords.x, coords.y, coords.z) or GetEntityCoords(ped)
    isnetworked = isnetworked or true
    ELoadModel(model)
    local veh = CreateVehicle(model, coords.x, coords.y, coords.z, heading, isnetworked, false)
    local netid = NetworkGetNetworkIdFromEntity(veh)
    SetVehicleHasBeenOwnedByPlayer(veh, true)
    SetNetworkIdCanMigrate(netid, true)
    SetVehicleNeedsToBeHotwired(veh, false)
    SetVehRadioStation(veh, 'OFF')
    SetVehicleFuelLevel(veh, 100.0)
    SetModelAsNoLongerNeeded(model)
    if teleportInto then TaskWarpPedIntoVehicle(PlayerPedId(), veh, -1) end
    if cb then cb(veh) end
end

function ELoadModel(model)
    if HasModelLoaded(model) then return end
    RequestModel(model)
    while not HasModelLoaded(model) do
        Wait(0)
    end
end
