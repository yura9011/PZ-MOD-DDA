-- DDA Radiation Broadcast System
-- Client-side radio/TV broadcast for radiation warnings
-- Requirements: 5.1, 5.2
-- Pattern: Based on Unseasonal Weather DynamicRadio implementation

local CS_RadiationBroadcast = {}

-- Load dependencies
local CS_Config = require("DDA/CS_Config")

-- ============================================================================
-- DYNAMIC RADIO CHANNEL SETUP
-- ============================================================================

local CS_RF_UUID = "CS-RAD-001"
local CS_RF_FREQ = 93500 -- 93.5 MHz (DDA Emergency Frequency)

-- Cache for channel reference
CS_RadiationBroadcast.channel = nil
CS_RadiationBroadcast.lastHeard = nil

--- Get current world hours
--- @return number worldHours Current world age in hours
local function getWorldHours()
    local gt = getGameTime and getGameTime()
    return gt and gt:getWorldAgeHours() or 0
end

--- Ensure the DDA radio channel exists
--- @param scriptManager table Optional script manager from OnLoadRadioScripts
--- @return table|nil channel The DynamicRadioChannel or nil
function CS_RadiationBroadcast.ensureChannel(scriptManager)
    if not DynamicRadio then return nil end
    
    DynamicRadio.channels = DynamicRadio.channels or {}
    DynamicRadio.cache = DynamicRadio.cache or {}
    
    -- Return cached channel if exists
    if DynamicRadio.cache[CS_RF_UUID] then
        CS_RadiationBroadcast.channel = DynamicRadio.cache[CS_RF_UUID]
        return CS_RadiationBroadcast.channel
    end
    
    -- Check if channel already in list
    local foundInList = false
    for _, ch in ipairs(DynamicRadio.channels) do
        if ch.uuid == CS_RF_UUID then
            foundInList = true
            break
        end
    end
    
    -- Add to channel list if not found
    if not foundInList then
        table.insert(DynamicRadio.channels, {
            name = "DDA Emergency Network",
            freq = CS_RF_FREQ,
            category = "Emergency",
            uuid = CS_RF_UUID,
            register = true,
        })
    end
    
    -- Create DynamicRadioChannel if API available
    if DynamicRadioChannel and DynamicRadioChannel.new then
        local cat = ChannelCategory and ChannelCategory.Emergency or ChannelCategory.Other
        local dynamicChannel = DynamicRadioChannel.new(
            "DDA Emergency Network",
            CS_RF_FREQ,
            cat,
            CS_RF_UUID
        )
        
        if dynamicChannel then
            if dynamicChannel.setAirCounterMultiplier then
                dynamicChannel:setAirCounterMultiplier(1.0)
            end
            if scriptManager and scriptManager.AddChannel then
                scriptManager:AddChannel(dynamicChannel, false)
            end
            DynamicRadio.cache[CS_RF_UUID] = dynamicChannel
            CS_RadiationBroadcast.channel = dynamicChannel
            return dynamicChannel
        end
    end
    
    return nil
end

--- Get the DDA radio channel
--- @return table|nil channel The channel or nil
function CS_RadiationBroadcast.getChannel()
    return CS_RadiationBroadcast.ensureChannel()
end

-- ============================================================================
-- BROADCAST MESSAGE GENERATION (Requirements 5.1, 5.2)
-- ============================================================================

--- Radiation type display names for broadcasts
CS_RadiationBroadcast.typeNames = {
    green = "GREEN RADIATION",
    violet = "VIOLET RADIATION", 
    red = "RED RADIATION"
}

--- Radiation type descriptions for broadcasts
CS_RadiationBroadcast.typeDescriptions = {
    green = "Causes slow poisoning and increased stress. Seek shelter immediately.",
    violet = "Causes hallucinations and panic. Find a safe indoor location.",
    red = "EXTREME DANGER. Causes rapid damage. Stalker zombies may spawn. Take cover NOW."
}

