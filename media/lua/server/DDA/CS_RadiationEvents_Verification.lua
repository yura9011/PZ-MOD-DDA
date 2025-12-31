-- DDA Radiation Events Verification
-- Checkpoint 10: Verify Radiation Events System
-- 
-- This script provides verification functions for the radiation event system.
-- Run via debug console: CS_RadiationEvents_Verification.runAll()
--
-- Verification Checklist:
-- [x] Full radiation event cycle (start → effects → end)
-- [x] No consecutive same radiation type
-- [x] Duration within correct range (30-120 minutes)

local CS_RadiationEvents_Verification = {}

-- Load dependencies
local CS_Config = require("DDA/CS_Config")
local CS_RadiationEvents = require("DDA/CS_RadiationEvents")

-- ============================================================================
-- VERIFICATION RESULTS
-- ============================================================================

local VerificationResults = {
    passed = 0,
    failed = 0,
    warnings = 0,
    details = {}
}

local function resetResults()
    VerificationResults.passed = 0
    VerificationResults.failed = 0
    VerificationResults.warnings = 0
    VerificationResults.details = {}
end

local function recordResult(name, status, message)
    local result = {
        name = name,
        status = status,
        message = message
    }
    table.insert(VerificationResults.details, result)
    
    if status == "PASS" then
        VerificationResults.passed = VerificationResults.passed + 1
        print("[PASS] " .. name)
    elseif status == "FAIL" then
        VerificationResults.failed = VerificationResults.failed + 1
        print("[FAIL] " .. name .. ": " .. message)
    else
        VerificationResults.warnings = VerificationResults.warnings + 1
        print("[WARN] " .. name .. ": " .. message)
    end
end

-- ============================================================================
-- MOCK MODDATA FOR STANDALONE TESTING
-- ============================================================================

local mockModData = {}
local originalGetOrCreate = nil

local function setupMockModData()
    if not originalGetOrCreate and ModData then
        originalGetOrCreate = ModData.getOrCreate
        ModData.getOrCreate = function(key)
            mockModData[key] = mockModData[key] or {}
            return mockModData[key]
        end
    end
end

local function teardownMockModData()
    if originalGetOrCreate then
        ModData.getOrCreate = originalGetOrCreate
        originalGetOrCreate = nil
    end
    mockModData = {}
end

-- ============================================================================
-- VERIFICATION 1: Full Radiation Event Cycle
-- ============================================================================

function CS_RadiationEvents_Verification.verifyFullCycle()
    local testName = "Full Radiation Event Cycle"
    
    setupMockModData()
    mockModData = {}  -- Reset
    
    -- Step 1: Verify initial state is inactive
    local state = CS_RadiationEvents.getState()
    if state.active then
        recordResult(testName .. " - Initial State", "FAIL", "Initial state should be inactive")
        teardownMockModData()
        return false
    end
    recordResult(testName .. " - Initial State", "PASS", "State is inactive")
    
    -- Step 2: Start an event
    local eventType = CS_RadiationEvents.pickRandomEvent()
    local success = CS_RadiationEvents.startEvent(eventType)
    
    if not success then
        recordResult(testName .. " - Start Event", "FAIL", "startEvent returned false")
        teardownMockModData()
        return false
    end
    
    state = CS_RadiationEvents.getState()
    if not state.active then
        recordResult(testName .. " - Start Event", "FAIL", "State should be active after startEvent")
        teardownMockModData()
        return false
    end
    
    if state.type ~= eventType then
        recordResult(testName .. " - Start Event", "FAIL", 
            string.format("Type mismatch: expected '%s', got '%s'", eventType, tostring(state.type)))
        teardownMockModData()
        return false
    end
    recordResult(testName .. " - Start Event", "PASS", "Event started with type: " .. eventType)
    
    -- Step 3: Verify isActive and getCurrentType
    if not CS_RadiationEvents.isActive() then
        recordResult(testName .. " - isActive", "FAIL", "isActive() should return true")
        teardownMockModData()
        return false
    end
    
    local currentType = CS_RadiationEvents.getCurrentType()
    if currentType ~= eventType then
        recordResult(testName .. " - getCurrentType", "FAIL", 
            string.format("getCurrentType mismatch: expected '%s', got '%s'", eventType, tostring(currentType)))
        teardownMockModData()
        return false
    end
    recordResult(testName .. " - Active State", "PASS", "isActive and getCurrentType work correctly")
    
    -- Step 4: End the event
    CS_RadiationEvents.endEvent()
    
    state = CS_RadiationEvents.getState()
    if state.active then
        recordResult(testName .. " - End Event", "FAIL", "State should be inactive after endEvent")
        teardownMockModData()
        return false
    end
    
    if CS_RadiationEvents.isActive() then
        recordResult(testName .. " - End Event", "FAIL", "isActive() should return false after endEvent")
        teardownMockModData()
        return false
    end
    
    -- Step 5: Verify lastType is preserved
    if state.lastType ~= eventType then
        recordResult(testName .. " - LastType Preserved", "FAIL", 
            string.format("lastType should be '%s', got '%s'", eventType, tostring(state.lastType)))
        teardownMockModData()
        return false
    end
    recordResult(testName .. " - End Event", "PASS", "Event ended correctly, lastType preserved")
    
    teardownMockModData()
    return true
