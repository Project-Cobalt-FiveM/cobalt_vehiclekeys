local config <const> = require 'config'

local AMBIENT_POPULATION <const> = { [1] = true, [2] = true, [3] = true, [4] = true, [5] = true }

local Keys <const> = {}

---@type table<string, table<string, true>>
local temporaryKeys <const> = {}

---@type table<integer, string>
local keyedPlates <const> = {}

---@param plate string
---@return string
function Keys.normalize(plate)
    return (plate:gsub('%s+', ''):upper())
end

---@param entity integer
---@return string plate the plate keys were given for, or the plate the game reports until then
function Keys.plateOf(entity)
    return keyedPlates[entity] or Keys.normalize(GetVehicleNumberPlateText(entity) or '')
end

---@param source integer
---@return string?
function Keys.citizenIdOf(source)
    return Player(source).state['cobalt:citizenid']
end

---@param plate string
---@return string?
local function ownerOf(plate)
    return exports.cobalt_core:GetVehicleOwnerByPlate(plate)
end

---@param plate string
---@param citizenId string
---@return boolean
local function hasTemporaryKey(plate, citizenId)
    return (temporaryKeys[plate] or {})[citizenId] == true
end

---@param source integer
---@param model number
---@return boolean
local function hasSharedKey(source, model)
    local job <const> = exports.cobalt_management:GetJob(source)
    local shared <const> = job and (config.sharedKeys[job.name] or config.sharedKeys[job.type])

    if not shared or not shared.vehicles[model] then return false end

    return job.onduty or not shared.requireOnDuty
end

---@param source integer
---@param plate string
---@return boolean
function Keys.holds(source, plate)
    local citizenId <const> = Keys.citizenIdOf(source)

    if not citizenId or plate == '' then return false end
    if hasTemporaryKey(plate, citizenId) then return true end

    return ownerOf(plate) == citizenId
end

---@param source integer
---@param entity integer
---@return boolean
function Keys.has(source, entity)
    return hasSharedKey(source, GetEntityModel(entity)) or Keys.holds(source, Keys.plateOf(entity))
end

---@param source integer
---@param entity integer
---@return boolean has the player holds a key for the vehicle
---@return boolean stealable no player owns its plate
function Keys.access(source, entity)
    local plate <const> = Keys.plateOf(entity)
    local owner <const> = ownerOf(plate)
    local stealable <const> = owner == nil

    if hasSharedKey(source, GetEntityModel(entity)) then return true, stealable end

    local citizenId <const> = Keys.citizenIdOf(source)

    if not citizenId or plate == '' then return false, stealable end

    return hasTemporaryKey(plate, citizenId) or owner == citizenId, stealable
end

---@param source integer
---@param plate string
---@param entity? integer
---@return boolean
function Keys.grant(source, plate, entity)
    local citizenId <const> = Keys.citizenIdOf(source)

    if not citizenId or plate == '' then return false end

    local holders <const> = temporaryKeys[plate] or {}
    local received <const> = not holders[citizenId]

    temporaryKeys[plate] = holders
    holders[citizenId] = true

    if entity and keyedPlates[entity] ~= plate then
        keyedPlates[entity] = plate
        Entity(entity).state:set('keyPlate', plate, true)
    end

    TriggerClientEvent('cobalt_vehiclekeys:keysGranted', source, plate, received)

    return true
end

---@param plate string
---@return boolean
function Keys.isHeld(plate)
    return next(temporaryKeys[plate] or {}) ~= nil
end

---@param source integer
---@param plate string
function Keys.take(source, plate)
    local citizenId <const> = Keys.citizenIdOf(source)
    local holders <const> = temporaryKeys[plate]

    if citizenId and holders then holders[citizenId] = nil end

    TriggerClientEvent('cobalt_vehiclekeys:keysRevoked', source, plate)
end

---@param plate string
function Keys.revokeAll(plate)
    for citizenId in pairs(temporaryKeys[plate] or {}) do
        local player <const> = exports.cobalt_core:GetPlayerByCitizenId(citizenId)

        if player then TriggerClientEvent('cobalt_vehiclekeys:keysRevoked', player.PlayerData.source, plate) end
    end

    temporaryKeys[plate] = nil
end

AddEventHandler('entityRemoved', function(entity)
    local plate <const> = keyedPlates[entity]

    if not plate then return end

    keyedPlates[entity] = nil

    if not temporaryKeys[plate] or ownerOf(plate) then return end

    Keys.revokeAll(plate)
end)

---@param source integer
---@return string[]
function Keys.platesOf(source)
    local citizenId <const> = Keys.citizenIdOf(source)

    if not citizenId then return {} end

    local plates <const> = {}

    for plate, holders in pairs(temporaryKeys) do
        if holders[citizenId] then plates[#plates + 1] = plate end
    end

    for _, vehicle in ipairs(exports.cobalt_core:GetVehiclesByCitizenId(citizenId, { 'plate' })) do
        plates[#plates + 1] = Keys.normalize(vehicle.plate)
    end

    return plates
end

---@param entity integer
---@return boolean
function Keys.isAmbient(entity)
    return AMBIENT_POPULATION[GetEntityPopulationType(entity)] == true
end

---@param entity integer
---@return boolean
function Keys.isStealable(entity)
    return ownerOf(Keys.plateOf(entity)) == nil
end

return Keys
