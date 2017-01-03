BoxRadius = 6

state = 0

bestScore = -1
bestRot = -1
bestX = -1
bestY = -1

Population = 300

genomeId = 0
speciesId = 0

isPlayTop = false
isPlayingTop = false
isSavePool = false
isLoadPool = false

lastClock = 0

console.writeline = (function(text) forms.settext(consoleLabel, text) end)

function drawBox(drawgrid, dx, dy)
	if dx < 0 or dx > 9 then
		return false
	elseif 10 * dy + dx > 209 or 10 * dy + dx < 0 then
		return true
	end
	if drawgrid then
		grid2[10 * dy + dx] = grid2[10 * dy + dx] + 1
	else
		--gui.drawBox(BoxRadius*dx,BoxRadius*dy,BoxRadius*(dx+1),BoxRadius*(dy+1),0xFF000000, 0x80808080)
		grid[10 * dy + dx] = grid[10 * dy + dx] + 1
	end
	return true
end

function getNextPiece(id)
	if id == 1 or id == 6 or id == 9 or id == 10 or id == 12 or id == 13 or id == 17 then
		return -1
	elseif id == 3 or id == 7 or id == 16 then
		return id-3
	elseif id == 18 then
		return 17
	else
		return id+1
	end
end

function drawPiece(id, x, y, correct, drawgrid)
	local valid = true
    if correct then
        if id == 3 or id == 4 or id == 10 or id == 15 or id == 18 then
            x = x - 1
        end
        if id == 0 or id == 5 or id == 16 or id == 17 then
            y = y - 1
        end
    end
    if id == 1 or id == 6 or id == 12 or id == 13 or id == 15 or id == 17 then
        valid = valid and drawBox(drawgrid, x+1, y)
    end
    if id == 3 or id == 4 or id == 6 or id == 9 or id == 15 then
        valid = valid and drawBox(drawgrid, x+2, y)
    end
    if id == 2 or id == 5 or id == 7 or id == 8 or id == 14 or id == 18 then
        valid = valid and drawBox(drawgrid, x, y+1)
    end
    if id ~= 4 and id ~= 5 and id ~= 15 and id ~= 16 then
        valid = valid and drawBox(drawgrid, x+1, y+1)
    end
    if id ~= 0 and id ~= 5 and id ~= 6 and id ~= 8 and id ~= 13 and id ~= 17 then
        valid = valid and drawBox(drawgrid, x+2, y+1)
    end
    if id == 18 then
        valid = valid and drawBox(drawgrid, x+3, y+1)
    end
    if id == 0 or id == 5 or id == 11 or id == 14 or id == 16 then
        valid = valid and drawBox(drawgrid, x, y+2)
    end
    if id ~= 3 and id ~= 7 and id ~= 12 and id ~= 14 and id ~= 15 and id ~= 18 then
        valid = valid and drawBox(drawgrid, x+1, y+2)
    end
    if id ~= 1 and id ~= 2 and id ~= 6 and id ~= 9 and id ~= 11 and id ~= 14 and id ~= 17 and id ~= 18 then
        valid = valid and drawBox(drawgrid, x+2, y+2)
    end 
    if id == 17 then
        valid = valid and drawBox(drawgrid, x+1, y+3)
    end
	return valid
end

function resetGrid()
	for i=0,199 do
		grid2[i] = grid[i]
	end
	for i=200,209 do
		grid2[i] = 1
	end
end

function normalize(genes)
	local sum = 0
	for k,v in pairs(genes) do
	   sum = sum + v
	end
	for k,v in pairs(genes) do
	   genes[k] = v / sum
	end
end

