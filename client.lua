ESX = exports["es_extended"]:getSharedObject()
local PlayerData = {}
local attachedVehicle = nil
local flatbedVehicle = nil

CreateThread(function()
    while ESX == nil do
        TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)
        Wait(0)
    end

    while ESX.GetPlayerData().job == nil do
        Wait(10)
    end

    PlayerData = ESX.GetPlayerData()
end)

RegisterNetEvent('esx:playerLoaded')
AddEventHandler('esx:playerLoaded', function(xPlayer)
    PlayerData = xPlayer
end)

RegisterNetEvent('esx:setJob')
AddEventHandler('esx:setJob', function(job)
    PlayerData.job = job
end)


local function hasAuthorizedJob()
    return PlayerData.job and PlayerData.job.name == Config.AuthorizedJob
end

local function GetNearestVehicle(coords, radius)
    local vehicles = ESX.Game.GetVehiclesInArea(coords, radius)
    local nearestDistance = radius
    local nearestVehicle = nil

    for k,vehicle in ipairs(vehicles) do
        local distance = #(coords - GetEntityCoords(vehicle))
        if distance < nearestDistance then
            nearestDistance = distance
            nearestVehicle = vehicle
        end
    end

    return nearestVehicle
end


local function isValidFlatbed(vehicle)
    local model = GetEntityModel(vehicle)
    for _, flatbedModel in ipairs(Config.AllowedFlatbeds) do
        if model == GetHashKey(flatbedModel) then
            return true
        end
    end
    return false
end


local function LoadVehicle()
    local playerPed = PlayerPedId()
    local coords = GetEntityCoords(playerPed)
    

    local vehicleToLoad = GetNearestVehicle(coords, 5.0)
    if not vehicleToLoad or vehicleToLoad == flatbedVehicle then
        ESX.ShowNotification('No vehicles found nearby')
        return
    end


    local vehicles = ESX.Game.GetVehiclesInArea(coords, 10.0)
    local nearestDistance = 10.0
    local potentialFlatbed = nil

    for _, vehicle in ipairs(vehicles) do
        if vehicle ~= vehicleToLoad and isValidFlatbed(vehicle) then
            local distance = #(coords - GetEntityCoords(vehicle))
            if distance < nearestDistance then
                nearestDistance = distance
                potentialFlatbed = vehicle
            end
        end
    end

    if not potentialFlatbed then
        ESX.ShowNotification('No flatbed found nearby')
        return
    end


    local modelHash = GetEntityModel(potentialFlatbed)
    local modelName = GetDisplayNameFromVehicleModel(modelHash)
    --ESX.ShowNotification('Platform found: ' .. modelName)


    flatbedVehicle = potentialFlatbed


    local flatbedCoords = GetEntityCoords(flatbedVehicle)
    local flatbedRotation = GetEntityRotation(flatbedVehicle)


    SetEntityCollision(vehicleToLoad, false, false)


    AttachEntityToEntity(vehicleToLoad, flatbedVehicle,
        GetEntityBoneIndexByName(flatbedVehicle, 'bodyshell'),
        Config.VehicleOffset.x,
        Config.VehicleOffset.y,
        Config.VehicleOffset.z,
        Config.VehicleOffset.pitch,
        Config.VehicleOffset.roll,
        Config.VehicleOffset.yaw,
        false, false, true, false, 2, true)


    attachedVehicle = vehicleToLoad

    ESX.ShowNotification('Vehicle successfully loaded')
end


local function UnloadVehicle()
    if not attachedVehicle then
        ESX.ShowNotification('No vehicles loaded')
        return
    end

    local playerPed = PlayerPedId()
    local flatbedCoords = GetEntityCoords(flatbedVehicle)
    local flatbedHeading = GetEntityHeading(flatbedVehicle)


    DetachEntity(attachedVehicle, true, true)


    local offset = -10.0 -- distance behind the floor
    local x = flatbedCoords.x - (math.sin(math.rad(flatbedHeading)) * offset)
    local y = flatbedCoords.y + (math.cos(math.rad(flatbedHeading)) * offset)
    
    SetEntityCoords(attachedVehicle, x, y, flatbedCoords.z)
    SetEntityHeading(attachedVehicle, flatbedHeading)


    SetEntityCollision(attachedVehicle, true, true)


    attachedVehicle = nil
    flatbedVehicle = nil

    ESX.ShowNotification('Vehicle downloaded successfully')
end


local function OpenLoadMenu()
    if not hasAuthorizedJob() then
        --ESX.ShowNotification('You do not have permission to use this command')
        return
    end

    ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'vehicle_load_menu',
    {
        title = 'Gestione Pianale',
        align = 'top-left',
        elements = {
            {label = 'Load Vehicle', value = 'load'},
            {label = 'Download Vehicle', value = 'unload'}
        }
    },
    function(data, menu)
        if data.current.value == 'load' then
            LoadVehicle()
        elseif data.current.value == 'unload' then
            UnloadVehicle()
        end
    end,
    function(data, menu)
        menu.close()
    end)
end


CreateThread(function()
    for _, model in ipairs(Config.AllowedFlatbeds) do
        exports.ox_target:addModel(GetHashKey(model), {
            {
                name = 'flatbed_menu',
                icon = 'fas fa-truck-loading',
                label = 'Floor Management',
                canInteract = function(entity)
                    return hasAuthorizedJob()
                end,
                onSelect = function(data)
                    OpenLoadMenu()
                end
            }
        })
    end
end)