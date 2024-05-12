-- ContrAI by JJ Coldiron
--
-- Inspired by SethBling's MarI/O code, this lua script utilizes
-- Kenneth Stanley's NEAT algorithm to evolve a neural net capable
-- of playing Konami's "Contra" for the NES. Designed to be used as
-- a plugin for the BizHawk emulator.

if gameinfo.getromname() == "Contra (USA)" then
        Filename = "level-start.state"
        ButtonNames = { "A", "B", "Up", "Down", "Left", "Right" }
end

-- Limited inputs to those within 6 tiles of the player
-- so as to reduce complexity
InputRadius = 6

InputCount = (InputRadius * 2 + 1) * (InputRadius * 2 + 1)
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


-- TODO: Find memory addresses for player x and y
function getPlayerPos()
        VerticalScroll = emu.read(0xFC, emu.memType.cpu)
        HorizontalScroll = emu.read(0xFD, emu.memType.cpu)
        PlayerOnscreenX = emu.read(0x0334, emu.memType.cpu)
        PlayerOnscreenY = emu.read(0x031A, emu.memType.cpu)
        PlayerX = HorizontalScroll + PlayerOnscreenX
        PlayerY = VerticalScroll + PlayerOnscreenY
end

function getTile(dx, dy)
        -- TODO: Find out how tiles are mapped in RAM
end

function getInputs()
        -- TODO: Finish called functions
        getPlayerPos()
end

-- TODO: Display fitness and input neurons correctly

while true do
        getPlayerPos()
        console.writeline("Fitness: " .. PlayerX)
end
