-- DDA Trophy Drops Test Runner
-- Standalone test runner for property tests (can be run outside PZ)
-- Usage: lua CS_TrophyDrops_TestRunner.lua

-- ============================================================================
-- MOCK PZ GLOBALS (for standalone testing)
-- ============================================================================

-- Mock ZombRand if not available
if not ZombRand then
    -- Fallback for standalone testing outside PZ
    ZombRand = function(max)
        if max <= 0 then return 0 end
        return 0  -- Deterministic for testing
    end
end

-- Mock print with timestamp (use getTimestamp if available)
local originalPrint = print
if getTimestampMs then
    print = function(...)
        originalPrint(string.format("[%s]", tostring(getTimestampMs())), ...)
    end
end

-- ============================================================================
-- INLINE CONFIG (for standalone testing)
-- ============================================================================

local CS_Config = {
    SpecialZombies = {
        titan = {
            healthMultiplier = 5.0,
            damageMultiplier = 2.0,
            outfit = "Juggernaut",
            drops = {
                {item = "DDA.TitanWeapon", chance = 1.0},
                {item = "DDA.TitanCore", chance = 1.0}
            }
        },
        stalker = {
            healthMultiplier = 2.0,
            damageMultiplier = 1.5,
            outfit = "Stalker",
            drops = {
                {item = "DDA.StalkerEye", chance = 1.0}
            }
        },
        brute = {
            healthMultiplier = 3.0,
            damageMultiplier = 3.0,
            outfit = "Brute",
            drops = {
                {item = "DDA.BruteArm", chance = 1.0}
            }
        }
    }
}

-- ============================================================================
-- INLINE TROPHY DROPS (for standalone testing)
-- ============================================================================

local CS_TrophyDrops = {}

function CS_TrophyDrops.isSpecialZombie(zombie)
    if not zombie then 
        return false, nil 
    end
    
    local outfitName = zombie:getOutfitName()
    if not outfitName then 
        return false, nil 
    end
    
    for typeName, typeData in pairs(CS_Config.SpecialZombies) do
        if outfitName == typeData.outfit then
            return true, typeName
        end
    end
    
    return false, nil
end

function CS_TrophyDrops.getDropsForType(typeName)
    if not typeName then return nil end
    local typeData = CS_Config.SpecialZombies[typeName]
    if not typeData then return nil end
    return typeData.drops
end

function CS_TrophyDrops.dropItems(square, drops)
    if not square or not drops then return 0 end
    
    local count = 0
    for _, dropDef in ipairs(drops) do
        local itemType = dropDef.item
        local chance = dropDef.chance or 1.0
        
        if ZombRand(100) / 100 < chance then
            square:AddWorldInventoryItem(itemType, 0, 0, 0)
            count = count + 1
        end
    end
    
    return count
end

function CS_TrophyDrops.processDeath(zombie)
    if not zombie then return false end
    
    local isSpecial, typeName = CS_TrophyDrops.isSpecialZombie(zombie)
    if not isSpecial then return false end
    
    local square = zombie:getCurrentSquare()
    if not square then return false end
    
    local drops = CS_TrophyDrops.getDropsForType(typeName)
    if not drops or #drops == 0 then return false end
    
    local dropCount = CS_TrophyDrops.dropItems(square, drops)
    return dropCount > 0
end

-- ============================================================================
-- TEST FRAMEWORK
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
    table.insert(TestResults.errors, {
        test = testName,
        message = message,
        example = example
    })
    print("[FAIL] " .. testName .. ": " .. message)
    if example then
        print("       Failing example: " .. tostring(example))
    end
end

-- ============================================================================
-- MOCK GENERATORS
-- ============================================================================

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
    
    return {
        _outfitName = outfitName,
        _square = mockSquare,
        getOutfitName = function(self) return self._outfitName end,
        getCurrentSquare = function(self) return self._square end
    }
end

