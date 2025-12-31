-- DDA Rare Spawn Event: "The Titan"
-- Replaces complex boss logic with a simple, lore-friendly rare encounter system.

local RareSpawnEvent = {}
local ZombieStats = require "DDA/ZombieStats"

-- Config
RareSpawnEvent.Outfit = "Juggernaut"
RareSpawnEvent.Chance = 5  -- 5% chance per day check
RareSpawnEvent.CheckInterval = 24 -- Check every 24 hours
RareSpawnEvent.MinionCount = 8
RareSpawnEvent.SprinterCount = 6  -- Doubled for more threat
RareSpawnEvent.TitanName = "Subject 4 (Titan)"
RareSpawnEvent.SpawnDistMin = 50  -- Minimum spawn distance
RareSpawnEvent.SpawnDistMax = 70  -- Maximum spawn distance

-- Helper: Get all online players (works for SP and MP)
local function getAllPlayers()
    local world = getWorld()
    local gamemode = world:getGameMode()
    
    if gamemode == "Multiplayer" then
        return getOnlinePlayers()
    else
        return IsoPlayer.getPlayers()
    end
end

-- Logic: "The Wandering Threat" - Multiplayer Aware
-- Each player online (and outside) gets their own 5% roll
-- This naturally scales: more players = more chances for Titan
RareSpawnEvent.CheckSpawn = function()
    local playerList = getAllPlayers()
    if not playerList then return end
    
    for i = 0, playerList:size() - 1 do
        local player = playerList:get(i)
        
        -- Only consider players who are outside (anti-griefing)
        if player and player:isOutside() then
            -- Each player rolls independently
            if ZombRand(100) < RareSpawnEvent.Chance then
                RareSpawnEvent.SpawnTitan(player)
                -- Note: Multiple Titans can spawn if multiple players win the roll
            end
        end
    end
end

-- Spawn Logic
RareSpawnEvent.SpawnTitan = function(player)
    if not player then return end
    
    local x, y, z = player:getX(), player:getY(), player:getZ()
    
    -- Pick a random spot 50-70 tiles away (wandering threat, not immediate)
    local distRange = RareSpawnEvent.SpawnDistMax - RareSpawnEvent.SpawnDistMin
    local dist = RareSpawnEvent.SpawnDistMin + ZombRand(distRange)
    local angle = ZombRand(360)
    local spawnX = x + dist * math.cos(math.rad(angle))
    local spawnY = y + dist * math.sin(math.rad(angle))
    
    -- Validation: Ensure valid square (not water, not void)
    local cell = getCell()
    local grid = cell:getGridSquare(spawnX, spawnY, z)
    
    -- If invalid or blocked, try a fallback (simple offset)
    if not grid or not grid:isFree(false) then
        spawnX = x + 50
        spawnY = y + 50
    end
    
    print("[DDA] !!! WARNING: TITAN DETECTED NEARBY !!!")
    player:Say("Do you hear that heavy breathing...?")
    
    -- 1. Spawn The Titan
    local bossList = addZombiesInOutfit(spawnX, spawnY, z, 1, RareSpawnEvent.Outfit, 0)
    if bossList and bossList:size() > 0 then
        local boss = bossList:get(0)
        ZombieStats.MakeBoss(boss)
        boss:setDir(IsoDirections.S)
        
        -- Add Rare Weapon Drop (Katana - rare vanilla weapon)
        -- TODO: Replace with DDA.TitanAxe once B42 script is fixed
        local weapon = boss:getInventory():AddItem("Base.Katana")
        
        -- Attach it visibly to their back if possible
        if weapon and boss.setAttachedItem then
            boss:setAttachedItem("Big Weapon On Back", weapon)
            print("[DDA] Titan spawned with Katana!")
        end
    end

    
    -- 2. Spawn The Horde (Sprinters)
    -- Hot-Swap: Temporarily set global speed to Sprinter
    local sandbox = getSandboxOptions()
    local speedOption = sandbox:getOptionByName("ZombieLore.Speed")
    local oldSpeed = speedOption:getValue()
    
    sandbox:set("ZombieLore.Speed", 1) -- 1 = Sprinters
    local sprinters = addZombiesInOutfit(spawnX - 2, spawnY - 2, z, RareSpawnEvent.SprinterCount, nil, 50)
    sandbox:set("ZombieLore.Speed", oldSpeed) -- Revert immediately
    
    if sprinters then
        for i=0, sprinters:size()-1 do
            local s = sprinters:get(i)
            ZombieStats.MakeSprinter(s) -- Apply our speed boost
        end
    end
    
    -- 3. Spawn The Fodder (Standard walkers)
    addZombiesInOutfit(spawnX + 2, spawnY + 2, z, RareSpawnEvent.MinionCount, nil, 50)
    
    -- Sound Effect? (Optional, skipping for now)
end

-- Debug Trigger
RareSpawnEvent.ForceSpawn = function()
    local p = getPlayer()
    if p then
        print("[DDA] FORCE SPAWN TRIGGERED")
        RareSpawnEvent.SpawnTitan(p)
    end
end

-- Automatic Timer
Events.EveryHours.Add(function()
    -- Only check once per day (e.g. at 2 AM or just check if hour % 24 == 0)
    -- Or check every hour with very low chance? 
    -- User asked for "Every 24h".
    
    local hour = getGameTime():getHour()
    if hour == 22 then -- Night Hunter
        RareSpawnEvent.CheckSpawn()
    end
end)

return RareSpawnEvent
