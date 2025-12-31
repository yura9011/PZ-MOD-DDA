-- DDA Radiation Overlay Property Tests
-- Property-based tests for the Radiation Overlay System
-- Run via debug console: CS_RadiationOverlay_Tests.runAll()

local CS_RadiationOverlay_Tests = {}

-- Load dependencies
local CS_Config = require("DDA/CS_Config")
local CS_RadiationOverlay = require("DDA/CS_RadiationOverlay")

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
-- GENERATORS
-- ============================================================================

--- Generate a random radiation type
--- @return string radiationType One of "green", "violet", "red"
local function generateRadiationType()
    local types = {"green", "violet", "red"}
    local index = ZombRand(#types) + 1
    return types[index]
end

--- Generate a random alpha value
--- @return number alpha Value between 0.0 and 1.0
local function generateAlpha()
    return ZombRand(101) / 100
end

--- Generate a random screen dimension
--- @return number dimension Value between 640 and 3840
local function generateScreenDimension()
    local dimensions = {640, 800, 1024, 1280, 1366, 1600, 1920, 2560, 3840}
    local index = ZombRand(#dimensions) + 1
    return dimensions[index]
end

-- ============================================================================
-- PROPERTY 5: Overlay Color Matches Radiation Type
-- **Feature: DDA-expansion, Property 5: Overlay Color Matches Radiation Type**
-- **Validates: Requirements 2.1, 2.2, 2.3**
--
-- *For any* active radiation event, the overlay color displayed SHALL match 
-- the radiation type: green=(0,255,0), violet=(128,0,255), red=(255,0,0).
-- ============================================================================

function CS_RadiationOverlay_Tests.property5_OverlayColorMatchesRadiationType()
    local testName = "Property 5: Overlay Color Matches Radiation Type"
    local iterations = 100
    local allPassed = true
    local failingExample = nil
    
    -- Expected colors for each radiation type
    local expectedColors = {
        green = {r = 0, g = 255, b = 0},
        violet = {r = 128, g = 0, b = 255},
        red = {r = 255, g = 0, b = 0}
    }
    
    for i = 1, iterations do
        -- Generate random radiation type
        local radiationType = generateRadiationType()
        
        -- Get the color for this type from the overlay system
        local actualColor = CS_RadiationOverlay.getColorForType(radiationType)
        
        -- Verify color is not nil
        if not actualColor then
            allPassed = false
            failingExample = string.format(
                "getColorForType('%s') returned nil",
                radiationType
            )
            break
        end
        
        -- Verify color matches expected
        local expected = expectedColors[radiationType]
        if actualColor.r ~= expected.r or 
           actualColor.g ~= expected.g or 
           actualColor.b ~= expected.b then
            allPassed = false
            failingExample = string.format(
                "Type '%s': expected color (%d,%d,%d) but got (%d,%d,%d)",
                radiationType,
                expected.r, expected.g, expected.b,
                actualColor.r or -1, actualColor.g or -1, actualColor.b or -1
            )
            break
        end
        
        -- Also verify the texture path exists for this type
        local texturePath = CS_RadiationOverlay.getTexturePathForType(radiationType)
        if not texturePath then
            allPassed = false
            failingExample = string.format(
                "getTexturePathForType('%s') returned nil",
                radiationType
            )
            break
        end
        
        -- Verify texture path contains the radiation type name
        if not texturePath:find(radiationType) then
            allPassed = false
            failingExample = string.format(
                "Texture path '%s' does not contain radiation type '%s'",
                texturePath, radiationType
            )
            break
        end
    end
    
    if allPassed then
        recordPass(testName)
    else
        recordFail(testName, "Color mismatch", failingExample)
    end
    
    return allPassed, failingExample
end

-- ============================================================================
-- PROPERTY 6: Fade In Increases Alpha
-- **Feature: DDA-expansion, Property 6: Fade In Increases Alpha**
-- **Validates: Requirements 2.4**
--
-- *For any* overlay fade-in operation, the alpha value SHALL monotonically 
-- increase from 0 toward the target alpha until reaching the target.
-- ============================================================================

function CS_RadiationOverlay_Tests.property6_FadeInIncreasesAlpha()
    local testName = "Property 6: Fade In Increases Alpha"
    local iterations = 100
    local allPassed = true
    local failingExample = nil
    
    for i = 1, iterations do
        -- Reset overlay state
        CS_RadiationOverlay.clear()
        CS_RadiationOverlay.state.initialized = true
        CS_RadiationOverlay.state.playerAlive = true
        
        -- Generate random target alpha
        local targetAlpha = 0.1 + (ZombRand(90) / 100)  -- 0.1 to 0.99
        
        -- Set overlay with a radiation type
        local radiationType = generateRadiationType()
        CS_RadiationOverlay.setOverlay(radiationType, targetAlpha)
        
        -- Verify initial state
        local initialAlpha = CS_RadiationOverlay.getAlpha()
        if initialAlpha ~= 0 then
            allPassed = false
            failingExample = string.format(
                "Initial alpha should be 0, got %f",
                initialAlpha
            )
            break
        end
        
        -- Simulate fade in by calling updateFade multiple times
        local previousAlpha = initialAlpha
        local maxSteps = 100
        local step = 0
        
        while CS_RadiationOverlay.isFadingIn() and step < maxSteps do
            CS_RadiationOverlay.updateFade()
            local currentAlpha = CS_RadiationOverlay.getAlpha()
            
            -- Alpha should be monotonically increasing
            if currentAlpha < previousAlpha then
                allPassed = false
                failingExample = string.format(
                    "Alpha decreased during fade in: %f -> %f (step %d, target %f)",
                    previousAlpha, currentAlpha, step, targetAlpha
                )
                break
            end
            
            previousAlpha = currentAlpha
            step = step + 1
        end
        
        if not allPassed then break end
        
        -- Verify final alpha reached target
        local finalAlpha = CS_RadiationOverlay.getAlpha()
        if math.abs(finalAlpha - targetAlpha) > 0.001 then
            allPassed = false
            failingExample = string.format(
                "Final alpha %f did not reach target %f after %d steps",
                finalAlpha, targetAlpha, step
            )
            break
        end
    end
    
    if allPassed then
        recordPass(testName)
    else
        recordFail(testName, "Fade in not monotonic", failingExample)
    end
    
    return allPassed, failingExample
end

-- ============================================================================
-- PROPERTY 7: Fade Out Decreases Alpha
-- **Feature: DDA-expansion, Property 7: Fade Out Decreases Alpha**
-- **Validates: Requirements 2.5**
--
-- *For any* overlay fade-out operation, the alpha value SHALL monotonically 
-- decrease from current alpha toward 0 until reaching 0.
-- ============================================================================

function CS_RadiationOverlay_Tests.property7_FadeOutDecreasesAlpha()
    local testName = "Property 7: Fade Out Decreases Alpha"
    local iterations = 100
    local allPassed = true
    local failingExample = nil
    
    for i = 1, iterations do
        -- Reset overlay state
        CS_RadiationOverlay.clear()
        CS_RadiationOverlay.state.initialized = true
        CS_RadiationOverlay.state.playerAlive = true
        
        -- Generate random starting alpha
        local startAlpha = 0.1 + (ZombRand(90) / 100)  -- 0.1 to 0.99
        
        -- Set overlay to starting alpha directly (simulate already faded in)
        CS_RadiationOverlay.state.alpha = startAlpha
        CS_RadiationOverlay.state.targetAlpha = startAlpha
        
        -- Start fade out
        CS_RadiationOverlay.fadeOut()
        
        -- Verify target is 0
        if CS_RadiationOverlay.getTargetAlpha() ~= 0 then
            allPassed = false
            failingExample = string.format(
                "fadeOut() should set target to 0, got %f",
                CS_RadiationOverlay.getTargetAlpha()
            )
            break
        end
        
        -- Simulate fade out by calling updateFade multiple times
        local previousAlpha = startAlpha
        local maxSteps = 100
        local step = 0
        
        while CS_RadiationOverlay.isFadingOut() and step < maxSteps do
            CS_RadiationOverlay.updateFade()
            local currentAlpha = CS_RadiationOverlay.getAlpha()
            
            -- Alpha should be monotonically decreasing
            if currentAlpha > previousAlpha then
                allPassed = false
                failingExample = string.format(
                    "Alpha increased during fade out: %f -> %f (step %d, start %f)",
                    previousAlpha, currentAlpha, step, startAlpha
                )
                break
            end
            
            previousAlpha = currentAlpha
            step = step + 1
        end
        
        if not allPassed then break end
        
        -- Verify final alpha reached 0
        local finalAlpha = CS_RadiationOverlay.getAlpha()
        if finalAlpha ~= 0 then
            allPassed = false
            failingExample = string.format(
                "Final alpha %f did not reach 0 after %d steps (start was %f)",
                finalAlpha, step, startAlpha
            )
            break
        end
    end
    
    if allPassed then
        recordPass(testName)
    else
        recordFail(testName, "Fade out not monotonic", failingExample)
    end
    
    return allPassed, failingExample
end

-- ============================================================================
-- PROPERTY 8: Overlay Matches Screen Size
-- **Feature: DDA-expansion, Property 8: Overlay Matches Screen Size**
-- **Validates: Requirements 2.6**
--
-- *For any* screen resolution, the overlay dimensions SHALL equal the screen 
-- width and height.
-- ============================================================================

function CS_RadiationOverlay_Tests.property8_OverlayMatchesScreenSize()
    local testName = "Property 8: Overlay Matches Screen Size"
    local iterations = 100
    local allPassed = true
    local failingExample = nil
    
    for i = 1, iterations do
        -- Generate random screen dimensions
        local newWidth = generateScreenDimension()
        local newHeight = generateScreenDimension()
        
        -- Simulate resolution change
        CS_RadiationOverlay.onResolutionChange(0, 0, newWidth, newHeight)
        
        -- Get overlay dimensions
        local overlayWidth, overlayHeight = CS_RadiationOverlay.getScreenDimensions()
        
        -- Verify dimensions match
        if overlayWidth ~= newWidth then
            allPassed = false
            failingExample = string.format(
                "Overlay width %d does not match screen width %d",
                overlayWidth, newWidth
            )
            break
        end
        
        if overlayHeight ~= newHeight then
            allPassed = false
            failingExample = string.format(
                "Overlay height %d does not match screen height %d",
                overlayHeight, newHeight
            )
            break
        end
    end
    
    if allPassed then
        recordPass(testName)
    else
        recordFail(testName, "Dimension mismatch", failingExample)
    end
    
    return allPassed, failingExample
end

-- ============================================================================
-- HELPER TESTS
-- ============================================================================

function CS_RadiationOverlay_Tests.testSetOverlay()
    local testName = "Helper: setOverlay correctness"
    local allPassed = true
    local failingExample = nil
    
    -- Test each radiation type
    local types = {"green", "violet", "red"}
    for _, radiationType in ipairs(types) do
        CS_RadiationOverlay.clear()
        CS_RadiationOverlay.state.initialized = true
        
        CS_RadiationOverlay.setOverlay(radiationType, 0.5)
        
        -- Verify radiation type was set
        if CS_RadiationOverlay.getRadiationType() ~= radiationType then
            allPassed = false
            failingExample = string.format(
                "setOverlay('%s') did not set radiation type correctly, got '%s'",
                radiationType, tostring(CS_RadiationOverlay.getRadiationType())
            )
            break
        end
        
        -- Verify target alpha was set
        if CS_RadiationOverlay.getTargetAlpha() ~= 0.5 then
            allPassed = false
            failingExample = string.format(
                "setOverlay target alpha should be 0.5, got %f",
                CS_RadiationOverlay.getTargetAlpha()
            )
            break
        end
    end
    
    -- Test nil radiation type
    CS_RadiationOverlay.clear()
    CS_RadiationOverlay.setOverlay(nil, 0.5)
    -- Should not crash, just log error
    
    -- Test invalid radiation type
    CS_RadiationOverlay.clear()
    CS_RadiationOverlay.setOverlay("invalid", 0.5)
    -- Should not crash, just log error
    
    if allPassed then
        recordPass(testName)
    else
        recordFail(testName, "setOverlay error", failingExample)
    end
    
    return allPassed, failingExample
end

function CS_RadiationOverlay_Tests.testClear()
    local testName = "Helper: clear correctness"
    local allPassed = true
    local failingExample = nil
    
    -- Set up overlay with some state
    CS_RadiationOverlay.state.initialized = true
    CS_RadiationOverlay.state.alpha = 0.5
    CS_RadiationOverlay.state.targetAlpha = 0.8
    CS_RadiationOverlay.state.radiationType = "green"
    
    -- Clear
    CS_RadiationOverlay.clear()
    
    -- Verify all state is reset
    if CS_RadiationOverlay.getAlpha() ~= 0 then
        allPassed = false
        failingExample = "clear() did not reset alpha to 0"
    elseif CS_RadiationOverlay.getTargetAlpha() ~= 0 then
        allPassed = false
        failingExample = "clear() did not reset targetAlpha to 0"
    elseif CS_RadiationOverlay.getRadiationType() ~= nil then
        allPassed = false
        failingExample = "clear() did not reset radiationType to nil"
    end
    
    if allPassed then
        recordPass(testName)
    else
        recordFail(testName, "clear error", failingExample)
    end
    
    return allPassed, failingExample
end

-- ============================================================================
-- TEST RUNNER
-- ============================================================================

function CS_RadiationOverlay_Tests.runAll()
    print("========================================")
    print("DDA Radiation Overlay Property Tests")
    print("========================================")
    
    resetResults()
    
    -- Run helper tests first
    CS_RadiationOverlay_Tests.testSetOverlay()
    CS_RadiationOverlay_Tests.testClear()
    
    -- Run property tests
    CS_RadiationOverlay_Tests.property5_OverlayColorMatchesRadiationType()
    CS_RadiationOverlay_Tests.property6_FadeInIncreasesAlpha()
    CS_RadiationOverlay_Tests.property7_FadeOutDecreasesAlpha()
    CS_RadiationOverlay_Tests.property8_OverlayMatchesScreenSize()
    
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

-- Run specific property test
function CS_RadiationOverlay_Tests.runProperty5()
    resetResults()
    CS_RadiationOverlay_Tests.property5_OverlayColorMatchesRadiationType()
    return TestResults
end

function CS_RadiationOverlay_Tests.runProperty6()
    resetResults()
    CS_RadiationOverlay_Tests.property6_FadeInIncreasesAlpha()
    return TestResults
end

function CS_RadiationOverlay_Tests.runProperty7()
    resetResults()
    CS_RadiationOverlay_Tests.property7_FadeOutDecreasesAlpha()
    return TestResults
end

function CS_RadiationOverlay_Tests.runProperty8()
    resetResults()
    CS_RadiationOverlay_Tests.property8_OverlayMatchesScreenSize()
    return TestResults
end

-- Export for debug console access
_G.CS_RadiationOverlay_Tests = CS_RadiationOverlay_Tests

return CS_RadiationOverlay_Tests