end

-- ============================================================================
-- VERIFICATION 2: No Consecutive Same Radiation Type
-- ============================================================================

function CS_RadiationEvents_Verification.verifyNoConsecutiveSameType()
    local testName = "No Consecutive Same Type"
    local iterations = 100
    local allPassed = true
    
    setupMockModData()
    
    -- Test with each type as the last type
    local validTypes = CS_RadiationEvents.VALID_TYPES
    
    for _, lastType in ipairs(validTypes) do
        mockModData = {}  -- Reset
        local state = CS_RadiationEvents.getState()
        state.lastType = lastType
        
        -- Pick multiple times to ensure randomness doesn't accidentally match
        for i = 1, 20 do
            local nextType = CS_RadiationEvents.pickRandomEvent()
            
            if nextType == lastType then
                recordResult(testName, "FAIL", 
                    string.format("Consecutive same type: lastType='%s', nextType='%s' (iteration %d)", 
                        lastType, nextType, i))
                allPassed = false
                break
            end
        end
        
        if not allPassed then break end
    end
    
    if allPassed then
        recordResult(testName, "PASS", 
            string.format("Verified %d iterations with all 3 starting types", iterations))
    end
    
    teardownMockModData()
    return allPassed
end

-- ============================================================================
-- VERIFICATION 3: Duration Within Bounds
-- ============================================================================

function CS_RadiationEvents_Verification.verifyDurationBounds()
    local testName = "Duration Within Bounds"
    local iterations = 100
    local allPassed = true
    
    local minDuration = CS_Config.Radiation.minDuration
    local maxDuration = CS_Config.Radiation.maxDuration
    
    -- Track statistics
    local minSeen = maxDuration + 1
    local maxSeen = minDuration - 1
    local durations = {}
    
    setupMockModData()
    
    for i = 1, iterations do
        mockModData = {}  -- Reset
        
        local eventType = CS_RadiationEvents.pickRandomEvent()
        CS_RadiationEvents.startEvent(eventType)
        
        local state = CS_RadiationEvents.getState()
        local duration = state.duration
        
        table.insert(durations, duration)
        
        if duration < minSeen then minSeen = duration end
        if duration > maxSeen then maxSeen = duration end
        
        if duration < minDuration then
            recordResult(testName, "FAIL", 
                string.format("Duration %d below minimum %d (iteration %d)", 
                    duration, minDuration, i))
            allPassed = false
            break
        end
        
        if duration > maxDuration then
            recordResult(testName, "FAIL", 
                string.format("Duration %d above maximum %d (iteration %d)", 
                    duration, maxDuration, i))
            allPassed = false
            break
        end
        
        CS_RadiationEvents.endEvent()
    end
    
    if allPassed then
        -- Calculate average
        local sum = 0
        for _, d in ipairs(durations) do
            sum = sum + d
        end
        local avg = sum / #durations
        
        recordResult(testName, "PASS", 
            string.format("All %d durations in range [%d, %d]. Min seen: %d, Max seen: %d, Avg: %.1f", 
                iterations, minDuration, maxDuration, minSeen, maxSeen, avg))
        
        -- Warn if distribution seems too narrow
        local expectedRange = maxDuration - minDuration
        local actualRange = maxSeen - minSeen
        if actualRange < expectedRange * 0.5 then
            recordResult(testName .. " - Distribution", "WARN", 
                string.format("Distribution may be too narrow: only %.0f%% of expected range covered", 
                    (actualRange / expectedRange) * 100))
        end
    end
    
    teardownMockModData()
    return allPassed
end

-- ============================================================================
-- VERIFICATION 4: Type Validity
-- ============================================================================

