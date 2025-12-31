-- DDA Zombie Stats Manager
-- Handles modification of zombie statistics (Health, Speed, Strength)

local ZombieStats = {}

-- Apply Boss Stats to a Zombie
function ZombieStats.MakeBoss(zombie)
    if not zombie then return end
    
    zombie:setHealth(4.5) 
    zombie:setSpeedMod(0.55)
    zombie:setUseless(false) 
    zombie:setTarget(nil)
    
    print("[DDA] Applied Boss Stats to Juggernaut ID: " .. tostring(zombie:getOnlineID()))
end

-- Force a zombie to be a Sprinter
function ZombieStats.MakeSprinter(zombie)
    if not zombie then return end
    
    -- Attempting to force animation variables known in B41/B42
    pcall(function() zombie:setVariable("forceSprint", true) end)
    pcall(function() zombie:setVariable("bSprinting", true) end)
    pcall(function() zombie:setVariable("isSprinting", true) end)
    
    -- Speed Mod (Mechanical Speed)
    -- 2.0 = Very fast, should be noticeable
    zombie:setSpeedMod(2.0)
    
    -- Reset other stats (fragile but fast)
    zombie:setHealth(1.0)
    
    -- Force update
    pcall(function() zombie:DoZombieStats() end)
end

return ZombieStats