function addToSpecies(child)
	local foundSpecies = false
	for s=1,#pool.species do
		local species = pool.species[s]
		local sum = 0
		for k,v in pairs(child.genes) do
			sum = sum + math.abs(v - species.genomes[1].genes[k])
		end
		if sum < 0.4 then
			table.insert(species.genomes, child)
			foundSpecies = true
			console.writeline("Inserted genome " .. child.id .. " into species " .. species.id)
			break
		end
	end
	if not foundSpecies then --newSpecies
		local childSpecies = {}
		childSpecies.genomes = {}
		childSpecies.averageRank = 0
		childSpecies.topFitness = 0
		childSpecies.staleness = 0
		childSpecies.id = speciesId
		speciesId = speciesId + 1
		table.insert(childSpecies.genomes, child)
		table.insert(pool.species, childSpecies)
		console.writeline("Created species " .. childSpecies.id)
		console.writeline("Inserted genome " .. child.id .. " into species " .. childSpecies.id)
	end
end

function newGenome()
	local genome = {}
	genome.genes = {}
	genome.genes["hole"] = 0.356631
	genome.genes["height"] = 0.510066
	genome.genes["heightDiff"] = 0.184483
	genome.genes["line"] = 0.760666
	--normalize(genome.genes)
	genome.fitness = 0
	genome.stage = 0
	genome.globalRank = 0
	genome.id = genomeId
	genomeId = genomeId + 1
	console.writeline("Created genome " .. genome.id)
	
	return genome
end

function copyGenome(genome)
	local genome2 = newGenome()
	for k,v in pairs(genome.genes) do
		genome2.genes[k] = v
	end
	
	return genome2
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

