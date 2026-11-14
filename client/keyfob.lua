local config <const> = require 'config'
local Keys <const> = require 'client.keys'
local Lock <const> = require 'client.lock'

local Keyfob <const> = {}

---@type integer?
local current

local function close()
    current = nil
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

---@return table<string, string>
local function uiLocales()
    local strings <const> = {}

    for key, value in pairs(lib.getLocales()) do
        if key:sub(1, 3) == 'ui.' then strings[key] = value end
    end

    return strings
end

---@param vehicle integer
---@param closeKey string
function Keyfob.open(vehicle, closeKey)
    current = vehicle

    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'open',
        data = {
            label = Keys.labelOf(GetEntityModel(vehicle)),
            plate = Keys.plateOf(vehicle),
            locked = Lock.isLocked(vehicle),
        },
        closeKey = closeKey:lower(),
        locales = uiLocales(),
    })
end

---@param vehicle integer
---@return boolean
local function inReach(vehicle)
    return DoesEntityExist(vehicle) and #(GetEntityCoords(cache.ped) - GetEntityCoords(vehicle)) <= config.distance.lock
end

RegisterNUICallback('close', function(_, cb)
    close()
    cb({})
end)

RegisterNUICallback('action', function(data, cb)
    local vehicle <const> = current
    local action <const> = type(data) == 'table' and data.action

    if not vehicle or not inReach(vehicle) then
        close()
        exports.cobalt_core:Notify(locale('keyfob.out_of_range'), 'error')
        return cb({})
    end

    if action == 'lock' or action == 'unlock' then
        local locked = Lock.set(vehicle, action == 'lock')

        if locked == nil then locked = Lock.isLocked(vehicle) end

        return cb({ locked = locked })
    end

    if action == 'trunk' or action == 'alarm' then Lock.remote(vehicle, action) end

    cb({ locked = Lock.isLocked(vehicle) })
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource or not current then return end

    SetNuiFocus(false, false)
end)

return Keyfob
