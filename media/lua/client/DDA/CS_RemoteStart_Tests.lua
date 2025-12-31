-- DDA Remote Start Property Tests
-- Property-based tests for the Remote Start System
-- Run via debug console: CS_RemoteStart_Tests.runAll()

local CS_RemoteStart_Tests = {}

-- Load dependencies
local CS_Config = require("DDA/CS_Config")
local CS_RemoteStart = require("DDA/CS_RemoteStart")

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
-- MOCK PLAYER GENERATOR
-- ============================================================================

--- Generate a mock player object for testing
--- @param x number|nil Initial X coordinate
--- @param y number|nil Initial Y coordinate
--- @param z number|nil Initial Z coordinate
--- @return table mockPlayer A mock player object
local function generateMockPlayer(x, y, z)
    local mockPlayer = {
        _x = x or 0,
        _y = y or 0,
        _z = z or 0,
        setX = function(self, newX) self._x = newX end,
        setY = function(self, newY) self._y = newY end,
        setZ = function(self, newZ) self._z = newZ end,
        getX = function(self) return self._x end,
        getY = function(self) return self._y end,
        getZ = function(self) return self._z end
    }
    return mockPlayer
end


-- ============================================================================
-- PROPERTY 18: New Player At Predefined Spawn
-- **Feature: DDA-expansion, Property 18: New Player At Predefined Spawn**
-- **Validates: Requirements 9.1, 9.4**
--
-- *For any* newly created player, the player's coordinates SHALL match one of 
-- the three predefined spawn locations.
-- ============================================================================