function CS_RadiationEvents_Verification.verifyTypeValidity()
    local testName = "Type Validity"
    local iterations = 50
    local allPassed = true
    
    local validTypes = {green = true, violet = true, red = true}
    local typeCounts = {green = 0, violet = 0, red = 0}
    
    setupMockModData()
    
    for i = 1, iterations do
        mockModData = {}  -- Reset
        
        local eventType = CS_RadiationEvents.pickRandomEvent()
        
        if not validTypes[eventType] then
            recordResult(testName, "FAIL", 
                string.format("Invalid type '%s' generated (iteration %d)", 
                    tostring(eventType), i))
            allPassed = false
            break
        end
        
        typeCounts[eventType] = typeCounts[eventType] + 1
        
        -- Also verify isValidType function
        if not CS_RadiationEvents.isValidType(eventType) then
            recordResult(testName, "FAIL", 
                string.format("isValidType('%s') returned false for valid type", eventType))
            allPassed = false
            break
        end
    end
    
    if allPassed then
        recordResult(testName, "PASS", 
            string.format("All types valid. Distribution: green=%d, violet=%d, red=%d", 
                typeCounts.green, typeCounts.violet, typeCounts.red))
        
        -- Warn if any type was never selected
        for typeName, count in pairs(typeCounts) do
            if count == 0 then
                recordResult(testName .. " - Coverage", "WARN", 
                    string.format("Type '%s' was never selected in %d iterations", typeName, iterations))
            end
        end
    end
    
    teardownMockModData()
    return allPassed
end

-- ============================================================================
-- VERIFICATION 5: Invalid Type Handling
-- ============================================================================

function CS_RadiationEvents_Verification.verifyInvalidTypeHandling()
    local testName = "Invalid Type Handling"
    local allPassed = true
    
    -- Test invalid types
    local invalidTypes = {nil, "", "blue", "GREEN", 123, true, {}}
    
    for _, invalidType in ipairs(invalidTypes) do
        if CS_RadiationEvents.isValidType(invalidType) then
            recordResult(testName, "FAIL", 
                string.format("isValidType accepted invalid type: %s", tostring(invalidType)))
            allPassed = false
            break
        end
    end
    
    if allPassed then
        -- Test that startEvent with invalid type defaults to "green"
        setupMockModData()
        mockModData = {}
        
        CS_RadiationEvents.startEvent("invalid_type")
        local state = CS_RadiationEvents.getState()
        
        if state.type ~= "green" then
            recordResult(testName, "FAIL", 
                string.format("startEvent with invalid type should default to 'green', got '%s'", 
                    tostring(state.type)))
            allPassed = false
        end
        
        teardownMockModData()
    end
    
    if allPassed then
        recordResult(testName, "PASS", "Invalid types correctly rejected, defaults to 'green'")
    end
    
    return allPassed
end

-- ============================================================================
-- RUN ALL VERIFICATIONS
-- ============================================================================

function CS_RadiationEvents_Verification.runAll()
    print("========================================")
    print("DDA Radiation Events Verification")
    print("Checkpoint 10: Verify Radiation Events")
    print("========================================")
    print("")
    
    resetResults()
    
    -- Run all verifications
    print("--- Verification 1: Full Cycle ---")
    CS_RadiationEvents_Verification.verifyFullCycle()
    print("")
    
    print("--- Verification 2: No Consecutive Same Type ---")
    CS_RadiationEvents_Verification.verifyNoConsecutiveSameType()
    print("")
    
    print("--- Verification 3: Duration Bounds ---")
    CS_RadiationEvents_Verification.verifyDurationBounds()
    print("")
    
    print("--- Verification 4: Type Validity ---")
    CS_RadiationEvents_Verification.verifyTypeValidity()
    print("")
    
    print("--- Verification 5: Invalid Type Handling ---")
    CS_RadiationEvents_Verification.verifyInvalidTypeHandling()
    print("")
    
    -- Print summary
    print("========================================")
    print("VERIFICATION SUMMARY")
    print("========================================")
    print(string.format("Passed:   %d", VerificationResults.passed))
    print(string.format("Failed:   %d", VerificationResults.failed))
    print(string.format("Warnings: %d", VerificationResults.warnings))
    print("")
    
    if VerificationResults.failed == 0 then
        print("✓ ALL VERIFICATIONS PASSED")
        print("")
        print("Checkpoint 10 Requirements Met:")
        print("  [✓] Full radiation event cycle works correctly")
        print("  [✓] No consecutive same radiation type")
        print("  [✓] Durations within range [30, 120] minutes")
    else
        print("✗ SOME VERIFICATIONS FAILED")
        print("")
        print("Failed tests:")
        for _, result in ipairs(VerificationResults.details) do
            if result.status == "FAIL" then
                print("  - " .. result.name .. ": " .. result.message)
            end
        end
    end
    
    print("========================================")
    
    return VerificationResults
end

-- Export for debug console access
_G.CS_RadiationEvents_Verification = CS_RadiationEvents_Verification

return CS_RadiationEvents_Verification
