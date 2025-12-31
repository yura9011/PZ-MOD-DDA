-- ============================================
-- DDA Expansion Debug Menu
-- Unified debug menu for testing all expansion features
-- Accessed via right-click context menu when Debug Mode is on
-- ============================================

local CS_DebugMenu = {}

-- Load dependencies
local CS_Config = require("DDA/CS_Config")
local CS_Client = require("DDA/CS_Client")

-- ============================================================================
-- UTILITY
-- ============================================================================

local function getPlayerAndSquare(playerNum, worldObjects)
    local player = getSpecificPlayer(playerNum)
    if not player then return nil, nil end
    
    local square = nil
    if worldObjects then
        for _, obj in ipairs(worldObjects) do
            if obj:getSquare() then
                square = obj:getSquare()
                break
            end
        end
    end
    
    if not square then
        square = player:getCurrentSquare()
    end
    
    return player, square
end

-- ============================================================================
-- RADIATION DEBUG
-- ============================================================================

local function addRadiationOptions(subMenu, player)
    subMenu:addOption("--- RADIATION (SERVER) ---", nil, nil)
    
    -- Start Green Radiation
    subMenu:addOption("Start GREEN Radiation", player, function()
        CS_Client.sendCommand("StartEvent", {type="green"})
        player:Say("[DEBUG] Sent StartEvent(green)")
    end)
    
    -- Start Violet Radiation
    subMenu:addOption("Start VIOLET Radiation", player, function()
        CS_Client.sendCommand("StartEvent", {type="violet"})
        player:Say("[DEBUG] Sent StartEvent(violet)")
    end)
    
    -- Start Red Radiation
    subMenu:addOption("Start RED Radiation", player, function()
        CS_Client.sendCommand("StartEvent", {type="red"})
        player:Say("[DEBUG] Sent StartEvent(red)")
    end)
    
    -- End Radiation
    subMenu:addOption("END Radiation", player, function()
        CS_Client.sendCommand("EndEvent")
        player:Say("[DEBUG] Sent EndEvent")
    end)
    
    -- Check Radiation Status
    subMenu:addOption("Check Radiation Status", player, function()
        CS_Client.sendCommand("CheckStatus")
    end)
    
    subMenu:addOption("--- OVERLAYS (CLIENT) ---", nil, nil)
    
    -- Test Overlays Directly
    subMenu:addOption("Test Overlay (Green)", player, function()
        if _G.CS_RadiationOverlay then
            _G.CS_RadiationOverlay.setOverlay("green", 0.5)
        end
    end)

    subMenu:addOption("Test Overlay (Violet)", player, function()
        if _G.CS_RadiationOverlay then
            _G.CS_RadiationOverlay.setOverlay("violet", 0.5)
        end
    end)

    subMenu:addOption("Test Overlay (Red)", player, function()
        if _G.CS_RadiationOverlay then
            _G.CS_RadiationOverlay.setOverlay("red", 0.5)
        end
    end)
    
    subMenu:addOption("Clear Overlay", player, function()
        if _G.CS_RadiationOverlay then
            _G.CS_RadiationOverlay.clear()
        end
    end)
end

-- ============================================================================
-- SPECIAL ZOMBIE DEBUG
-- ============================================================================

local function addZombieOptions(subMenu, player, square)
    subMenu:addOption("--- SPECIAL ZOMBIES ---", nil, nil)
    
    if not square then
        subMenu:addOption("(No square selected)", nil, nil)
        return
    end
    
    local x, y, z = square:getX(), square:getY(), square:getZ()
    
    -- Spawn Titan
    subMenu:addOption("Spawn TITAN (Juggernaut)", player, function()
        CS_Client.sendCommand("SpawnSpecial", {x=x, y=y, z=z, type="titan"})
    end)
    
    -- Spawn Stalker
    subMenu:addOption("Spawn STALKER", player, function()
        CS_Client.sendCommand("SpawnSpecial", {x=x, y=y, z=z, type="stalker"})
    end)
    
    -- Spawn Brute
    subMenu:addOption("Spawn BRUTE", player, function()
        CS_Client.sendCommand("SpawnSpecial", {x=x, y=y, z=z, type="brute"})
    end)
