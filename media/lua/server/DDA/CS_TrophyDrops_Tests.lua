-- DDA Trophy Drops Property Tests
-- Property-based tests for the Trophy Drop System
-- Run via debug console: CS_TrophyDrops_Tests.runAll()

local CS_TrophyDrops_Tests = {}

-- Load dependencies
local CS_Config = require("DDA/CS_Config")
local CS_TrophyDrops = require("DDA/CS_TrophyDrops")

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
-- MOCK ZOMBIE GENERATOR
-- ============================================================================

--- Generate a mock zombie object for testing
--- @param outfitName string|nil The outfit name to assign
--- @param x number|nil X coordinate
--- @param y number|nil Y coordinate
--- @param z number|nil Z coordinate
--- @return table mockZombie A mock zombie object
local function generateMockZombie(outfitName, x, y, z)
    local mockSquare = {
        _x = x or 100,
        _y = y or 100,
        _z = z or 0,
        _items = {},
        getX = function(self) return self._x end,
        getY = function(self) return self._y end,
        getZ = function(self) return self._z end,
        AddWorldInventoryItem = function(self, itemType, ox, oy, oz)
            table.insert(self._items, {
                itemType = itemType,
                offsetX = ox,
                offsetY = oy,
                offsetZ = oz
            })
            return true
        end,
        getItems = function(self) return self._items end
    }
    
    local mockZombie = {
        _outfitName = outfitName,
        _square = mockSquare,
        getOutfitName = function(self) return self._outfitName end,
        getCurrentSquare = function(self) return self._square end
    }
    
    return mockZombie
end

