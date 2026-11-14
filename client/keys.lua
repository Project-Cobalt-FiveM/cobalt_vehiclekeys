local Keys <const> = {}

---@type table<string, true>
local plates <const> = {}

---@param plate string
---@return string
function Keys.normalize(plate)
    return (plate:gsub('%s+', ''):upper())
end

---@param vehicle integer
---@return string
function Keys.plateOf(vehicle)
    return Keys.normalize(GetVehicleNumberPlateText(vehicle) or '')
end

---@param model number
---@return string
function Keys.labelOf(model)
    local displayName <const> = GetDisplayNameFromVehicleModel(model)
    local name = GetLabelText(displayName)
    local make <const> = GetLabelText(GetMakeNameFromVehicleModel(model))

    if name == 'NULL' then name = displayName end
    if make == 'NULL' or make == '' then return name end

    return ('%s %s'):format(make, name)
end

---@param vehicle integer
---@return integer?
function Keys.netId(vehicle)
    if not DoesEntityExist(vehicle) or not NetworkGetEntityIsNetworked(vehicle) then return end

    return NetworkGetNetworkIdFromEntity(vehicle)
end

---@param vehicle integer
---@return boolean
function Keys.has(vehicle)
    if plates[Keys.plateOf(vehicle)] then return true end
    if not Keys.netId(vehicle) then return false end

    local keyPlate <const> = Entity(vehicle).state.keyPlate

    return keyPlate ~= nil and plates[keyPlate] == true
end

---@param plate string
function Keys.add(plate)
    plates[plate] = true
end

---@param vehicle integer
---@return boolean
function Keys.refresh(vehicle)
    local netId <const> = Keys.netId(vehicle)

    if not netId then return false end

    local held <const> = lib.callback.await('cobalt_vehiclekeys:hasKey', false, netId) == true

    plates[Keys.plateOf(vehicle)] = held or nil

    return held
end

---@param range number
---@return integer?
function Keys.nearest(range)
    if cache.vehicle and Keys.has(cache.vehicle) then return cache.vehicle end

    local coords <const> = GetEntityCoords(cache.ped)
    local nearest, nearestDistance

    for _, entry in ipairs(lib.getNearbyVehicles(coords, range, true)) do
        local distance <const> = #(coords - entry.coords)

        if Keys.has(entry.vehicle) and (not nearestDistance or distance < nearestDistance) then
            nearest, nearestDistance = entry.vehicle, distance
        end
    end

    return nearest
end

---@param loggedIn boolean?
local function sync(loggedIn)
    table.wipe(plates)

    if not loggedIn then return end

    lib.callback('cobalt_vehiclekeys:getKeys', false, function(list)
        for _, plate in ipairs(list or {}) do
            plates[plate] = true
        end
    end)
end

---@param plate unknown
---@return string?
local function eventPlate(plate)
    if type(plate) ~= 'string' then return end

    plate = Keys.normalize(plate)

    return plate ~= '' and plate or nil
end

RegisterNetEvent('cobalt_vehiclekeys:keysGranted', function(plate, received)
    plate = eventPlate(plate)

    if not plate then return end

    plates[plate] = true

    if received == true then exports.cobalt_core:Notify(locale('keys.received', plate), 'success') end
end)

RegisterNetEvent('cobalt_vehiclekeys:keysRevoked', function(plate)
    plate = eventPlate(plate)

    if not plate then return end

    plates[plate] = nil
end)

AddStateBagChangeHandler('LoggedIn', ('player:%s'):format(cache.serverId), function(_, _, loggedIn)
    sync(loggedIn)
end)

RegisterNetEvent('cobalt_management:membershipChanged', function()
    sync(LocalPlayer.state.LoggedIn)
end)

sync(LocalPlayer.state.LoggedIn)

return Keys
