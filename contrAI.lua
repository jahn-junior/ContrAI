-- ContrAI by JJ Coldiron
--
-- Inspired by SethBling's MarI/O code, this lua script utilizes
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
function getPlayerPos()
  playerX = emu.read(0x0334, emu.memType.cpu)
  playerY = emu.read(0x031A, emu.memType.cpu)
end

function getTile(dx, dy)
  -- TODO: Find out how tiles are mapped in RAM
end

function getInputs()
  -- TODO: Finish called functions
  getPlayerPos()
  
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

 
if pool == nil then
        initializePool()
end
 
 
function nextGenome()
        pool.currentGenome = pool.currentGenome + 1
        if pool.currentGenome > #pool.species[pool.currentSpecies].genomes then
                pool.currentGenome = 1
                pool.currentSpecies = pool.currentSpecies+1
                if pool.currentSpecies > #pool.species then
                        newGeneration()
                        pool.currentSpecies = 1
                end
        end
end
 
function fitnessAlreadyMeasured()
        local species = pool.species[pool.currentSpecies]
        local genome = species.genomes[pool.currentGenome]
       
        return genome.fitness ~= 0
end
 
function displayGenome(genome)
        local network = genome.network
        local cells = {}
        local i = 1
        local cell = {}
        for dy=-BoxRadius,BoxRadius do
                for dx=-BoxRadius,BoxRadius do
                        cell = {}
                        cell.x = 50+5*dx
                        cell.y = 70+5*dy
                        cell.value = network.neurons[i].value
                        cells[i] = cell
                        i = i + 1
                end
        end
        local biasCell = {}
        biasCell.x = 80
        biasCell.y = 110
        biasCell.value = network.neurons[Inputs].value
        cells[Inputs] = biasCell
       
        for o = 1,Outputs do
                cell = {}
                cell.x = 220
                cell.y = 30 + 8 * o
                cell.value = network.neurons[MaxNodes + o].value
                cells[MaxNodes+o] = cell
                local color
                if cell.value > 0 then
                        color = 0xFF0000FF
                else
                        color = 0xFF000000
                end
                gui.drawText(223, 24+8*o, ButtonNames[o], color, 9)
        end
       
        for n,neuron in pairs(network.neurons) do
                cell = {}
                if n > Inputs and n <= MaxNodes then
                        cell.x = 140
                        cell.y = 40
                        cell.value = neuron.value
                        cells[n] = cell
                end
        end
       
        for n=1,4 do
                for _,gene in pairs(genome.genes) do
                        if gene.enabled then
                                local c1 = cells[gene.into]
                                local c2 = cells[gene.out]
                                if gene.into > Inputs and gene.into <= MaxNodes then
                                        c1.x = 0.75*c1.x + 0.25*c2.x
                                        if c1.x >= c2.x then
                                                c1.x = c1.x - 40
                                        end
                                        if c1.x < 90 then
                                                c1.x = 90
                                        end
                                       
                                        if c1.x > 220 then
                                                c1.x = 220
                                        end
                                        c1.y = 0.75*c1.y + 0.25*c2.y
                                       
                                end
                                if gene.out > Inputs and gene.out <= MaxNodes then
                                        c2.x = 0.25*c1.x + 0.75*c2.x
                                        if c1.x >= c2.x then
                                                c2.x = c2.x + 40
                                        end
                                        if c2.x < 90 then
                                                c2.x = 90
                                        end
                                        if c2.x > 220 then
                                                c2.x = 220
                                        end
                                        c2.y = 0.25*c1.y + 0.75*c2.y
                                end
                        end
                end
        end
       
        gui.drawBox(50-BoxRadius*5-3,70-BoxRadius*5-3,50+BoxRadius*5+2,70+BoxRadius*5+2,0xFF000000, 0x80808080)
        for n,cell in pairs(cells) do
                if n > Inputs or cell.value ~= 0 then
                        local color = math.floor((cell.value+1)/2*256)
                        if color > 255 then color = 255 end
                        if color < 0 then color = 0 end
                        local opacity = 0xFF000000
                        if cell.value == 0 then
                                opacity = 0x50000000
                        end
                        color = opacity + color*0x10000 + color*0x100 + color
                        gui.drawBox(cell.x-2,cell.y-2,cell.x+2,cell.y+2,opacity,color)
                end
        end
        for _,gene in pairs(genome.genes) do
                if gene.enabled then
                        local c1 = cells[gene.into]
                        local c2 = cells[gene.out]
                        local opacity = 0xA0000000
                        if c1.value == 0 then
                                opacity = 0x20000000
                        end
                       
                        local color = 0x80-math.floor(math.abs(sigmoid(gene.weight))*0x80)
                        if gene.weight > 0 then
                                color = opacity + 0x8000 + 0x10000*color
                        else
                                color = opacity + 0x800000 + 0x100*color
                        end
                        gui.drawLine(c1.x+1, c1.y, c2.x-3, c2.y, color)
                end
        end
       
        gui.drawBox(49,71,51,78,0x00000000,0x80FF0000)
       
        if forms.ischecked(showMutationRates) then
                local pos = 100
                for mutation,rate in pairs(genome.mutationRates) do
                        gui.drawText(100, pos, mutation .. ": " .. rate, 0xFF000000, 10)
                        pos = pos + 8
                end
        end
