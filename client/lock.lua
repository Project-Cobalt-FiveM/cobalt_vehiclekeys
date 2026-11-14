local Keys <const> = require 'client.keys'

local FOB_DICT <const> = 'anim@mp_player_intmenu@key_fob@'
local FOB_CLIP <const> = 'fob_click_fp'
local SIGNAL_MS <const> = 600
local TRUNK_DOOR <const> = 5

local Lock <const> = {}

---@param vehicle integer
---@return boolean
function Lock.isLocked(vehicle)
    return GetVehicleDoorLockStatus(vehicle) >= 2
end

local function clickFob()
    if cache.vehicle then return end

    lib.requestAnimDict(FOB_DICT)
    TaskPlayAnim(cache.ped, FOB_DICT, FOB_CLIP, 8.0, 8.0, -1, 48, 0, false, false, false)
    RemoveAnimDict(FOB_DICT)
end

---@param vehicle integer
---@param locked boolean
---@return boolean?
function Lock.set(vehicle, locked)
    local netId <const> = Keys.netId(vehicle)

    if not netId then return end

    clickFob()

    return lib.callback.await('cobalt_vehiclekeys:setLocked', false, netId, locked)
end

---@param vehicle integer
function Lock.toggle(vehicle)
    local locked <const> = Lock.set(vehicle, not Lock.isLocked(vehicle))

    if locked == nil then return end

    exports.cobalt_core:Notify(locale(locked and 'lock.locked' or 'lock.unlocked'), locked and 'info' or 'success')
end

---@param vehicle integer
---@param action 'trunk' | 'alarm'
---@return boolean
function Lock.remote(vehicle, action)
    local netId <const> = Keys.netId(vehicle)

    if not netId then return false end

    clickFob()

    if action == 'trunk' then
        return lib.callback.await('cobalt_vehiclekeys:toggleDoor', false, netId, TRUNK_DOOR) == true
    end

    return lib.callback.await('cobalt_vehiclekeys:soundAlarm', false, netId) == true
end

RegisterNetEvent('cobalt_vehiclekeys:signal', function(netId, locked)
    local vehicle <const> = NetworkGetEntityFromNetworkId(netId)

    if vehicle == 0 then return end

    PlaySoundFromEntity(-1, locked and 'Remote_Control_Close' or 'Remote_Control_Open', vehicle, 'PI_Menu_Sounds', false, 0)
    SetVehicleIndicatorLights(vehicle, 0, true)
    SetVehicleIndicatorLights(vehicle, 1, true)
    Wait(SIGNAL_MS)
    SetVehicleIndicatorLights(vehicle, 0, false)
    SetVehicleIndicatorLights(vehicle, 1, false)
end)

RegisterNetEvent('cobalt_vehiclekeys:ownerAction', function(netId, action, door)
    local vehicle <const> = NetworkGetEntityFromNetworkId(netId)

    if vehicle == 0 or not NetworkHasControlOfEntity(vehicle) then return end

    if action == 'alarm' then
        SetVehicleAlarm(vehicle, true)
        StartVehicleAlarm(vehicle)
        return
    end

    if action ~= 'door' or math.type(door) ~= 'integer' then return end

    if GetVehicleDoorAngleRatio(vehicle, door) > 0.0 then
        SetVehicleDoorShut(vehicle, door, false)
    else
        SetVehicleDoorOpen(vehicle, door, false, false)
    end
end)

return Lock
