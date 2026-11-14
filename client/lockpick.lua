local config <const> = require 'config'
local Keys <const> = require 'client.keys'
local Ignition <const> = require 'client.ignition'

local DOOR_DICT <const> = 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@'
local DOOR_CLIP <const> = 'machinic_loop_mechandplayer'

local busy = false

---@param skillCheck VehicleKeysSkillCheck
---@return boolean
local function passSkillCheck(skillCheck)
    return exports.cobalt_core:SkillCheck(skillCheck.difficulty, skillCheck.inputs) == true
end

---@param vehicle integer
---@param item string
local function lockpickDoor(vehicle, item)
    local netId <const> = Keys.netId(vehicle)

    if not netId then return end

    TaskTurnPedToFaceEntity(cache.ped, vehicle, 800)
    Wait(800)

    if not lib.callback.await('cobalt_vehiclekeys:startLockpick', false, netId, item, 'door') then
        exports.cobalt_core:Notify(locale('lockpick.door_refused'), 'error')
        return
    end

    lib.requestAnimDict(DOOR_DICT)
    TaskPlayAnim(cache.ped, DOOR_DICT, DOOR_CLIP, 8.0, 8.0, -1, 49, 0, false, false, false)

    local success <const> = passSkillCheck(config.doorLockpick)

    StopAnimTask(cache.ped, DOOR_DICT, DOOR_CLIP, 1.0)
    RemoveAnimDict(DOOR_DICT)

    if lib.callback.await('cobalt_vehiclekeys:lockpickDoor', false, netId, success) then
        exports.cobalt_core:Notify(locale('lockpick.door_success'), 'success')
    else
        exports.cobalt_core:Notify(locale('lockpick.door_failed'), 'error')
    end
end

---@param vehicle integer
---@param item string
local function lockpickIgnition(vehicle, item)
    local netId <const> = Keys.netId(vehicle)

    if not netId then return end

    if not lib.callback.await('cobalt_vehiclekeys:startLockpick', false, netId, item, 'ignition') then
        exports.cobalt_core:Notify(locale('lockpick.ignition_refused'), 'error')
        return
    end

    local success <const> = passSkillCheck(config.ignitionLockpick)

    if not lib.callback.await('cobalt_vehiclekeys:lockpickIgnition', false, netId, success) then
        exports.cobalt_core:Notify(locale('lockpick.ignition_failed'), 'error')
        return
    end

    Ignition.start(vehicle)
end

---@param item string
local function useLockpick(item)
    local vehicle = cache.vehicle

    if vehicle then
        if cache.seat ~= -1 or Keys.has(vehicle) then return end

        return lockpickIgnition(vehicle, item)
    end

    vehicle = lib.getClosestVehicle(GetEntityCoords(cache.ped), config.distance.lockpick, false)

    if not vehicle then
        exports.cobalt_core:Notify(locale('lockpick.none_nearby'), 'error')
        return
    end

    if GetVehicleDoorLockStatus(vehicle) < 2 then
        exports.cobalt_core:Notify(locale('lockpick.not_locked'), 'error')
        return
    end

    lockpickDoor(vehicle, item)
end

exports('UseLockpick', function(event, item)
    if event ~= 'usedItem' or busy then return end

    busy = true
    useLockpick(item.name)
    busy = false
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == cache.resource and IsEntityPlayingAnim(cache.ped, DOOR_DICT, DOOR_CLIP, 3) then
        StopAnimTask(cache.ped, DOOR_DICT, DOOR_CLIP, 1.0)
    end
end)
