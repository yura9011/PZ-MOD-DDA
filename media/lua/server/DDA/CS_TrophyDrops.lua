-- DDA Trophy Drop System
-- Handles drops from special zombies when they die
-- Requirements: 6.1, 6.2, 6.3, 6.4, 7.1, 7.2, 7.3

local CS_TrophyDrops = {}

-- Load dependencies
local CS_Config = require("DDA/CS_Config")
local CS_Utils = require("DDA/CS_Utils")

-- ============================================================================
-- SPECIAL ZOMBIE DETECTION (Requirements 6.3, 7.3)
-- ============================================================================

--- Check if a zombie is a special type by its outfit name
--- @param zombie IsoZombie The zombie to check
--- @return boolean isSpecial True if the zombie is a special type
--- @return string|nil typeName The type name if special, nil otherwise
function CS_TrophyDrops.isSpecialZombie(zombie)
    if not zombie then 
        return false, nil 
    end
    
    -- Priority 1: Check ModData (Reliable from SpawnSpecial)
    if zombie:getModData().cs_type then
        return true, zombie:getModData().cs_type
    end
    
    -- Priority 2: Check Outfit (Legacy/Natural Spawns)
    local outfitName = zombie:getOutfitName()
    if outfitName then 
        for typeName, typeData in pairs(CS_Config.SpecialZombies) do
            if outfitName == typeData.outfit then
                return true, typeName
            end
        end
    end
    
    return false, nil
end

-- ============================================================================
-- DROP LOGIC (Requirements 6.1, 6.2, 6.4, 7.1, 7.2)
-- ============================================================================

--- Get the drop table for a special zombie type
--- @param typeName string The special zombie type name (titan, stalker, brute)
--- @return table|nil drops Array of drop definitions or nil if type not found
function CS_TrophyDrops.getDropsForType(typeName)
    if not typeName then return nil end
    
    local typeData = CS_Config.SpecialZombies[typeName]
    if not typeData then return nil end
    
    return typeData.drops
end

--- Drop items into zombie inventory (safer than world drop)
--- @param zombie IsoZombie The zombie to add items to
--- @param drops table Array of drop definitions {item, chance}
--- @return number count Number of items dropped
function CS_TrophyDrops.dropItems(zombie, drops)
    if not zombie or not drops then return 0 end
    
    local count = 0
    local inventory = zombie:getInventory()
    
    for _, dropDef in ipairs(drops) do
        local itemType = dropDef.item
        local chance = dropDef.chance or 1.0
        
        -- Roll for drop chance
        if CS_Utils.randomChance(chance) then
            -- Add directly to inventory
            inventory:AddItem(itemType)
            count = count + 1
            
            CS_Utils.logInfo("Added " .. itemType .. " to zombie inventory")
        end
    end
    
    return count
end

--- Process trophy drops when a zombie dies
--- @param zombie IsoZombie The zombie that died
--- @return boolean success True if drops were processed
function CS_TrophyDrops.processDeath(zombie)
    if not zombie then 
        CS_Utils.logWarning("processDeath called with nil zombie")
        return false 
    end
    
    -- Check if this is a special zombie
    local isSpecial, typeName = CS_TrophyDrops.isSpecialZombie(zombie)
    
    if not isSpecial then
        return false
    end
    
    CS_Utils.logInfo("Special zombie death detected: " .. typeName)
    
    -- Get drops for this zombie type
    local drops = CS_TrophyDrops.getDropsForType(typeName)
    if not drops or #drops == 0 then
        CS_Utils.logWarning("No drops defined for type: " .. typeName)
        return false
    end
    
    -- Drop the items into inventory
    local dropCount = CS_TrophyDrops.dropItems(zombie, drops)
    
    CS_Utils.logInfo("Added " .. dropCount .. " trophy items to " .. typeName)
    
    return dropCount > 0
end

-- ============================================================================
-- EVENT HANDLER
-- ============================================================================

--- OnZombieDead event handler
--- CRITICAL: OnZombieDead fires BEFORE death completes and only fires ONCE per zombie
--- @param zombie IsoZombie The zombie that died
function CS_TrophyDrops.onZombieDead(zombie)
    -- Process trophy drops
    CS_TrophyDrops.processDeath(zombie)
end

-- Register event handler
Events.OnZombieDead.Add(CS_TrophyDrops.onZombieDead)

CS_Utils.logInfo("Trophy Drop System initialized")

return CS_TrophyDrops