function cullSpecies(cutToOne)
	for s = 1,#pool.species do
		local species = pool.species[s]
		
		console.writeline("Culling species " .. species.id)
		local remaining = (cutToOne and 1) or math.ceil(#species.genomes/2)
		while #species.genomes > remaining do
			local removed = table.remove(species.genomes)
			console.writeline("Removed genome " .. removed.id)
		end
	end
end

function removeStaleSpecies()
	local survived = {}

	for s = 1,#pool.species do
		local species = pool.species[s]
		
		if species.genomes[1].fitness > species.topFitness then
			species.topFitness = species.genomes[1].fitness
			species.staleness = 0
		else
			species.staleness = species.staleness + 1
		end
		if species.staleness < 15 or species.topFitness >= pool.maxFitness then
			table.insert(survived, species)
		else
			console.writeline("Removed stale species " .. species.id)
		end
	end

	pool.species = survived
end

function removeWeakSpecies()
	local survived = {}

	local sum = sumAverageRank()
	for s = 1,#pool.species do
		local species = pool.species[s]
		local breed = math.floor(species.averageRank / sum * Population)
		if breed >= 1 then
			table.insert(survived, species)
		else
			console.writeline("Removed weak species " .. species.id)
		end
	end

	pool.species = survived
end

function calculateAverageRank()
	for s = 1,#pool.species do
		local species = pool.species[s]
		local sum = 0
	
		for g=1,#species.genomes do
			local genome = species.genomes[g]
			sum = sum + genome.globalRank
		end
	
		species.averageRank = sum / #species.genomes
		console.writeline("Average rank of species " .. species.id .. ": " .. species.averageRank)
	end
end

function sumAverageRank()
	local sum = 0
	for s = 1,#pool.species do
		local species = pool.species[s]
		sum = sum + species.averageRank
	end

	return sum
end

function crossover(g1, g2)
	local child = newGenome()
	for k,v in pairs(child.genes) do
		local p = math.random()
		if p < 0.75 then
			child.genes[k] = g1.genes[k]*g1.fitness + g2.genes[k]*g2.fitness
		elseif p < 0.875 then
			child.genes[k] = g1.genes[k]
		else
			child.genes[k] = g2.genes[k]
		end
	end
	
	return child
end

function mutate(genome)
	for k,v in pairs(genome.genes) do
		if math.random() < 0.1 then
			console.writeline("Mutated " .. k)
			genome.genes[k] = v + (math.random() - 0.5)/2.5
		end
	end
end

function breedChild(species)
	local child = {}
	if #species.genomes ~= 1 and math.random() < 0.75 then
		repeat
			g1 = species.genomes[math.random(1, #species.genomes)]
			g2 = species.genomes[math.random(1, #species.genomes)]
		until g1.id ~= g2.id
		console.writeline("Sexually reproducting genome " .. g1.id .. " and " .. g2.id .. " in species " .. species.id)
		child = crossover(g1, g2)
	else
		g = species.genomes[math.random(1, #species.genomes)]
		console.writeline("Asexually reproducting genome " .. g.id .. " in species " .. species.id)
		child = copyGenome(g)
	end
	
	mutate(child)
	normalize(child.genes)
	
	return child
end

function sortSpecies()
	for s = 1,#pool.species do
		local species = pool.species[s]
		table.sort(species.genomes, function (a,b)
			return (a.fitness > b.fitness)
		end)
	end
end	

function newGeneration()
	sortSpecies()
	cullSpecies(false)
	removeStaleSpecies()
	rankGlobally()
	calculateAverageRank()
	removeWeakSpecies()
	local sum = sumAverageRank()
	local children = {}
	for s = 1,#pool.species do
		local species = pool.species[s]
		breed = math.floor(species.averageRank / sum * Population) - 1
		for i=1,breed do
			table.insert(children, breedChild(species))
		end
	end
	cullSpecies(true)
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

function nextGenome()
	isPlayingTop = false
	
	pool.currentGenome = pool.currentGenome + 1
	if pool.currentGenome > #pool.species[pool.currentSpecies].genomes then
		pool.currentGenome = 1
		pool.currentSpecies = pool.currentSpecies + 1
		if pool.currentSpecies > #pool.species then
			newGeneration()
			pool.currentSpecies = 1
		end
	end
	
	local species = pool.species[pool.currentSpecies]
	local genome = species.genomes[pool.currentGenome]
	if genome.stage < 3 then
		genome.fitness = 0
	elseif genome.fitness ~= 0 then
		console.writeline("Generation " .. pool.generation .. " species " .. species.id .. " genome " .. genome.id .. " fitness: " .. genome.fitness .. "!")
		nextGenome()
	end
end

function playTop()
	isPlayTop = true
end

function onExit()
	forms.destroy(form)
end

function writeFile(filename)
	local file = io.open(filename, "w")
	file:write(pool.generation .. "\n")
	file:write(pool.maxFitness .. "\n")
	file:write(#pool.species .. "\n")
	for n,species in pairs(pool.species) do
		file:write(species.id .. "\n")
		file:write(species.topFitness .. "\n")
		file:write(species.staleness .. "\n")
		file:write(#species.genomes .. "\n")
		for m,genome in pairs(species.genomes) do
			if genome.stage < 3 then
				genome.fitness = 0
			end
			file:write(genome.id .. "\n")
			file:write(genome.fitness .. "\n")
			file:write(genome.stage .. "\n")
			for k,v in pairs(genome.genes) do
				file:write(k .. "\n")
				file:write(v .. "\n")
			end
			file:write("done\n")
		end
	end
	file:close()
end

function loadFile(filename)
	local file = io.open(filename, "r")
	pool = {}
	pool.species = {}
	pool.currentGenome = 1
	pool.currentSpecies = 1
	
	pool.generation = file:read("*number")
	pool.maxFitness = file:read("*number")
	forms.settext(maxFitnessLabel, "Max Fitness: " .. pool.maxFitness)
	
	local numSpecies = file:read("*number")
	for s=1,numSpecies do
		local species = {}
		species.genomes = {}
		species.averageRank = 0
		species.id = file:read("*number")
		species.topFitness = file:read("*number")
		species.staleness = file:read("*number")
		table.insert(pool.species, species)
		
		local numGenomes = file:read("*number")
		for g=1,numGenomes do
			local genome = {}
			genome.genes = {}
			genome.globalRank = 0
			genome.id = file:read("*number")
			genome.fitness = file:read("*number")
			genome.stage = file:read("*number")
			local line = file:read("*line")
			while line ~= "done" do
				genome.genes[line] = file:read("*number")
				line = file:read("*line")
			end
			table.insert(species.genomes, genome)
		end
	end
	file:close()
	
	local species = pool.species[pool.currentSpecies]
	local genome = species.genomes[pool.currentGenome]
	if genome.fitness ~= 0 then
		console.writeline("Generation " .. pool.generation .. " species " .. species.id .. " genome " .. genome.id .. " fitness: " .. genome.fitness .. "!")
		nextGenome()
	end
	
	savestate.load("Tetris0.state")
end

function savePool()
	isSavePool = true
end
 
function loadPool()
	isLoadPool = true
end

pool = {}
pool.species = {}
pool.generation = 0
pool.currentGenome = 1
pool.currentSpecies = 1
pool.maxFitness = 0

event.onexit(onExit)
form = forms.newform(200, 260, "Evolving tetris")
maxFitnessLabel = forms.textbox(form, "Max Fitness: " .. pool.maxFitness, 170, 25, nil, 5, 8)
consoleLabel = forms.textbox(form, "console", 170, 60, nil, 5, 32, true)
saveButton = forms.button(form, "Save", savePool, 5, 102)
loadButton = forms.button(form, "Load", loadPool, 80, 102)
saveLoadFile = forms.textbox(form, "save.pool", 170, 25, nil, 5, 148)
saveLoadLabel = forms.label(form, "Save/Load:", 5, 129)
playTopButton = forms.button(form, "Play Top", playTop, 5, 170)

for i=1,Population do
	local genome = newGenome()
	addToSpecies(genome)
end

writeFile("backup." .. pool.generation .. "." .. forms.gettext(saveLoadFile))

while true do
	local species = pool.species[pool.currentSpecies]
	local genome = species.genomes[pool.currentGenome]
	
	grid = {}
	for i=0,199 do
		grid[i] = 0
	end
	
	grid2 = {}
	resetGrid()
	
	local gameOver = false
	
	--gui.drawBox(0, 0, 300, 26, 0xD0FFFFFF, 0xD0FFFFFF)
    --gui.drawBox(0, 0, 60, 300, 0xD0FFFFFF, 0xD0FFFFFF)
    for a=0,19 do
        for b=0,9 do
            local tile = memory.readbyte(0x400 + 10 * a + b)
            if tile < 239 then
                drawBox(false, b, a)
            end
        end
    end
    local currentPiece = memory.readbyte(0x42)
	
	memory.writebyte(0x64, 29)
	
	local status = memory.readbyte(0x48)
	local mode = memory.readbyte(0xC0)
	if status == 0 or mode == 5 or mode == 1 then
		savestate.load("Tetris0.state")
	elseif status == 10 or gameOver then
		state = 0
		if not isPlayingTop then
			local score = memory.readbyterange(0x73, 3)
			genome.fitness = genome.fitness
				+ math.floor(score[2]/16)*100000
				+ (score[2]%16)*10000
				+ math.floor(score[1]/16)*1000
				+ (score[1]%16)*100
				+ math.floor(score[0]/16)*10
				+ (score[0]%16)
		end
		if genome.stage < 2 then
			console.writeline("Generation " .. pool.generation .. " species " .. species.id .. " genome " .. genome.id .. " stage " .. genome.stage .. " fitness: " .. genome.fitness)
			genome.stage = genome.stage + 1
			savestate.load("Tetris" .. genome.stage .. ".state")
		else
			if genome.fitness > pool.maxFitness then
				pool.maxFitness = genome.fitness
				forms.settext(maxFitnessLabel, "Max Fitness: " .. pool.maxFitness)
				writeFile("backup." .. pool.generation .. "." .. forms.gettext(saveLoadFile))
			end
			console.writeline("Generation " .. pool.generation .. " species " .. species.id .. " genome " .. genome.id .. " fitness: " .. genome.fitness)
			nextGenome()
			savestate.load("Tetris0.state")
		end
	elseif status == 1 then
		--local controller = {}
		--[[if state > 1 then
			local x = memory.readbyte(0x40)
			if state % 2 == 1 then
				if bestRot > 0 then
					controller["P1 B"] = true
					bestRot = bestRot - 1
				end
				if bestX < x then
					controller["P1 Left"] = true
				elseif bestX > x then
					controller["P1 Right"] = true
				elseif bestRot == -1 then
					controller["P1 Down"] = true
				end
			elseif bestX == x and bestRot == -1 then
				controller["P1 Down"] = true
			end
		else]]--
		if state == 0 then
			bestScore = -1
			repeat
				for j=-1,8 do
					local k = 0
					local valid = true
					local valid2 = true
					while valid and k < 20 do
						resetGrid()
						if drawPiece(currentPiece, j, k, true, true) then
							for i=0,209 do
								if grid2[i] > 1 then
									valid = false
									break
								end
							end
							k = k + 1
						else
							valid2 = false
							break
						end
					end
					if valid2 then
						resetGrid()
						drawPiece(currentPiece, j, k - 2, true, true)
						local holeSum = 0
						local heightSum = 0
						local heightDiffSum = 0
						local heightLast = 0
						local clearLine = 0
						for b=0,9 do
							local height = 0
							local hole = 0
							local holeHeight = 0
							for a=19,0,-1 do
								if grid2[10 * a + b] == 1 then
									height = 20 - a
									holeHeight = holeHeight + hole
								else
									hole = hole + 1
								end
							end
							heightSum = heightSum + height + 0.3*holeHeight
							holeSum = holeSum + hole + height - 20
							if b ~= 0 then
								heightDiffSum = heightDiffSum + math.abs(height - heightLast)
							end
							heightLast = height
						end
						for a=0,19 do
							local lineclear = true
							for b=0,9 do
								if grid2[10 * a + b] == 0 then
									lineclear = false
									break
								end
							end
							if lineclear then
								clearLine = clearLine + 1
							end
						end
						local score = genome.genes["hole"]*holeSum
							+ genome.genes["height"]*heightSum
							+ genome.genes["heightDiff"]*heightDiffSum
							- genome.genes["line"]*clearLine
						if bestScore == -1 or score < bestScore then
							bestScore = score
							bestRot = currentPiece
							bestX = j + 1
							bestY = k - 1
						end
					end
				end
				currentPiece = getNextPiece(currentPiece)
			until currentPiece == -1
		elseif state == 1 then
			memory.writebyte(0x62, bestRot)
		elseif state == 2 then
			memory.writebyte(0x60, bestX)
			memory.writebyte(0x61, bestY)
		end
		state = state + 1
		--joypad.set(controller)
	--elseif status == 4 then
		--memory.writebyte(0x68, 5)
	elseif status == 8 then
		state = 0
	end
	
	--gui.drawText(0, 6, "Gen " .. pool.generation .. " species " .. species.id .. " genome " .. genome.id.. " stage " .. genome.stage, 0xFF000000, 11)
	--gui.drawText(0, 12, "Max fitness: " .. math.floor(pool.maxFitness), 0xFF000000, 11)
	
	if isPlayTop then
		isPlayTop = false
		isPlayingTop = true
		
		genome.fitness = 0
		genome.stage = 0
		
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
		--pool.species[maxs].genomes[maxg].stage = 0
		
		savestate.load("Tetris0.state")
	elseif isSavePool then
		isSavePool = false
		local filename = forms.gettext(saveLoadFile)
		writeFile(filename)
	elseif isLoadPool then
		isLoadPool = false
		local filename = forms.gettext(saveLoadFile)
		loadFile(filename)
	end
	
	emu.frameadvance()
end