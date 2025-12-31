-- DDA Special Zombies Property Tests
-- Property-based tests for the Special Zombie Spawner System
-- Run via debug console: CS_SpecialZombies_Tests.runAll()

local CS_SpecialZombies_Tests = {}

-- Load dependencies
local CS_Config = require("DDA/CS_Config")
local CS_SpecialZombies = require("DDA/CS_SpecialZombies")

-- ============================================================================
-- TEST FRAMEWORK (Simple PBT Implementation)
-- ============================================================================

local TestResults = {
    passed = 0,
    failed = 0,
    errors = {}
}

local function resetResults()
    TestResults.passed = 0
    TestResults.failed = 0
    TestResults.errors = {}
end

local function recordPass(testName)
    TestResults.passed = TestResults.passed + 1
    print("[PASS] " .. testName)
end

local function recordFail(testName, message, example)
    TestResults.failed = TestResults.failed + 1
    local errorInfo = {
        test = testName,
        message = message,
        example = example
    }
    table.insert(TestResults.errors, errorInfo)
    print("[FAIL] " .. testName .. ": " .. message)
    if example then
        print("       Failing example: " .. tostring(example))
    end
end

-- ============================================================================
-- MOCK GENERATORS
-- ============================================================================

--- Generate a mock room object
--- @param roomName string|nil The room name
--- @return table mockRoom A mock room object
local function generateMockRoom(roomName)
    if roomName == nil then
        return nil
    end
    
    return {
        _name = roomName,
        getName = function(self) return self._name end
    }
end

--- Generate a mock square object
--- @param roomName string|nil The room name (nil = outdoor)
--- @param x number|nil X coordinate
--- @param y number|nil Y coordinate
--- @param z number|nil Z coordinate
--- @return table mockSquare A mock square object
local function generateMockSquare(roomName, x, y, z)
    local mockRoom = generateMockRoom(roomName)
    
    return {
        _x = x or 100,
        _y = y or 100,
        _z = z or 0,
        _room = mockRoom,
        getX = function(self) return self._x end,
        getY = function(self) return self._y end,
        getZ = function(self) return self._z end,
        getRoom = function(self) return self._room end
    }
end

--- Generate a mock zombie object
--- @param square table|nil The mock square
--- @param health number|nil Base health
--- @return table mockZombie A mock zombie object
local function generateMockZombie(square, health)
    local mockModData = {}
    
    return {
        _square = square,
        _health = health or 100,
        _modData = mockModData,
        _persistentID = ZombRand(1000000) + 1,
        _outfitName = nil,
        getCurrentSquare = function(self) return self._square end,
        getHealth = function(self) return self._health end,
        setHealth = function(self, h) self._health = h end,
        getModData = function(self) return self._modData end,
        getPersistentOutfitID = function(self) return self._persistentID end,
        getOutfitName = function(self) return self._outfitName end,
        dressInNamedOutfit = function(self, name) self._outfitName = name end,
        setAttackedBy = function(self, attacker) end  -- No-op for mock
    }
end

