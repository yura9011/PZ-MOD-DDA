-- DDA Remote Start System
-- Teleports new players to predefined spawn locations
-- Requirements: 9.1, 9.3, 9.4

local CS_RemoteStart = {}

-- Load configuration
local CS_Config = require("DDA/CS_Config")

-- ============================================================================
-- STATE
-- ============================================================================

CS_RemoteStart.initialized = false

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================

--- Get a random spawn location from the configured list
--- @return table spawnLocation {x, y, z, name}
function CS_RemoteStart.getRandomSpawn()
    local spawns = CS_Config.SpawnLocations
    if not spawns or #spawns == 0 then
        print("[CS_RemoteStart] ERROR: No spawn locations configured!")
        return nil
    end
    
    -- Check for forced debug spawn
    if CS_Config.Debug and CS_Config.Debug.forceSpawnIndex then
        local idx = CS_Config.Debug.forceSpawnIndex
        if spawns[idx] then
            print("[CS_RemoteStart] DEBUG: Forcing spawn at index " .. idx .. ": " .. spawns[idx].name)
            return spawns[idx]
        else
             print("[CS_RemoteStart] WARNING: Invalid forceSpawnIndex " .. idx .. ". Using random.")
        end
    end
    
    -- ZombRand returns 0 to n-1, so add 1 for Lua 1-based indexing
    local index = ZombRand(#spawns) + 1
    return spawns[index]
end

--- Teleport a player to a specific spawn location
--- @param player IsoPlayer The player to teleport
--- @param spawnLocation table {x, y, z, name}
--- @return boolean success Whether the teleport was successful
function CS_RemoteStart.teleportToSpawn(player, spawnLocation)
    if not player then
        print("[CS_RemoteStart] ERROR: Player is nil!")
        return false
    end
    
    if not spawnLocation then
        print("[CS_RemoteStart] ERROR: Spawn location is nil!")
        return false
    end
    
    local x = spawnLocation.x
    local y = spawnLocation.y
    local z = spawnLocation.z
    local name = spawnLocation.name or "Unknown"
    
    -- Validate coordinates
    if not x or not y or not z then
        print("[CS_RemoteStart] ERROR: Invalid spawn coordinates!")
        return false
    end
    
    -- Perform teleport
    player:setX(x)
    player:setY(y)
    player:setZ(z)
    
    -- Log the teleport
    if CS_Config.Debug and CS_Config.Debug.enabled then
        print(string.format("[CS_RemoteStart] Teleported player to '%s' (%d, %d, %d)", 
            name, x, y, z))
    end
    
    return true
end

--- Check if a player's position matches a predefined spawn location
--- @param player IsoPlayer The player to check
--- @return boolean isAtSpawn Whether the player is at a predefined spawn
--- @return table|nil matchedSpawn The matched spawn location or nil
function CS_RemoteStart.isAtPredefinedSpawn(player)
    if not player then return false, nil end
    
    local px = player:getX()
    local py = player:getY()
    local pz = player:getZ()
    
    for _, spawn in ipairs(CS_Config.SpawnLocations) do
        -- Check if player is at this spawn (with small tolerance for floating point)
        if math.abs(px - spawn.x) < 1 and 
           math.abs(py - spawn.y) < 1 and 
           math.abs(pz - spawn.z) < 1 then
            return true, spawn
        end
    end
    
    return false, nil
end

-- ============================================================================
-- BLACKOUT SYSTEM (Immersive Spawn)
-- ============================================================================

CS_RemoteStart.blackoutPanel = nil
CS_RemoteStart.isFading = false

--- Update the blackout fading
function CS_RemoteStart.updateBlackout()
    if not CS_RemoteStart.blackoutPanel or not CS_RemoteStart.isFading then return end
    
    local panel = CS_RemoteStart.blackoutPanel
    local currentAlpha = panel.backgroundColor.a
    
    if currentAlpha > 0 then
        panel.backgroundColor.a = currentAlpha - 0.01 -- Fade speed
    else
        panel.backgroundColor.a = 0
        panel:removeFromUIManager()
        CS_RemoteStart.blackoutPanel = nil
        CS_RemoteStart.isFading = false
        Events.OnTick.Remove(CS_RemoteStart.updateBlackout)
    end
end


-- ============================================================================
-- EVENT HANDLERS
-- ============================================================================

--- Handler for OnCreatePlayer event
--- Teleports new players to a random predefined spawn location with blackout
--- @param playerIndex number The player index (0-based)
--- @param player IsoPlayer The player object
function CS_RemoteStart.onCreatePlayer(playerIndex, player)
    if not player then return end
    
    -- Check if player has already spawned via this system
    local md = player:getModData()
    if md.CS_Spawned then
        return
    end

    -- Get a random spawn location
    local spawn = CS_RemoteStart.getRandomSpawn()
    if not spawn then return end

    -- Enable Blackout immediately using ISPanel
    local core = getCore()
    local w, h = core:getScreenWidth(), core:getScreenHeight()
    local panel = ISPanel:new(0, 0, w, h)
    panel:initialise()
    panel.backgroundColor = {r=0, g=0, b=0, a=1}
    panel:addToUIManager()
    CS_RemoteStart.blackoutPanel = panel

    -- Use OnTick to ensure world is loaded before teleport
    local ticks = 0
    local function doTeleport()
        ticks = ticks + 1
        if ticks >= 20 then -- Wait slightly longer (300ms) to ensure world chunks load
            Events.OnTick.Remove(doTeleport)
            
            -- Teleport
            CS_RemoteStart.teleportToSpawn(player, spawn)
            md.CS_Spawned = true
            
            -- Start Fade Out after teleport
            CS_RemoteStart.isFading = true
            Events.OnTick.Add(CS_RemoteStart.updateBlackout)
        end
    end
    
    Events.OnTick.Add(doTeleport)
end

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

--- Initialize the Remote Start system
function CS_RemoteStart.init()
    if CS_RemoteStart.initialized then
        return
    end
    
    -- Validate configuration
    if not CS_Config.SpawnLocations or #CS_Config.SpawnLocations == 0 then
        print("[CS_RemoteStart] ERROR: No spawn locations configured in CS_Config!")
        return
    end
    
    print(string.format("[CS_RemoteStart] Initialized with %d spawn locations", 
        #CS_Config.SpawnLocations))
    
    CS_RemoteStart.initialized = true
end

-- ============================================================================
-- EVENT REGISTRATION
-- ============================================================================

-- Register the OnCreatePlayer event handler
if Events and Events.OnCreatePlayer then
    Events.OnCreatePlayer.Add(CS_RemoteStart.onCreatePlayer)
    print("[CS_RemoteStart] Registered OnCreatePlayer event handler")
else
    print("[CS_RemoteStart] ERROR: Events.OnCreatePlayer not available!")
end

-- Initialize on game start
if Events and Events.OnGameStart then
    Events.OnGameStart.Add(CS_RemoteStart.init)
else
    -- Fallback: initialize immediately
    CS_RemoteStart.init()
end

-- Export for external access
_G.CS_RemoteStart = CS_RemoteStart

return CS_RemoteStart
