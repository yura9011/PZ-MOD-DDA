--[[
    Charged Strike Mod - UI System
    Displays a charge bar above the player while charging.
]]

require "ISUI/ISUIElement"

DDA = DDA or {}

-- UI Configuration
DDA.UI = {
    barWidth = 60,
    barHeight = 8,
    barOffsetY = -80,  -- Offset above player head
    colors = {
        background = { r = 0.1, g = 0.1, b = 0.1, a = 0.8 },
        tier1 = { r = 0.5, g = 0.5, b = 0.5, a = 1.0 },  -- Gray (normal)
        tier2 = { r = 1.0, g = 1.0, b = 0.0, a = 1.0 },  -- Yellow
        tier3 = { r = 1.0, g = 0.5, b = 0.0, a = 1.0 },  -- Orange
        tier4 = { r = 1.0, g = 0.0, b = 0.0, a = 1.0 },  -- Red
        border = { r = 1.0, g = 1.0, b = 1.0, a = 0.5 },
    }
}

local function getTierColor(tierIndex)
    local colors = DDA.UI.colors
    if tierIndex == 4 then return colors.tier4
    elseif tierIndex == 3 then return colors.tier3
    elseif tierIndex == 2 then return colors.tier2
    else return colors.tier1
    end
end

-- Custom UI Element for Charge Bar
ISChargeBar = ISUIElement:derive("ISChargeBar")

function ISChargeBar:new(playerNum)
    local x = 0
    local y = 0
    local width = DDA.UI.barWidth
    local height = DDA.UI.barHeight
    
    local o = ISUIElement:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    
    o.playerNum = playerNum
    o.player = getSpecificPlayer(playerNum)
    o.backgroundColor = DDA.UI.colors.background
    o:setVisible(false)
    
    return o
end

function ISChargeBar:update()
    ISUIElement.update(self)
    
    self.player = getSpecificPlayer(self.playerNum)
    if not self.player or self.player:isDead() then
        self:setVisible(false)
        return
    end
    
    -- Get charge info from core system
    local info = DDA.getChargeInfo and DDA.getChargeInfo(self.player)
    
    if info and info.isCharging and info.chargePercent > 0 then
        self:setVisible(true)
        
        -- Position above player
        local sx = isoToScreenX(self.playerNum, self.player:getX(), self.player:getY(), self.player:getZ())
        local sy = isoToScreenY(self.playerNum, self.player:getX(), self.player:getY(), self.player:getZ())
        
        self:setX(sx - self.width / 2)
        self:setY(sy + DDA.UI.barOffsetY)
    else
        self:setVisible(false)
    end
end

function ISChargeBar:render()
    if not self:getIsVisible() then return end
    
    local info = DDA.getChargeInfo and DDA.getChargeInfo(self.player)
    if not info then return end
    
    local bg = self.backgroundColor
    local tierColor = getTierColor(info.currentTier)
    local border = DDA.UI.colors.border
    
    -- Draw background
    self:drawRect(0, 0, self.width, self.height, bg.a, bg.r, bg.g, bg.b)
    
    -- Draw charge fill
    local fillWidth = self.width * info.chargePercent
    self:drawRect(0, 0, fillWidth, self.height, tierColor.a, tierColor.r, tierColor.g, tierColor.b)
    
    -- Draw tier thresholds
    local thresholds = { 0.50, 0.75, 1.00 }
    for _, t in ipairs(thresholds) do
        local lineX = self.width * t
        self:drawRect(lineX - 1, 0, 2, self.height, 0.3, 1, 1, 1)
    end
    
    -- Draw border
    self:drawRectBorder(0, 0, self.width, self.height, border.a, border.r, border.g, border.b)
    
    -- Draw tier text
    if info.currentTier > 1 then
        local text = "x" .. math.floor(DDA.Config.Tiers[info.currentTier].damageMultiplier)
        local textWidth = getTextManager():MeasureStringX(UIFont.Small, text)
        self:drawText(text, (self.width - textWidth) / 2, self.height + 2, 1, 1, 1, 1, UIFont.Small)
    end
end

-- Create UI instances for all local players
DDA.UIInstances = {}

local function createUI()
    for i = 0, getNumActivePlayers() - 1 do
        if not DDA.UIInstances[i] then
            local bar = ISChargeBar:new(i)
            bar:initialise()
            bar:addToUIManager()
            DDA.UIInstances[i] = bar
        end
    end
end

local function removeUI()
    for i, bar in pairs(DDA.UIInstances) do
        if bar then
            bar:removeFromUIManager()
        end
    end
    DDA.UIInstances = {}
end

-- Event hooks
Events.OnGameStart.Add(createUI)
Events.OnMainMenuEnter.Add(removeUI)

print("[DDA] UI system loaded")
