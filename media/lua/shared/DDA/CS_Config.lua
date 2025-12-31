-- DDA Configuration
-- Central configuration for all DDA expansion systems
-- Requirements: 1.1, 11.1, 11.2, 11.3, 9.2

local CS_Config = {}

-- ============================================================================
-- RADIATION SYSTEM (Requirement 1.1)
-- ============================================================================
CS_Config.Radiation = {
    -- Radiation types with their effects
    types = {
        green = {
            damagePerTick = 0.5,      -- Slow poison damage
            stressIncrease = 0.02,    -- Stress increase per tick
            overlayColor = {r = 0, g = 255, b = 0},
            texturePath = "media/textures/GUI/radiation_green.png"
        },
        violet = {
            panicIncrease = 0.05,     -- Panic increase per tick
            hallucinationChance = 0.1, -- Chance of hallucination per tick
            overlayColor = {r = 128, g = 0, b = 255},
            texturePath = "media/textures/GUI/radiation_violet.png"
        },
        red = {
            damagePerTick = 2.0,      -- Fast damage
            stalkerSpawnChance = 0.05, -- Chance to spawn Stalker nearby
            overlayColor = {r = 255, g = 0, b = 0},
            texturePath = "media/textures/GUI/radiation_red.png"
        }
    },
    
    -- Event timing
    minDuration = 30,        -- Minimum duration in game minutes
    maxDuration = 120,       -- Maximum duration in game minutes
    eventChance = 10,        -- Percent chance per check (EveryTenMinutes)
    
    -- Overlay settings
    fadeSpeed = 0.02,        -- Alpha change per frame during fade
    maxAlpha = 0.4           -- Maximum overlay opacity
}

-- ============================================================================
-- BROADCAST SYSTEM (Requirements 5.1, 5.2)
-- ============================================================================
CS_Config.Broadcast = {
    frequency = 93500,       -- 93.5 MHz (DDA Emergency Frequency)
    channelName = "DDA Emergency Network",
    channelUUID = "CS-RAD-001",
    
    -- Broadcast timing
    minWarningHours = 1.0,   -- Minimum hours before event to broadcast
    maxWarningHours = 3.0,   -- Maximum hours before event to broadcast
    
    -- Message priority (higher = more important)
    priority = 10
}

-- ============================================================================
-- SPECIAL ZOMBIE STATS (Requirements 11.1, 11.2, 11.3)
-- ============================================================================
CS_Config.SpecialZombies = {
    titan = {
        healthMultiplier = 5.0,
        damageMultiplier = 2.0,
        outfit = "Juggernaut", -- Uses JuggernautXML
        drops = {
            {item = "ChargedStrike.TitanWeapon", chance = 1.0},
            {item = "ChargedStrike.TitanCore", chance = 1.0}
        }
    },
    stalker = {
        healthMultiplier = 2.0,
        damageMultiplier = 1.5,
        outfit = "Stalker",
        drops = {
            {item = "ChargedStrike.StalkerEye", chance = 1.0},
            {item = "ChargedStrike.TitanWeapon", chance = 0.5},
            {item = "ChargedStrike.TitanCore", chance = 0.5}
        }
    },
    abomination = {
        healthMultiplier = 4.0,
        damageMultiplier = 2.0,
        outfit = "Abomination",
        drops = {
            {item = "ChargedStrike.TitanWeapon", chance = 0.5},
            {item = "ChargedStrike.TitanCore", chance = 0.5}
        }
    },
    brute = {
        healthMultiplier = 3.0,
        damageMultiplier = 3.0,
        outfit = "NeonGhoul",
        drops = {
            {item = "ChargedStrike.BruteArm", chance = 1.0}
        }
    }
}

-- Spawn chances (Requirements 10.1, 10.2)
CS_Config.SpawnChances = {
    keyBuilding = 0.05,      -- 5% in factories, warehouses, military, hospitals (Production)
    normalBuilding = 0.005   -- 0.5% elsewhere (Production)
}

-- Key building room name patterns for higher spawn rates (Requirement 10.3)
-- These patterns are matched against room:getName() using string.find()
CS_Config.KeyRoomPatterns = {
    -- Factory/Industrial
    "factory",
    "warehouse", 
    "industrial",
    "storage",
    "garage",
    "mechanic",
    
    -- Military
    "military",
    "armory",
    "army",
    "barracks",
    
    -- Hospital/Medical
    "hospital",
    "medical",
    "clinic",
    "pharmacy",
    "morgue",
    "surgery",
    
    -- Additional high-value locations
    "prison",
    "police",
    "firestation",
    "gunstore"
}

-- ============================================================================
-- REMOTE START SYSTEM (Requirement 9.2)
-- ============================================================================
CS_Config.SpawnLocations = {
    {x = 4103, y = 6537, z = -1, name = "Graffiti Basement"},
    -- {x = 9976, y = 12628, z = 0, name = "Pool Patio"}, -- TODO: Verify Z level (surface vs basement)
    -- {x = 5576, y = 9367, z = 0, name = "Bunker"}, -- TODO: Verify Z level
    -- {x = 10764, y = 10544, z = -1, name = "Barrel Basement"}, -- TODO: Verify collision/coordinates
    {x = 8724, y = 14087, z = -1, name = "Utility Basement"}
}

-- ============================================================================
-- PROTECTION SYSTEM (Requirements 3.1-3.5)
-- ============================================================================
CS_Config.Protection = {
    indoorIntact = 1.0,      -- 100% protection indoors with intact room
    indoorDamaged = 0.5,     -- 50% protection with broken doors/windows
    outdoorHazmat = 1.0,     -- 100% protection with hazmat suit
    outdoorNone = 0.0,       -- 0% protection outdoors without hazmat
    
    -- Hazmat suit detection configuration
    -- Body locations to check for hazmat suit
    hazmatBodyLocations = {
        "FullSuit",          -- Full body suit slot
        "Jacket",            -- Jacket slot (some hazmat suits use this)
        "TorsoExtra"         -- Extra torso slot
    },
    
    -- Item patterns that count as hazmat protection
    -- Any item containing these strings in its FullType will provide protection
    hazmatItems = {
        "Hazmat",            -- Standard hazmat suits
        "NBCSuit",           -- NBC protection suits
        "RadiationSuit"      -- Radiation protection suits
    }
}

-- ============================================================================
-- TROPHY ITEMS (Requirements 6.1, 6.2, 7.1, 7.2)
-- ============================================================================
CS_Config.TrophyItems = {
    TitanCore = "ChargedStrike.TitanCore",
    TitanWeapon = "ChargedStrike.TitanWeapon",
    TitanWeaponBroken = "ChargedStrike.TitanWeapon_Broken",
    StalkerEye = "ChargedStrike.StalkerEye",
    BruteArm = "ChargedStrike.BruteArm"
}

-- ============================================================================
-- WEAPON REFORGING (Requirements 8.1, 8.2, 8.3, 8.4)
-- ============================================================================
CS_Config.Reforging = {
    -- Titan weapon reforging
    titanWeapon = {
        brokenItem = "ChargedStrike.TitanWeapon_Broken",
        reforgedItem = "ChargedStrike.TitanWeapon",
        requiredCore = "ChargedStrike.TitanCore",
        craftTime = 200,
        xpReward = 10
    }
}

-- ============================================================================
-- DEBUG SETTINGS
-- ============================================================================
CS_Config.Debug = {
    enabled = false,         -- Disabled for release
    logLevel = 0,            -- 0=none
    forceRadiation = false,
    forceRadiationType = nil,
    forceSpawnIndex = nil
}

return CS_Config