end

-- ============================================================================
-- TROPHY DEBUG
-- ============================================================================

local function addTrophyOptions(subMenu, player, square)
    subMenu:addOption("--- TROPHIES ---", nil, nil)
    
    if not square then return end
    local x, y, z = square:getX(), square:getY(), square:getZ()
    
    -- Drop Items
    subMenu:addOption("Drop TitanCore Here", player, function()
        CS_Client.sendCommand("DropItem", {x=x, y=y, z=z, item="DDA.TitanCore"})
    end)
    
    subMenu:addOption("Drop TitanWeapon Here", player, function()
        CS_Client.sendCommand("DropItem", {x=x, y=y, z=z, item="DDA.TitanWeapon"})
    end)
    
    subMenu:addOption("Drop StalkerEye Here", player, function()
        CS_Client.sendCommand("DropItem", {x=x, y=y, z=z, item="DDA.StalkerEye"})
    end)
    
    subMenu:addOption("Drop BruteArm Here", player, function()
        CS_Client.sendCommand("DropItem", {x=x, y=y, z=z, item="DDA.BruteArm"})
    end)
end

-- ============================================================================
-- REMOTE START DEBUG
-- ============================================================================

local function addRemoteStartOptions(subMenu, player)
    subMenu:addOption("--- REMOTE START ---", nil, nil)
    
    -- Teleport to each spawn
    for i, spawn in ipairs(CS_Config.SpawnLocations) do
        local label = string.format("Teleport to #%d: %s", i, spawn.name or "Unknown")
        subMenu:addOption(label, player, function()
            player:setX(spawn.x)
            player:setY(spawn.y)
            player:setZ(spawn.z)
            player:Say("[DEBUG] Teleported to " .. (spawn.name or "spawn " .. i))
        end)
    end
    
    -- Show current position
    subMenu:addOption("Show Current Position", player, function()
        local x = math.floor(player:getX())
        local y = math.floor(player:getY())
        local z = math.floor(player:getZ())
        player:Say(string.format("[DEBUG] Position: X:%d Y:%d Z:%d", x, y, z))
        print(string.format("[CS_Debug] Player position: X:%d Y:%d Z:%d", x, y, z))
    end)
end

-- ============================================================================
-- PROTECTION DEBUG
-- ============================================================================

local function addProtectionOptions(subMenu, player)
    subMenu:addOption("--- PROTECTION ---", nil, nil)
    
    -- Check if player is protected
    subMenu:addOption("Check Protection Status", player, function()
        local sq = player:getCurrentSquare()
        local room = sq and sq:getRoom()
        
        if room then
            player:Say("[DEBUG] INDOORS - Room: " .. tostring(room:getName()))
        else
            player:Say("[DEBUG] OUTDOORS - No room")
        end
    end)
end

-- ============================================================================
-- MAIN MENU BUILDER
-- ============================================================================

local function onFillWorldObjectContextMenu(playerNum, context, worldObjects, test)
    -- Only show in debug mode
    if not getDebug() and not (CS_Config.Debug and CS_Config.Debug.enabled) then
        return
    end
    
    local player, square = getPlayerAndSquare(playerNum, worldObjects)
    if not player then return end
    
    -- Create main debug submenu
    local mainOption = context:addOption("👾 DDA Expansion Debug", nil, nil)
    local subMenu = context:getNew(context)
    context:addSubMenu(mainOption, subMenu)
    
    -- Add all debug sections
    addRadiationOptions(subMenu, player)
    addZombieOptions(subMenu, player, square)
    addTrophyOptions(subMenu, player, square)
    addRemoteStartOptions(subMenu, player)
    addProtectionOptions(subMenu, player)
end

-- ============================================================================
-- EVENT REGISTRATION
-- ============================================================================

Events.OnFillWorldObjectContextMenu.Add(onFillWorldObjectContextMenu)

print("[DDA] Expansion Debug Menu loaded")

return CS_DebugMenu