function CS_RemoteStart_Tests.property18_NewPlayerAtPredefinedSpawn()
    local testName = "Property 18: New Player At Predefined Spawn"
    local iterations = 100
    local allPassed = true
    local failingExample = nil
    
    -- Build lookup table of valid spawn locations
    local validSpawns = {}
    for _, spawn in ipairs(CS_Config.SpawnLocations) do
        local key = string.format("%d,%d,%d", spawn.x, spawn.y, spawn.z)
        validSpawns[key] = spawn
    end
    
    for i = 1, iterations do
        -- Create a mock player at random initial position
        local initialX = ZombRand(10000)
        local initialY = ZombRand(10000)
        local initialZ = ZombRand(8) - 4
        local mockPlayer = generateMockPlayer(initialX, initialY, initialZ)
        
        -- Simulate player creation event
        CS_RemoteStart.onCreatePlayer(0, mockPlayer)
        
        -- Get player's final position
        local finalX = mockPlayer:getX()
        local finalY = mockPlayer:getY()
        local finalZ = mockPlayer:getZ()
        
        -- Check if final position matches any predefined spawn
        local isAtValidSpawn = false
        for _, spawn in ipairs(CS_Config.SpawnLocations) do
            -- Allow small tolerance for floating point comparison
            if math.abs(finalX - spawn.x) < 1 and
               math.abs(finalY - spawn.y) < 1 and
               math.abs(finalZ - spawn.z) < 1 then
                isAtValidSpawn = true
                break
            end
        end
        
        if not isAtValidSpawn then
            allPassed = false
            failingExample = string.format(
                "Player teleported to (%d, %d, %d) which is not a predefined spawn. " ..
                "Initial position was (%d, %d, %d). Valid spawns: %s",
                finalX, finalY, finalZ,
                initialX, initialY, initialZ,
                table.concat(
                    (function()
                        local names = {}
                        for _, s in ipairs(CS_Config.SpawnLocations) do
                            table.insert(names, string.format("%s(%d,%d,%d)", 
                                s.name, s.x, s.y, s.z))
                        end
                        return names
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
        recordFail(testName, "Player not at predefined spawn", failingExample)
    end
    
    return allPassed, failingExample
end


-- ============================================================================
-- PROPERTY 19: Random Spawn Covers All Locations
-- **Feature: DDA-expansion, Property 19: Random Spawn Covers All Locations**
-- **Validates: Requirements 9.3**
--
-- *For any* sufficiently large sample of new player spawns, all three spawn 
-- locations SHALL be represented (no location has 0% probability).
-- ============================================================================

function CS_RemoteStart_Tests.property19_RandomSpawnCoversAllLocations()
    local testName = "Property 19: Random Spawn Covers All Locations"
    local iterations = 300  -- Higher iterations to ensure statistical coverage
    local allPassed = true
    local failingExample = nil
    
    -- Track spawn counts per location
    local spawnCounts = {}
    for _, spawn in ipairs(CS_Config.SpawnLocations) do
        local key = string.format("%d,%d,%d", spawn.x, spawn.y, spawn.z)
        spawnCounts[key] = {
            count = 0,
            name = spawn.name,
            x = spawn.x,
            y = spawn.y,
            z = spawn.z
        }
    end
    
    -- Run many spawn simulations
    for i = 1, iterations do
        local mockPlayer = generateMockPlayer(0, 0, 0)
        
        -- Simulate player creation
        CS_RemoteStart.onCreatePlayer(0, mockPlayer)
        
        -- Record which spawn was selected
        local finalX = mockPlayer:getX()
        local finalY = mockPlayer:getY()
        local finalZ = mockPlayer:getZ()
        
        for _, spawn in ipairs(CS_Config.SpawnLocations) do
            if math.abs(finalX - spawn.x) < 1 and
               math.abs(finalY - spawn.y) < 1 and
               math.abs(finalZ - spawn.z) < 1 then
                local key = string.format("%d,%d,%d", spawn.x, spawn.y, spawn.z)
                spawnCounts[key].count = spawnCounts[key].count + 1
                break
            end
        end
    end
    
    -- Verify all locations were used at least once
    local missingLocations = {}
    for key, data in pairs(spawnCounts) do
        if data.count == 0 then
            table.insert(missingLocations, data.name)
        end
    end
    
    if #missingLocations > 0 then
        allPassed = false
        
        -- Build distribution report
        local distribution = {}
        for key, data in pairs(spawnCounts) do
            table.insert(distribution, string.format(
                "%s: %d/%d (%.1f%%)",
                data.name, data.count, iterations, 
                (data.count / iterations) * 100
            ))
        end
        
        failingExample = string.format(
            "After %d spawns, these locations were never selected: [%s]. " ..
            "Distribution: %s",
            iterations,
            table.concat(missingLocations, ", "),
            table.concat(distribution, ", ")
        )
    end
    
    if allPassed then
        recordPass(testName)
        
        -- Print distribution for informational purposes
        print("  Spawn distribution:")
        for key, data in pairs(spawnCounts) do
            print(string.format("    %s: %d/%d (%.1f%%)",
                data.name, data.count, iterations,
                (data.count / iterations) * 100
            ))
        end
    else
        recordFail(testName, "Not all spawn locations covered", failingExample)
    end
    
    return allPassed, failingExample
end


-- ============================================================================
-- ADDITIONAL HELPER: Test teleportToSpawn directly
-- ============================================================================

function CS_RemoteStart_Tests.testTeleportToSpawn()
    local testName = "Helper: teleportToSpawn correctness"
    local allPassed = true
    local failingExample = nil
    
    -- Test each spawn location directly
    for _, spawn in ipairs(CS_Config.SpawnLocations) do
        local mockPlayer = generateMockPlayer(0, 0, 0)
        
        local success = CS_RemoteStart.teleportToSpawn(mockPlayer, spawn)
        
        if not success then
            allPassed = false
            failingExample = string.format(
                "teleportToSpawn returned false for spawn '%s'",
                spawn.name
            )
            break
        end
        
        -- Verify coordinates match
        if mockPlayer:getX() ~= spawn.x or
           mockPlayer:getY() ~= spawn.y or
           mockPlayer:getZ() ~= spawn.z then
            allPassed = false
            failingExample = string.format(
                "Player at (%d,%d,%d) after teleport to '%s' (%d,%d,%d)",
                mockPlayer:getX(), mockPlayer:getY(), mockPlayer:getZ(),
                spawn.name, spawn.x, spawn.y, spawn.z
            )
            break
        end
    end
    
    -- Test nil player handling
    local nilResult = CS_RemoteStart.teleportToSpawn(nil, CS_Config.SpawnLocations[1])
    if nilResult ~= false then
        allPassed = false
        failingExample = "teleportToSpawn should return false for nil player"
    end
    
    -- Test nil spawn handling
    local mockPlayer = generateMockPlayer(0, 0, 0)
    local nilSpawnResult = CS_RemoteStart.teleportToSpawn(mockPlayer, nil)
    if nilSpawnResult ~= false then
        allPassed = false
        failingExample = "teleportToSpawn should return false for nil spawn"
    end
    
    if allPassed then
        recordPass(testName)
    else
        recordFail(testName, "teleportToSpawn error", failingExample)
    end
    
    return allPassed, failingExample
end

-- ============================================================================
-- ADDITIONAL HELPER: Test isAtPredefinedSpawn
-- ============================================================================

function CS_RemoteStart_Tests.testIsAtPredefinedSpawn()
    local testName = "Helper: isAtPredefinedSpawn correctness"
    local allPassed = true
    local failingExample = nil
    
    -- Test each spawn location
    for _, spawn in ipairs(CS_Config.SpawnLocations) do
        local mockPlayer = generateMockPlayer(spawn.x, spawn.y, spawn.z)
        
        local isAtSpawn, matchedSpawn = CS_RemoteStart.isAtPredefinedSpawn(mockPlayer)
        
        if not isAtSpawn then
            allPassed = false
            failingExample = string.format(
                "Player at (%d,%d,%d) not detected as at spawn '%s'",
                spawn.x, spawn.y, spawn.z, spawn.name
            )
            break
        end
        
        if matchedSpawn.name ~= spawn.name then
            allPassed = false
            failingExample = string.format(
                "Matched spawn '%s' instead of expected '%s'",
                matchedSpawn.name, spawn.name
            )
            break
        end
    end
    
    -- Test player NOT at spawn
    local offPlayer = generateMockPlayer(1000, 1000, 0)
    local isAtSpawn, _ = CS_RemoteStart.isAtPredefinedSpawn(offPlayer)
    if isAtSpawn then
        allPassed = false
        failingExample = "Player at (1000,1000,0) incorrectly detected as at spawn"
    end
    
    -- Test nil player
    local nilResult, _ = CS_RemoteStart.isAtPredefinedSpawn(nil)
    if nilResult ~= false then
        allPassed = false
        failingExample = "isAtPredefinedSpawn should return false for nil player"
    end
    
    if allPassed then
        recordPass(testName)
    else
        recordFail(testName, "isAtPredefinedSpawn error", failingExample)
    end
    
    return allPassed, failingExample
end

-- ============================================================================
-- TEST RUNNER
-- ============================================================================

function CS_RemoteStart_Tests.runAll()
    print("========================================")
    print("DDA Remote Start Property Tests")
    print("========================================")
    
    resetResults()
    
    -- Run helper tests first
    CS_RemoteStart_Tests.testTeleportToSpawn()
    CS_RemoteStart_Tests.testIsAtPredefinedSpawn()
    
    -- Run property tests
    CS_RemoteStart_Tests.property18_NewPlayerAtPredefinedSpawn()
    CS_RemoteStart_Tests.property19_RandomSpawnCoversAllLocations()
    
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
_G.CS_RemoteStart_Tests = CS_RemoteStart_Tests

return CS_RemoteStart_Tests
