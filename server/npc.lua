local config <const> = require 'config'
local Keys <const> = require 'server.keys'

local LOCK_DELAY_MS <const> = 1000

---@param entity integer
local function rollLock(entity)
    if not DoesEntityExist(entity) or Keys.isHeld(Keys.plateOf(entity)) then return end

    local parked <const> = GetPedInVehicleSeat(entity, -1) == 0
    local chance <const> = parked and config.npc.parkedLockChance or config.npc.drivingLockChance

    if math.random() >= chance then return end

    SetVehicleDoorsLocked(entity, 2)
end

AddEventHandler('entityCreated', function(entity)
    if not DoesEntityExist(entity) or GetEntityType(entity) ~= 2 then return end
    if not Keys.isAmbient(entity) or GetVehicleType(entity) ~= 'automobile' then return end

    SetTimeout(LOCK_DELAY_MS, function()
        rollLock(entity)
    end)
end)
