local config <const> = require 'config'
local Keys <const> = require 'client.keys'

local CYCLE_CLASS <const> = 13
local MOTORCYCLE_CLASS <const> = 8
local UPPER_BODY_FLAG <const> = 48
local INPUT_VEH_ACCELERATE <const> = 71
local PED_FLAG_DISABLE_ENGINE_START <const> = 429

---@type table<IgnitionFailure, string>
local FAILURE_LOCALES <const> = {
    fuel = 'ignition.failure_fuel',
    engine = 'ignition.failure_engine',
}

local HOTWIRE_DICT <const> = 'veh@std@ds@base'
local HOTWIRE_CLIP <const> = 'hotwire'

local ignition <const> = config.ignition

local Ignition <const> = {}

---@type integer?
local keyless

local hotwiring = false
local busy = false

---@param ped integer
local function setEngineFlag(ped)
    SetPedConfigFlag(ped, PED_FLAG_DISABLE_ENGINE_START, not config.player.autoEngine)
end

local function release()
    if not keyless then return end

    if DoesEntityExist(keyless) then
        SetVehicleUndriveable(keyless, false)
        SetHornEnabled(keyless, true)
    end

    keyless = nil
    exports.cobalt_core:HideTextUI()
end

---@param vehicle integer
---@return boolean
local function stillDriving(vehicle)
    return cache.vehicle == vehicle and cache.seat == -1 and DoesEntityExist(vehicle)
end

---@param vehicle integer
---@return VehicleKeysAnim?
local function loadKeyTurn(vehicle)
    local anim <const> = GetVehicleClass(vehicle) == MOTORCYCLE_CLASS and ignition.bikeAnim or ignition.anim

    if not pcall(lib.requestAnimDict, anim.dict) then return end

    if GetAnimDuration(anim.dict, anim.clip) <= 0.0 then
        RemoveAnimDict(anim.dict)
        return
    end

    return anim
end

---@param anim VehicleKeysAnim?
---@param durationMs integer
local function turnKey(anim, durationMs)
    if not anim then return end

    TaskPlayAnim(cache.ped, anim.dict, anim.clip, 8.0, -8.0, durationMs, UPPER_BODY_FLAG, 0.0, false, false, false)
end

local function holdThrottle()
    CreateThread(function()
        while busy do
            DisableControlAction(0, INPUT_VEH_ACCELERATE, true)
            Wait(0)
        end
    end)
end

---@param vehicle integer
---@param failedCranks integer
---@param anim VehicleKeysAnim?
---@return boolean
local function crank(vehicle, failedCranks, anim)
    for _ = 1, failedCranks do
        turnKey(anim, ignition.failedCrankMs)
        SetVehicleEngineOn(vehicle, true, false, true)
        Wait(ignition.failedCrankMs)
        SetVehicleEngineOn(vehicle, false, true, true)
        Wait(ignition.retryMs)

        if not stillDriving(vehicle) then return false end
    end

    return true
end

---@param vehicle integer
---@param anim VehicleKeysAnim?
local function catch(vehicle, anim)
    turnKey(anim, ignition.crankMs)
    SetVehicleEngineOn(vehicle, true, false, true)
    Wait(ignition.crankMs)

    if not GetIsVehicleEngineRunning(vehicle) then SetVehicleEngineOn(vehicle, true, true, true) end
end

---@param vehicle integer
---@param withKey boolean
local function ignite(vehicle, withKey)
    local netId <const> = Keys.netId(vehicle)

    if not netId then return end

    busy = true

    local failedCranks <const>, failure <const> = lib.callback.await('cobalt_vehiclekeys:ignite', false, netId)

    if not failedCranks then
        busy = false
        exports.cobalt_core:Notify(locale('ignition.no_keys'), 'error')
        return
    end

    local anim <const> = withKey and loadKeyTurn(vehicle) or nil

    holdThrottle()
    SetPedConfigFlag(cache.ped, PED_FLAG_DISABLE_ENGINE_START, false)

    if crank(vehicle, failedCranks, anim) and not failure then catch(vehicle, anim) end

    setEngineFlag(cache.ped)

    if anim then RemoveAnimDict(anim.dict) end

    busy = false

    if failure and stillDriving(vehicle) then exports.cobalt_core:Notify(locale(FAILURE_LOCALES[failure]), 'error') end
end

