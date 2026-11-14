local config <const> = require 'config'
local Keys <const> = require 'server.keys'

require 'server.npc'

local HOTWIRE_GRACE_MS <const> = 500
local SIGNAL_RANGE <const> = 50.0
local HOLDUP_GRACE_MS <const> = 2000
local OWNER_MIGRATION_MS <const> = 1000
local LAST_DOOR <const> = 5
local DEAD_HEALTH <const> = 100

---@class HotwireAttempt
---@field entity integer
---@field startedAt integer

---@type table<integer, HotwireAttempt>
local hotwires <const> = {}

---@alias LockpickKind 'door' | 'ignition'

---@class LockpickAttempt
---@field entity integer
---@field item string
---@field kind LockpickKind
---@field startedAt integer

---@type table<integer, LockpickAttempt>
local lockpicks <const> = {}

---@class HoldupAttempt
---@field entity integer
---@field driver integer
---@field startedAt integer

---@type table<integer, HoldupAttempt>
local holdups <const> = {}

---@type table<LockpickKind, VehicleKeysSkillCheck>
local LOCKPICK_CHECKS <const> = {
    door = config.doorLockpick,
    ignition = config.ignitionLockpick,
}

---@param source integer
---@param text string
---@param kind 'success' | 'error' | 'info'
local function notify(source, text, kind)
    exports.cobalt_core:Notify(source, text, kind)
end

---@param entity unknown
---@return integer?
local function vehicleOrNil(entity)
    if type(entity) ~= 'number' or not DoesEntityExist(entity) or GetEntityType(entity) ~= 2 then return end

    return entity
end

---@param netId unknown
---@return integer?
local function vehicleFromNetId(netId)
    if type(netId) ~= 'number' then return end

    return vehicleOrNil(NetworkGetEntityFromNetworkId(netId))
end

---@param source integer
---@param entity integer
---@param range number
---@return boolean
local function withinRange(source, entity, range)
    return #(GetEntityCoords(GetPlayerPed(source)) - GetEntityCoords(entity)) <= range
end

---@param source integer
---@param entity integer
---@return boolean
local function isDriver(source, entity)
    return GetPedInVehicleSeat(entity, -1) == GetPlayerPed(source)
end

---@param source integer
---@param item unknown
---@return boolean
local function carriesLockpick(source, item)
    if type(item) ~= 'string' or not config.lockpickItems[item] then return false end

    return (exports.cobalt_inventory:GetItemCount(source, item) or 0) > 0
end

---@param source integer
---@param item string
local function wearLockpick(source, item)
    if math.random() >= config.lockpickItems[item] then return end

    exports.cobalt_inventory:RemoveItem(source, item, 1, nil, 'cobalt_vehiclekeys:lockpick')
    notify(source, locale('lockpick.broke'), 'error')
end

---@param entity integer
---@param action 'door' | 'alarm'
---@param ... any
local function runOnOwner(entity, action, ...)
    local owner <const> = NetworkGetEntityOwner(entity)

    if owner <= 0 then return end

    TriggerClientEvent('cobalt_vehiclekeys:ownerAction', owner, NetworkGetNetworkIdFromEntity(entity), action, ...)
end

---@param entity integer
---@param locked boolean
local function signal(entity, locked)
    local netId <const> = NetworkGetNetworkIdFromEntity(entity)

    for _, player in ipairs(lib.getNearbyPlayers(GetEntityCoords(entity), SIGNAL_RANGE)) do
        TriggerClientEvent('cobalt_vehiclekeys:signal', player.id, netId, locked)
    end
end

lib.callback.register('cobalt_vehiclekeys:hasKey', function(source, netId)
    local entity <const> = vehicleFromNetId(netId)

    return entity ~= nil and Keys.has(source, entity)
end)

lib.callback.register('cobalt_vehiclekeys:getKeys', function(source)
    return Keys.platesOf(source)
end)