--- Generate random outfit name from a pool
--- @param includeSpecial boolean Whether to include special zombie outfits
--- @return string outfitName A random outfit name
local function generateRandomOutfit(includeSpecial)
    local normalOutfits = {
        "Civilian", "Police", "Firefighter", "Doctor", "Nurse",
        "Worker", "Farmer", "Chef", "Mechanic", "Soldier",
        nil -- Include nil as a possibility
    }
    
    local specialOutfits = {}
    for _, typeData in pairs(CS_Config.SpecialZombies) do
        table.insert(specialOutfits, typeData.outfit)
    end
    
    local pool = {}
    for _, outfit in ipairs(normalOutfits) do
        table.insert(pool, outfit)
    end
    
    if includeSpecial then
        for _, outfit in ipairs(specialOutfits) do
            table.insert(pool, outfit)
        end
    end
    
    local index = ZombRand(#pool) + 1
    return pool[index]
end

-- ============================================================================
-- PROPERTY 13: Special Zombie Detection By Outfit
-- **Feature: DDA-expansion, Property 13: Special Zombie Detection By Outfit**
-- **Validates: Requirements 6.3, 7.3**
-- 
-- *For any* zombie, the system SHALL correctly identify it as special if and 
-- only if its outfit name matches a registered special type ("Juggernaut", 
-- "Stalker", "Brute").
-- ============================================================================

function CS_TrophyDrops_Tests.property13_SpecialZombieDetectionByOutfit()
    local testName = "Property 13: Special Zombie Detection By Outfit"
    local iterations = 100
    local allPassed = true
    local failingExample = nil
    
    -- Build set of valid special outfits
    local specialOutfits = {}
    for typeName, typeData in pairs(CS_Config.SpecialZombies) do
        specialOutfits[typeData.outfit] = typeName
    end
    
    for i = 1, iterations do
        -- Generate random outfit (including special and normal)
        local outfit = generateRandomOutfit(true)
        local mockZombie = generateMockZombie(outfit)
        
        -- Test detection
        local isSpecial, detectedType = CS_TrophyDrops.isSpecialZombie(mockZombie)
        
        -- Expected result
        local expectedSpecial = outfit ~= nil and specialOutfits[outfit] ~= nil
        local expectedType = outfit and specialOutfits[outfit] or nil
        
        -- Verify: isSpecial should be true IFF outfit is in specialOutfits
        if isSpecial ~= expectedSpecial then
            allPassed = false
            failingExample = string.format(
                "outfit='%s', isSpecial=%s (expected %s)",
                tostring(outfit), tostring(isSpecial), tostring(expectedSpecial)
            )
            break
        end
        
        -- Verify: detectedType should match expected type
        if isSpecial and detectedType ~= expectedType then
            allPassed = false
            failingExample = string.format(
                "outfit='%s', detectedType='%s' (expected '%s')",
                tostring(outfit), tostring(detectedType), tostring(expectedType)
            )
            break
        end
    end
    
    if allPassed then
        recordPass(testName)
    else
        recordFail(testName, "Detection mismatch", failingExample)
    end
    
    return allPassed, failingExample
end

-- ============================================================================
-- PROPERTY 14: Special Zombie Drops At Correct Location
-- **Feature: DDA-expansion, Property 14: Special Zombie Drops At Correct Location**
-- **Validates: Requirements 6.4, 7.1, 7.2**
--
-- *For any* special zombie death, all dropped items SHALL be placed on the 
-- same tile where the zombie died.
-- ============================================================================

function CS_TrophyDrops_Tests.property14_DropsAtCorrectLocation()
    local testName = "Property 14: Special Zombie Drops At Correct Location"
    local iterations = 100
    local allPassed = true
    local failingExample = nil
    
    -- Get all special outfits
    local specialOutfits = {}
    for typeName, typeData in pairs(CS_Config.SpecialZombies) do
        table.insert(specialOutfits, typeData.outfit)
    end
    
    for i = 1, iterations do
        -- Generate random coordinates
        local x = ZombRand(10000)
        local y = ZombRand(10000)
        local z = ZombRand(8) - 4  -- -4 to 3
        
        -- Pick a random special outfit
        local outfit = specialOutfits[ZombRand(#specialOutfits) + 1]
        local mockZombie = generateMockZombie(outfit, x, y, z)
        
        -- Process death
        CS_TrophyDrops.processDeath(mockZombie)
        
        -- Get dropped items
        local square = mockZombie:getCurrentSquare()
        local items = square:getItems()
        
        -- Verify all items were dropped at the zombie's square
        for _, item in ipairs(items) do
            -- Items should be at offset 0,0,0 from the square
            if item.offsetX ~= 0 or item.offsetY ~= 0 or item.offsetZ ~= 0 then
                allPassed = false
                failingExample = string.format(
                    "Item '%s' dropped at offset (%d,%d,%d) instead of (0,0,0) at square (%d,%d,%d)",
                    item.itemType, item.offsetX, item.offsetY, item.offsetZ, x, y, z
                )
                break
            end
        end
        
        if not allPassed then break end
    end
    
    if allPassed then
        recordPass(testName)
    else
        recordFail(testName, "Item dropped at wrong location", failingExample)
    end
    
    return allPassed, failingExample
end

-- ============================================================================
-- PROPERTY 15: Titan Drops Both Items
-- **Feature: DDA-expansion, Property 15: Titan Drops Both Items**
-- **Validates: Requirements 6.1, 6.2**
--
-- *For any* Titan zombie death, the system SHALL drop exactly one TitanWeapon 
-- AND one TitanCore.
-- ============================================================================

function CS_TrophyDrops_Tests.property15_TitanDropsBothItems()
    local testName = "Property 15: Titan Drops Both Items"
    local iterations = 100
    local allPassed = true
    local failingExample = nil
    
    -- Get Titan outfit name
    local titanOutfit = CS_Config.SpecialZombies.titan.outfit
    local expectedDrops = CS_Config.SpecialZombies.titan.drops
    
    for i = 1, iterations do
        -- Generate random coordinates
        local x = ZombRand(10000)
        local y = ZombRand(10000)
        local z = ZombRand(8) - 4
        
        -- Create Titan zombie
        local mockZombie = generateMockZombie(titanOutfit, x, y, z)
        
        -- Process death
        CS_TrophyDrops.processDeath(mockZombie)
        
        -- Get dropped items
        local square = mockZombie:getCurrentSquare()
        local items = square:getItems()
        
        -- Count dropped items by type
        local droppedTypes = {}
        for _, item in ipairs(items) do
            droppedTypes[item.itemType] = (droppedTypes[item.itemType] or 0) + 1
        end
        
        -- Verify each expected drop is present
        for _, dropDef in ipairs(expectedDrops) do
            local expectedItem = dropDef.item
            local expectedChance = dropDef.chance
            
            -- For 100% chance drops, item must be present
            if expectedChance >= 1.0 then
                if not droppedTypes[expectedItem] or droppedTypes[expectedItem] < 1 then
                    allPassed = false
                    failingExample = string.format(
                        "Titan at (%d,%d,%d) did not drop '%s' (dropped: %s)",
                        x, y, z, expectedItem, 
                        table.concat(items, ", ") or "nothing"
                    )
                    break
                end
            end
        end
        
        if not allPassed then break end
    end
    
    if allPassed then
        recordPass(testName)
    else
        recordFail(testName, "Titan missing required drops", failingExample)
    end
    
    return allPassed, failingExample
end

-- ============================================================================
-- TEST RUNNER
-- ============================================================================

function CS_TrophyDrops_Tests.runAll()
    print("========================================")
    print("DDA Trophy Drops Property Tests")
    print("========================================")
    
    resetResults()
    
    -- Run all property tests
    CS_TrophyDrops_Tests.property13_SpecialZombieDetectionByOutfit()
    CS_TrophyDrops_Tests.property14_DropsAtCorrectLocation()
    CS_TrophyDrops_Tests.property15_TitanDropsBothItems()
    
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
_G.CS_TrophyDrops_Tests = CS_TrophyDrops_Tests

return CS_TrophyDrops_Tests
