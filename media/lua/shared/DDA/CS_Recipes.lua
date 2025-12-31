-- DDA Recipe Callbacks
-- Handles custom recipe logic for Titan weapon reforging
-- Requirements: 8.2, 8.3, 8.4

-- Ensure Recipe.OnCreate table exists
Recipe = Recipe or {}
Recipe.OnCreate = Recipe.OnCreate or {}

--- OnCreate callback for Reforge Titan Weapon recipe
-- Ensures the reforged weapon has full condition
-- @param items Table of input items used in the recipe
-- @param result The resulting TitanWeapon
-- @param player The player performing the craft
function Recipe.OnCreate.ReforgeTitanWeapon(items, result, player)
    if not result then return end
    
    -- Set the weapon to full condition (Requirement 8.3)
    result:setCondition(result:getConditionMax())
    
    -- Log for debugging
    if CS_Config and CS_Config.Debug and CS_Config.Debug.enabled then
        print("[DDA] Titan Weapon reforged to full condition: " .. result:getCondition() .. "/" .. result:getConditionMax())
    end
    
    -- Give some XP for the craft
    if player then
        player:getXp():AddXP(Perks.MetalWelding, 10)
    end
end

print("[DDA] Recipe callbacks loaded")
