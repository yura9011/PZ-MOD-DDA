--[[
    Charged Strike Mod - Core System (Optimized)
    Hold right-click while standing still to charge a powerful attack.
    
    Tiers:
    - 0-49%:  x1 damage, x1 stamina, x1 durability (normal)
    - 50-74%: x2 damage, x1.5 stamina, x1.5 durability
    - 75-99%: x3 damage, x2 stamina, x2 durability
    - 100%:   x4 damage, x3 stamina, x3 durability + guaranteed knockdown
    
    Optimization Notes:
    - Globals cached at file scope
    - Early exits to reduce processing
    - Debug logging disabled for production
]]

DDA = DDA or {}

-- ===============================
-- GLOBALS CACHE (Performance)
-- ===============================
local getTimestampMs = getTimestampMs
local instanceof = instanceof
local math_min = math.min
local math_floor = math.floor
local getGameTime = getGameTime

-- ===============================
-- CONFIGURATION
-- ===============================
DDA.Config = {
    MaxChargeTime = 3.0,  -- Seconds to reach 100%
    Tiers = {
        { threshold = 0.00, damageMultiplier = 1.0, staminaMultiplier = 1.0, durabilityMultiplier = 1.0, knockdown = false },
        { threshold = 0.50, damageMultiplier = 2.0, staminaMultiplier = 1.5, durabilityMultiplier = 1.5, knockdown = false },
        { threshold = 0.75, damageMultiplier = 3.0, staminaMultiplier = 2.0, durabilityMultiplier = 2.0, knockdown = false },
        { threshold = 1.00, damageMultiplier = 4.0, staminaMultiplier = 3.0, durabilityMultiplier = 3.0, knockdown = true  },
    },
    Debug = false,  -- DISABLED FOR PRODUCTION
    
    -- Filter what weapons can use this ability
    AllowedWeapons = {
        ["Base.Katana"] = true,
        ["ChargedStrike.TitanMachete"] = true,
        ["ChargedStrike.TitanAxe"] = true,
        ["ChargedStrike.TitanWeapon"] = true,
    },
}

-- Local reference for hot path
local Config = DDA.Config
local AllowedWeapons = Config.AllowedWeapons
local Tiers = Config.Tiers
local MaxChargeTime = Config.MaxChargeTime

-- ===============================
-- STATE TRACKING
-- ===============================
DDA.State = {}

local function getPlayerState(player)
    local id = player:getPlayerNum()
    local state = DDA.State[id]
    if not state then
        state = {
            isCharging = false,
            chargeTime = 0,
            chargePercent = 0,
            currentTier = 1,
            pendingChargePercent = 0,
            pendingChargeTier = 1,
            pendingChargeExpireTime = 0,
            chargeCooldownUntil = 0,
        }
        DDA.State[id] = state
    end
    return state
end

local function getTierForPercent(percent)
    for i = #Tiers, 1, -1 do
        if percent >= Tiers[i].threshold then
            return i, Tiers[i]
        end
    end
    return 1, Tiers[1]
end

local function debugLog(msg)
    if Config.Debug then
        print("[DDA] " .. msg)
    end
end

-- ===============================
-- MAIN UPDATE LOOP (Optimized)
-- ===============================
local function onPlayerUpdate(player)
    -- Early exit: dead or nil
    if not player or player:isDead() then return end
    
    -- Get weapon first for early exit
    local weapon = player:getPrimaryHandItem()
    
    -- Early exit: no weapon or not in whitelist
    if not weapon then return end
    if not AllowedWeapons[weapon:getFullType()] then return end
    
    -- Early exit: not a melee weapon
    if not instanceof(weapon, "HandWeapon") or weapon:isRanged() then return end
    
    -- Now we know player has a valid weapon, continue with charging logic
    local state = getPlayerState(player)
    local isAiming = player:isAiming()
    local isMoving = player:isPlayerMoving()
    
    local currentTime = getTimestampMs()
    local isOnCooldown = currentTime < state.chargeCooldownUntil
    
    local currentlyCharging = isAiming and not isMoving and not isOnCooldown
    
    if currentlyCharging then
        state.isCharging = true
        
        local deltaTime = getGameTime():getMultiplier() / 30
        state.chargeTime = math_min(state.chargeTime + deltaTime, MaxChargeTime)
        state.chargePercent = state.chargeTime / MaxChargeTime
        
        local tierIndex, tierData = getTierForPercent(state.chargePercent)
        
        if tierIndex ~= state.currentTier then
            debugLog(string.format("TIER UP: %d -> %d (x%.1f damage)", state.currentTier, tierIndex, tierData.damageMultiplier))
        end
        state.currentTier = tierIndex
    else
        if state.isCharging and state.chargePercent > 0 then
            state.pendingChargePercent = state.chargePercent
            state.pendingChargeTier = state.currentTier
            state.pendingChargeExpireTime = currentTime + 1000
        end
        
        state.isCharging = false
        state.chargeTime = 0
        state.chargePercent = 0
        state.currentTier = 1
    end