local function generateRandomOutfit(includeSpecial)
    local normalOutfits = {
        "Civilian", "Police", "Firefighter", "Doctor", "Nurse",
        "Worker", "Farmer", "Chef", "Mechanic", "Soldier"
    }
    
    local pool = {}
    for _, outfit in ipairs(normalOutfits) do
        table.insert(pool, outfit)
    end
    table.insert(pool, nil) -- Include nil
    
    if includeSpecial then
        for _, typeData in pairs(CS_Config.SpecialZombies) do
            table.insert(pool, typeData.outfit)
        end
    end
    
    return pool[ZombRand(#pool) + 1]
end

-- ============================================================================
-- PROPERTY TESTS
-- ============================================================================

-- **Feature: DDA-expansion, Property 13: Special Zombie Detection By Outfit**
-- **Validates: Requirements 6.3, 7.3**
local function property13_SpecialZombieDetectionByOutfit()
    local testName = "Property 13: Special Zombie Detection By Outfit"
    local iterations = 100
    local allPassed = true
    local failingExample = nil
    
    local specialOutfits = {}
    for typeName, typeData in pairs(CS_Config.SpecialZombies) do
        specialOutfits[typeData.outfit] = typeName
    end
    
    for i = 1, iterations do
        local outfit = generateRandomOutfit(true)
        local mockZombie = generateMockZombie(outfit)
        
        local isSpecial, detectedType = CS_TrophyDrops.isSpecialZombie(mockZombie)
        
        local expectedSpecial = outfit ~= nil and specialOutfits[outfit] ~= nil
        local expectedType = outfit and specialOutfits[outfit] or nil
        
        if isSpecial ~= expectedSpecial then
            allPassed = false
            failingExample = string.format(
                "outfit='%s', isSpecial=%s (expected %s)",
                tostring(outfit), tostring(isSpecial), tostring(expectedSpecial)
            )
            break
        end
        
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

-- **Feature: DDA-expansion, Property 14: Special Zombie Drops At Correct Location**
-- **Validates: Requirements 6.4, 7.1, 7.2**
local function property14_DropsAtCorrectLocation()
    local testName = "Property 14: Special Zombie Drops At Correct Location"
    local iterations = 100
    local allPassed = true
    local failingExample = nil
    
    local specialOutfits = {}
    for _, typeData in pairs(CS_Config.SpecialZombies) do
        table.insert(specialOutfits, typeData.outfit)
    end
    
    for i = 1, iterations do
        local x = ZombRand(10000)
        local y = ZombRand(10000)
        local z = ZombRand(8) - 4
        
        local outfit = specialOutfits[ZombRand(#specialOutfits) + 1]
        local mockZombie = generateMockZombie(outfit, x, y, z)
        
        CS_TrophyDrops.processDeath(mockZombie)
        
        local square = mockZombie:getCurrentSquare()
        local items = square:getItems()
        
        for _, item in ipairs(items) do
            if item.offsetX ~= 0 or item.offsetY ~= 0 or item.offsetZ ~= 0 then
                allPassed = false
                failingExample = string.format(
                    "Item '%s' at offset (%d,%d,%d) instead of (0,0,0)",
                    item.itemType, item.offsetX, item.offsetY, item.offsetZ
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

-- **Feature: DDA-expansion, Property 15: Titan Drops Both Items**
-- **Validates: Requirements 6.1, 6.2**
local function property15_TitanDropsBothItems()
    local testName = "Property 15: Titan Drops Both Items"
    local iterations = 100
    local allPassed = true
    local failingExample = nil
    
    local titanOutfit = CS_Config.SpecialZombies.titan.outfit
    local expectedDrops = CS_Config.SpecialZombies.titan.drops
    
    for i = 1, iterations do
        local x = ZombRand(10000)
        local y = ZombRand(10000)
        local z = ZombRand(8) - 4
        
        local mockZombie = generateMockZombie(titanOutfit, x, y, z)
        
        CS_TrophyDrops.processDeath(mockZombie)
        
        local square = mockZombie:getCurrentSquare()
        local items = square:getItems()
        
        local droppedTypes = {}
        for _, item in ipairs(items) do
            droppedTypes[item.itemType] = (droppedTypes[item.itemType] or 0) + 1
        end
        
        for _, dropDef in ipairs(expectedDrops) do
            local expectedItem = dropDef.item
            local expectedChance = dropDef.chance
            
            if expectedChance >= 1.0 then
                if not droppedTypes[expectedItem] or droppedTypes[expectedItem] < 1 then
                    allPassed = false
                    local droppedList = {}
                    for itemType, _ in pairs(droppedTypes) do
                        table.insert(droppedList, itemType)
                    end
                    failingExample = string.format(
                        "Titan missing '%s' (dropped: %s)",
                        expectedItem, table.concat(droppedList, ", ")
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
-- MAIN
-- ============================================================================

print("========================================")
print("DDA Trophy Drops Property Tests")
print("========================================")

resetResults()

property13_SpecialZombieDetectionByOutfit()
property14_DropsAtCorrectLocation()
property15_TitanDropsBothItems()

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
    -- Note: os.exit() not available in PZ Kahlua
end
-- Tests complete