lib.callback.register('cobalt_vehiclekeys:setLocked', function(source, netId, locked)
    local entity <const> = vehicleFromNetId(netId)

    if not entity or type(locked) ~= 'boolean' then return end
    if config.noLock[GetEntityModel(entity)] then return end
    if not withinRange(source, entity, config.distance.lock) then return end

    if not Keys.has(source, entity) then
        notify(source, locale('keys.missing'), 'error')
        return
    end

    SetVehicleDoorsLocked(entity, locked and 2 or 1)
    signal(entity, locked)

    return locked
end)

lib.callback.register('cobalt_vehiclekeys:toggleDoor', function(source, netId, door)
    local entity <const> = vehicleFromNetId(netId)

    if not entity then return false end
    if math.type(door) ~= 'integer' or door < 0 or door > LAST_DOOR then return false end
    if not withinRange(source, entity, config.distance.lock) then return false end
    if not Keys.has(source, entity) then return false end

    runOnOwner(entity, 'door', door)

    return true
end)

lib.callback.register('cobalt_vehiclekeys:soundAlarm', function(source, netId)
    local entity <const> = vehicleFromNetId(netId)

    if not entity or not withinRange(source, entity, config.distance.lock) then return false end
    if not Keys.has(source, entity) then return false end

    runOnOwner(entity, 'alarm')

    return true
end)

---@param source integer
---@param entity integer
---@param kind LockpickKind
---@return boolean
local function canLockpick(source, entity, kind)
    if kind == 'door' then
        if not withinRange(source, entity, config.distance.lockpick) then return false end
        if GetVehicleDoorLockStatus(entity) < 2 then return false end

        return Keys.isStealable(entity)
    end

    if not isDriver(source, entity) then return false end

    local has <const>, stealable <const> = Keys.access(source, entity)

    return not has and stealable
end

lib.callback.register('cobalt_vehiclekeys:startLockpick', function(source, netId, item, kind)
    local entity <const> = vehicleFromNetId(netId)

    if not entity or not LOCKPICK_CHECKS[kind] or not carriesLockpick(source, item) then return false end
    if not canLockpick(source, entity, kind) then return false end

    lockpicks[source] = { entity = entity, item = item, kind = kind, startedAt = GetGameTimer() }

    return true
end)

---@param source integer
---@param netId unknown
---@param kind LockpickKind
---@param success unknown
---@return integer?
local function finishLockpick(source, netId, kind, success)
    local attempt <const> = lockpicks[source]
    local entity <const> = vehicleFromNetId(netId)

    lockpicks[source] = nil

    if not attempt or not entity or attempt.entity ~= entity or attempt.kind ~= kind then return end
    if not carriesLockpick(source, attempt.item) then return end

    wearLockpick(source, attempt.item)

    if success ~= true then return end
    if GetGameTimer() - attempt.startedAt < LOCKPICK_CHECKS[kind].minMs then return end
    if not canLockpick(source, entity, kind) then return end

    return entity
end

lib.callback.register('cobalt_vehiclekeys:lockpickDoor', function(source, netId, success)
    local entity <const> = finishLockpick(source, netId, 'door', success)

    if not entity then return false end

    SetVehicleDoorsLocked(entity, 1)

    return true
end)

lib.callback.register('cobalt_vehiclekeys:lockpickIgnition', function(source, netId, success)
    local entity <const> = finishLockpick(source, netId, 'ignition', success)

    if not entity then return false end

    return Keys.grant(source, Keys.plateOf(entity), entity)
end)

lib.callback.register('cobalt_vehiclekeys:startHotwire', function(source, netId)
    local entity <const> = vehicleFromNetId(netId)

    if not entity or not isDriver(source, entity) then return false end

    local has <const>, stealable <const> = Keys.access(source, entity)

    if has or not stealable then return false end

    hotwires[source] = { entity = entity, startedAt = GetGameTimer() }

    if math.random() < config.hotwire.alarmChance then runOnOwner(entity, 'alarm') end

    return true
end)

