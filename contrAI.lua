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

Inputs = (InputRadius * 2 + 1) * (InputRadius * 2 + 1)
Outputs = #ButtonNames

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
        HorizontalScroll = memory.readbyte(0xFD)
        VerticalScroll = memory.readbyte(0xFC)
        PlayerOnscreenX = memory.readbyte(0x0334)
        PlayerOnscreenY = memory.readbyte(0x031A)
end

function measureFitness()
        LevelScreenNumber = memory.readbyte(0x64)
        LevelScreenScrollOffset = memory.readbyte(0x65)
        Fitness = (LevelScreenNumber << 8) + LevelScreenScrollOffset
end

function getSprites()
        local sprites = {}

        for i = 0, 0xF do
                local enemyX = memory.readbyte(0x0324 + i)
                local enemyY = memory.readbyte(0x033E + i)
                sprites[#sprites + 1] = { ["x"] = enemyX, ["y"] = enemyY }
        end

        return sprites
end

-- Reads BG_COLLISION_DATA from memory and returns the tile type (0 = empty, 1 = floor).
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
        local floorColor = 0x508FBC8F
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
                return 1
        else
                return 0
        end
end

function isWithinRange(x, y)
        return x > PlayerOnscreenX - (InputRadius * 16) and x < PlayerOnscreenX + (InputRadius * 16)
            and y > PlayerOnscreenY - (InputRadius * 16) and y < PlayerOnscreenY + (InputRadius * 16)
end

function getInputs()
        getPlayerPos()
        Sprites = getSprites()

        local inputs = {}

        for y = 0, 300, 16 do
                for x = 0, 300, 16 do
                        inputs[#inputs + 1] = 0

                        local tile = getTileCollisionCode(x - math.fmod(HorizontalScroll, 16),
                                y - math.fmod(VerticalScroll, 16))
                        if tile == 1 and isWithinRange(x, y) then
                                inputs[#inputs] = 1
                        end

                        for i = 1, #Sprites do
                                if isWithinRange(Sprites[i]["x"], Sprites[i]["y"]) then
                                        if math.abs(y - Sprites[i]["y"]) <= 8 and math.abs(x - Sprites[i]["x"]) <= 8 then
                                                inputs[#inputs] = -1
                                        end
                                end
                        end
                end
        end
end

function sigmoid(x)
        return 2 / (1 + math.exp(-4.9 * x)) - 1
end

function newInnovation()
        pool.innovation = pool.innovation + 1
        return pool.innovation
end

while true do
        measureFitness()
        Inputs = getInputs()

        emu.frameadvance()
end

function newPool()
        local pool = {}
        pool.species = {}
        pool.generation = 0
        pool.innovation = Outputs
        pool.currentSpecies = 1
        pool.currentGenome = 1
        pool.currentFrame = 0
        pool.maxFitness = 0

        return pool
end

function newSpecies()
        local species = {}
        species.topFitness = 0
        species.staleness = 0
        species.genomes = {}
        species.averageFitness = 0

        return species
end

function newGenome()
        local genome = {}
        genome.genes = {}
        genome.fitness = 0
        genome.adjustedFitness = 0
        genome.network = {}
        genome.maxneuron = 0
        genome.globalRank = 0
        genome.mutationRates = {}
        genome.mutationRates["connections"] = MutateConnectionsChance
        genome.mutationRates["link"] = LinkMutationChance
        genome.mutationRates["bias"] = BiasMutationChance
        genome.mutationRates["node"] = NodeMutationChance
        genome.mutationRates["enable"] = EnableMutationChance
        genome.mutationRates["disable"] = DisableMutationChance
        genome.mutationRates["step"] = StepSize

        return genome
end

function copyGenome(genome)
        local genome2 = newGenome()
        for g = 1, #genome.genes do
                table.insert(genome2.genes, copyGene(genome.genes[g]))
        end
        genome2.maxneuron = genome.maxneuron
        genome2.mutationRates["connections"] = genome.mutationRates["connections"]
        genome2.mutationRates["link"] = genome.mutationRates["link"]
        genome2.mutationRates["bias"] = genome.mutationRates["bias"]
        genome2.mutationRates["node"] = genome.mutationRates["node"]
        genome2.mutationRates["enable"] = genome.mutationRates["enable"]
        genome2.mutationRates["disable"] = genome.mutationRates["disable"]

        return genome2
end

function basicGenome()
        local genome = newGenome()
        local innovation = 1

        genome.maxneuron = Inputs
        mutate(genome)

        return genome
end

function newGene()
        local gene = {}
        gene.into = 0
        gene.out = 0
        gene.weight = 0.0
        gene.enabled = true
        gene.innovation = 0

        return gene
end

function copyGene(gene)
        local gene2 = newGene()
        gene2.into = gene.into
        gene2.out = gene.out
        gene2.weight = gene.weight
        gene2.enabled = gene.enabled
        gene2.innovation = gene.innovation

        return gene2
end

function newNeuron()
        local neuron = {}
        neuron.incoming = {}
        neuron.value = 0.0

        return neuron
end

function generateNetwork(genome)
        local network = {}
        network.neurons = {}

        for i = 1, Inputs do
                network.neurons[i] = newNeuron()
        end

        for o = 1, Outputs do
                network.neurons[MaxNodes + o] = newNeuron()
        end

        table.sort(genome.genes, function(a, b)
                return (a.out < b.out)
        end)

        for i = 1, #genome.genes do
                local gene = genome.genes[i]

                if gene.enabled then
                        if network.neurons[gene.out] == nil then
                                network.neurons[gene.out] = newNeuron()
                        end

                        local neuron = network.neurons[gene.out]

                        table.insert(neuron.incoming, gene)
                        if network.neurons[gene.into] == nil then
                                network.neurons[gene.into] = newNeuron()
                        end
                end
        end

        genome.network = network
end

function evaluateNetwork(network, inputs)
        table.insert(inputs, 1)
        if #inputs ~= Inputs then
                console.writeline("Incorrect number of neural network inputs.")
                return {}
        end

        for i = 1, Inputs do
                network.neurons[i].value = inputs[i]
        end

        for _, neuron in pairs(network.neurons) do
                local sum = 0
                for j = 1, #neuron.incoming do
                        local incoming = neuron.incoming[j]
                        local other = network.neurons[incoming.into]
                        sum = sum + incoming.weight * other.value
                end

                if #neuron.incoming > 0 then
                        neuron.value = sigmoid(sum)
                end
        end

        local outputs = {}
        for o = 1, Outputs do
                local button = "P1 " .. ButtonNames[o]
                if network.neurons[MaxNodes + o].value > 0 then
                        outputs[button] = true
                else
                        outputs[button] = false
                end
        end

        return outputs
end

function crossover(g1, g2)
        -- Make sure g1 is the higher fitness genome
        if g2.fitness > g1.fitness then
                tempg = g1
                g1 = g2
                g2 = tempg
        end

        local child = newGenome()

        local innovations2 = {}
        for i = 1, #g2.genes do
                local gene = g2.genes[i]
                innovations2[gene.innovation] = gene
        end

        for i = 1, #g1.genes do
                local gene1 = g1.genes[i]
                local gene2 = innovations2[gene1.innovation]
                if gene2 ~= nil and math.random(2) == 1 and gene2.enabled then
                        table.insert(child.genes, copyGene(gene2))
                else
                        table.insert(child.genes, copyGene(gene1))
                end
        end

        child.maxneuron = math.max(g1.maxneuron, g2.maxneuron)

        for mutation, rate in pairs(g1.mutationRates) do
                child.mutationRates[mutation] = rate
        end

        return child
end

function randomNeuron(genes, nonInput)
        local neurons = {}
        if not nonInput then
                for i = 1, Inputs do
                        neurons[i] = true
                end
        end
        for o = 1, Outputs do
                neurons[MaxNodes + o] = true
        end
        for i = 1, #genes do
                if (not nonInput) or genes[i].into > Inputs then
                        neurons[genes[i].into] = true
                end
                if (not nonInput) or genes[i].out > Inputs then
                        neurons[genes[i].out] = true
                end
        end

        local count = 0
        for _, _ in pairs(neurons) do
                count = count + 1
        end
        local n = math.random(1, count)

        for k, v in pairs(neurons) do
                n = n - 1
                if n == 0 then
                        return k
                end
        end

        return 0
end

function containsLink(genes, link)
        for i = 1, #genes do
                local gene = genes[i]
                if gene.into == link.into and gene.out == link.out then
                        return true
                end
        end
end

function pointMutate(genome)
        local step = genome.mutationRates["step"]

        for i = 1, #genome.genes do
                local gene = genome.genes[i]
                if math.random() < PerturbChance then
                        gene.weight = gene.weight + math.random() * step * 2 - step
                else
                        gene.weight = math.random() * 4 - 2
                end
        end
end

function linkMutate(genome, forceBias)
        local neuron1 = randomNeuron(genome.genes, false)
        local neuron2 = randomNeuron(genome.genes, true)

        local newLink = newGene()

        if neuron1 <= Inputs and neuron2 <= Inputs then
                --Both input nodes
                return
        end

        if neuron2 <= Inputs then
                -- Swap output and input
                local temp = neuron1
                neuron1 = neuron2
                neuron2 = temp
        end

        newLink.into = neuron1
        newLink.out = neuron2

        if forceBias then
                newLink.into = Inputs
        end

        if containsLink(genome.genes, newLink) then
                return
        end

        newLink.innovation = newInnovation()
        newLink.weight = math.random() * 4 - 2

        table.insert(genome.genes, newLink)
end

function nodeMutate(genome)
        if #genome.genes == 0 then
                return
        end
 
        genome.maxneuron = genome.maxneuron + 1
 
        local gene = genome.genes[math.random(1,#genome.genes)]
        if not gene.enabled then
                return
        end

        gene.enabled = false
       
        local gene1 = copyGene(gene)
        gene1.out = genome.maxneuron
        gene1.weight = 1.0
        gene1.innovation = newInnovation()
        gene1.enabled = true
        table.insert(genome.genes, gene1)
       
        local gene2 = copyGene(gene)
        gene2.into = genome.maxneuron
        gene2.innovation = newInnovation()
        gene2.enabled = true
        table.insert(genome.genes, gene2)
end

function enableDisableMutate(genome, enable)
        local candidates = {}
        for _,gene in pairs(genome.genes) do
                if gene.enabled == not enable then
                        table.insert(candidates, gene)
                end
        end
       
        if #candidates == 0 then
                return
        end
       
        local gene = candidates[math.random(1,#candidates)]
        gene.enabled = not gene.enabled
end

function mutate(genome)
        for mutation,rate in pairs(genome.mutationRates) do
                if math.random(1,2) == 1 then
                        genome.mutationRates[mutation] = 0.95*rate
                else
                        genome.mutationRates[mutation] = 1.05263*rate
                end
        end
 
        if math.random() < genome.mutationRates["connections"] then
                pointMutate(genome)
        end
       
        local p = genome.mutationRates["link"]
        while p > 0 do
                if math.random() < p then
                        linkMutate(genome, false)
                end
                p = p - 1
        end
 
        p = genome.mutationRates["bias"]
        while p > 0 do
                if math.random() < p then
                        linkMutate(genome, true)
                end
                p = p - 1
        end
       
        p = genome.mutationRates["node"]
        while p > 0 do
                if math.random() < p then
                        nodeMutate(genome)
                end
                p = p - 1
        end
       
        p = genome.mutationRates["enable"]
        while p > 0 do
                if math.random() < p then
                        enableDisableMutate(genome, true)
                end
                p = p - 1
        end
 
        p = genome.mutationRates["disable"]
        while p > 0 do
                if math.random() < p then
                        enableDisableMutate(genome, false)
                end
                p = p - 1
        end
end

function disjoint(genes1, genes2)
        local i1 = {}
        for i = 1,#genes1 do
                local gene = genes1[i]
                i1[gene.innovation] = true
        end
 
        local i2 = {}
        for i = 1,#genes2 do
                local gene = genes2[i]
                i2[gene.innovation] = true
        end
       
        local disjointGenes = 0
        for i = 1,#genes1 do
                local gene = genes1[i]
                if not i2[gene.innovation] then
                        disjointGenes = disjointGenes+1
                end
        end
       
        for i = 1,#genes2 do
                local gene = genes2[i]
                if not i1[gene.innovation] then
                        disjointGenes = disjointGenes+1
                end
        end
       
        local n = math.max(#genes1, #genes2)
       
        return disjointGenes / n
end

function weights(genes1, genes2)
        local i2 = {}
        for i = 1,#genes2 do
                local gene = genes2[i]
                i2[gene.innovation] = gene
        end
 
        local sum = 0
        local coincident = 0
        for i = 1,#genes1 do
                local gene = genes1[i]
                if i2[gene.innovation] ~= nil then
                        local gene2 = i2[gene.innovation]
                        sum = sum + math.abs(gene.weight - gene2.weight)
                        coincident = coincident + 1
                end
        end
       
        return sum / coincident
end

function sameSpecies(genome1, genome2)
        local dd = DeltaDisjoint*disjoint(genome1.genes, genome2.genes)
        local dw = DeltaWeights*weights(genome1.genes, genome2.genes)
        return dd + dw < DeltaThreshold
end
 
function rankGlobally()
        local global = {}
        for s = 1,#pool.species do
                local species = pool.species[s]
                for g = 1,#species.genomes do
                        table.insert(global, species.genomes[g])
                end
        end
        table.sort(global, function (a,b)
                return (a.fitness < b.fitness)
        end)
       
        for g=1,#global do
                global[g].globalRank = g
        end
end
 
function calculateAverageFitness(species)
        local total = 0
       
        for g=1,#species.genomes do
                local genome = species.genomes[g]
                total = total + genome.globalRank
        end
       
        species.averageFitness = total / #species.genomes
end

function totalAverageFitness()
        local total = 0
        for s = 1,#pool.species do
                local species = pool.species[s]
                total = total + species.averageFitness
        end
 
        return total
end
 
function cullSpecies(cutToOne)
        for s = 1,#pool.species do
                local species = pool.species[s]
               
                table.sort(species.genomes, function (a,b)
                        return (a.fitness > b.fitness)
                end)
               
                local remaining = math.ceil(#species.genomes/2)
                if cutToOne then
                        remaining = 1
                end
                while #species.genomes > remaining do
                        table.remove(species.genomes)
                end
        end
end

function breedChild(species)
        local child = {}
        if math.random() < CrossoverChance then
                g1 = species.genomes[math.random(1, #species.genomes)]
                g2 = species.genomes[math.random(1, #species.genomes)]
                child = crossover(g1, g2)
        else
                g = species.genomes[math.random(1, #species.genomes)]
                child = copyGenome(g)
        end
       
        mutate(child)
       
        return child
end
 
function removeStaleSpecies()
        local survived = {}
 
        for s = 1,#pool.species do
                local species = pool.species[s]
               
                table.sort(species.genomes, function (a,b)
                        return (a.fitness > b.fitness)
                end)
               
                if species.genomes[1].fitness > species.topFitness then
                        species.topFitness = species.genomes[1].fitness
                        species.staleness = 0
                else
                        species.staleness = species.staleness + 1
                end
                if species.staleness < StaleSpecies or species.topFitness >= pool.maxFitness then
                        table.insert(survived, species)
                end
        end
 
        pool.species = survived
end

function removeWeakSpecies()
        local survived = {}
 
        local sum = totalAverageFitness()
        for s = 1,#pool.species do
                local species = pool.species[s]
                breed = math.floor(species.averageFitness / sum * Population)
                if breed >= 1 then
                        table.insert(survived, species)
                end
        end
 
        pool.species = survived
end
 
 
function addToSpecies(child)
        local foundSpecies = false
        for s=1,#pool.species do
                local species = pool.species[s]
                if not foundSpecies and sameSpecies(child, species.genomes[1]) then
                        table.insert(species.genomes, child)
                        foundSpecies = true
                end
        end
       
        if not foundSpecies then
                local childSpecies = newSpecies()
                table.insert(childSpecies.genomes, child)
                table.insert(pool.species, childSpecies)
        end
end
 
function newGeneration()
        cullSpecies(false) -- Cull the bottom half of each species
        rankGlobally()
        removeStaleSpecies()
        rankGlobally()
        for s = 1,#pool.species do
                local species = pool.species[s]
                calculateAverageFitness(species)
        end
        removeWeakSpecies()
        local sum = totalAverageFitness()
        local children = {}
        for s = 1,#pool.species do
                local species = pool.species[s]
                breed = math.floor(species.averageFitness / sum * Population) - 1
                for i=1,breed do
                        table.insert(children, breedChild(species))
                end
        end
        cullSpecies(true) -- Cull all but the top member of each species
        while #children + #pool.species < Population do
                local species = pool.species[math.random(1, #pool.species)]
                table.insert(children, breedChild(species))
        end
        for c=1,#children do
                local child = children[c]
                addToSpecies(child)
        end
       
        pool.generation = pool.generation + 1
       
        writeFile("backup." .. pool.generation .. "." .. forms.gettext(saveLoadFile))
end
       
function initializePool()
        pool = newPool()
 
        for i=1,Population do
                basic = basicGenome()
                addToSpecies(basic)
        end
 
        initializeRun()
end
 
function clearJoypad()
        controller = {}
        for b = 1,#ButtonNames do
                controller["P1 " .. ButtonNames[b]] = false
        end
        joypad.set(controller)
end