--- Format time for broadcast display
--- @param hoursFromNow number Hours until event
--- @return string formattedTime Human-readable time string
function CS_RadiationBroadcast.formatTime(hoursFromNow)
    if hoursFromNow < 1 then
        local minutes = math.floor(hoursFromNow * 60)
        if minutes <= 0 then
            return "IMMINENT"
        end
        return string.format("in approximately %d minutes", minutes)
    elseif hoursFromNow < 2 then
        return "within the next hour"
    else
        return string.format("in approximately %d hours", math.floor(hoursFromNow))
    end
end

--- Generate broadcast message lines for a radiation warning
--- Requirement 5.2: Include radiation type and approximate start time
--- @param radiationType string The radiation type ("green", "violet", "red")
--- @param hoursUntilStart number Hours until the event starts
--- @return table lines Array of RadioLine objects
function CS_RadiationBroadcast.generateWarningLines(radiationType, hoursUntilStart)
    local lines = {}
    
    if not RadioLine or not RadioLine.new then
        print("[CS_RadiationBroadcast] WARN: RadioLine API unavailable")
        return lines
    end
    
    local typeName = CS_RadiationBroadcast.typeNames[radiationType] or "UNKNOWN RADIATION"
    local typeDesc = CS_RadiationBroadcast.typeDescriptions[radiationType] or "Seek shelter."
    local timeStr = CS_RadiationBroadcast.formatTime(hoursUntilStart)
    
    -- Color based on radiation type (RGB values for RadioLine)
    local r, g, b = 255, 255, 0 -- Default yellow for warnings
    if radiationType == "green" then
        r, g, b = 0, 255, 0
    elseif radiationType == "violet" then
        r, g, b = 200, 100, 255
    elseif radiationType == "red" then
        r, g, b = 255, 50, 50
    end
    
    -- Build message lines
    -- Line 1: Alert header
    table.insert(lines, RadioLine.new(
        "*** EMERGENCY BROADCAST - RADIATION ALERT ***",
        255, 50, 50
    ))
    
    -- Line 2: Radiation type (Requirement 5.2)
    table.insert(lines, RadioLine.new(
        string.format("WARNING: %s detected in the region.", typeName),
        r, g, b
    ))
    
    -- Line 3: Time estimate (Requirement 5.2)
    table.insert(lines, RadioLine.new(
        string.format("Expected arrival: %s.", timeStr),
        255, 255, 0
    ))
    
    -- Line 4: Description/advice
    table.insert(lines, RadioLine.new(
        typeDesc,
        200, 200, 200
    ))
    
    -- Line 5: Closing
    table.insert(lines, RadioLine.new(
        "Stay tuned to 93.5 MHz for updates. Stay safe.",
        150, 150, 150
    ))
    
    return lines
end

--- Validate that a broadcast message contains required info
--- Used for property testing (Property 12)
--- @param radiationType string The radiation type
--- @param hoursUntilStart number Hours until event
--- @param messageText string The full message text to validate
--- @return boolean isValid True if message contains type and time info
function CS_RadiationBroadcast.validateBroadcastContent(radiationType, hoursUntilStart, messageText)
    if not messageText or messageText == "" then
        return false
    end
    
    -- Check for radiation type mention
    local typeName = CS_RadiationBroadcast.typeNames[radiationType]
    local hasType = typeName and messageText:find(typeName, 1, true) ~= nil
    
    -- Check for time information
    local hasTime = false
    if hoursUntilStart < 1 then
        hasTime = messageText:find("minutes", 1, true) ~= nil or 
                  messageText:find("IMMINENT", 1, true) ~= nil
    elseif hoursUntilStart < 2 then
        hasTime = messageText:find("hour", 1, true) ~= nil
    else
        hasTime = messageText:find("hours", 1, true) ~= nil
    end
    
    return hasType and hasTime
end

-- ============================================================================
-- BROADCAST EMISSION
-- ============================================================================

