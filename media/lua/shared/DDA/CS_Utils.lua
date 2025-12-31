-- DDA Utilities
-- Shared utility functions for all DDA systems
-- Requirements: Architecture general

local CS_Utils = {}

-- Cache globals for performance
local getGameTime = getGameTime
local ZombRand = ZombRand
local tostring = tostring
local type = type

-- ============================================================================
-- LOGGING
-- ============================================================================
local LOG_PREFIX = "[DDA] "

function CS_Utils.log(message, level)
    level = level or 3  -- Default to info
    local config = require("DDA/CS_Config")
    if config.Debug.enabled and level <= config.Debug.logLevel then
        print(LOG_PREFIX .. tostring(message))
    end
end

function CS_Utils.logError(message)
    print(LOG_PREFIX .. "ERROR: " .. tostring(message))
end

function CS_Utils.logWarning(message)
    CS_Utils.log("WARNING: " .. tostring(message), 2)
end

function CS_Utils.logInfo(message)
    CS_Utils.log(tostring(message), 3)
end

function CS_Utils.logVerbose(message)
    CS_Utils.log(tostring(message), 4)
end

-- ============================================================================
-- MODDATA HELPERS (MP-Safe)
-- ============================================================================

-- Get or create DDA ModData
function CS_Utils.getModData()
    local md = ModData.getOrCreate("DDA")
    return md
end

-- Get player-specific ModData
function CS_Utils.getPlayerModData(player)
    if not player then return nil end
    local md = player:getModData()
    md.DDA = md.DDA or {}
    return md.DDA
end

-- ============================================================================
-- PLAYER DETECTION (MP-Safe)
-- Requirements: 3.1, 3.2, 3.3, 3.4, 3.5
-- ============================================================================

-- Check if player is indoors (in a room)
-- Requirements: 3.1, 3.4
function CS_Utils.isPlayerIndoors(player)
    if not player then return false end
    
    local sq = player:getCurrentSquare()
    if not sq then return false end
    
    local room = sq:getRoom()
    return room ~= nil
end

-- Check if a door or window object is destroyed/broken
-- Helper function for room integrity detection
local function isObjectBroken(object)
    if not object then return false end
    
    -- Check for IsoWindow
    if instanceof(object, "IsoWindow") then
        -- Windows have isDestroyed() method
        if object.isDestroyed and object:isDestroyed() then
            return true
        end
        -- Also check if window is smashed (health = 0)
        if object.getHealth and object:getHealth() <= 0 then
            return true
        end
        return false
    end
    
    -- Check for IsoDoor
    if instanceof(object, "IsoDoor") then
        -- Doors can be destroyed
        if object.isDestroyed and object:isDestroyed() then
            return true
        end
        -- Check health for thumpable doors
        if object.getHealth and object:getHealth() <= 0 then
            return true
        end
        return false
    end
    
    -- Check for IsoThumpable (player-built doors/windows)
    if instanceof(object, "IsoThumpable") then
        if object:isDoor() or object:isWindow() then
            if object.isDestroyed and object:isDestroyed() then
                return true
            end
            if object.getHealth and object:getHealth() <= 0 then
                return true
            end
        end
        return false
    end
    
    return false
end

-- Get room integrity (1.0 = intact, 0.5 = damaged)
-- Requirement 3.2: 50% protection if doors/windows are broken
function CS_Utils.getRoomIntegrity(player)
    if not player then return 0 end
    
    local sq = player:getCurrentSquare()
    if not sq then return 0 end
    
    local room = sq:getRoom()
    if not room then return 0 end
    
    -- Get room definition to iterate all squares in the room
    local roomDef = room:getRoomDef()
    if not roomDef then
        -- Can't determine room bounds, assume intact
        return 1.0
    end
    
    local cell = getCell()
    if not cell then return 1.0 end
    
    -- Iterate through all squares in the room to check doors/windows
    local hasBrokenOpening = false
    
    for x = roomDef:getX(), roomDef:getX2() do
        for y = roomDef:getY(), roomDef:getY2() do
            local roomSquare = cell:getGridSquare(x, y, roomDef:getZ())
            if roomSquare then
                local objects = roomSquare:getObjects()
                if objects then
                    for i = 0, objects:size() - 1 do
                        local object = objects:get(i)
                        if isObjectBroken(object) then
                            hasBrokenOpening = true
                            break
                        end
                    end
                end
            end
            if hasBrokenOpening then break end
        end
        if hasBrokenOpening then break end
    end
    
    if hasBrokenOpening then
        return 0.5  -- Damaged room = 50% protection
    end
    
    return 1.0  -- Intact room = 100% protection
end