end
 
function writeFile(filename)
        local file = io.open(filename, "w")
        file:write(pool.generation .. "\n")
        file:write(pool.maxFitness .. "\n")
        file:write(#pool.species .. "\n")
        for n,species in pairs(pool.species) do
                file:write(species.topFitness .. "\n")
                file:write(species.staleness .. "\n")
                file:write(#species.genomes .. "\n")
                for m,genome in pairs(species.genomes) do
                        file:write(genome.fitness .. "\n")
                        file:write(genome.maxneuron .. "\n")
                        for mutation,rate in pairs(genome.mutationRates) do
                                file:write(mutation .. "\n")
                                file:write(rate .. "\n")
                        end
                        file:write("done\n")
                       
                        file:write(#genome.genes .. "\n")
                        for l,gene in pairs(genome.genes) do
                                file:write(gene.into .. " ")
                                file:write(gene.out .. " ")
                                file:write(gene.weight .. " ")
                                file:write(gene.innovation .. " ")
                                if(gene.enabled) then
                                        file:write("1\n")
                                else
                                        file:write("0\n")
                                end
                        end
                end
        end
        file:close()
end
 
function savePool()
        local filename = forms.gettext(saveLoadFile)
        writeFile(filename)
end
 
function loadFile(filename)
        local file = io.open(filename, "r")
        pool = newPool()
        pool.generation = file:read("*number")
        pool.maxFitness = file:read("*number")
        forms.settext(maxFitnessLabel, "Max Fitness: " .. math.floor(pool.maxFitness))
        local numSpecies = file:read("*number")
        for s=1,numSpecies do
                local species = newSpecies()
                table.insert(pool.species, species)
                species.topFitness = file:read("*number")
                species.staleness = file:read("*number")
                local numGenomes = file:read("*number")
                for g=1,numGenomes do
                        local genome = newGenome()
                        table.insert(species.genomes, genome)
                        genome.fitness = file:read("*number")
                        genome.maxneuron = file:read("*number")
                        local line = file:read("*line")
                        while line ~= "done" do
                                genome.mutationRates[line] = file:read("*number")
                                line = file:read("*line")
                        end
                        local numGenes = file:read("*number")
                        for n=1,numGenes do
                                local gene = newGene()
                                table.insert(genome.genes, gene)
                                local enabled
                                gene.into, gene.out, gene.weight, gene.innovation, enabled = file:read("*number", "*number", "*number", "*number", "*number")
                                if enabled == 0 then
                                        gene.enabled = false
                                else
                                        gene.enabled = true
                                end
                               
                        end
                end
        end
        file:close()
       
        while fitnessAlreadyMeasured() do
                nextGenome()
        end
        initializeRun()
        pool.currentFrame = pool.currentFrame + 1
end
 
function loadPool()
        local filename = forms.gettext(saveLoadFile)
        loadFile(filename)
end
 
function playTop()
        local maxfitness = 0
        local maxs, maxg
        for s,species in pairs(pool.species) do
                for g,genome in pairs(species.genomes) do
                        if genome.fitness > maxfitness then
                                maxfitness = genome.fitness
                                maxs = s
                                maxg = g
                        end
                end
        end
       
        pool.currentSpecies = maxs
        pool.currentGenome = maxg
        pool.maxFitness = maxfitness
        forms.settext(maxFitnessLabel, "Max Fitness: " .. math.floor(pool.maxFitness))
        initializeRun()
        pool.currentFrame = pool.currentFrame + 1
        return
end
 
function onExit()
        forms.destroy(form)
end
 
writeFile("temp.pool")
 
event.onexit(onExit)
 
form = forms.newform(200, 260, "Fitness")
maxFitnessLabel = forms.label(form, "Max Fitness: " .. math.floor(pool.maxFitness), 5, 8)
showNetwork = forms.checkbox(form, "Show Map", 5, 30)
showMutationRates = forms.checkbox(form, "Show M-Rates", 5, 52)
restartButton = forms.button(form, "Restart", initializePool, 5, 77)
saveButton = forms.button(form, "Save", savePool, 5, 102)
loadButton = forms.button(form, "Load", loadPool, 80, 102)
saveLoadFile = forms.textbox(form, Filename .. ".pool", 170, 25, nil, 5, 148)
saveLoadLabel = forms.label(form, "Save/Load:", 5, 129)
playTopButton = forms.button(form, "Play Top", playTop, 5, 170)
hideBanner = forms.checkbox(form, "Hide Banner", 5, 190)
 
 
while true do
        local backgroundColor = 0xD0FFFFFF
        if not forms.ischecked(hideBanner) then
                gui.drawBox(0, 0, 300, 26, backgroundColor, backgroundColor)
        end
 
        local species = pool.species[pool.currentSpecies]
        local genome = species.genomes[pool.currentGenome]
       
        if forms.ischecked(showNetwork) then
                displayGenome(genome)
        end
       
        if pool.currentFrame%5 == 0 then
                evaluateCurrent()
        end
 
        joypad.set(controller)
 
        getPositions()
        if marioX > rightmost then
                rightmost = marioX
                timeout = TimeoutConstant
        end
       
        timeout = timeout - 1
       
       
        local timeoutBonus = pool.currentFrame / 4
        if timeout + timeoutBonus <= 0 then
                local fitness = rightmost - pool.currentFrame / 2
                -- fitness += 1000 level complete
                genome.fitness = fitness
               
                if fitness > pool.maxFitness then
                        pool.maxFitness = fitness
                        forms.settext(maxFitnessLabel, "Max Fitness: " .. math.floor(pool.maxFitness))
                        writeFile("backup." .. pool.generation .. "." .. forms.gettext(saveLoadFile))
                end
               
                console.writeline("Gen " .. pool.generation .. " species " .. pool.currentSpecies .. " genome " .. pool.currentGenome .. " fitness: " .. fitness)
                pool.currentSpecies = 1
                pool.currentGenome = 1
                while fitnessAlreadyMeasured() do
                        nextGenome()
                end
                initializeRun()
        end
 
        local measured = 0
        local total = 0
        for _,species in pairs(pool.species) do
                for _,genome in pairs(species.genomes) do
                        total = total + 1
                        if genome.fitness ~= 0 then
                                measured = measured + 1
                        end
                end
        end
        if not forms.ischecked(hideBanner) then
                gui.drawText(0, 0, "Gen " .. pool.generation .. " species " .. pool.currentSpecies .. " genome " .. pool.currentGenome .. " (" .. math.floor(measured/total*100) .. "%)", 0xFF000000, 11)
                gui.drawText(0, 12, "Fitness: " .. math.floor(rightmost - (pool.currentFrame) / 2 - (timeout + timeoutBonus)*2/3), 0xFF000000, 11)
                gui.drawText(100, 12, "Max Fitness: " .. math.floor(pool.maxFitness), 0xFF000000, 11)
        end
               
        pool.currentFrame = pool.currentFrame + 1
 
        emu.frameadvance();
end
