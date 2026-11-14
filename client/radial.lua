local Keys <const> = require 'client.keys'
local Ignition <const> = require 'client.ignition'

local REACH <const> = 3.0
local MAX_EXTRAS <const> = 12

local core <const> = exports.cobalt_core

---@type table<integer, table<integer, boolean>>
local windowsDown <const> = {}

---@return integer?
local function targetVehicle()
    if cache.vehicle then return cache.vehicle end

    return (lib.getClosestVehicle(GetEntityCoords(cache.ped), REACH, false))
end

---@return boolean
local function inside()
    return cache.vehicle ~= false
end

---@return boolean
local function driving()
    return inside() and cache.seat == -1
end

---@return boolean
local function noKeys()
    local vehicle <const> = targetVehicle()

    return not vehicle or not Keys.has(vehicle)
end

---@param door integer
local function toggleDoor(door)
    local vehicle <const> = targetVehicle()
    local netId <const> = vehicle and Keys.netId(vehicle)

    if not netId then return end

    CreateThread(function() lib.callback.await('cobalt_vehiclekeys:toggleDoor', false, netId, door) end)
end

---@param window integer
local function toggleWindow(window)
    local vehicle <const> = cache.vehicle
    if not vehicle then return end

    local states <const> = windowsDown[vehicle] or {}
    windowsDown[vehicle] = states

    if states[window] then
        RollUpWindow(vehicle, window)
    else
        RollDownWindow(vehicle, window)
    end

    states[window] = not states[window]
end

local function toggleEngine()
    local vehicle <const> = cache.vehicle

    if vehicle then CreateThread(function() Ignition.toggle(vehicle) end) end
end

---@param seat integer
local function moveToSeat(seat)
    local vehicle <const> = cache.vehicle
    if not vehicle or not IsVehicleSeatFree(vehicle, seat) then return end

    SetPedIntoVehicle(cache.ped, vehicle, seat)
end

---@param extra integer
local function toggleExtra(extra)
    local vehicle <const> = cache.vehicle
    if not vehicle or not NetworkHasControlOfEntity(vehicle) then return end

    SetVehicleExtra(vehicle, extra, IsVehicleExtraTurnedOn(vehicle, extra))
end

---@param door integer
---@return boolean
local function hasDoor(door)
    local vehicle <const> = targetVehicle()

    return vehicle ~= nil and GetIsDoorValid(vehicle, door)
end

---@param seat integer
---@return boolean
local function seatFree(seat)
    local vehicle <const> = cache.vehicle
    if not vehicle then return false end
    if seat >= GetVehicleMaxNumberOfPassengers(vehicle) then return false end

    return IsVehicleSeatFree(vehicle, seat)
end

---@return boolean
local function hasExtras()
    local vehicle <const> = cache.vehicle
    if not vehicle then return false end

    for extra = 1, MAX_EXTRAS do
        if DoesExtraExist(vehicle, extra) then return true end
    end

    return false
end

local doors <const> = {
    { door = 0, labelKey = 'radial.front_left' },
    { door = 1, labelKey = 'radial.front_right' },
    { door = 2, labelKey = 'radial.rear_left' },
    { door = 3, labelKey = 'radial.rear_right' },
    { door = 4, labelKey = 'radial.hood' },
    { door = 5, labelKey = 'radial.trunk' },
}

local doorItems <const> = {}

for _, entry in ipairs(doors) do
    doorItems[#doorItems + 1] = {
        id = ('vehiclekeys:door:%d'):format(entry.door),
        label = locale(entry.labelKey),
        icon = entry.door == 5 and 'package' or 'door',
        keepOpen = true,
        canInteract = function() return hasDoor(entry.door) end,
        disabled = noKeys,
        onSelect = function() toggleDoor(entry.door) end,
    }
end

local windows <const> = {
    { window = 0, door = 0, labelKey = 'radial.front_left' },
    { window = 1, door = 1, labelKey = 'radial.front_right' },
    { window = 2, door = 2, labelKey = 'radial.rear_left' },
    { window = 3, door = 3, labelKey = 'radial.rear_right' },
}

local windowItems <const> = {}

for _, entry in ipairs(windows) do
    windowItems[#windowItems + 1] = {
        id = ('vehiclekeys:window:%d'):format(entry.window),
        label = locale(entry.labelKey),
        icon = 'arrows-down-up',
        keepOpen = true,
        canInteract = function() return inside() and hasDoor(entry.door) end,
        onSelect = function() toggleWindow(entry.window) end,
    }
end

local seats <const> = {
    { seat = -1, labelKey = 'radial.driver' },
    { seat = 0, labelKey = 'radial.passenger' },
    { seat = 1, labelKey = 'radial.rear_left' },
    { seat = 2, labelKey = 'radial.rear_right' },
    { seat = 3, labelKey = 'radial.seat_5' },
    { seat = 4, labelKey = 'radial.seat_6' },
}

local seatItems <const> = {}

for _, entry in ipairs(seats) do
    seatItems[#seatItems + 1] = {
        id = ('vehiclekeys:seat:%d'):format(entry.seat),
        label = locale(entry.labelKey),
        icon = entry.seat == -1 and 'steering-wheel' or 'armchair',
        canInteract = function() return seatFree(entry.seat) end,
        onSelect = function() moveToSeat(entry.seat) end,
    }
end

local extraItems <const> = {}

for extra = 1, MAX_EXTRAS do
    extraItems[#extraItems + 1] = {
        id = ('vehiclekeys:extra:%d'):format(extra),
        label = locale('radial.extra', extra),
        icon = 'sliders-horizontal',
        keepOpen = true,
        canInteract = function() return cache.vehicle and DoesExtraExist(cache.vehicle, extra) or false end,
        onSelect = function() toggleExtra(extra) end,
    }
end

core:RegisterRadial({ id = 'vehiclekeys:doors', label = locale('radial.doors'), items = doorItems })
core:RegisterRadial({ id = 'vehiclekeys:windows', label = locale('radial.windows'), items = windowItems })
core:RegisterRadial({ id = 'vehiclekeys:seats', label = locale('radial.seats'), items = seatItems })
core:RegisterRadial({ id = 'vehiclekeys:extras', label = locale('radial.extras'), items = extraItems })

core:RegisterRadial({
    id = 'vehiclekeys:vehicle',
    label = locale('radial.vehicle'),
    items = {
        {
            id = 'vehiclekeys:engine',
            label = locale('radial.engine'),
            icon = 'power',
            canInteract = driving,
            disabled = noKeys,
            onSelect = toggleEngine,
        },
        { id = 'vehiclekeys:doors', label = locale('radial.doors'), icon = 'door', menu = 'vehiclekeys:doors' },
        { id = 'vehiclekeys:windows', label = locale('radial.windows'), icon = 'arrows-down-up', menu = 'vehiclekeys:windows', canInteract = inside },
        { id = 'vehiclekeys:seats', label = locale('radial.seats'), icon = 'armchair', menu = 'vehiclekeys:seats', canInteract = inside },
        {
            id = 'vehiclekeys:extras',
            label = locale('radial.extras'),
            icon = 'sliders-horizontal',
            menu = 'vehiclekeys:extras',
            canInteract = function() return driving() and hasExtras() end,
            disabled = noKeys,
        },
    },
})

core:AddRadialItem({
    id = 'vehiclekeys:vehicle',
    label = locale('radial.vehicle'),
    icon = 'car',
    menu = 'vehiclekeys:vehicle',
    canInteract = function() return targetVehicle() ~= nil end,
})

lib.onCache('vehicle', function(vehicle)
    if not vehicle then table.wipe(windowsDown) end
end)
