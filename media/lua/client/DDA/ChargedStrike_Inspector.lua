--[[
    Object Inspection Utility
]]

DDA = DDA or {}

function DDA.inspect(obj)
    if not obj then return "nil" end
    print("INSULATION: Inspecting object of type " .. tostring(instanceof(obj, "IsoPlayer") and "IsoPlayer" or "Unknown"))
    
    -- Print all methods available to Lua
    for k, v in pairs(obj) do
        print("KEY: " .. tostring(k) .. " | TYPE: " .. type(v))
    end
end

function DDA.debugStats(player)
    local stats = player:getStats()
    if not stats then 
        print("DEBUG: Stats is nil!")
        return 
    end
    
    print("DEBUG: Stats object found. Attempting to list keys via pairs...")
    -- Generic loop might not work for Java objects but let's try
    pcall(function()
        for k, v in pairs(stats) do
            print("STATS KEY: " .. tostring(k))
        end
    end)
    
    -- Try common names
    print("DEBUG: Testing common method names:")
    print("  getEndurance: " .. tostring(stats.getEndurance))
    print("  getFatigue: " .. tostring(stats.getFatigue))
    print("  getHunger: " .. tostring(stats.getHunger))
    print("  getThirst: " .. tostring(stats.getThirst))
end
