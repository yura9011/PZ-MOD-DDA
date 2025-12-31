-- DDA OnBreak Handlers
-- Handles weapon breaking behavior for Titan weapons
-- Requirements: 8.1 (Broken weapon persistence)

-- Ensure OnBreak table exists
OnBreak = OnBreak or {}

--- OnBreak handler for TitanWeapon
-- When a TitanWeapon breaks, it becomes a TitanWeapon_Broken instead of being destroyed
-- This allows the player to reforge it with a TitanCore
-- @param item The TitanWeapon that is breaking
-- @param player The player using the weapon (may be nil)
function OnBreak.TitanWeapon(item, player)
    if not item then return end
    
    local inv
    local cont = item:getContainer()
    local sq
    
    -- Get the square if item is in world
    if item:getWorldItem() and item:getWorldItem():getSquare() then 
        sq = item:getWorldItem():getSquare() 
    end
    
    local newItem
    
    -- Handle based on where the item is
    if player and cont == player:getInventory() then
        -- Item is in player's inventory
        inv = player:getInventory()
        newItem = inv:AddItem("DDA.TitanWeapon_Broken")
        
        if newItem then
            -- If player was holding the weapon, equip the broken version
            local primary = player:getPrimaryHandItem() == item
            local secondary = player:getSecondaryHandItem() == item
            
            if primary then
                player:setPrimaryHandItem(newItem)
                if newItem:isTwoHandWeapon() and secondary then 
                    player:setSecondaryHandItem(newItem) 
                end
            elseif secondary then 
                player:setSecondaryHandItem(newItem) 
            end
            
            player:reportEvent("EventAttachItem")
        end
        
        -- Set condition to max for the broken weapon (it's a new item)
        if newItem then
            newItem:setCondition(newItem:getConditionMax())
        end
        
    elseif sq then
        -- Item is in the world
        newItem = sq:AddWorldInventoryItem("DDA.TitanWeapon_Broken", ZombRand(100)/100, ZombRand(100)/100, 0.0)
        
    elseif cont then
        -- Item is in a container
        newItem = cont:AddItem("DDA.TitanWeapon_Broken")
    end
    
    if not newItem then return end
    
    -- Copy blood level from original weapon
    newItem:copyBloodLevelFrom(item)
    
    -- Sync for multiplayer
    newItem:SynchSpawn()
    
    -- Remove the original weapon
    item:Remove()
    
    -- Trigger container update event
    triggerEvent("OnContainerUpdate")
    
    -- Log for debugging
    if CS_Config and CS_Config.Debug and CS_Config.Debug.enabled then
        print("[DDA] TitanWeapon broke -> TitanWeapon_Broken created")
    end
end

print("[DDA] OnBreak handlers loaded")