-- Check if player is wearing hazmat suit
-- Requirement 3.3: Hazmat suit provides 100% protection outdoors
function CS_Utils.isWearingHazmat(player)
    if not player then return false end
    
    local config = require("DDA/CS_Config")
    local hazmatItems = config.Protection.hazmatItems or {"Hazmat"}
    
    -- Iterate all worn items (B42 compatible pattern)
    local wornItems = player:getWornItems()
    if not wornItems then return false end
    
    for i = 0, wornItems:size() - 1 do
        local wornItem = wornItems:get(i)
        if wornItem then
            local item = wornItem:getItem()
            if item then
                local itemType = item:getFullType()
                if itemType then
                    for _, hazmatPattern in ipairs(hazmatItems) do
                        if itemType:find(hazmatPattern) then
                            CS_Utils.logVerbose("Hazmat detected: " .. itemType)
                            return true
                        end
                    end
                end
            end
        end
    end
    
    return false
end

-- Calculate total protection level (0.0 to 1.0)
-- Requirements: 3.1, 3.2, 3.3, 3.4, 3.5
function CS_Utils.calculateProtection(player)
    if not player then return 0 end
    
    local config = require("DDA/CS_Config")
    
    -- Check indoor status first (Requirement 3.1, 3.4)
    if CS_Utils.isPlayerIndoors(player) then
        local integrity = CS_Utils.getRoomIntegrity(player)
        if integrity >= 1.0 then
            -- Requirement 3.1: 100% protection indoors with intact room
            return config.Protection.indoorIntact
        else
            -- Requirement 3.2: 50% protection with broken doors/windows
            return config.Protection.indoorDamaged
        end
    end
    
    -- Outdoor - check for hazmat (Requirement 3.3)
    if CS_Utils.isWearingHazmat(player) then
        return config.Protection.outdoorHazmat
    end
    
    -- Requirement 3.4: 0% protection outdoors without hazmat
    return config.Protection.outdoorNone
end

-- Calculate actual damage after protection (Requirement 3.5)
-- Formula: actualDamage = baseDamage * (1 - protectionLevel)
function CS_Utils.calculateDamageAfterProtection(baseDamage, protectionLevel)
    if not baseDamage or baseDamage <= 0 then return 0 end
    if not protectionLevel then protectionLevel = 0 end
    
    -- Clamp protection between 0 and 1
    protectionLevel = math.max(0, math.min(1, protectionLevel))
    
    return baseDamage * (1 - protectionLevel)
end

-- ============================================================================
-- RANDOM HELPERS
-- ============================================================================

-- Get random element from array
function CS_Utils.randomElement(array)
    if not array or #array == 0 then return nil end
    local index = ZombRand(#array) + 1
    return array[index]
end

-- Random chance check (0.0 to 1.0)
function CS_Utils.randomChance(chance)
    return ZombRand(100) / 100 < chance
end

-- Random integer in range (inclusive)
function CS_Utils.randomRange(min, max)
    return ZombRand(max - min + 1) + min
end

-- ============================================================================
-- TIME HELPERS
-- ============================================================================

-- Get current world age in hours
function CS_Utils.getWorldAgeHours()
    return getGameTime():getWorldAgeHours()
end

-- Get current game time in minutes
function CS_Utils.getGameTimeMinutes()
    local gt = getGameTime()
    return gt:getDay() * 24 * 60 + gt:getHour() * 60 + gt:getMinutes()
end

-- ============================================================================
-- ZOMBIE HELPERS
-- ============================================================================

-- Check if zombie is a special type by outfit
function CS_Utils.isSpecialZombie(zombie)
    if not zombie then return false, nil end
    
    local outfitName = zombie:getOutfitName()
    if not outfitName then return false, nil end
    
    local config = require("DDA/CS_Config")
    
    for typeName, typeData in pairs(config.SpecialZombies) do
        if outfitName == typeData.outfit then
            return true, typeName
        end
    end
    
    return false, nil
end

-- Get special zombie type by outfit name
function CS_Utils.getSpecialZombieType(outfitName)
    if not outfitName then return nil end
    
    local config = require("DDA/CS_Config")
    
    for typeName, typeData in pairs(config.SpecialZombies) do
        if outfitName == typeData.outfit then
            return typeName
        end
    end
    
    return nil
end

-- Prevent stale zombie error 5000
function CS_Utils.preventStaleZombieError(zombie)
    if not zombie then return end
    
    local cell = getCell()
    if cell then
        local fakeZombie = cell:getFakeZombieForHit()
        if fakeZombie then
            zombie:setAttackedBy(fakeZombie)
        end
    end
end

-- ============================================================================
-- ITEM HELPERS
-- ============================================================================

-- Drop item at square
function CS_Utils.dropItemAtSquare(square, itemType)
    if not square or not itemType then return false end
    
    local x = square:getX()
    local y = square:getY()
    local z = square:getZ()
    
    square:AddWorldInventoryItem(itemType, 0, 0, 0)
    CS_Utils.logInfo("Dropped " .. itemType .. " at " .. x .. "," .. y .. "," .. z)
    
    return true
end

return CS_Utils
