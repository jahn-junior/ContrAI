-- ContrAI by JJ Coldiron
--
-- Inspired by SethBling's MarI/O code, this lua script utilizes
-- Kenneth Stanley's NEAT algorithm to evolve a neural net capable
-- of playing Konami's "Contra" for the NES. Designed to be used as
-- a plugin for the BizHawk emulator.

Filename = "level-start.state"
ButtonNames = { "A", "B", "Up", "Down", "Left", "Right" }

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
--                                      0x06 - 0xF8 (empty tiles)
--                                      0xF9 - 0xFE (water tiles)
--                                             0xFF (solid collision)

-- Fitness will be determined by how far right the player has moved
-- into the level.
--
-- This can be measured using the Level Screen Number (0x64 in RAM)
-- and the Level Screen Scroll Offset (0x65 in RAM).


-- TODO: Find memory addresses for player x and y
function getPlayerPos()
        PlayerOnscreenX = memory.readbyte(0x0334)
        PlayerOnscreenY = memory.readbyte(0x031A)
end

function measureFitness()
        LevelScreenNumber = memory.readbyte(0x64)
        LevelScreenScrollOffset = memory.readbyte(0x65)
        Fitness = (LevelScreenNumber << 8) + LevelScreenScrollOffset
end

function getCollisionData()
        HorizontalScroll = memory.readbyte(0xFD)
        VerticalScroll = memory.readbyte(0xFC)

        Inputs = {}

        for y = 1, 14 do
                Inputs[y] = {}
                for x = 1, 16 do
                        Inputs[y][x] = 0
                end
        end

        local y = 1
        local x = 1

        for i = 0, 300, 16 do
                for j = 0, 300, 16 do
                        Inputs[y][x] = getTileCollisionCode(i - math.fmod(HorizontalScroll, 16), j - math.fmod(VerticalScroll, 16))
                        x = x + 1
                end
                y = y + 1
        end
end

-- Reads BG_COLLISION_DATA from memory and returns the tile type.
-- 0 = empty, 1 = floor tile, 2 = water tile, 3 = solid tile

-- Adapted from https://github.com/vermiceli/nes-contra-us
function getTileCollisionCode(x, y)
        PPUSettings = memory.readbyte(0xFF)
        
        local adjustedY = y + VerticalScroll
        local adjustedX = x + HorizontalScroll

        if adjustedY >= 0xF0 then
                adjustedY = adjustedY + 0x0F
                adjustedY = adjustedY - 255
        end

        local nameTable = (PPUSettings ~ 0x00) & 0x01

        if adjustedX > 255 then
                nameTable = nameTable ~ 1
                adjustedX = adjustedX - 255
        end

        adjustedY = (adjustedY >> 2) & 0x3C
        adjustedX = adjustedX >> 4
        local bgCollisionOffset = (adjustedX >> 2) | adjustedY

        if nameTable == 1 then
                bgCollisionOffset = bgCollisionOffset | 0x40
        end

        local collisionCodeByte = memory.readbyte(0x680 + bgCollisionOffset)
        adjustedX = adjustedX & 0x03
        local collisionCode = 0

        if adjustedX == 0 then
                collisionCode = collisionCodeByte >> 6
        elseif adjustedX == 1 then
                collisionCode = collisionCodeByte >> 4
        elseif adjustedX == 2 then
                collisionCode = collisionCodeByte >> 2
        else
                collisionCode = collisionCodeByte
        end

        collisionCode = collisionCode & 0x03

        -- Draws collision rectangles onscreen for debugging
        local floorColor = 0x508fbc8f
        local waterColor = 0x500096FF
        local solidColor = 0x50A9A9A9
        local tileColor = 0x0
        if collisionCode == 0x01 then
            tileColor = floorColor
        elseif collisionCode == 0x02 then
            tileColor = waterColor
        elseif collisionCode == 0x03 then
            tileColor = solidColor
        end

        if collisionCode ~= 0 then
                gui.drawRectangle(x, y, 16, 16, tileColor)
        end

        return collisionCode
end

function getInputs()
        getPlayerPos()
        getCollisionData()
end

-- TODO: Display fitness and input neurons correctly

while true do
        measureFitness()
        getCollisionData()

        for i = 1, 14 do
                console.writeline("{" .. Inputs[i][1] .. "} " .. "{" .. Inputs[i][2] .. "} " .. "{" .. Inputs[i][3] .. "} " .. "{" .. Inputs[i][4] .. "} " ..
                                  "{" .. Inputs[i][5] .. "} " .. "{" .. Inputs[i][6] .. "} " .. "{" .. Inputs[i][7] .. "} " .. "{" .. Inputs[i][8] .. "} " ..
                                  "{" .. Inputs[i][9] .. "} " .. "{" .. Inputs[i][10] .. "} " .. "{" .. Inputs[i][11] .. "} " .. "{" .. Inputs[i][12] .. "} " ..
                                  "{" .. Inputs[i][13] .. "} " .. "{" .. Inputs[i][14] .. "} " .. "{" .. Inputs[i][15] .. "} " .. "{" .. Inputs[i][16] .. "} ")
        end

        --console.writeline("Fitness: " .. Fitness)

        emu.frameadvance()
end
