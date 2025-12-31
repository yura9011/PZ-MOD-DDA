-- DDA Debug Commands
-- Console commands for testing Remote Start and other systems
-- Usage: Open debug console and type the command

local CS_DebugCommands = {}

local CS_Config = require("DDA/CS_Config")
local CS_RemoteStart = require("DDA/CS_RemoteStart")

-- ============================================================================
-- REMOTE START DEBUG
-- ============================================================================

--- Force teleport to a specific spawn location by index
--- Usage: CS_Debug.teleportTo(1) -- Teleports to first spawn (Graffiti Basement)
function CS_DebugCommands.teleportTo(index)
    local player = getPlayer()
    if not player then 
        print("[CS_Debug] ERROR: No player found")
        return 
    end
    
    local spawns = CS_Config.SpawnLocations
    if not spawns or #spawns == 0 then
        print("[CS_Debug] ERROR: No spawn locations configured")
        return
    end
    
    index = index or 1
    if index < 1 or index > #spawns then
        print("[CS_Debug] ERROR: Invalid index. Use 1 to " .. #spawns)
        return
    end
    
    local spawn = spawns[index]
    CS_RemoteStart.teleportToSpawn(player, spawn)
    print("[CS_Debug] Teleported to: " .. spawn.name .. " (" .. spawn.x .. ", " .. spawn.y .. ", " .. spawn.z .. ")")
end

--- List all spawn locations
function CS_DebugCommands.listSpawns()
    print("[CS_Debug] === Spawn Locations ===")
    for i, spawn in ipairs(CS_Config.SpawnLocations) do
        print(string.format("  [%d] %s: (%d, %d, %d)", i, spawn.name, spawn.x, spawn.y, spawn.z))
    end
end

--- Check current player spawn status
function CS_DebugCommands.checkStatus()
    local player = getPlayer()
    if not player then 
        print("[CS_Debug] ERROR: No player found")
        return 
    end
    
    local md = player:getModData()
    local spawned = md.CS_Spawned and "YES" or "NO"
    local x, y, z = math.floor(player:getX()), math.floor(player:getY()), math.floor(player:getZ())
    
    print("[CS_Debug] === Player Status ===")
    print("  Position: " .. x .. ", " .. y .. ", " .. z)
    print("  CS_Spawned flag: " .. spawned)
    print("  isServer: " .. tostring(isServer()))
    print("  isClient: " .. tostring(isClient()))
end

--- Reset spawn flag (allows re-testing spawn on next character create)
function CS_DebugCommands.resetSpawnFlag()
    local player = getPlayer()
    if not player then 
        print("[CS_Debug] ERROR: No player found")
        return 
    end
    
    player:getModData().CS_Spawned = nil
    print("[CS_Debug] CS_Spawned flag reset. Next character creation will trigger teleport.")
end

--- Force spawn flag (prevents teleport on next character create)
function CS_DebugCommands.setSpawnFlag()
    local player = getPlayer()
    if not player then 
        print("[CS_Debug] ERROR: No player found")
        return 
    end
    
    player:getModData().CS_Spawned = true
    print("[CS_Debug] CS_Spawned flag set. Teleport will NOT trigger.")
end

-- ============================================================================
-- RADIATION DEBUG
-- ============================================================================

--- Start a radiation event
--- Usage: CS_Debug.startRadiation("red") or CS_Debug.startRadiation("green")
function CS_DebugCommands.startRadiation(radiationType)
    radiationType = radiationType or "green"
    if _G.CS_RadiationEvents then
        _G.CS_RadiationEvents.startEvent(radiationType)
        print("[CS_Debug] Started " .. radiationType .. " radiation event")
    else
        print("[CS_Debug] ERROR: CS_RadiationEvents not loaded (run on server/SP)")
    end
end

--- Stop current radiation event
function CS_DebugCommands.stopRadiation()
    if _G.CS_RadiationEvents then
        _G.CS_RadiationEvents.endEvent()
        print("[CS_Debug] Radiation event ended")
    else
        print("[CS_Debug] ERROR: CS_RadiationEvents not loaded")
    end
end

-- ============================================================================
-- EXPORT
-- ============================================================================

-- Make available globally for console
_G.CS_Debug = CS_DebugCommands

print("[CS_DebugCommands] Loaded. Use CS_Debug.listSpawns(), CS_Debug.checkStatus(), etc.")

return CS_DebugCommands
