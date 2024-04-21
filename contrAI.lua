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

-- Limited inputs to those within 6 tiles of the player
-- so as to reduce complexity
InputRadius = 6

InputCount = (InputRadius * 2 + 1) * (InputRadius* 2 + 1)
OutputCount = #ButtonNames

-- Variables for use in NEAT

Population = 300
DeltaDisjoint = 2.0
DeltaWeights = 0.4
DeltaThreshold = 1.0
StaleSpecies = 15
MutateConnectionsChance = 0.25
PerturbChance = 0.90
CrossoverChance = 0.75
LinkMutationChance = 2.0
NodeMutationChance = 0.50
BiasMutationChance = 0.40
StepSize = 0.1
DisableMutationChance = 0.4
EnableMutationChance = 0.2
TimeoutConstant = 20
MaxNodes = 1000000

-- TODO: Find memory addresses for player x and y
function getPositions()
  playerX = 0
  playerY = 0
  screenX = 0
  screenY = 0
end

function getTile(dx, dy)
  -- TODO: Find out how tiles are mapped in RAM
end

function getSprites()
  -- TODO: Find out how sprites are mapped in RAM
end

function getExtendedSprites()
  -- TODO: Same as above
end

function getInputs()
  -- TODO: Finish called functions
  getPositions()
  sprites = getSprites()
  extendedSprites = getExtendedSprites()

  local inputs = {}

  for dy = -InputRadius * 16, InputRadius * 16, 16 do
    for dx = -InputRadius * 16, InputRadius * 16, 16 do
      inputs[#inputs + 1] = 0
      tile = getTile(dx, dy)
    end
  end
end

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

while true do
  -- Main loop
end
