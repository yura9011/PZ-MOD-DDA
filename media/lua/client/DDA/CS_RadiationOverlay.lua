-- DDA Radiation Overlay System
-- Renders full-screen visual effects for radiation events
-- Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 2.6
-- **Feature: DDA-expansion, Overlay System**

local CS_RadiationOverlay = {}

-- Load dependencies
local CS_Config = require("DDA/CS_Config")
local CS_Utils = require("DDA/CS_Utils")

-- ============================================================================
-- OVERLAY STATE
-- ============================================================================

CS_RadiationOverlay.state = {
    -- Current texture being displayed
    texture = nil,
    texturePath = nil,
    
    -- Alpha values for fade effect
    alpha = 0,
    targetAlpha = 0,
    
    -- Fade configuration
    fadeSpeed = CS_Config.Radiation.fadeSpeed or 0.02,
    maxAlpha = CS_Config.Radiation.maxAlpha or 0.4,
    
    -- Screen dimensions
    screenWidth = 0,
    screenHeight = 0,
    
    -- Current radiation type (for color matching)
    radiationType = nil,
    
    -- Is overlay system initialized
    initialized = false,
    
    -- Is player alive (don't render if dead)
    playerAlive = false
}

-- ============================================================================
-- TEXTURE MANAGEMENT
-- ============================================================================

--- Load a texture by path
--- @param texturePath string Path to the texture file
--- @return userdata|nil texture The loaded texture or nil if failed
function CS_RadiationOverlay.loadTexture(texturePath)
    if not texturePath then
        CS_Utils.logError("loadTexture: texturePath is nil")
        return nil
    end
    
    local texture = getTexture(texturePath)
    if not texture then
        CS_Utils.logWarning("Failed to load texture: " .. texturePath)
        return nil
    end
    
    return texture
end

--- Get texture path for a radiation type
--- @param radiationType string The radiation type ("green", "violet", "red")
--- @return string|nil texturePath The texture path or nil if invalid type
function CS_RadiationOverlay.getTexturePathForType(radiationType)
    if not radiationType then return nil end
    
    local typeConfig = CS_Config.Radiation.types[radiationType]
    if not typeConfig then
        CS_Utils.logWarning("Unknown radiation type: " .. tostring(radiationType))
        return nil
    end
    
    return typeConfig.texturePath
end

--- Get overlay color for a radiation type
--- @param radiationType string The radiation type ("green", "violet", "red")
--- @return table|nil color The color table {r, g, b} or nil if invalid type
function CS_RadiationOverlay.getColorForType(radiationType)
    if not radiationType then return nil end
    
    local typeConfig = CS_Config.Radiation.types[radiationType]
    if not typeConfig then return nil end
    
    return typeConfig.overlayColor
end

-- ============================================================================
-- OVERLAY CONTROL
-- ============================================================================

--- Initialize the overlay system
function CS_RadiationOverlay.init()
    if CS_RadiationOverlay.state.initialized then return end
    
    -- Get initial screen dimensions
    CS_RadiationOverlay.updateScreenDimensions()
    
    CS_RadiationOverlay.state.initialized = true
    CS_Utils.logInfo("Radiation Overlay system initialized")
end

--- Update screen dimensions from core
function CS_RadiationOverlay.updateScreenDimensions()
    local core = getCore()
    if core then
        CS_RadiationOverlay.state.screenWidth = core:getScreenWidth()
        CS_RadiationOverlay.state.screenHeight = core:getScreenHeight()
    end
end

--- Set the overlay for a specific radiation type
--- @param radiationType string The radiation type ("green", "violet", "red")
--- @param targetAlpha number|nil Target alpha (0.0 to 1.0), defaults to maxAlpha
function CS_RadiationOverlay.setOverlay(radiationType, targetAlpha)
    if not radiationType then
        CS_Utils.logError("setOverlay: radiationType is nil")
        return
    end
    
    local texturePath = CS_RadiationOverlay.getTexturePathForType(radiationType)
    if not texturePath then
        CS_Utils.logError("setOverlay: No texture path for type: " .. tostring(radiationType))
        return
    end
    
    -- Load texture if different from current
    if texturePath ~= CS_RadiationOverlay.state.texturePath then
        CS_RadiationOverlay.state.texture = CS_RadiationOverlay.loadTexture(texturePath)
        CS_RadiationOverlay.state.texturePath = texturePath
    end
    
    CS_RadiationOverlay.state.radiationType = radiationType
    CS_RadiationOverlay.state.targetAlpha = targetAlpha or CS_RadiationOverlay.state.maxAlpha
    
    CS_Utils.logInfo("Overlay set to type: " .. radiationType .. 
        " with target alpha: " .. CS_RadiationOverlay.state.targetAlpha)
end

--- Start fade in effect
--- @param targetAlpha number|nil Target alpha value (defaults to maxAlpha)
function CS_RadiationOverlay.fadeIn(targetAlpha)
    CS_RadiationOverlay.state.targetAlpha = targetAlpha or CS_RadiationOverlay.state.maxAlpha
    CS_Utils.logVerbose("Fade in started, target: " .. CS_RadiationOverlay.state.targetAlpha)
end

--- Start fade out effect
function CS_RadiationOverlay.fadeOut()
    CS_RadiationOverlay.state.targetAlpha = 0
    CS_Utils.logVerbose("Fade out started")
end

--- Clear the overlay immediately
function CS_RadiationOverlay.clear()
    CS_RadiationOverlay.state.alpha = 0
    CS_RadiationOverlay.state.targetAlpha = 0
    CS_RadiationOverlay.state.texture = nil
    CS_RadiationOverlay.state.texturePath = nil
    CS_RadiationOverlay.state.radiationType = nil
    CS_Utils.logVerbose("Overlay cleared")
end

-- ============================================================================
-- FADE LOGIC
-- ============================================================================

--- Update alpha value for smooth fade transitions
--- Called every frame to interpolate alpha toward target
function CS_RadiationOverlay.updateFade()
    local state = CS_RadiationOverlay.state
    local fadeSpeed = state.fadeSpeed
    
    if state.alpha < state.targetAlpha then
        -- Fade in: increase alpha
        state.alpha = state.alpha + fadeSpeed
        if state.alpha > state.targetAlpha then
            state.alpha = state.targetAlpha
        end
    elseif state.alpha > state.targetAlpha then
        -- Fade out: decrease alpha
        state.alpha = state.alpha - fadeSpeed
        if state.alpha < state.targetAlpha then
            state.alpha = state.targetAlpha
        end
    end
    
    -- Clamp alpha to valid range
    if state.alpha < 0 then state.alpha = 0 end
    if state.alpha > 1 then state.alpha = 1 end
end

-- ============================================================================
-- RENDERING
-- ============================================================================

--- Render the overlay
--- Called by OnPreUIDraw or OnPostUIDraw event
function CS_RadiationOverlay.render()
    local state = CS_RadiationOverlay.state
    
    -- Don't render if not initialized or player is dead
    if not state.initialized or not state.playerAlive then
        return
    end
    
    -- Update fade animation
    CS_RadiationOverlay.updateFade()
    
    -- Don't render if alpha is 0 or no texture
    if state.alpha <= 0 or not state.texture then
        return
    end
    
    -- Draw the overlay texture
    UIManager.DrawTexture(
        state.texture,
        0,                      -- x position
        0,                      -- y position
        state.screenWidth,      -- width
        state.screenHeight,     -- height
        state.alpha             -- alpha/opacity
    )
end

-- ============================================================================
-- EVENT HANDLERS
-- ============================================================================

--- Handle screen resolution change
--- @param oldW number Old screen width
--- @param oldH number Old screen height
--- @param newW number New screen width
--- @param newH number New screen height
function CS_RadiationOverlay.onResolutionChange(oldW, oldH, newW, newH)
    CS_RadiationOverlay.state.screenWidth = newW
    CS_RadiationOverlay.state.screenHeight = newH
    CS_Utils.logInfo("Resolution changed to " .. newW .. "x" .. newH)
end

--- Handle game boot (initialize screen dimensions)
function CS_RadiationOverlay.onGameBoot()
    CS_RadiationOverlay.updateScreenDimensions()
end

--- Handle player creation (mark player as alive)
function CS_RadiationOverlay.onCreatePlayer()
    CS_RadiationOverlay.state.playerAlive = true
    CS_RadiationOverlay.init()
    CS_RadiationOverlay.clear()
end

--- Handle player death (stop rendering)
function CS_RadiationOverlay.onPlayerDeath()
    CS_RadiationOverlay.state.playerAlive = false
    CS_RadiationOverlay.clear()
end

-- ============================================================================
-- GETTERS FOR TESTING
-- ============================================================================

--- Get current alpha value
--- @return number alpha Current alpha value (0.0 to 1.0)
function CS_RadiationOverlay.getAlpha()
    return CS_RadiationOverlay.state.alpha
end

--- Get target alpha value
--- @return number targetAlpha Target alpha value (0.0 to 1.0)
function CS_RadiationOverlay.getTargetAlpha()
    return CS_RadiationOverlay.state.targetAlpha
end

--- Get current radiation type
--- @return string|nil radiationType Current radiation type or nil
function CS_RadiationOverlay.getRadiationType()
    return CS_RadiationOverlay.state.radiationType
end

--- Get screen dimensions
--- @return number, number width, height Screen dimensions
function CS_RadiationOverlay.getScreenDimensions()
    return CS_RadiationOverlay.state.screenWidth, CS_RadiationOverlay.state.screenHeight
end

--- Check if overlay is visible (alpha > 0)
--- @return boolean isVisible True if overlay is visible
function CS_RadiationOverlay.isVisible()
    return CS_RadiationOverlay.state.alpha > 0
end

--- Check if overlay is fading in
--- @return boolean isFadingIn True if alpha is increasing toward target
function CS_RadiationOverlay.isFadingIn()
    return CS_RadiationOverlay.state.alpha < CS_RadiationOverlay.state.targetAlpha
end

--- Check if overlay is fading out
--- @return boolean isFadingOut True if alpha is decreasing toward target
function CS_RadiationOverlay.isFadingOut()
    return CS_RadiationOverlay.state.alpha > CS_RadiationOverlay.state.targetAlpha
end

-- ============================================================================
-- REGISTER EVENT HANDLERS
-- ============================================================================

--- Handle Server Commands (Requirement 1.1)
--- @param module string The module name
--- @param command string The command name
--- @param args table The command arguments
function CS_RadiationOverlay.onServerCommand(module, command, args)
    if module ~= "DDA" then return end
    
    if command == "RadiationStart" then
        CS_Utils.logInfo("[Client] Received RadiationStart: " .. tostring(args.type))
        CS_RadiationOverlay.setOverlay(args.type)
        CS_RadiationOverlay.fadeIn()
        
    elseif command == "RadiationEnd" then
        CS_Utils.logInfo("[Client] Received RadiationEnd")
        CS_RadiationOverlay.fadeOut()
        
    elseif command == "RadiationWarning" then
        -- Optional: Display warning text or sound
        CS_Utils.logInfo("[Client] Radiation Warning: " .. tostring(args.type) .. " in " .. tostring(args.hoursUntil) .. "h")
    end
end

-- ============================================================================
-- DAMAGE & EFFECTS (Client-Side Logic)
-- ============================================================================

--- Apply radiation effects to local player
--- @param player IsoPlayer The local player
local function applyClientEffects(player)
    if not player or player:isDead() then return end
    
    local type = CS_RadiationOverlay.state.radiationType
    if not type then return end
    
    local config = CS_Config.Radiation.types[type]
    if not config then return end
    
    -- Calculate Protection (Client-side is reliable)
    local protection = CS_Utils.calculateProtection(player)
    
    -- 100% Protection block
    if protection >= 1.0 then return end
    
    local multiplier = 1.0 - protection
    local bodyDamage = player:getBodyDamage()
    local stats = player:getStats()
    
    -- Apply Effects using B42 API
    if type == "green" then
        -- Poison/Stress (B42: CharacterStat.STRESS)
        if config.damagePerTick and bodyDamage then
            -- Apply damage to head as general radiation sickness
            local head = bodyDamage:getBodyPart(BodyPartType.Head)
            if head then
                local dmg = config.damagePerTick * multiplier
                head:setAdditionalPain(head:getAdditionalPain() + dmg)
                -- Visual feedback - text bubble
                player:Say("*Radiation sickness...*")
            end
        end
        if config.stressIncrease and stats then
            stats:add(CharacterStat.STRESS, config.stressIncrease * multiplier)
        end
        
    elseif type == "violet" then
        -- Panic (B42: CharacterStat.PANIC)
        if config.panicIncrease and stats then
            -- Visual feedback - text bubble (Always show, even if stats fail)
            player:Say("*My mind feels foggy...*")
            
            -- Apply Panic
            if CharacterStat.PANIC then
                stats:add(CharacterStat.PANIC, config.panicIncrease * multiplier)
            elseif CharacterStat.STRESS then
                -- Fallback to stress if PANIC enum is missing
                stats:add(CharacterStat.STRESS, config.panicIncrease * multiplier)
            end
            
            -- Hallucination Sound
            if ZombRand(100) < (config.hallucinationChance or 0.1) * 100 then
                 player:getEmitter():playSound("ZombieSurprised") -- Placeholder for scary sound
            end
        end
        
    elseif type == "red" then
        -- High Damage
        if config.damagePerTick and bodyDamage then
            local head = bodyDamage:getBodyPart(BodyPartType.Head)
            if head then
                local dmg = config.damagePerTick * multiplier
                head:setAdditionalPain(head:getAdditionalPain() + dmg)
                -- Visual feedback - text bubble
                player:Say("*CRITICAL RADIATION!*")
            end
        end
    end
end

--- Periodic check for effects (Every Game Minute)
function CS_RadiationOverlay.onEveryOneMinute()
    if not CS_RadiationOverlay.state.initialized then return end
    
    -- Only apply if overlay/event is active
    if not CS_RadiationOverlay.state.radiationType then return end
    
    local player = getPlayer()
    if player then
        applyClientEffects(player)
    end
end

-- Register Event Handlers
Events.OnGameBoot.Add(CS_RadiationOverlay.onGameBoot)
Events.OnResolutionChange.Add(CS_RadiationOverlay.onResolutionChange)
Events.OnCreatePlayer.Add(CS_RadiationOverlay.onCreatePlayer)
Events.OnPlayerDeath.Add(CS_RadiationOverlay.onPlayerDeath)
Events.OnPreUIDraw.Add(CS_RadiationOverlay.render)
Events.OnServerCommand.Add(CS_RadiationOverlay.onServerCommand)
Events.EveryOneMinute.Add(CS_RadiationOverlay.onEveryOneMinute)

-- Export for global access
_G.CS_RadiationOverlay = CS_RadiationOverlay

return CS_RadiationOverlay