--- Generate random room name from a pool
--- @param includeKey boolean Whether to include key building room names
--- @return string|nil roomName A random room name or nil
local function generateRandomRoomName(includeKey)
    local normalRooms = {
        "bedroom", "livingroom", "kitchen", "bathroom", "office",
        "closet", "hallway", "basement", "attic", "diningroom",
        "laundry", "porch", "shed", "store", "restaurant",
        nil  -- Include nil for outdoor
    }
    
    local keyRooms = {
        "factory", "warehouse", "military", "hospital",
        "armory", "pharmacy", "gunstore", "police",
        "industrial", "storage", "mechanic", "barracks"
    }
    
    local pool = {}
    for _, room in ipairs(normalRooms) do
        table.insert(pool, room)
    end
    
    if includeKey then
        for _, room in ipairs(keyRooms) do
            table.insert(pool, room)
        end
    end
    
    local index = ZombRand(#pool) + 1
    return pool[index]
end

-- ============================================================================
-- PROPERTY 20: Key Building Higher Spawn Rate
-- **Feature: DDA-expansion, Property 20: Key Building Higher Spawn Rate**
-- **Validates: Requirements 10.1, 10.2**
--
-- *For any* zombie spawn in a key building (factory, warehouse, military, 
-- hospital), the special conversion chance SHALL be 5%. For non-key buildings, 
-- the chance SHALL be 0.5%.
-- ============================================================================

function CS_SpecialZombies_Tests.property20_KeyBuildingHigherSpawnRate()
    local testName = "Property 20: Key Building Higher Spawn Rate"
    local iterations = 100
    local allPassed = true
    local failingExample = nil
    
    local expectedKeyChance = CS_Config.SpawnChances.keyBuilding      -- 0.05 (5%)
    local expectedNormalChance = CS_Config.SpawnChances.normalBuilding -- 0.005 (0.5%)
    
    for i = 1, iterations do
        -- Generate random room name (including key and normal)
        local roomName = generateRandomRoomName(true)
        local mockSquare = generateMockSquare(roomName)
        
        -- Get spawn chance
        local spawnChance = CS_SpecialZombies.getSpawnChance(mockSquare)
        
        -- Determine if this is a key building
        local isKey = CS_SpecialZombies.isKeyBuilding(mockSquare)
        
        -- Verify spawn chance matches expected
        local expectedChance = isKey and expectedKeyChance or expectedNormalChance
        
        if spawnChance ~= expectedChance then
            allPassed = false
            failingExample = string.format(
                "roomName='%s', isKey=%s, spawnChance=%.4f (expected %.4f)",
                tostring(roomName), tostring(isKey), spawnChance, expectedChance
            )
            break
        end
    end
    
    if allPassed then
        recordPass(testName)
    else
        recordFail(testName, "Spawn chance mismatch", failingExample)
    end
    
    return allPassed, failingExample
end

-- ============================================================================
-- PROPERTY 21: Room Detection Returns Valid Types
-- **Feature: DDA-expansion, Property 21: Room Detection Returns Valid Types**
-- **Validates: Requirements 10.3**
--
-- *For any* square with a room, the room detector SHALL return a valid room 
-- type string or nil.
-- ============================================================================

function CS_SpecialZombies_Tests.property21_RoomDetectionReturnsValidTypes()
    local testName = "Property 21: Room Detection Returns Valid Types"
    local iterations = 100
    local allPassed = true
    local failingExample = nil
    
    for i = 1, iterations do
        -- Generate random room name
        local roomName = generateRandomRoomName(true)
        local mockSquare = generateMockSquare(roomName)
        
        -- Get room name from detector
        local detectedName = CS_SpecialZombies.getRoomName(mockSquare)
        
        -- Verify: if room exists, detected name should match
        if roomName ~= nil then
            if detectedName ~= roomName then
                allPassed = false
                failingExample = string.format(
                    "roomName='%s', detectedName='%s'",
                    tostring(roomName), tostring(detectedName)
                )
                break
            end
        else
            -- If no room (outdoor), detected name should be nil
            if detectedName ~= nil then
                allPassed = false
                failingExample = string.format(
                    "roomName=nil (outdoor), detectedName='%s' (expected nil)",
                    tostring(detectedName)
                )
                break
            end
        end
        
        -- Additional check: isKeyBuilding should return boolean
        local isKey, returnedName = CS_SpecialZombies.isKeyBuilding(mockSquare)
        
        if type(isKey) ~= "boolean" then
            allPassed = false
            failingExample = string.format(
                "isKeyBuilding returned non-boolean: %s (type: %s)",
                tostring(isKey), type(isKey)
            )
            break
        end
        
        -- If isKey is true, returnedName should be the room name
        if isKey and returnedName ~= roomName then
            allPassed = false
            failingExample = string.format(
                "isKey=true but returnedName='%s' != roomName='%s'",
                tostring(returnedName), tostring(roomName)
            )
            break
        end
    end
    
    if allPassed then
        recordPass(testName)
    else
        recordFail(testName, "Room detection issue", failingExample)
    end
    
    return allPassed, failingExample
end

-- ============================================================================
-- PROPERTY 22: Special Type Selection Covers All Types
-- **Feature: DDA-expansion, Property 22: Special Type Selection Covers All Types**
-- **Validates: Requirements 10.4**
--
-- *For any* sufficiently large sample of special zombie conversions, all three 
-- types (Titan, Stalker, Brute) SHALL be represented.
-- ============================================================================

function CS_SpecialZombies_Tests.property22_SpecialTypeSelectionCoversAllTypes()
    local testName = "Property 22: Special Type Selection Covers All Types"
    local iterations = 300  -- Need more iterations to ensure coverage
    local allPassed = true
    local failingExample = nil
    
    -- Track which types have been selected
    local selectedTypes = {}
    local expectedTypes = {}
    
    for typeName, _ in pairs(CS_Config.SpecialZombies) do
        expectedTypes[typeName] = true
        selectedTypes[typeName] = 0
    end
    
    -- Run many selections
    for i = 1, iterations do
        local selectedType = CS_SpecialZombies.selectRandomType()
        
        if selectedType then
            selectedTypes[selectedType] = (selectedTypes[selectedType] or 0) + 1
        end
    end
    
    -- Verify all types were selected at least once
    for typeName, _ in pairs(expectedTypes) do
        if not selectedTypes[typeName] or selectedTypes[typeName] == 0 then
            allPassed = false
            failingExample = string.format(
                "Type '%s' was never selected in %d iterations. Distribution: %s",
                typeName, iterations,
                table.concat(
                    (function()
                        local parts = {}
                        for t, c in pairs(selectedTypes) do
                            table.insert(parts, t .. "=" .. c)
                        end
                        return parts
                    end)(),
                    ", "
                )
            )
            break
        end
    end
    
    if allPassed then
        recordPass(testName)
    else
        recordFail(testName, "Not all types covered", failingExample)
    end
    
    return allPassed, failingExample
end

-- ============================================================================
-- PROPERTY 23: Special Zombie Stats Match Multipliers
-- **Feature: DDA-expansion, Property 23: Special Zombie Stats Match Multipliers**
-- **Validates: Requirements 11.1, 11.2, 11.3**
--
-- *For any* special zombie:
-- - Titan: health = baseHealth * 5, damage = baseDamage * 2
-- - Stalker: health = baseHealth * 2, damage = baseDamage * 1.5
-- - Brute: health = baseHealth * 3, damage = baseDamage * 3
-- ============================================================================

function CS_SpecialZombies_Tests.property23_SpecialZombieStatsMatchMultipliers()
    local testName = "Property 23: Special Zombie Stats Match Multipliers"
    local iterations = 100
    local allPassed = true
    local failingExample = nil
    
    -- Mock the preventStaleZombieError function to avoid needing getCell()
    local originalPrevent = CS_SpecialZombies.applyStats
    
    for i = 1, iterations do
        -- Generate random base health
        local baseHealth = ZombRand(50, 200)
        
        -- Test each special type
        for typeName, typeData in pairs(CS_Config.SpecialZombies) do
            local mockSquare = generateMockSquare("factory")
            local mockZombie = generateMockZombie(mockSquare, baseHealth)
            
            -- Apply stats
            local success = CS_SpecialZombies.applyStats(mockZombie, typeName)
            
            if not success then
                allPassed = false
                failingExample = string.format(
                    "applyStats failed for type '%s'",
                    typeName
                )
                break
            end
            
            -- Verify health multiplier
            local expectedHealth = baseHealth * typeData.healthMultiplier
            local actualHealth = mockZombie:getHealth()
            
            -- Allow small floating point tolerance
            if math.abs(actualHealth - expectedHealth) > 0.01 then
                allPassed = false
                failingExample = string.format(
                    "type='%s', baseHealth=%d, expectedHealth=%.2f, actualHealth=%.2f (multiplier=%.1f)",
                    typeName, baseHealth, expectedHealth, actualHealth, typeData.healthMultiplier
                )
                break
            end
            
            -- Verify damage multiplier is stored in ModData
            local modData = mockZombie:getModData()
            if modData.CS_DamageMultiplier ~= typeData.damageMultiplier then
                allPassed = false
                failingExample = string.format(
                    "type='%s', expectedDamageMultiplier=%.1f, actualDamageMultiplier=%.1f",
                    typeName, typeData.damageMultiplier, modData.CS_DamageMultiplier or 0
                )
                break
            end
            
            -- Verify type is stored in ModData
            if modData.CS_SpecialType ~= typeName then
                allPassed = false
                failingExample = string.format(
                    "type='%s', storedType='%s'",
                    typeName, tostring(modData.CS_SpecialType)
                )
                break
            end
        end
        
        if not allPassed then break end
    end
    
    if allPassed then
        recordPass(testName)
    else
        recordFail(testName, "Stats mismatch", failingExample)
    end
    
    return allPassed, failingExample
end

-- ============================================================================
-- TEST RUNNER
-- ============================================================================

function CS_SpecialZombies_Tests.runAll()
    print("========================================")
    print("DDA Special Zombies Property Tests")
    print("========================================")
    
    resetResults()
    
    -- Run all property tests
    CS_SpecialZombies_Tests.property20_KeyBuildingHigherSpawnRate()
    CS_SpecialZombies_Tests.property21_RoomDetectionReturnsValidTypes()
    CS_SpecialZombies_Tests.property22_SpecialTypeSelectionCoversAllTypes()
    CS_SpecialZombies_Tests.property23_SpecialZombieStatsMatchMultipliers()
    
    -- Print summary
    print("========================================")
    print(string.format("Results: %d passed, %d failed", 
        TestResults.passed, TestResults.failed))
    print("========================================")
    
    if TestResults.failed > 0 then
        print("Failing tests:")
        for _, err in ipairs(TestResults.errors) do
            print("  - " .. err.test)
            print("    " .. err.message)
            if err.example then
                print("    Example: " .. err.example)
            end
        end
    end
    
    return TestResults
end

-- Export for debug console access
_G.CS_SpecialZombies_Tests = CS_SpecialZombies_Tests

return CS_SpecialZombies_Tests
