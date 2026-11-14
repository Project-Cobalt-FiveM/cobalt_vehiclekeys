local config <const> = require 'config'
local Keys <const> = require 'client.keys'

local AIM_CHECK_MS <const> = 500
local HOLD_CHECK_MS <const> = 250
local EXIT_TIMEOUT_MS <const> = 3000
local REFUSAL_RETRY_MS <const> = 3000
local HANDS_UP_DICT <const> = 'random@mugging3'
local HANDS_UP_CLIP <const> = 'handsup_standing_base'

---@class Holdup
---@field ped integer
---@field netId integer
---@field interval integer

---@type Holdup?
local holdup

---@type integer?
local aimWatch

---@type integer?
local refused
local refusedUntil = 0

---@type table<integer, true>
local surrendering <const> = {}

local robKeybind

---@param ped integer
---@return integer?
local function hijackableVehicle(ped)
    if not IsEntityAPed(ped) or IsPedAPlayer(ped) or IsPedDeadOrDying(ped, true) then return end

    local vehicle <const> = GetVehiclePedIsIn(ped, false)

    if vehicle == 0 or GetPedInVehicleSeat(vehicle, -1) ~= ped then return end
    if config.noCarjack[GetEntityModel(vehicle)] or Keys.has(vehicle) then return end
    if #(GetEntityCoords(cache.ped) - GetEntityCoords(ped)) > config.distance.rob then return end

    return vehicle
end

---@param netId integer
---@return integer?
local function ownedPed(netId)
    local ped <const> = NetworkDoesNetworkIdExist(netId) and NetworkGetEntityFromNetworkId(netId) or 0

    if ped == 0 or not NetworkHasControlOfEntity(ped) or IsPedDeadOrDying(ped, true) then return end

    return ped
end

---@param ped integer
local function surrender(ped)
    surrendering[ped] = true
    TaskSetBlockingOfNonTemporaryEvents(ped, true)
    TaskLeaveAnyVehicle(ped, 0, 256)

    local deadline <const> = GetGameTimer() + EXIT_TIMEOUT_MS

    while IsPedInAnyVehicle(ped, false) and GetGameTimer() < deadline do Wait(100) end

    lib.requestAnimDict(HANDS_UP_DICT)

    if surrendering[ped] then
        surrendering[ped] = nil
        TaskPlayAnim(ped, HANDS_UP_DICT, HANDS_UP_CLIP, 8.0, 8.0, -1, 49, 0, false, false, false)
    end

    RemoveAnimDict(HANDS_UP_DICT)
end

---@param ped integer
---@return boolean
local function stillHeld(ped)
    if not DoesEntityExist(ped) or cache.vehicle then return false end
    if #(GetEntityCoords(cache.ped) - GetEntityCoords(ped)) > config.distance.rob then return false end

    local aiming <const>, target <const> = GetEntityPlayerIsFreeAimingAt(cache.playerId)

    return aiming and target == ped
end

local function clearHoldup()
    ClearInterval(holdup.interval)
    holdup = nil
    robKeybind:disable(true)
    exports.cobalt_core:HideTextUI()
end

local function release()
    if not holdup then return end

    clearHoldup()
    TriggerServerEvent('cobalt_vehiclekeys:endHoldup')
end

local function giveUp()
    release()
    exports.cobalt_core:Notify(locale('carjack.fled'), 'error')
end

local function takeKeys()
    if not holdup then return end

    if lib.callback.await('cobalt_vehiclekeys:robKeys', false, holdup.netId) == nil then return end

    release()
end

robKeybind = lib.addKeybind({
    name = 'cobalt_vk_rob',
    description = locale('keybind.rob'),
    defaultKey = config.robKey,
    disabled = true,
    onPressed = takeKeys,
})

local function offerKeys()
    robKeybind:disable(false)
    exports.cobalt_core:ShowTextUI(locale('carjack.prompt'), { key = robKeybind:getCurrentKey(), position = 'left-center' })
end

---@param ped integer
---@param vehicle integer
local function holdUp(ped, vehicle)
    local netId <const> = Keys.netId(vehicle)

    if not netId then return end

    if not lib.callback.await('cobalt_vehiclekeys:startHoldup', false, netId) then
        refused = vehicle
        refusedUntil = GetGameTimer() + REFUSAL_RETRY_MS
        return
    end

    local fleesAt <const> = GetGameTimer() + config.holdupSeconds * 1000
    local exitBy <const> = GetGameTimer() + EXIT_TIMEOUT_MS
    local offered = false

    holdup = {
        ped = ped,
        netId = netId,
        interval = SetInterval(function()
            if IsPedDeadOrDying(ped, true) then return takeKeys() end
            if GetGameTimer() >= fleesAt then return giveUp() end

            local seated <const> = IsPedInAnyVehicle(ped, false)

            if seated and GetGameTimer() < exitBy then return end
            if not stillHeld(ped) then return release() end
            if seated or offered then return end

            offered = true
            offerKeys()
        end, HOLD_CHECK_MS),
    }
end

local function watchAim()
    if holdup or cache.vehicle then return end

    local aiming <const>, target <const> = GetEntityPlayerIsFreeAimingAt(cache.playerId)
    local vehicle <const> = aiming and hijackableVehicle(target)

    if vehicle and (vehicle ~= refused or GetGameTimer() >= refusedUntil) then holdUp(target, vehicle) end
end

---@param weapon number | false
local function onWeapon(weapon)
    if weapon and not aimWatch then
        aimWatch = SetInterval(watchAim, AIM_CHECK_MS)
        return
    end

    if weapon or not aimWatch then return end

    ClearInterval(aimWatch)
    aimWatch = nil
    release()
end

RegisterNetEvent('cobalt_vehiclekeys:surrender', function(netId)
    local ped <const> = ownedPed(netId)

    if ped then surrender(ped) end
end)

RegisterNetEvent('cobalt_vehiclekeys:flee', function(netId, robber)
    local ped <const> = ownedPed(netId)

    if not ped then return end

    surrendering[ped] = nil
    ClearPedTasks(ped)
    TaskSetBlockingOfNonTemporaryEvents(ped, false)

    local player <const> = GetPlayerFromServerId(robber)

    if player ~= -1 then TaskReactAndFleePed(ped, GetPlayerPed(player)) end
end)

lib.onCache('weapon', onWeapon)
onWeapon(cache.weapon)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource or not holdup then return end

    clearHoldup()
end)
