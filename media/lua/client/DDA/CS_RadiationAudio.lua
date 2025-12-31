-- DDA Radiation Audio System
-- Handles Geiger counter sound effects based on radiation levels
-- Requirements: 5.4 (Audio Feedback)

local CS_RadiationAudio = {}

-- Load dependencies
local CS_Config = require("DDA/CS_Config")
local CS_Utils = require("DDA/CS_Utils")
local CS_RadiationOverlay = require("DDA/CS_RadiationOverlay")

-- ============================================================================
-- STATE
-- ============================================================================

CS_RadiationAudio.state = {
    emitter = nil,
    soundRef = nil,
    isPlaying = false,
    lastClickTime = 0,
    clickInterval = 1000 -- ms
}

-- ============================================================================
-- AUDIO CONTROL
-- ============================================================================

--- Get or create audio emitter for the local player
--- @return FMODSoundEmitter emitter
function CS_RadiationAudio.getEmitter()
    local player = getPlayer()
    if not player then return nil end
    
    -- In B42/B41 usually getEmitter() exists on player
    if player.getEmitter then
        return player:getEmitter()
    end
    
    return nil
end

--- Update geiger counter audio
--- Called every tick to manage clicks
function CS_RadiationAudio.update()
    -- Only run if radiation is active visible client-side
    if not CS_RadiationOverlay.isVisible() then
        return
    end

    local player = getPlayer()
    if not player or player:isDead() then return end

    -- Check protection level
    local protection = CS_Utils.calculateProtection(player)
    
    -- If 100% protected, silence or very low frequency
    if protection >= 1.0 then
        -- Maybe occasional click to show it's working outside?
        -- For now, silence to reward protection
        return 
    end

    -- Calculate interval based on radiation type and protection
    -- Less protection = faster clicks
    -- Red radiation = faster clicks
    
    local baseInterval = 1000 -- 1 second default
    local type = CS_RadiationOverlay.getRadiationType()
    
    if type == "green" then
        baseInterval = 800
    elseif type == "violet" then
        baseInterval = 500
    elseif type == "red" then
        baseInterval = 200
    end
    
    -- Apply protection factor (more protection = slower clicks)
    -- protection 0.5 -> interval * 2
    -- protection 0.0 -> interval * 1
    local multiplier = 1 + (protection * 4) 
    local finalInterval = baseInterval * multiplier
    
    -- Randomize slightly
    finalInterval = finalInterval * (0.8 + (ZombRand(40)/100))

    local currentTime = getTimestampMs()
    if currentTime - CS_RadiationAudio.state.lastClickTime > finalInterval then
        CS_RadiationAudio.playClick()
        CS_RadiationAudio.state.lastClickTime = currentTime
    end
end

--- Play a single geiger click
function CS_RadiationAudio.playClick()
    local emitter = CS_RadiationAudio.getEmitter()
    if emitter then
        -- "UI_Toggle" is a generic click if custom sound missing
        -- TODO: Replace with "DDA.GeigerClick"
        emitter:playSound("UI_Toggle") 
    end
end

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

Events.OnTick.Add(CS_RadiationAudio.update)

return CS_RadiationAudio