---@param vehicle integer
local function shutOff(vehicle)
    busy = true

    local anim <const> = loadKeyTurn(vehicle)

    turnKey(anim, ignition.stopMs)
    Wait(ignition.stopMs)

    if stillDriving(vehicle) then SetVehicleEngineOn(vehicle, false, false, true) end
    if anim then RemoveAnimDict(anim.dict) end

    busy = false
end

---@param vehicle integer
function Ignition.start(vehicle)
    Keys.add(Keys.plateOf(vehicle))
    release()

    if not busy then ignite(vehicle, false) end
end

---@param vehicle integer
function Ignition.toggle(vehicle)
    if busy then return end

    if not Keys.has(vehicle) then
        exports.cobalt_core:Notify(locale('ignition.no_keys'), 'error')
        return
    end

    if GetIsVehicleEngineRunning(vehicle) then return shutOff(vehicle) end

    ignite(vehicle, true)
end

local function toggleDriven()
    if not cache.vehicle or cache.seat ~= -1 then return end

    Ignition.toggle(cache.vehicle)
end

---@param vehicle integer
local function hotwire(vehicle)
    local netId <const> = Keys.netId(vehicle)

    if not netId then return end

    if not lib.callback.await('cobalt_vehiclekeys:startHotwire', false, netId) then
        exports.cobalt_core:Notify(locale('ignition.hotwire_refused'), 'error')
        return
    end

    hotwiring = true

    local finished <const> = exports.cobalt_core:Progressbar({
        label = locale('ignition.hotwiring'),
        duration = config.hotwire.duration,
        icon = 'wrench',
        canCancel = true,
        disable = { move = true, car = true, combat = true },
        anim = { dict = HOTWIRE_DICT, clip = HOTWIRE_CLIP, flag = 49 },
    })

    hotwiring = false

    if not finished then
        exports.cobalt_core:Notify(locale('ignition.hotwire_cancelled'), 'info')
        return
    end

    if not lib.callback.await('cobalt_vehiclekeys:finishHotwire', false, netId) then
        exports.cobalt_core:Notify(locale('ignition.hotwire_failed'), 'error')
        return
    end

    Ignition.start(vehicle)
end

local hotwireKeybind <const> = lib.addKeybind({
    name = 'cobalt_vk_hotwire',
    description = locale('keybind.hotwire'),
    defaultKey = config.hotwireKey,
    onPressed = function()
        if hotwiring or not keyless or keyless ~= cache.vehicle then return end
        if GetIsVehicleEngineRunning(keyless) then return end

        hotwire(keyless)
    end,
})

---@param vehicle integer
local function hold(vehicle)
    keyless = vehicle

    SetVehicleEngineOn(vehicle, false, true, true)
    SetVehicleUndriveable(vehicle, true)
    SetHornEnabled(vehicle, false)
    exports.cobalt_core:ShowTextUI(locale('ignition.hotwire_prompt'), {
        key = hotwireKeybind:getCurrentKey(),
        position = 'left-center',
    })
end

---@param vehicle integer
local function onDriverSeat(vehicle)
    SetVehicleNeedsToBeHotwired(vehicle, false)
    SetVehicleRadioLoud(vehicle, config.loudRadio)

    if GetVehicleClass(vehicle) == CYCLE_CLASS then return end
    if Keys.has(vehicle) or Keys.refresh(vehicle) then return end
    if not stillDriving(vehicle) then return end

    local netId <const> = Keys.netId(vehicle)

    if not netId then return end

    if GetIsVehicleEngineRunning(vehicle) and lib.callback.await('cobalt_vehiclekeys:claimRunning', false, netId) then
        Keys.add(Keys.plateOf(vehicle))
        return
    end

    if not stillDriving(vehicle) then return end

    hold(vehicle)
end

RegisterCommand('engine', toggleDriven, false)
TriggerEvent('chat:addSuggestion', '/engine', locale('commands.engine'))

lib.addKeybind({
    name = 'cobalt_vk_ignition',
    description = locale('keybind.engine'),
    defaultKey = config.engineKey,
    onPressed = toggleDriven,
})

setEngineFlag(cache.ped)
lib.onCache('ped', setEngineFlag)

lib.onCache('seat', function(seat)
    if seat ~= -1 then return release() end
    if cache.vehicle then onDriverSeat(cache.vehicle) end
end)

lib.onCache('vehicle', function(vehicle)
    if not vehicle then release() end
end)

AddEventHandler('cobalt_vehiclekeys:keysGranted', function()
    if keyless and Keys.has(keyless) then release() end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == cache.resource then release() end
end)

return Ignition
