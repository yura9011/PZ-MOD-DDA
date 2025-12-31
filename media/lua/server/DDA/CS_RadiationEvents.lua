-- DDA Radiation Event Manager
-- Server-side radiation event management with ModData persistence
-- Requirements: 1.1, 1.2, 1.3, 1.4, 1.5

local CS_RadiationEvents = {}

-- Load dependencies
local CS_Config = require("DDA/CS_Config")
local CS_Utils = require("DDA/CS_Utils")
local CS_SpecialZombies = require("DDA/CS_SpecialZombies")

-- Cache globals for performance
local getGameTime = getGameTime
local ZombRand = ZombRand
local Events = Events
local ModData = ModData
local getNumActivePlayers = getNumActivePlayers
local getSpecificPlayer = getSpecificPlayer

-- ============================================================================
-- SINGLEPLAYER WORKAROUND (KB Verified B42)
-- sendServerCommand does NOT work in singleplayer
-- ============================================================================
local function sendCommandToClient(module, command, args)
    if isServer() then
        -- Multiplayer: use standard sendServerCommand
        sendServerCommand(module, command, args)
    else
        -- Singleplayer: triggerEvent directly to client
        triggerEvent("OnServerCommand", module, command, args)
    end
    print("[CS_RadiationEvents] Sent " .. command .. " (SP: " .. tostring(not isServer()) .. ")")
end

-- ============================================================================
-- VALID RADIATION TYPES (Requirement 1.1)
-- ============================================================================
CS_RadiationEvents.VALID_TYPES = {"green", "violet", "red"}

-- ============================================================================
-- MODDATA STATE MANAGEMENT (MP-Safe)
-- ============================================================================

--- Get or create radiation state from ModData
--- @return table state The radiation state table
function CS_RadiationEvents.getState()
    local md = ModData.getOrCreate("DDA")
    if not md.radiation then
        md.radiation = {
            active = false,           -- Is radiation currently active
            type = nil,               -- Current radiation type: "green", "violet", "red"
            startTime = 0,            -- World age hours when event started
            duration = 0,             -- Duration in game minutes
            lastType = nil,           -- Last radiation type (to avoid repetition)
            nextCheckTime = 0,        -- Next time to check for new event
            pendingEvent = nil        -- Scheduled event waiting to start {type, scheduledStartTime}
        }
    end
    return md.radiation
end

--- Validate that a radiation type is valid
--- @param radiationType string The type to validate
--- @return boolean isValid True if type is valid
function CS_RadiationEvents.isValidType(radiationType)
    if not radiationType then return false end
    for _, validType in ipairs(CS_RadiationEvents.VALID_TYPES) do
        if radiationType == validType then
            return true
        end
    end
    return false
end

--- Check if radiation is currently active
--- @return boolean isActive True if radiation is active
function CS_RadiationEvents.isActive()
    local state = CS_RadiationEvents.getState()
    return state.active == true
end

--- Get current radiation type (nil if inactive)
--- @return string|nil type The current radiation type or nil
function CS_RadiationEvents.getCurrentType()
    local state = CS_RadiationEvents.getState()
    if state.active then
        return state.type
    end
    return nil
end

--- Get last radiation type (for avoiding repetition)
--- @return string|nil lastType The last radiation type or nil
function CS_RadiationEvents.getLastType()
    local state = CS_RadiationEvents.getState()
    return state.lastType
end

-- ============================================================================
-- EVENT SELECTION (Requirement 1.2, 1.4)
-- ============================================================================