lib.callback.register('cobalt_vehiclekeys:finishHotwire', function(source, netId)
    local attempt <const> = hotwires[source]
    local entity <const> = vehicleFromNetId(netId)

    hotwires[source] = nil

    if not attempt or not entity or attempt.entity ~= entity then return false end
    if GetGameTimer() - attempt.startedAt < config.hotwire.duration - HOTWIRE_GRACE_MS then return false end
    if not isDriver(source, entity) then return false end

    return Keys.grant(source, Keys.plateOf(entity), entity)
end)

lib.callback.register('cobalt_vehiclekeys:claimRunning', function(source, netId)
    local entity <const> = vehicleFromNetId(netId)

    if not entity or not isDriver(source, entity) or not GetIsVehicleEngineRunning(entity) then return false end
    if not Keys.isAmbient(entity) or not Keys.isStealable(entity) then return false end

    return Keys.grant(source, Keys.plateOf(entity), entity)
end)

---@param entity integer
---@return number
local function crankFailChance(entity)
    local ignition <const> = config.ignition
    local damage <const> = math.min(math.max((1000.0 - GetVehicleEngineHealth(entity)) / 1000.0, 0.0), 1.0)
    local fuel <const> = Entity(entity).state.fuel or 100.0
    local fuelShortfall <const> = math.max(ignition.lowFuel - fuel, 0.0) / ignition.lowFuel

    return ignition.failChance + damage * ignition.damageFailChance + fuelShortfall * ignition.lowFuelFailChance
end

---@alias IgnitionFailure 'fuel' | 'engine'

---@param entity integer
---@return IgnitionFailure?
local function ignitionFailure(entity)
    if (Entity(entity).state.fuel or 100.0) <= 0.0 then return 'fuel' end
    if GetVehicleEngineHealth(entity) <= 0.0 then return 'engine' end
end

lib.callback.register('cobalt_vehiclekeys:ignite', function(source, netId)
    local entity <const> = vehicleFromNetId(netId)

    if not entity or not isDriver(source, entity) or not Keys.has(source, entity) then return end

    local maxFailed <const> = config.ignition.maxFailedCranks
    local failure <const> = ignitionFailure(entity)

    if failure then return maxFailed, failure end

    local chance <const> = crankFailChance(entity)
    local failed = 0

    while failed < maxFailed and math.random() < chance do failed += 1 end

    return failed
end)

---@param source integer
---@param entity integer
---@param driver integer
---@return boolean
local function canRob(source, entity, driver)
    if config.noCarjack[GetEntityModel(entity)] then return false end
    if not DoesEntityExist(driver) or not withinRange(source, driver, config.distance.rob) then return false end

    return Keys.isAmbient(entity) and Keys.isStealable(entity)
end

---@param ped integer
---@param event string
---@param ... any
local function commandPed(ped, event, ...)
    if not DoesEntityExist(ped) then return end

    local owner <const> = NetworkGetEntityOwner(ped)

    if owner <= 0 then return end

    TriggerClientEvent(event, owner, NetworkGetNetworkIdFromEntity(ped), ...)
end

---@param source integer
---@param holdup HoldupAttempt?
local function endHoldup(source, holdup)
    if holdup then commandPed(holdup.driver, 'cobalt_vehiclekeys:flee', source) end
end

lib.callback.register('cobalt_vehiclekeys:startHoldup', function(source, netId)
    local entity <const> = vehicleFromNetId(netId)

    if not entity then return false end

    local driver <const> = GetPedInVehicleSeat(entity, -1)

    if driver == 0 or IsPedAPlayer(driver) then return false end
    if GetSelectedPedWeapon(GetPlayerPed(source)) == `WEAPON_UNARMED` then return false end
    if not canRob(source, entity, driver) then return false end

    endHoldup(source, holdups[source])
    holdups[source] = { entity = entity, driver = driver, startedAt = GetGameTimer() }
    commandPed(driver, 'cobalt_vehiclekeys:surrender')

    return true
end)