--- Emit a radiation warning broadcast on the radio channel
--- Requirement 5.1: Broadcast warning via radio/TV before event starts
--- @param radiationType string The radiation type
--- @param hoursUntilStart number Hours until the event starts
--- @return boolean success True if broadcast was emitted
function CS_RadiationBroadcast.emitWarning(radiationType, hoursUntilStart)
    local lines = CS_RadiationBroadcast.generateWarningLines(radiationType, hoursUntilStart)
    
    if not lines or #lines == 0 then
        print("[CS_RadiationBroadcast] No lines to broadcast")
        return false
    end
    
    local channel = CS_RadiationBroadcast.getChannel()
    if not channel then
        print("[CS_RadiationBroadcast] Channel not ready, cannot emit broadcast")
        return false
    end
    
    -- Create broadcast
    local broadcastId = string.format("CS_Radiation_%s_%d", radiationType, ZombRand(1, 99999))
    local bc = RadioBroadCast and RadioBroadCast.new and RadioBroadCast.new(broadcastId, -1, -1)
    
    if not bc then
        print("[CS_RadiationBroadcast] RadioBroadCast API unavailable")
        return false
    end
    
    -- Add lines to broadcast
    for _, line in ipairs(lines) do
        if line then
            if line.setCodes then line:setCodes(false) end
            if line.setPriority then line:setPriority(10) end -- High priority for emergency
            if line.setLoop then line:setLoop(false) end
            bc:AddRadioLine(line)
        end
    end
    
    -- Verify broadcast has content
    if bc.getRadioLines and bc:getRadioLines() and bc:getRadioLines():isEmpty() then
        print("[CS_RadiationBroadcast] WARN: Broadcast has zero lines, skipping")
        return false
    end
    
    -- Emit on channel
    channel:setAiringBroadcast(bc)
    
    print(string.format(
        "[CS_RadiationBroadcast] Broadcast emitted: type=%s, eta=%s hours, lines=%d",
        radiationType, tostring(hoursUntilStart), #lines
    ))
    
    return true
end

-- ============================================================================
-- ON DEVICE TEXT LISTENER
-- ============================================================================

--- Handle radio/TV text reception
--- Requirement 5.3: Display pending warnings when player tunes in
--- @param guid string Device GUID
--- @param codes table Codes
--- @param x number X position
--- @param y number Y position
--- @param z number Z position
--- @param text string The text received
--- @param device table The device object
local function onDeviceText(guid, codes, x, y, z, text, device)
    if not device then return end
    
    local data = device.getDeviceData and device:getDeviceData()
    if not data then return end
    if data:getIsTurnedOn() ~= true then return end
    if data:getChannel() ~= CS_RF_FREQ then return end
    
    -- Log that we heard something on our channel
    CS_RadiationBroadcast.lastHeard = {
        text = text,
        x = x, y = y, z = z,
        time = getWorldHours(),
    }
    
    if CS_Config.Debug.enabled then
        print("[CS_RadiationBroadcast] Heard on 93.5 MHz: " .. tostring(text))
    end
end

-- ============================================================================
-- SERVER COMMAND HANDLER
-- ============================================================================

--- Handle server commands for radiation broadcasts
--- @param module string The module name
--- @param command string The command name
--- @param args table Command arguments
local function onServerCommand(module, command, args)
    if module ~= "DDA" then return end
    
    if command == "RadiationWarning" then
        -- Server is requesting a broadcast
        local radiationType = args.type
        local hoursUntilStart = args.hoursUntil or 1
        
        if radiationType then
            CS_RadiationBroadcast.emitWarning(radiationType, hoursUntilStart)
        end
    end
end

-- ============================================================================
-- EVENT HOOKS
-- ============================================================================

--- Register channel on radio scripts load
local function onLoadRadioScripts(scriptManager, isNewGame)
    CS_RadiationBroadcast.ensureChannel(scriptManager)
end

--- Initialize on game start
local function onGameStart()
    CS_RadiationBroadcast.ensureChannel()
    print("[CS_RadiationBroadcast] Initialized on 93.5 MHz")
end

-- Register event handlers
Events.OnLoadRadioScripts.Add(onLoadRadioScripts)
Events.OnGameStart.Add(onGameStart)
Events.OnInitWorld.Add(CS_RadiationBroadcast.ensureChannel)
Events.OnDeviceText.Add(onDeviceText)
Events.OnServerCommand.Add(onServerCommand)

-- Export for testing and external access
return CS_RadiationBroadcast
