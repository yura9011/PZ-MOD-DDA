-- CS_SpecialZombies.lua
-- Handles detection of special buildings and spawning of special zombies (Requirement 10.1, 10.2)

local CS_Config = require("DDA/CS_Config")
local CS_Utils = require("DDA/CS_Utils")

-- Cache globals for performance (Critical for OnZombieUpdate)
local ZombRand = ZombRand
local string_find = string.find
local ipairs = ipairs

local CS_SpecialZombies = {}

--- Check if a square belongs to a key building (Requirement 10.3)
--- @param square IsoGridSquare The square to check
--- @return boolean isKey True if the square is in a key building
function CS_SpecialZombies.isKeyBuilding(square)
    if not square then return false end
    
    local room = square:getRoom()
    if not room then return false end
    
    local roomName = room:getName()
    if not roomName then return false end
    
    roomName = roomName:lower()
    
    for _, pattern in ipairs(CS_Config.KeyRoomPatterns) do
        if string.find(roomName, pattern) then
            return true
        end
    end
    
    return false
end

--- Determine the type of special zombie to spawn
--- @return string type Zombie type ID (titan, stalker, brute)
function CS_SpecialZombies.rollZombieType()
    local roll = ZombRand(100)
    if roll < 15 then -- 15% Titan
        return "titan"
    elseif roll < 30 then -- 15% Abomination
        return "abomination"
    elseif roll < 65 then -- 35% Stalker
        return "stalker"
    else -- 35% Brute
        return "brute"
    end
end

--- Process a zombie spawn event to see if it should be special
--- @param zombie IsoZombie The zombie that just spawned
function CS_SpecialZombies.onZombieUpdate(zombie)
    -- Early exit for efficiency
    if not zombie then return end
    
    local modData = zombie:getModData()
    if modData.CS_Processed then return end
    modData.CS_Processed = true
    
    local square = zombie:getSquare()
    if not square then 
        -- If square is nil, retry next update
        modData.CS_Processed = false
        return 
    end
    
    local isKey = CS_SpecialZombies.isKeyBuilding(square)
    local chance = isKey and CS_Config.SpawnChances.keyBuilding or CS_Config.SpawnChances.normalBuilding
    
    if CS_Utils.randomChance(chance) then
        local zombieType = CS_SpecialZombies.rollZombieType()
        CS_SpecialZombies.makeSpecial(zombie, zombieType)
    end
end

--- Transform a normal zombie into a special zombie
--- @param zombie IsoZombie The zombie to transform
--- @param zombieType string Type of special zombie (titan, stalker, brute)
function CS_SpecialZombies.makeSpecial(zombie, zombieType)
    local typeData = CS_Config.SpecialZombies[zombieType]
    if not typeData then return end
    
    local room = zombie:getSquare():getRoom()
    local roomName = room and room:getName() or "outside"
    CS_Utils.logInfo("Spawning special zombie: " .. zombieType .. " in room: " .. roomName)
    
    -- Apply outfit safely
    local status, err = pcall(function()
        if zombie.dressInNamedOutfit then
            zombie:dressInNamedOutfit(typeData.outfit)
        end
    end)
    if not status then 
        print("[CS_SpecialZombies] Error setting outfit: " .. tostring(err)) 
    end
    
    -- Stats multipliers safely
    pcall(function()
        if typeData.healthMultiplier then
            local newMaxHealth = nil
            
            -- Try to get current max health
            if zombie.getMaxHealth and type(zombie.getMaxHealth) == "function" then
                local currentMax = zombie:getMaxHealth()
                newMaxHealth = currentMax * typeData.healthMultiplier
            else
                print("[CS_SpecialZombies] Warning: getMaxHealth missing on zombie object")
            end
            
            -- Only proceed if we successfully calculated a new max health
            if newMaxHealth then
                -- Set new max health
                if zombie.setMaxHealth and type(zombie.setMaxHealth) == "function" then
                    zombie:setMaxHealth(newMaxHealth)
                else
                    print("[CS_SpecialZombies] Warning: setMaxHealth missing on zombie object")
                end
                
                -- Heal to new max
                if zombie.setHealth and type(zombie.setHealth) == "function" then
                    zombie:setHealth(newMaxHealth)
                else
                     print("[CS_SpecialZombies] Warning: setHealth missing on zombie object")
                end
            end
        end
        
        -- Force stats update (MP safety)
        if zombie.DoZombieStats and type(zombie.DoZombieStats) == "function" then
            zombie:DoZombieStats()
        end
    end)
    
    -- Store type for drop logic later
    zombie:getModData().CS_Type = zombieType
end

-- Hook into zombie spawn
-- Note: OnZombieUpdate is expensive if checking all zombies every tick.
-- We should use OnCreateZombie if it exists in B42, or a periodic scan.
-- For now, using a simple check on first update.
Events.OnZombieUpdate.Add(CS_SpecialZombies.onZombieUpdate)

return CS_SpecialZombies
