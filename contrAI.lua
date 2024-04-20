-- ContrAI by JJ Coldiron
--
-- Inspired by SethBling's Mar/IO code, this lua script utilizes
-- Kenneth Stanley's NEAT algorithm to evolve a neural net capable
-- of playing Konami's "Contra" for the NES. Designed to be used as
-- a plugin for the BizHawk emulator.

if gameinfo.getromname() == "Contra (USA)" then
  Filename = "level-start.state"
  ButtonNames = {"A", "B", "Up", "Down", "Left", "Right"}
end

-- Width and height decided by dividing resolution
-- into 16x16 collision tiles
screenWidth = 32
screenHeight = 28

inputCount = screenWidth * screenHeight + 1

-- Level 1-1 of Contra is divided into 13 screens.
-- Each screen is divided into a 7x8 grid of supertiles.
-- Each supertile is 4x4 regular tiles.
-- Each tile is 8x8 pixels.
--
-- Code needs to pay attention to tiles 0x01 - 0x05 (floor tiles)
--                                      0xF9 - 0xFE (water tiles)
--                                             0xFF (solid collision)

-- Fitness will be determined by how far right the player has moved
-- into the level.
--
-- This can be measured using the Level Screen Number (0x64 in RAM)
-- and the Level Screen Scroll Offset (0x65 in RAM).

-- Declare constants for NEAT

while true do
  -- Main loop
end
