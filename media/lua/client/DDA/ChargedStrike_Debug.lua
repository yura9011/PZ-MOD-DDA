--[[
    Charged Strike Mod - Debug Context Menu
    Right-click debug menu for testing charge system.
    Only appears when DDA.Config.Debug = true
]]

require "ISUI/ISInventoryPaneContextMenu"

DDA = DDA or {}
DDA.Debug = {}

-- Debug Context Menu
local function onFillInventoryObjectContextMenu(playerNum, context, items)
    -- Only show if debug mode is enabled
    if not DDA.Config or not DDA.Config.Debug then
        return
    end
    
    local player = getSpecificPlayer(playerNum)
    if not player then return end
    
    local state = DDA.State and DDA.State[player:getPlayerNum()]
    
    -- Main debug menu
    local option = context:addOption("[DEBUG] DDA", nil, nil)
    local subMenu = context:getNew(context)
    context:addSubMenu(option, subMenu)
    
    -- === Current State Info ===
    subMenu:addOption("--- Current State ---", nil, nil)
    
    local chargePercent = state and math.floor((state.chargePercent or 0) * 100) or 0
    local tier = state and state.currentTier or 1
    local isCharging = state and state.isCharging or false
    local pendingPercent = state and math.floor((state.pendingChargePercent or 0) * 100) or 0
    
    subMenu:addOption("Charge: " .. chargePercent .. "% | Tier: " .. tier, nil, nil)
    subMenu:addOption("Charging: " .. tostring(isCharging), nil, nil)
    subMenu:addOption("Pending: " .. pendingPercent .. "%", nil, nil)
    
    -- === Config Settings ===
    subMenu:addOption("--- Config ---", nil, nil)
    subMenu:addOption("Max Time: " .. DDA.Config.MaxChargeTime .. "s", nil, nil)
    
    -- === Charge Manipulation ===
    subMenu:addOption("--- Set Charge ---", nil, nil)
    
    subMenu:addOption("Set Charge: 0% (Reset)", player, function()
        if DDA.State[player:getPlayerNum()] then
            local s = DDA.State[player:getPlayerNum()]
            s.chargePercent = 0
            s.chargeTime = 0
            s.currentTier = 1
            s.pendingChargePercent = 0
            s.pendingChargeTier = 1
        end
        player:Say("[DEBUG] Charge reset to 0%")
    end)
    
    subMenu:addOption("Set Charge: 50% (Tier 2)", player, function()
        if DDA.State[player:getPlayerNum()] then
            local s = DDA.State[player:getPlayerNum()]
            s.chargePercent = 0.50
            s.chargeTime = DDA.Config.MaxChargeTime * 0.50
            s.currentTier = 2
        end
        player:Say("[DEBUG] Charge set to 50% (Tier 2)")
    end)
    
    subMenu:addOption("Set Charge: 75% (Tier 3)", player, function()
        if DDA.State[player:getPlayerNum()] then
            local s = DDA.State[player:getPlayerNum()]
            s.chargePercent = 0.75
            s.chargeTime = DDA.Config.MaxChargeTime * 0.75
            s.currentTier = 3
        end
        player:Say("[DEBUG] Charge set to 75% (Tier 3)")
    end)
    
    subMenu:addOption("Set Charge: 100% (Tier 4)", player, function()
        if DDA.State[player:getPlayerNum()] then
            local s = DDA.State[player:getPlayerNum()]
            s.chargePercent = 1.0
            s.chargeTime = DDA.Config.MaxChargeTime
            s.currentTier = 4
        end
        player:Say("[DEBUG] Charge set to 100% (Tier 4)")
    end)
    
    -- === Set Pending Charge (for attack tests) ===
    subMenu:addOption("--- Set Pending Charge ---", nil, nil)
    
    subMenu:addOption("Set Pending: 100% (Tier 4)", player, function()
        if DDA.State[player:getPlayerNum()] then
            local s = DDA.State[player:getPlayerNum()]
            s.pendingChargePercent = 1.0
            s.pendingChargeTier = 4
            s.pendingChargeExpireTime = getTimestampMs() + 10000  -- 10 seconds for testing
        end
        player:Say("[DEBUG] Pending charge set to 100% (10s window)")
    end)
    
    subMenu:addOption("Clear Pending Charge", player, function()
        if DDA.State[player:getPlayerNum()] then
            local s = DDA.State[player:getPlayerNum()]
            s.pendingChargePercent = 0
            s.pendingChargeTier = 1
            s.pendingChargeExpireTime = 0
        end
        player:Say("[DEBUG] Pending charge cleared")
    end)
    
    -- === Config Manipulation ===
    subMenu:addOption("--- Config Tests ---", nil, nil)
    
    subMenu:addOption("Max Time: 1s (Fast)", player, function()
        DDA.Config.MaxChargeTime = 1.0
        player:Say("[DEBUG] Charge time set to 1 second")
    end)
    
    subMenu:addOption("Max Time: 3s (Default)", player, function()
        DDA.Config.MaxChargeTime = 3.0
        player:Say("[DEBUG] Charge time set to 3 seconds")
    end)
    
    subMenu:addOption("Max Time: 5s (Slow)", player, function()
        DDA.Config.MaxChargeTime = 5.0
        player:Say("[DEBUG] Charge time set to 5 seconds")
    end)
    
    -- === Tier Info ===
    subMenu:addOption("--- Tier Info ---", nil, nil)
    
    for i, tierData in ipairs(DDA.Config.Tiers) do
        local info = string.format("Tier %d: x%.1f dmg, x%.1f stam, KD=%s", 
            i, 
            tierData.damageMultiplier, 
            tierData.staminaMultiplier,
            tostring(tierData.knockdown))
        subMenu:addOption(info, nil, nil)
    end
    
    -- === Player Stats ===
    subMenu:addOption("--- Player Stats ---", nil, nil)
    
    subMenu:addOption("Show Stamina", player, function()
        local stats = player:getStats()
        if stats then
            local endurance = stats:getEndurance()
            player:Say("[DEBUG] Stamina: " .. math.floor(endurance * 100) .. "%")
        end
    end)
    
    subMenu:addOption("Restore Stamina", player, function()
        local stats = player:getStats()
        if stats then
            stats:setEndurance(1.0)
            player:Say("[DEBUG] Stamina restored to 100%")
        end
    end)
    
    subMenu:addOption("Drain Stamina (50%)", player, function()
        local stats = player:getStats()
        if stats then
            stats:setEndurance(0.5)
            player:Say("[DEBUG] Stamina set to 50%")
        end
    end)
    
    -- === Weapon Info ===
    subMenu:addOption("--- Weapon Info ---", nil, nil)
    
    subMenu:addOption("Show Weapon Condition", player, function()
        local weapon = player:getPrimaryHandItem()
        if weapon and instanceof(weapon, "HandWeapon") then
            local cond = weapon:getCondition()
            local maxCond = weapon:getConditionMax()
            player:Say("[DEBUG] " .. weapon:getDisplayName() .. ": " .. cond .. "/" .. maxCond)
        else
            player:Say("[DEBUG] No melee weapon equipped")
        end
    end)
    
    subMenu:addOption("Repair Weapon (Full)", player, function()
        local weapon = player:getPrimaryHandItem()
        if weapon and instanceof(weapon, "HandWeapon") then
            weapon:setCondition(weapon:getConditionMax())
            player:Say("[DEBUG] " .. weapon:getDisplayName() .. " repaired!")
        else
            player:Say("[DEBUG] No melee weapon equipped")
        end
    end)
    
    -- === Spawn Test Zombie ===
    subMenu:addOption("--- Test Targets ---", nil, nil)
    
    subMenu:addOption("Spawn Zombie (in front)", player, function()
        local x = player:getX() + 2
        local y = player:getY()
        local z = player:getZ()
        local cell = getWorld():getCell()
        if cell then
            local square = cell:getGridSquare(x, y, z)
            if square then
                addZombiesInOutfit(x, y, z, 1, "", 0)
                player:Say("[DEBUG] Zombie spawned!")
            end
        end
    end)
    
    -- === Toggle Debug ===
    subMenu:addOption("--- Toggle ---", nil, nil)
    
    subMenu:addOption("Disable Debug Mode", player, function()
        DDA.Config.Debug = false
        player:Say("[DEBUG] Debug mode DISABLED (menu will hide)")
    end)
end

-- Register event
Events.OnFillInventoryObjectContextMenu.Add(onFillInventoryObjectContextMenu)

print("[DDA] Debug context menu loaded")