RegisterNetEvent('cobalt_vehiclekeys:endHoldup', function()
    local holdup <const> = holdups[source]

    holdups[source] = nil
    endHoldup(source, holdup)
end)

---@param driver integer
---@param entity integer
---@return boolean
local function stillSeated(driver, entity)
    if not DoesEntityExist(driver) or GetEntityHealth(driver) <= DEAD_HEALTH then return false end

    return GetVehiclePedIsIn(driver, false) == entity
end

lib.callback.register('cobalt_vehiclekeys:robKeys', function(source, netId)
    local holdup <const> = holdups[source]
    local entity <const> = vehicleFromNetId(netId)

    if holdup and entity and stillSeated(holdup.driver, entity) then return end

    holdups[source] = nil
    endHoldup(source, holdup)

    if not holdup or not entity or holdup.entity ~= entity then return false end
    if GetGameTimer() - holdup.startedAt > config.holdupSeconds * 1000 + HOLDUP_GRACE_MS then return false end
    if not canRob(source, entity, holdup.driver) then return false end

    return Keys.grant(source, Keys.plateOf(entity), entity)
end)

lib.addCommand('givekey', {
    help = locale('commands.givekey'),
    params = {
        { name = 'target', type = 'playerId', help = locale('commands.givekey_target'), optional = true },
    },
}, function(source, args)
    local entity <const> = GetVehiclePedIsIn(GetPlayerPed(source), true)

    if entity == 0 or not withinRange(source, entity, config.distance.lock) or not Keys.has(source, entity) then
        notify(source, locale('keys.none_nearby'), 'error')
        return
    end

    local coords <const> = GetEntityCoords(GetPlayerPed(source))
    local target <const> = args.target or lib.getClosestPlayer(coords, config.distance.giveKey, source)

    if not target or target == source or not withinRange(source, GetPlayerPed(target), config.distance.giveKey) then
        notify(source, locale('keys.no_player_nearby'), 'error')
        return
    end

    local plate <const> = Keys.plateOf(entity)

    if not Keys.grant(target, plate, entity) then return end

    notify(source, locale('keys.given', plate), 'success')
end)

AddEventHandler('playerDropped', function()
    local playerId <const> = source
    local holdup <const> = holdups[playerId]

    hotwires[playerId] = nil
    lockpicks[playerId] = nil
    holdups[playerId] = nil

    if not holdup or not DoesEntityExist(holdup.driver) then return end

    if NetworkGetEntityOwner(holdup.driver) == playerId then
        SetTimeout(OWNER_MIGRATION_MS, function() endHoldup(playerId, holdup) end)
        return
    end

    endHoldup(playerId, holdup)
end)

---@param source integer
---@param plate string
---@param entity? integer
---@return boolean
exports('GiveKey', function(source, plate, entity)
    if type(plate) ~= 'string' then return false end

    return Keys.grant(source, Keys.normalize(plate), vehicleOrNil(entity))
end)

---@param plate string
---@return boolean
exports('RemoveKeys', function(plate)
    if type(plate) ~= 'string' then return false end

    Keys.revokeAll(Keys.normalize(plate))

    return true
end)

---@param source integer
---@param plate string
---@return boolean
exports('TakeKey', function(source, plate)
    if type(plate) ~= 'string' then return false end

    Keys.take(source, Keys.normalize(plate))

    return true
end)

---@param source integer
---@param vehicle integer | string
---@return boolean
exports('HasKey', function(source, vehicle)
    if type(vehicle) == 'number' then
        local entity <const> = vehicleOrNil(vehicle)

        return entity ~= nil and Keys.has(source, entity)
    end

    if type(vehicle) ~= 'string' then return false end

    return Keys.holds(source, Keys.normalize(vehicle))
end)