end

-- ===============================
-- WEAPON HIT (Optimized)
-- ===============================
local function onWeaponHitCharacter(attacker, target, weapon, damage)
    if not attacker or not instanceof(attacker, "IsoPlayer") then return end
    
    local state = getPlayerState(attacker)
    local currentTime = getTimestampMs()
    
    local chargePercent = 0
    local chargeTier = 1
    
    if state.pendingChargePercent > 0 and currentTime < state.pendingChargeExpireTime then
        chargePercent = state.pendingChargePercent
        chargeTier = state.pendingChargeTier
    elseif state.chargePercent > 0 then
        chargePercent = state.chargePercent
        chargeTier = state.currentTier
    end
    
    if chargePercent > 0 then
        local tierIndex, tierData = getTierForPercent(chargePercent)
        
        -- Apply extra damage
        if tierData.damageMultiplier > 1 and target and target.getHealth then
            local extraDamage = damage * (tierData.damageMultiplier - 1)
            target:setHealth(target:getHealth() - extraDamage)
            
            HaloTextHelper.addTextWithArrow(attacker, "x" .. math_floor(tierData.damageMultiplier), true, HaloTextHelper.getColorGreen())
        end
        
        -- Apply extra stamina cost
        if tierData.staminaMultiplier > 1 then
            pcall(function()
                local stats = attacker:getStats()
                if stats then
                    local staminaCost = 0.05 * tierData.staminaMultiplier
                    if CharacterStat and CharacterStat.ENDURANCE and stats.remove then
                        stats:remove(CharacterStat.ENDURANCE, staminaCost)
                    elseif stats.getEndurance and stats.setEndurance then
                        stats:setEndurance(stats:getEndurance() - staminaCost)
                    end
                end
            end)
        end
        
        -- Apply extra durability loss
        if tierData.durabilityMultiplier > 1 and weapon then
            pcall(function()
                local extraLoss = math_floor(tierData.durabilityMultiplier - 1)
                for i = 1, extraLoss do
                    weapon:setCondition(weapon:getCondition() - 1)
                end
            end)
        end
        
        -- Guaranteed knockdown at max tier
        if tierData.knockdown and target and target.setKnockedDown then
            target:setKnockedDown(true)
        end
        
        -- Reset charge
        state.chargeTime = 0
        state.chargePercent = 0
        state.currentTier = 1
        state.pendingChargePercent = 0
        state.pendingChargeTier = 1
        state.pendingChargeExpireTime = 0
        state.chargeCooldownUntil = currentTime + 500
    end
end

-- ===============================
-- PUBLIC API
-- ===============================
function DDA.getChargeInfo(player)
    if not player then return nil end
    local state = getPlayerState(player)
    return {
        isCharging = state.isCharging,
        chargePercent = state.chargePercent,
        currentTier = state.currentTier,
        tierData = Tiers[state.currentTier]
    }
end

-- ===============================
-- EVENT HOOKS
-- ===============================
Events.OnPlayerUpdate.Add(onPlayerUpdate)
Events.OnWeaponHitCharacter.Add(onWeaponHitCharacter)

print("[DDA] Core system loaded - v1.1.0 (Optimized)")
