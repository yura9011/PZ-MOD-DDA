-- DDA Zombie Zone Definitions
-- Registers special zombie outfits with spawn chances
-- Pattern from OccultZombies mod

require "NPCs/ZombiesZoneDefinition"

ZombiesZoneDefinition.Default = ZombiesZoneDefinition.Default or {}

-- Special Zombies (low chance spawn)
-- Juggernaut = Titan (uses Juggernaut outfit from clothing.xml)
-- NeonGhoul = Brute (uses NeonGhoul outfit from clothing.xml)
table.insert(ZombiesZoneDefinition.Default, { name = "Juggernaut", chance = 1 })  -- 1% Titan
table.insert(ZombiesZoneDefinition.Default, { name = "NeonGhoul", chance = 2 })   -- 2% Brute

print("[DDA] Zombie Zone Definitions loaded - Juggernaut(1%), NeonGhoul(2%)")
