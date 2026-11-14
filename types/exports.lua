---@meta

---@class CobaltVehiclekeysExports
local CobaltVehiclekeysExports = {}

---**Server.** Gives a player a key for a plate and notifies them with the plate when the key is new; false when the plate is not a string or the grant fails. Pass the vehicle so the key is dropped when that vehicle leaves the world and no player owns the plate.
---@param source integer server id
---@param plate string
---@param entity? integer server vehicle handle carrying the plate
---@return boolean
function CobaltVehiclekeysExports:GiveKey(source, plate, entity) end

---**Server.** Revokes every key for a plate.
---@param plate string
---@return boolean
function CobaltVehiclekeysExports:RemoveKeys(plate) end

---**Server.** Takes one player's key for a plate.
---@param source integer server id
---@param plate string
---@return boolean
function CobaltVehiclekeysExports:TakeKey(source, plate) end

---**Server.** Whether that player holds a key. Given a vehicle, it also counts the job's shared keys for its model and a key given for that vehicle under another plate. Given a plate, it checks that plate only. There is no client export: a client could fake its answer.
---@param source integer server id
---@param vehicle integer | string server vehicle handle, or a plate
---@return boolean
function CobaltVehiclekeysExports:HasKey(source, vehicle) end

exports.cobalt_vehiclekeys = CobaltVehiclekeysExports

---**Client.** The `lockpick` and `advancedlockpick` items' client export. On `usedItem` it picks the ignition of the vehicle the player sits in, or the door of the closest locked vehicle.
---@param event 'usingItem' | 'usedItem'
---@param item { name: string }
function CobaltVehiclekeysExports:UseLockpick(event, item) end
