---@class VehicleKeysSkillCheck
---@field difficulty table
---@field inputs string[]
---@field minMs integer

---@class VehicleKeysAnim
---@field dict string
---@field clip string

---@class VehicleKeysIgnition
---@field anim VehicleKeysAnim
---@field bikeAnim VehicleKeysAnim
---@field crankMs integer
---@field failedCrankMs integer
---@field retryMs integer
---@field stopMs integer
---@field maxFailedCranks integer
---@field failChance number
---@field damageFailChance number
---@field lowFuel number
---@field lowFuelFailChance number

---@class VehicleKeysSharedKey
---@field requireOnDuty boolean
---@field vehicles table<number, true>

return {
    -- Keys and keybinds (players can rebind them in GTA settings)
    keyfob = true, -- true opens the keyfob menu on lockKey; false makes lockKey a plain lock toggle
    lockKey = 'L', -- default key to lock and unlock, or open the keyfob
    hotwireKey = 'E', -- default key to hotwire a vehicle without keys
    robKey = 'E', -- default key to take the keys from a held-up driver
    engineKey = 'G', -- default key to start or stop the engine

    -- Starting the engine
    ---@type VehicleKeysIgnition
    ignition = {
        anim = { dict = 'veh@std@ds@base', clip = 'start_engine' }, -- key-turn animation in cars
        bikeAnim = { dict = 'veh@bike@sport@front@base', clip = 'start_engine' }, -- key-turn animation on bikes
        crankMs = 1200, -- milliseconds a successful crank takes
        failedCrankMs = 800, -- milliseconds a failed crank takes
        retryMs = 600, -- milliseconds between failed cranks
        stopMs = 700, -- milliseconds to switch the engine off
        maxFailedCranks = 3, -- failed cranks before the engine starts anyway (or gives up when out of fuel or wrecked)
        failChance = 0.04, -- chance each crank fails on a healthy, fuelled vehicle, 0.0 to 1.0
        damageFailChance = 0.6, -- extra fail chance at zero engine health, scaled by damage
        lowFuel = 15.0, -- fuel level below which cranks start to fail more often
        lowFuelFailChance = 0.35, -- extra fail chance at empty, scaled by how far below lowFuel
    },

    -- Locals' vehicles
    npc = {
        parkedLockChance = 0.7, -- chance a parked local vehicle is locked, 0.0 to 1.0
        drivingLockChance = 0.3, -- chance a driven local vehicle is locked
    },

    -- Lockpick items and the chance each attempt breaks one, passed or failed, 0.0 to 1.0; names must exist in cobalt_inventory
    ---@type table<string, number>
    lockpickItems = {
        lockpick = 0.35,
        advancedlockpick = 0.1,
    },

    -- Skill check to pick a door lock: cobalt_core SkillCheck difficulties and the keys to press
    ---@type VehicleKeysSkillCheck
    doorLockpick = {
        difficulty = { 'easy', 'easy', { areaSize = 60, speedMultiplier = 1 }, 'medium' }, -- one entry per stage: 'easy', 'medium', 'hard' or a custom table
        inputs = { '1', '2', '3', '4' }, -- keys the skill check can ask for
        minMs = 2000, -- fewest milliseconds a real pass takes; the server rejects faster ones
    },

    -- Skill check to pick the ignition
    ---@type VehicleKeysSkillCheck
    ignitionLockpick = {
        difficulty = { 'easy', 'medium', 'medium' }, -- one entry per stage: 'easy', 'medium', 'hard' or a custom table
        inputs = { 'w', 'a', 's', 'd' }, -- keys the skill check can ask for
        minMs = 1200, -- fewest milliseconds a real pass takes; the server rejects faster ones
    },

    -- Hotwiring
    hotwire = {
        duration = 10000, -- milliseconds a hotwire takes
        alarmChance = 0.2, -- chance the alarm goes off, 0.0 to 1.0
    },

    -- Carjacking
    holdupSeconds = 120, -- seconds a driver held at gunpoint waits before fleeing without handing over the keys

    -- Ranges, in meters
    distance = {
        lock = 15.0, -- key use: lock, unlock, doors, trunk, alarm and /givekey
        lockpick = 3.0, -- picking a door lock
        rob = 8.0, -- taking keys from a held-up driver
        giveKey = 5.0, -- handing keys to another player
    },

    -- Seat and engine behaviour for players
    player = {
        kick = true, -- the driver can push passengers out by entering their seat
        shuffle = false, -- passengers slide into the driver's seat on their own
        autoEngine = false, -- engines start and stop by themselves when entering and leaving
    },

    -- Vehicle models that never lock, as [`model`] = true
    ---@type table<number, true>
    noLock = {},

    -- Vehicle models whose drivers can't be carjacked
    ---@type table<number, true>
    noCarjack = {
        [`stockade`] = true,
    },

    -- Job vehicles any member can drive without a key, keyed by job name or job type (leo, ems, mechanic)
    ---@type table<string, VehicleKeysSharedKey>
    sharedKeys = {
        police = {
            requireOnDuty = true, -- members must be on duty to drive these without a key
            vehicles = { -- models covered, as [`model`] = true
                [`police`] = true,
                [`police2`] = true,
                [`police3`] = true,
                [`policet`] = true,
                [`sheriff`] = true,
                [`sheriff2`] = true,
                [`fbi`] = true,
                [`fbi2`] = true,
            },
        },
        ambulance = {
            requireOnDuty = true,
            vehicles = {
                [`ambulance`] = true,
                [`lguard`] = true,
            },
        },
        mechanic = {
            requireOnDuty = false,
            vehicles = {
                [`towtruck`] = true,
                [`flatbed`] = true,
            },
        },
    },

    -- Radio
    loudRadio = true, -- people outside a vehicle hear its radio
}
