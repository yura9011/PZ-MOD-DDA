-- ============================================
-- TitanTest Debug Spawner
-- Run in debug console with various methods
-- ============================================

TitanDebug = TitanDebug or {}

-- Method 1: Using addZombiesInOutfit (recommended)
function TitanDebug.Spawn()
    local player = getPlayer()
    if not player then 
        print("[TitanDebug] No player found")
        return 
    end
    
    local x = player:getX() + 3
    local y = player:getY() + 3
    local z = player:getZ()
    
    -- addZombiesInOutfit(x, y, z, count, outfitName, radius)
    addZombiesInOutfit(x, y, z, 1, "TitanTest", 0)
    
    print("[TitanDebug] Spawned TitanTest zombie at " .. x .. ", " .. y)
    return true
end

-- Method 2: Using square:addZombie() then dress
function TitanDebug.SpawnAlt()
    local player = getPlayer()
    if not player then return end
    
    local x = player:getX() + 3
    local y = player:getY() + 3
    local z = player:getZ()
    
    local cell = getCell()
    local square = cell:getGridSquare(x, y, z)
    if not square then 
        print("[TitanDebug] Invalid square")
        return nil 
    end
    
    local zombie = square:addZombie()
    
    if zombie then
        zombie:dressInNamedOutfit("TitanTest")
        print("[TitanDebug] Spawned TitanTest via addZombie")
    end
    return zombie
end

-- Method 3: Using IsoZombie.new (most control)
function TitanDebug.SpawnRaw()
    local player = getPlayer()
    if not player then return end
    
    local x = player:getX() + 2
    local y = player:getY() + 2
    local z = player:getZ()
    
    local cell = getCell()
    local square = cell:getGridSquare(x, y, z)
    if not square then return end
    
    local zombie = IsoZombie.new(cell)
    zombie:setX(x)
    zombie:setY(y)
    zombie:setZ(z)
    zombie:setSquare(square)
    zombie:dressInNamedOutfit("TitanTest")
    square:getMovingObjects():add(zombie)
    
    print("[TitanDebug] Spawned TitanTest via IsoZombie.new")
    return zombie
end

-- Spawn multiple for comparison
function TitanDebug.SpawnMany(count)
    count = count or 5
    for i = 1, count do
        TitanDebug.Spawn()
    end
    print("[TitanDebug] Spawned " .. count .. " TitanTest zombies")
end

print("[TitanDebug] Commands loaded:")
print("  TitanDebug.Spawn()       - Spawn 1 TitanTest (addZombiesInOutfit)")
print("  TitanDebug.SpawnAlt()    - Spawn 1 TitanTest (square:addZombie)")
print("  TitanDebug.SpawnRaw()    - Spawn 1 TitanTest (IsoZombie.new)")
print("  TitanDebug.SpawnMany(5)  - Spawn multiple")
