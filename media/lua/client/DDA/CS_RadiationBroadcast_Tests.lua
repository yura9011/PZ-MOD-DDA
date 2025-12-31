-- DDA Radiation Broadcast Property Tests
-- Property-based tests for the Radiation Broadcast System
-- Run via debug console: CS_RadiationBroadcast_Tests.runAll()

local CS_RadiationBroadcast_Tests = {}

-- Load dependencies
local CS_Config = require("DDA/CS_Config")
local CS_RadiationBroadcast = require("DDA/CS_RadiationBroadcast")

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

--- Generate a random valid radiation type
--- @return string radiationType One of "green", "violet", "red"
local function generateRadiationType()
    local types = {"green", "violet", "red"}
    return types[ZombRand(#types) + 1]
end

--- Generate a random hours until start value
--- @return number hoursUntilStart Random value between 0 and 5 hours
local function generateHoursUntilStart()
    -- Generate values across different ranges to test all time formatting
    local ranges = {
        {0, 0.5},      -- Minutes range (< 1 hour)
        {0.5, 1},      -- Near 1 hour
        {1, 2},        -- 1-2 hours
        {2, 5}         -- Multiple hours
    }
    local range = ranges[ZombRand(#ranges) + 1]
    return range[1] + (ZombRand(100) / 100) * (range[2] - range[1])
end

-- ============================================================================
-- PROPERTY 12: Broadcast Contains Required Info
-- **Feature: DDA-expansion, Property 12: Broadcast Contains Required Info**
-- **Validates: Requirements 5.1, 5.2**
--
-- *For any* radiation warning broadcast, the message SHALL contain the 
-- radiation type and approximate start time.
-- ============================================================================

function CS_RadiationBroadcast_Tests.property12_BroadcastContainsRequiredInfo()
    local testName = "Property 12: Broadcast Contains Required Info"
    local iterations = 100
    local allPassed = true
    local failingExample = nil
    
    for i = 1, iterations do
        -- Generate random inputs
        local radiationType = generateRadiationType()
        local hoursUntilStart = generateHoursUntilStart()
        
        -- Generate warning lines
        local lines = CS_RadiationBroadcast.generateWarningLines(radiationType, hoursUntilStart)
        
        -- Verify lines were generated
        if not lines or #lines == 0 then
            allPassed = false
            failingExample = string.format(
                "iteration=%d, type='%s', hours=%.2f: No lines generated",
                i, radiationType, hoursUntilStart
            )
            break
        end
        
        -- Concatenate all line text for validation
        local fullMessage = ""
        for _, line in ipairs(lines) do
            -- In test environment, lines may be tables with text property
            -- or RadioLine objects with getText method
            local lineText = ""
            if type(line) == "table" then
                if line.getText then
                    lineText = line:getText() or ""
                elseif line.text then
                    lineText = line.text or ""
                else
                    -- Assume it's a mock RadioLine, try to extract text
                    lineText = tostring(line)
                end
            elseif type(line) == "string" then
                lineText = line
            end
            fullMessage = fullMessage .. " " .. lineText
        end
        
        -- Validate using the broadcast system's validation function
        local isValid = CS_RadiationBroadcast.validateBroadcastContent(
            radiationType, 
            hoursUntilStart, 
            fullMessage
        )
        
        if not isValid then
            allPassed = false
            failingExample = string.format(
                "iteration=%d, type='%s', hours=%.2f: Message missing required info. Message: '%s'",
                i, radiationType, hoursUntilStart, fullMessage:sub(1, 200)
            )
            break
        end
    end
    
    if allPassed then
        recordPass(testName)
    else
        recordFail(testName, "Broadcast missing required information", failingExample)
    end
    
    return allPassed, failingExample
end

--- Test that radiation type is always included in broadcast
function CS_RadiationBroadcast_Tests.property12_TypeAlwaysIncluded()
    local testName = "Property 12a: Radiation Type Always Included"
    local iterations = 100
    local allPassed = true
    local failingExample = nil
    
    local validTypes = {"green", "violet", "red"}
    
    for i = 1, iterations do
        -- Test each type
        local radiationType = validTypes[(i % 3) + 1]
        local hoursUntilStart = generateHoursUntilStart()
        
        -- Generate warning lines
        local lines = CS_RadiationBroadcast.generateWarningLines(radiationType, hoursUntilStart)
        
        if not lines or #lines == 0 then
            allPassed = false
            failingExample = string.format(
                "iteration=%d, type='%s': No lines generated",
                i, radiationType
            )
            break
        end
        
        -- Get expected type name
        local expectedTypeName = CS_RadiationBroadcast.typeNames[radiationType]
        if not expectedTypeName then
            allPassed = false
            failingExample = string.format(
                "iteration=%d, type='%s': No type name defined",
                i, radiationType
            )
            break
        end
        
        -- Check if type name appears in any line
        local foundType = false
        for _, line in ipairs(lines) do
            local lineText = ""
            if type(line) == "table" then
                if line.getText then
                    lineText = line:getText() or ""
                elseif line.text then
                    lineText = line.text or ""
                end
            elseif type(line) == "string" then
                lineText = line
            end
            
            if lineText:find(expectedTypeName, 1, true) then
                foundType = true
                break
            end
        end
        
        if not foundType then
            allPassed = false
            failingExample = string.format(
                "iteration=%d, type='%s': Expected type name '%s' not found in broadcast",
                i, radiationType, expectedTypeName
            )
            break
        end
    end
    
    if allPassed then
        recordPass(testName)
    else
        recordFail(testName, "Radiation type not included in broadcast", failingExample)
    end
    
    return allPassed, failingExample
end

--- Test that time information is always included in broadcast
function CS_RadiationBroadcast_Tests.property12_TimeAlwaysIncluded()
    local testName = "Property 12b: Time Information Always Included"
    local iterations = 100
    local allPassed = true
    local failingExample = nil
    
    -- Test different time ranges
    local timeRanges = {
        {0.1, "minutes"},      -- < 1 hour: should mention minutes
        {0.5, "minutes"},      -- < 1 hour: should mention minutes
        {1.5, "hour"},         -- 1-2 hours: should mention hour
        {3.0, "hours"},        -- > 2 hours: should mention hours
        {0.01, "IMMINENT"}     -- Very soon: should say IMMINENT
    }
    
    for i = 1, iterations do
        local rangeIndex = (i % #timeRanges) + 1
        local hoursUntilStart = timeRanges[rangeIndex][1]
        local expectedKeyword = timeRanges[rangeIndex][2]
        local radiationType = generateRadiationType()
        
        -- Generate warning lines
        local lines = CS_RadiationBroadcast.generateWarningLines(radiationType, hoursUntilStart)
        
        if not lines or #lines == 0 then
            allPassed = false
            failingExample = string.format(
                "iteration=%d, hours=%.2f: No lines generated",
                i, hoursUntilStart
            )
            break
        end
        
        -- Check if time keyword appears in any line
        local foundTime = false
        for _, line in ipairs(lines) do
            local lineText = ""
            if type(line) == "table" then
                if line.getText then
                    lineText = line:getText() or ""
                elseif line.text then
                    lineText = line.text or ""
                end
            elseif type(line) == "string" then
                lineText = line
            end
            
            if lineText:find(expectedKeyword, 1, true) then
                foundTime = true
                break
            end
        end
        
        if not foundTime then
            allPassed = false
            failingExample = string.format(
                "iteration=%d, hours=%.2f: Expected time keyword '%s' not found in broadcast",
                i, hoursUntilStart, expectedKeyword
            )
            break
        end
    end
    
    if allPassed then
        recordPass(testName)
    else
        recordFail(testName, "Time information not included in broadcast", failingExample)
    end
    
    return allPassed, failingExample
end

--- Test formatTime function produces valid output for all inputs
function CS_RadiationBroadcast_Tests.property12_FormatTimeValid()
    local testName = "Property 12c: formatTime Produces Valid Output"
    local iterations = 100
    local allPassed = true
    local failingExample = nil
    
    for i = 1, iterations do
        -- Generate random hours value (0 to 10 hours)
        local hoursUntilStart = ZombRand(1000) / 100  -- 0.00 to 10.00
        
        -- Format the time
        local formattedTime = CS_RadiationBroadcast.formatTime(hoursUntilStart)
        
        -- Verify output is a non-empty string
        if type(formattedTime) ~= "string" then
            allPassed = false
            failingExample = string.format(
                "iteration=%d, hours=%.2f: formatTime returned non-string: %s",
                i, hoursUntilStart, type(formattedTime)
            )
            break
        end
        
        if formattedTime == "" then
            allPassed = false
            failingExample = string.format(
                "iteration=%d, hours=%.2f: formatTime returned empty string",
                i, hoursUntilStart
            )
            break
        end
        
        -- Verify output contains expected keywords based on time
        local hasExpectedContent = false
        if hoursUntilStart < 0.01 then
            hasExpectedContent = formattedTime:find("IMMINENT", 1, true) ~= nil
        elseif hoursUntilStart < 1 then
            hasExpectedContent = formattedTime:find("minute", 1, true) ~= nil
        elseif hoursUntilStart < 2 then
            hasExpectedContent = formattedTime:find("hour", 1, true) ~= nil
        else
            hasExpectedContent = formattedTime:find("hour", 1, true) ~= nil
        end
        
        if not hasExpectedContent then
            allPassed = false
            failingExample = string.format(
                "iteration=%d, hours=%.2f: formatTime output '%s' missing expected time keyword",
                i, hoursUntilStart, formattedTime
            )
            break
        end
    end
    
    if allPassed then
        recordPass(testName)
    else
        recordFail(testName, "formatTime produced invalid output", failingExample)
    end
    
    return allPassed, failingExample
end

--- Test validateBroadcastContent correctly validates messages
function CS_RadiationBroadcast_Tests.property12_ValidationCorrectness()
    local testName = "Property 12d: Validation Function Correctness"
    local iterations = 100
    local allPassed = true
    local failingExample = nil
    
    for i = 1, iterations do
        local radiationType = generateRadiationType()
        local hoursUntilStart = generateHoursUntilStart()
        
        local typeName = CS_RadiationBroadcast.typeNames[radiationType]
        local timeStr = CS_RadiationBroadcast.formatTime(hoursUntilStart)
        
        -- Test valid message (contains both type and time)
        local validMessage = string.format("WARNING: %s detected. Expected %s.", typeName, timeStr)
        local isValid = CS_RadiationBroadcast.validateBroadcastContent(radiationType, hoursUntilStart, validMessage)
        
        if not isValid then
            allPassed = false
            failingExample = string.format(
                "iteration=%d: Valid message rejected. type='%s', hours=%.2f, message='%s'",
                i, radiationType, hoursUntilStart, validMessage
            )
            break
        end
        
        -- Test invalid message (missing type)
        local missingTypeMessage = string.format("WARNING: Radiation detected. Expected %s.", timeStr)
        local shouldBeInvalid1 = CS_RadiationBroadcast.validateBroadcastContent(radiationType, hoursUntilStart, missingTypeMessage)
        
        if shouldBeInvalid1 then
            allPassed = false
            failingExample = string.format(
                "iteration=%d: Message missing type was accepted. type='%s', message='%s'",
                i, radiationType, missingTypeMessage
            )
            break
        end
        
        -- Test invalid message (empty)
        local emptyValid = CS_RadiationBroadcast.validateBroadcastContent(radiationType, hoursUntilStart, "")
        if emptyValid then
            allPassed = false
            failingExample = string.format(
                "iteration=%d: Empty message was accepted",
                i
            )
            break
        end
        
        -- Test invalid message (nil)
        local nilValid = CS_RadiationBroadcast.validateBroadcastContent(radiationType, hoursUntilStart, nil)
        if nilValid then
            allPassed = false
            failingExample = string.format(
                "iteration=%d: Nil message was accepted",
                i
            )
            break
        end
    end
    
    if allPassed then
        recordPass(testName)
    else
        recordFail(testName, "Validation function incorrect", failingExample)
    end
    
    return allPassed, failingExample
end

-- ============================================================================
-- TEST RUNNER
-- ============================================================================

function CS_RadiationBroadcast_Tests.runAll()
    print("========================================")
    print("DDA Radiation Broadcast Property Tests")
    print("========================================")
    
    resetResults()
    
    -- Run Property 12 tests
    CS_RadiationBroadcast_Tests.property12_BroadcastContainsRequiredInfo()
    CS_RadiationBroadcast_Tests.property12_TypeAlwaysIncluded()
    CS_RadiationBroadcast_Tests.property12_TimeAlwaysIncluded()
    CS_RadiationBroadcast_Tests.property12_FormatTimeValid()
    CS_RadiationBroadcast_Tests.property12_ValidationCorrectness()
    
    -- Print summary
    print("========================================")
    print(string.format("Results: %d passed, %d failed", TestResults.passed, TestResults.failed))
    print("========================================")
    
    if #TestResults.errors > 0 then
        print("\nFailed Tests:")
        for _, err in ipairs(TestResults.errors) do
            print(string.format("  - %s: %s", err.test, err.message))
            if err.example then
                print(string.format("    Example: %s", err.example))
            end
        end
    end
    
    return TestResults
end

--- Run a single property test by name
function CS_RadiationBroadcast_Tests.runProperty(propertyNumber)
    resetResults()
    
    if propertyNumber == 12 then
        CS_RadiationBroadcast_Tests.property12_BroadcastContainsRequiredInfo()
        CS_RadiationBroadcast_Tests.property12_TypeAlwaysIncluded()
        CS_RadiationBroadcast_Tests.property12_TimeAlwaysIncluded()
        CS_RadiationBroadcast_Tests.property12_FormatTimeValid()
        CS_RadiationBroadcast_Tests.property12_ValidationCorrectness()
    else
        print("Unknown property number: " .. tostring(propertyNumber))
    end
    
    return TestResults
end

-- Export for testing and external access
return CS_RadiationBroadcast_Tests