--- Pick a random radiation type that is different from the last type
--- Requirement 1.2: SHALL NOT select the same radiation type for the next event
--- @return string radiationType A valid radiation type different from lastType
function CS_RadiationEvents.pickRandomEvent()
    local state = CS_RadiationEvents.getState()
    local lastType = state.lastType
    
    -- Build list of available types (excluding last type)
    local availableTypes = {}
    for _, radiationType in ipairs(CS_RadiationEvents.VALID_TYPES) do
        if radiationType ~= lastType then
            table.insert(availableTypes, radiationType)
        end
    end
    
    -- If no available types (shouldn't happen with 3 types), use all types
    if #availableTypes == 0 then
        availableTypes = CS_RadiationEvents.VALID_TYPES
    end
    
    -- Pick random from available
    local index = ZombRand(#availableTypes) + 1
    return availableTypes[index]
end

--- Check if a new radiation event should start
--- Called by EveryTenMinutes event
--- Requirement 1.4: Trigger radiation events at random intervals
--- Requirement 5.1: Broadcast warning before event starts
function CS_RadiationEvents.checkForEvent()
    local state = CS_RadiationEvents.getState()
    
    -- Don't start new event if one is already active or pending
    if state.active then
        return
    end
    
    -- Check pending events first
    if state.pendingEvent then
        CS_RadiationEvents.checkPendingEvent()
        return
    end
    
    -- Check if debug mode forces radiation
    if CS_Config.Debug.forceRadiation then
        local forcedType = CS_Config.Debug.forceRadiationType or CS_RadiationEvents.pickRandomEvent()
        -- In debug mode, start immediately without broadcast delay
        CS_RadiationEvents.startEvent(forcedType)
        return
    end
    
    -- Random chance to schedule event (with broadcast warning)
    local chance = ZombRand(100)
    if chance < CS_Config.Radiation.eventChance then
        local eventType = CS_RadiationEvents.pickRandomEvent()
        -- Schedule event with broadcast warning (Requirement 5.1)
        CS_RadiationEvents.scheduleEvent(eventType)
    end
end

-- ============================================================================
-- EVENT LIFECYCLE (Requirement 1.3, 1.5)
-- ============================================================================

--- Schedule a radiation warning broadcast before event starts
--- Requirement 5.1: Broadcast warning via radio/TV before event starts
--- @param eventType string The radiation type
--- @param hoursUntilStart number Hours until the event starts
function CS_RadiationEvents.scheduleBroadcast(eventType, hoursUntilStart)
    if not CS_RadiationEvents.isValidType(eventType) then
        return
    end
    
    -- Send command to clients to emit broadcast
    -- Requirement 5.2: Include radiation type and approximate start time
    sendCommandToClient("DDA", "RadiationWarning", {
        type = eventType,
        hoursUntil = hoursUntilStart
    })
    
    CS_Utils.logInfo(string.format(
        "Radiation broadcast scheduled: type=%s, eta=%.1f hours",
        eventType, hoursUntilStart
    ))
end

--- Schedule a radiation event to start after a delay (with broadcast warning)
--- @param eventType string The radiation type to schedule
--- @param delayHours number Hours until event starts (default: 1-3 hours)
--- @return boolean success True if event was scheduled
function CS_RadiationEvents.scheduleEvent(eventType, delayHours)
    -- Validate type
    if not CS_RadiationEvents.isValidType(eventType) then
        CS_Utils.logError("Invalid radiation type for scheduling: " .. tostring(eventType))
        eventType = "green"
    end
    
    local state = CS_RadiationEvents.getState()
    
    -- Don't schedule if already active or pending
    if state.active or state.pendingEvent then
        return false
    end
    
    -- Default delay: 1-3 hours
    delayHours = delayHours or (ZombRand(1, 4) + ZombRand(0, 100) / 100)
    
    local currentHours = CS_Utils.getWorldAgeHours()
    
    -- Store pending event
    state.pendingEvent = {
        type = eventType,
        scheduledStartTime = currentHours + delayHours
    }
    
    -- Emit broadcast warning (Requirement 5.1)
    CS_RadiationEvents.scheduleBroadcast(eventType, delayHours)
    
    CS_Utils.logInfo(string.format(
        "Radiation event scheduled: type=%s, starts in %.1f hours",
        eventType, delayHours
    ))
    
    return true
end

--- Check if a pending event should start
function CS_RadiationEvents.checkPendingEvent()
    local state = CS_RadiationEvents.getState()
    
    if not state.pendingEvent then
        return
    end
    
    local currentHours = CS_Utils.getWorldAgeHours()
    
    if currentHours >= state.pendingEvent.scheduledStartTime then
        local eventType = state.pendingEvent.type
        state.pendingEvent = nil  -- Clear pending
        CS_RadiationEvents.startEvent(eventType)
    end
end

--- Start a new radiation event
--- Requirement 1.3: Duration between 30 and 120 minutes
--- @param eventType string The radiation type to start
--- @return boolean success True if event started successfully
function CS_RadiationEvents.startEvent(eventType)
    -- Validate type
    if not CS_RadiationEvents.isValidType(eventType) then
        CS_Utils.logError("Invalid radiation type: " .. tostring(eventType))
        -- Default to green if invalid
        eventType = "green"
    end
    
    local state = CS_RadiationEvents.getState()
    
    -- Calculate random duration (Requirement 1.3: 30-120 minutes)
    local minDuration = CS_Config.Radiation.minDuration
    local maxDuration = CS_Config.Radiation.maxDuration
    local duration = CS_Utils.randomRange(minDuration, maxDuration)
    
    -- Update state
    state.active = true
    state.type = eventType
    state.startTime = CS_Utils.getWorldAgeHours()
    state.duration = duration
    state.lastType = eventType  -- Remember for next event
    
    CS_Utils.logInfo(string.format(
        "Radiation event started: type=%s, duration=%d minutes",
        eventType, duration
    ))
    
    -- Trigger client notification (will be handled by client-side code)
    sendCommandToClient("DDA", "RadiationStart", {
        type = eventType,
        duration = duration
    })
    
    return true
end

--- End the current radiation event
--- Requirement 1.5: Maintain normal gameplay when inactive
function CS_RadiationEvents.endEvent()
    local state = CS_RadiationEvents.getState()
    
    if not state.active then
        return  -- Already inactive
    end
    
    local endedType = state.type
    
    -- Clear active state but keep lastType
    state.active = false
    state.type = nil
    state.startTime = 0
    state.duration = 0
    -- state.lastType is preserved for next event selection
    
    CS_Utils.logInfo("Radiation event ended: " .. tostring(endedType))
    
    -- Trigger client notification
    sendCommandToClient("DDA", "RadiationEnd", {
        lastType = endedType
    })
end

--- Check if current event should end based on duration
function CS_RadiationEvents.checkEventDuration()
    local state = CS_RadiationEvents.getState()
    
    if not state.active then
        return
    end
    
    -- Calculate elapsed time in minutes
    local currentHours = CS_Utils.getWorldAgeHours()
    local elapsedHours = currentHours - state.startTime
    local elapsedMinutes = elapsedHours * 60
    
    -- Check if duration exceeded
    if elapsedMinutes >= state.duration then
        CS_RadiationEvents.endEvent()
    end
end

-- ============================================================================
-- RADIATION EFFECTS (Requirement 4.1, 4.2, 4.3, 4.4)
-- ============================================================================

--- Apply radiation effects to a player based on current radiation type
--- Requirement 4.4: Adjust effect intensity based on protection
--- @param player IsoPlayer The player to apply effects to
function CS_RadiationEvents.applyEffects(player)
    if not player then return end
    
    local state = CS_RadiationEvents.getState()
    
    -- Requirement 1.5: No effects when inactive
    if not state.active then
        return
    end
    
    local radiationType = state.type
    if not radiationType then return end
    
    -- Get protection level
    local protection = CS_Utils.calculateProtection(player)
    
    -- If fully protected, no effects
    if protection >= 1.0 then
        return
    end
    
    -- Get radiation config for this type
    local radiationConfig = CS_Config.Radiation.types[radiationType]
    if not radiationConfig then return end
    
    -- Calculate damage multiplier based on protection
    local damageMultiplier = 1 - protection
    
    -- Apply type-specific effects
    if radiationType == "green" then
        -- Requirement 4.1: Slow poison damage and stress
        CS_RadiationEvents.applyGreenEffects(player, radiationConfig, damageMultiplier)
    elseif radiationType == "violet" then
        -- Requirement 4.2: Hallucinations and panic
        CS_RadiationEvents.applyVioletEffects(player, radiationConfig, damageMultiplier)
    elseif radiationType == "red" then
        -- Requirement 4.3: Fast damage and Stalker spawns
        CS_RadiationEvents.applyRedEffects(player, radiationConfig, damageMultiplier)
    end
end

--- Apply green radiation effects
--- @param player IsoPlayer The player
--- @param config table The radiation config
--- @param multiplier number Damage multiplier (0-1)
function CS_RadiationEvents.applyGreenEffects(player, config, multiplier)
    -- Damage is applied client-side in CS_RadiationOverlay.lua
    -- Server only handles events/spawns
end

--- Apply violet radiation effects
--- @param player IsoPlayer The player
--- @param config table The radiation config
--- @param multiplier number Damage multiplier (0-1)
function CS_RadiationEvents.applyVioletEffects(player, config, multiplier)
    -- Damage/Panic is applied client-side in CS_RadiationOverlay.lua
    -- Server only handles events/spawns
end

--- Apply red radiation effects (Stalker spawns)
--- @param player IsoPlayer The player
--- @param config table The radiation config
--- @param multiplier number Damage multiplier (0-1)
function CS_RadiationEvents.applyRedEffects(player, config, multiplier)
    -- Damage is applied client-side in CS_RadiationOverlay.lua
    
    -- Try to spawn/transform a Stalker nearby
    if not config.stalkerSpawnChance then return end
    
    if CS_Utils.randomChance(config.stalkerSpawnChance) then
        local cell = player:getCell()
        local zombieList = cell:getZombieList()
        if not zombieList or zombieList:isEmpty() then return end
        
        -- Pick a random zombie to transform
        local zIndex = ZombRand(zombieList:size())
        local zombie = zombieList:get(zIndex)
        
        -- Only transform if valid, active, and not already special
        if zombie and not zombie:isDead() and not zombie:getModData().CS_Type then
            -- Check distance (don't spawn right on top of player, but close enough)
            local dist = zombie:DistTo(player)
            if dist > 5 and dist < 20 then
                 CS_SpecialZombies.makeSpecial(zombie, "stalker")
                 CS_Utils.logInfo("Red Radiation transformed a Stalker near " .. player:getUsername())
            end
        end
    end
end

-- ============================================================================
-- EVENT HOOKS
-- ============================================================================

--- EveryTenMinutes handler - check for new events and duration
local function onEveryTenMinutes()
    -- Check if current event should end
    CS_RadiationEvents.checkEventDuration()
    
    -- Check pending events
    CS_RadiationEvents.checkPendingEvent()
    
    -- Check if new event should start
    CS_RadiationEvents.checkForEvent()
end

--- EveryOneMinute handler - apply effects to all players
local function onEveryOneMinute()
    if not CS_RadiationEvents.isActive() then
        return
    end
    
    -- Apply effects to all active players (MP-safe)
    for i = 0, getNumActivePlayers() - 1 do
        local player = getSpecificPlayer(i)
        if player then
            CS_RadiationEvents.applyEffects(player)
        end
    end
end

--- Initialize event hooks
function CS_RadiationEvents.init()
    Events.EveryTenMinutes.Add(onEveryTenMinutes)
    -- NOTE: Effects are applied CLIENT-SIDE in CS_RadiationOverlay.lua
    -- Server only manages event state (start/end/duration)
    CS_Utils.logInfo("CS_RadiationEvents initialized")
end

-- Auto-initialize on game start
Events.OnGameStart.Add(CS_RadiationEvents.init)

-- Export for global access by CS_ServerCommands
_G.CS_RadiationEvents = CS_RadiationEvents

-- Export for testing and external access
return CS_RadiationEvents
