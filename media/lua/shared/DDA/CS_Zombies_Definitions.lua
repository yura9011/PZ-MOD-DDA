-- CS_Zombies_Definitions.lua
-- Registers custom zombie outfits for the DDA expansion
-- Requirement: 11.1, 11.2, 11.3

local function initOutfits()
    -- In B42, ZombieOutfits might not be initialized during this phase
    -- or the table structure might have changed.
    if not ZombieOutfits then 
        ZombieOutfits = {}
    end
    if not ZombieOutfits.free then
        ZombieOutfits.free = {}
    end

    -- Juggernaut Outfit (Titan)
    ZombieOutfits.free["Juggernaut"] = {
        top = {
            { item = "DDA.Juggernaut", chance = 100 },
        },
        allowUnderwear = false,
    }

    -- Stalker Outfit (Uses Juggernaut model as placeholder)
    ZombieOutfits.free["Stalker"] = {
        top = {
            { item = "DDA.Stalker", chance = 100 },
        },
        allowUnderwear = false,
    }

    -- Brute Outfit (Neon Ghoul)
    ZombieOutfits.free["Brute"] = {
        top = {
            { item = "DDA.Brute", chance = 100 },
        },
        allowUnderwear = false,
    }
    
    print("[DDA] Special zombie outfits registered (Safer Load).")
end

-- Call initialization
initOutfits()
