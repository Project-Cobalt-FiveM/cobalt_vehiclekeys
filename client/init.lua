local config <const> = require 'config'
local Keys <const> = require 'client.keys'
local Lock <const> = require 'client.lock'
local Keyfob <const> = require 'client.keyfob'

require 'client.ignition'
require 'client.lockpick'
require 'client.carjack'
require 'client.radial'

local PED_FLAG_WARP_SEAT_PRIORITY <const> = 328
local PED_FLAG_DISABLE_WINDOW_SMASH <const> = 448
local PED_FLAG_AUTO_LOCKPICK <const> = 426
local PED_FLAG_KICK_PASSENGERS <const> = 252
local PED_FLAG_PREVENT_AUTO_SHUFFLE <const> = 184
local PED_FLAG_DRIVER_SEAT_ONLY <const> = 366
local PED_FLAG_TURRET_SEAT <const> = 360
local PED_FLAG_AUTO_ENGINE_STOP <const> = 241

---@param ped integer
local function setPedFlags(ped)
    SetPedConfigFlag(ped, PED_FLAG_WARP_SEAT_PRIORITY, true)
    SetPedConfigFlag(ped, PED_FLAG_DISABLE_WINDOW_SMASH, true)
    SetPedConfigFlag(ped, PED_FLAG_AUTO_LOCKPICK, false)
    SetPedConfigFlag(ped, PED_FLAG_KICK_PASSENGERS, config.player.kick)
    SetPedConfigFlag(ped, PED_FLAG_PREVENT_AUTO_SHUFFLE, not config.player.shuffle)
    SetPedConfigFlag(ped, PED_FLAG_DRIVER_SEAT_ONLY, not config.player.shuffle)
    SetPedConfigFlag(ped, PED_FLAG_TURRET_SEAT, not config.player.shuffle)
    SetPedConfigFlag(ped, PED_FLAG_AUTO_ENGINE_STOP, not config.player.autoEngine)
end

---@param keybind CKeybind
local function useKeys(keybind)
    if IsNuiFocused() or IsPauseMenuActive() then return end

    local vehicle <const> = Keys.nearest(config.distance.lock)

    if not vehicle then
        exports.cobalt_core:Notify(locale('keys.none_nearby'), 'error')
        return
    end

    if config.noLock[GetEntityModel(vehicle)] then
        exports.cobalt_core:Notify(locale('lock.cannot_lock'), 'error')
        return
    end

    if config.keyfob then return Keyfob.open(vehicle, keybind:getCurrentKey()) end

    Lock.toggle(vehicle)
end

setPedFlags(cache.ped)
lib.onCache('ped', setPedFlags)

lib.addKeybind({
    name = 'cobalt_vk_lock',
    description = locale(config.keyfob and 'keybind.keyfob' or 'keybind.lock'),
    defaultKey = config.lockKey,
    onPressed = useKeys,
})

if not config.player.shuffle then
    local SHUFFLE_WINDOW <const> = 3000

    local shuffling = false

    RegisterCommand('shuff', function()
        if shuffling or not cache.vehicle then return end

        shuffling = true
        SetPedConfigFlag(cache.ped, PED_FLAG_PREVENT_AUTO_SHUFFLE, false)
        Wait(SHUFFLE_WINDOW)
        SetPedConfigFlag(cache.ped, PED_FLAG_PREVENT_AUTO_SHUFFLE, true)
        shuffling = false
    end, false)

    TriggerEvent('chat:addSuggestion', '/shuff', locale('commands.shuff'))
end
