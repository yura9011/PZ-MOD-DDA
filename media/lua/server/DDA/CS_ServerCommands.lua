-- DDA Server Command Handler
-- Handles commands sent from client (Debug Menu, UI)
-- Requirements: Client-Server synchronization

local CS_ServerCommands = {}

-- Load dependencies
local CS_Validation = require("DDA/CS_Utils") -- Reuse utils for logging
local CS_Config = require("DDA/CS_Config")

CS_ServerCommands.Commands = {}

-- ============================================================================
-- COMMAND HANDLERS
-- ============================================================================

-- Command: StartEvent
-- Args: { type = "green"|"violet"|"red" }
function CS_ServerCommands.Commands.StartEvent(player, args)
    if _G.CS_RadiationEvents then
        local success = _G.CS_RadiationEvents.startEvent(args.type)
        if success then
            local msg = "Started " .. tostring(args.type) .. " radiation event"
            print("[CS_Server] " .. msg)
            if player then player:Say("[SERVER] " .. msg) end
        else
            if player then player:Say("[SERVER] Failed to start event (Invalid type?)") end
        end
    end
end

-- Command: EndEvent
-- Args: {}
function CS_ServerCommands.Commands.EndEvent(player, args)
    if _G.CS_RadiationEvents then
        _G.CS_RadiationEvents.endEvent()
        if player then player:Say("[SERVER] Radiation event ended") end
    end
end

-- Command: CheckStatus
-- Args: {}
function CS_ServerCommands.Commands.CheckStatus(player, args)
    if _G.CS_RadiationEvents then
        local isActive = _G.CS_RadiationEvents.isActive()
        local type = _G.CS_RadiationEvents.getCurrentType()
        local status = isActive and ("ACTIVE (" .. tostring(type) .. ")") or "INACTIVE"
        if player then player:Say("[SERVER] Radiation: " .. status) end
    end
end

-- Command: SpawnSpecial
-- Args: { x=number, y=number, z=number, type="titan"|"stalker"|"brute" }
function CS_ServerCommands.Commands.SpawnSpecial(player, args)
    local x, y, z = args.x, args.y, args.z
    local type = args.type
    local typeData = CS_Config.SpecialZombies[type]
    
    if not typeData then
        if player then player:Say("[SERVER] Invalid special type: " .. tostring(type)) end
        return
    end
    
    local outfit = typeData.outfit
    local zombies = addZombiesInOutfit(x, y, z, 1, outfit, 0)
    
    if zombies and zombies:size() > 0 then
        local zombie = zombies:get(0)
        -- Apply stats
        local health = zombie:getHealth() * typeData.healthMultiplier
        zombie:setHealth(health)
        
        -- Special behaviors
        if type == "stalker" then
            zombie:setWalkType("sprinter")
        end
        
        -- Critical Fix: Tag zombie for reliable drop detection
        zombie:getModData().cs_type = type
        
        if player then player:Say("[SERVER] Spawned " .. type .. " with " .. typeData.healthMultiplier .. "x HP") end
    else
        if player then player:Say("[SERVER] Failed to spawn outfit: " .. tostring(outfit)) end
    end
end

-- Command: DropItem
-- Args: { x=number, y=number, z=number, item=string }
function CS_ServerCommands.Commands.DropItem(player, args)
    local square = getCell():getGridSquare(args.x, args.y, args.z)
    if square then
        square:AddWorldInventoryItem(args.item, 0, 0, 0)
        if player then player:Say("[SERVER] Dropped " .. tostring(args.item)) end
    end
end

-- ============================================================================
-- MAIN HANDLER
-- ============================================================================

local function onClientCommand(module, command, player, args)
    if module == "DDA" and CS_ServerCommands.Commands[command] then
        print("[CS_Server] Received command: " .. command)
        CS_ServerCommands.Commands[command](player, args)
    end
end

Events.OnClientCommand.Add(onClientCommand)
print("[DDA] Server Commands Initialized")

return CS_ServerCommands
