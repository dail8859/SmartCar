local Car = require("Car")
local Track = require("Track")
local luann = require("luann")
local TestHarness = require("TestHarness")
local debugGraph = require("debugGraph")

scale = 3
local smartcar = nil
local path = {}
local th

local dtGraph
local avGraph

function luann:draw()
	local x, y = 0, 0
	local dx, dy = 70, 30
	local max_cells = #self

	for layer_num = 1, #self do
		max_cells = math.max(max_cells, #self[layer_num].cells)
	end

	love.graphics.setColor(120, 120, 120)
	for layer_num = 1, #self do
		y = (max_cells - #self[layer_num].cells) / 2 * dy
		for cell_num = 1, #self[layer_num].cells do
			if layer_num > 1 then
				for weight_num = 1, #self[layer_num].cells[cell_num].weights do
					local prev_y = (max_cells - #self[layer_num - 1].cells) / 2 * dy + ((weight_num - 1) * dy)
					love.graphics.line(x - dx, prev_y, x, y)
				end
			end
			y = y + dy
		end
		y = 0
		x = x + dx
	end
	x, y = 0, 0
	for layer_num = 1, #self do
		y = (max_cells - #self[layer_num].cells) / 2 * dy
		for cell_num = 1, #self[layer_num].cells do
			local s = self[layer_num].cells[cell_num].signal * 255
			love.graphics.setColor(s, s, s)
			love.graphics.circle("fill", x, y, 5, 10)
			love.graphics.setColor(255, 120, 0)
			love.graphics.circle("line", x, y, 5, 10)
			y = y + dy
		end
		y = 0
		x = x + dx
	end
end

local sensors = {
	{ Vector( 4, 8), Vector( 45,  10) * 3.0 },
	{ Vector( 3, 8), Vector( 45,  50) * 3.0 },
	{ Vector( 2, 8), Vector( 30, 100) * 3.0 },
	{ Vector( 1, 8), Vector( 12, 125) * 3.0 },
	-- { Vector( 0, 8), Vector(  0, 200) * 3.0},
	{ Vector(-1, 8), Vector(-12, 125) * 3.0 },
	{ Vector(-2, 8), Vector(-30, 100) * 3.0 },
	{ Vector(-3, 8), Vector(-45,  50) * 3.0 },
	{ Vector(-4, 8), Vector(-45,  10) * 3.0 },
}

function map_range(a1, a2, b1, b2, s )
	return b1 + (s-a1)*(b2-b1)/(a2-a1)
end

function love.load()
	math.randomseed(os.time())

	love.physics.setMeter(1)
	th = TestHarness:new(sensors, getNewUserInputBrain())
	--love.graphics.setLineStyle("rough")

	dtGraph = debugGraph:new('custom', 600, 0, 200, 200)
	dtGraph.label = "Best"
	avGraph = debugGraph:new('custom', 600, 0, 200, 200)
	avGraph.label = "             Average"
end

function math.clamp(low, n, high) return math.min(math.max(n, low), high) end

function love.draw()
	avGraph._max = dtGraph._max
	love.graphics.setColor(255, 0, 0)
	avGraph:draw()
	love.graphics.setColor(0, 255, 0)
	dtGraph:draw()

	local _, brain = debug.getupvalue(th.inputCallback, 1)

	th:draw()
	if not brain then return end

	love.graphics.push()
	love.graphics.translate(30, 30)
	brain:draw()
	love.graphics.pop()

	-- Steering wheel
	love.graphics.push()
	love.graphics.translate(150, 40)
	love.graphics.setColor(0, 0, 255)
	love.graphics.setLineWidth(3)
	love.graphics.circle("line", 0, 0, 30, 20)
	love.graphics.rotate((brain[#brain].cells[2].signal * 2 - 1.0) * math.rad(65))
	love.graphics.line(-30, 0, 30, 0)
	love.graphics.rotate(math.rad(90))
	love.graphics.line(0, 0, 30, 0)
	love.graphics.pop()
	love.graphics.setLineWidth(1)

	-- Pedals
	love.graphics.push()
	love.graphics.translate(190, 20)
	if brain[#brain].cells[1].signal < 0.5 then
		local w = map_range(0.5, 0.0, 0, 30, brain[#brain].cells[1].signal)
		love.graphics.setColor(180, 0, 0)
		love.graphics.rectangle("fill", 30 - w, 0, w, 20)
	else
		local w = map_range(0.5, 1.0, 0, 30, brain[#brain].cells[1].signal)
		love.graphics.setColor(0, 180, 0)
		love.graphics.rectangle("fill", 30, 0, w, 20)
	end
	love.graphics.setColor(255, 255, 255)
	love.graphics.rectangle("line", 0, 0, 60, 20)
	love.graphics.pop()

	--if #path > 3 then
	--	love.graphics.setColor(130, 130, 130)
	--	love.graphics.line(path)
	--end
end

function getNewUserInputBrain()
	return function(sensor_input)
		local up = love.keyboard.isDown("up") and 1.0 or 0.0
		local down = love.keyboard.isDown("down") and 1.0 or 0.0
		local left = love.keyboard.isDown("left") and 1.0 or 0.0
		local right = love.keyboard.isDown("right") and 1.0 or 0.0
		return up, down, left, right
	end
end

function getNewANNBrain()
	local network = luann:new({#sensors, 16, 2}, 5, 1)
	network:bp({1.0, 1.0, 1.0, 1.0, 1.0, 1.0}, {0.6, 0.5})
	network:bp({1.0, 1.0, 1.0, 1.0, 1.0, 1.0}, {0.6, 0.5})
	network:bp({1.0, 1.0, 1.0, 1.0, 1.0, 1.0}, {0.6, 0.5})
	network:bp({1.0, 1.0, 1.0, 1.0, 1.0, 1.0}, {0.6, 0.5})
	network:bp({1.0, 1.0, 1.0, 1.0, 1.0, 1.0}, {0.6, 0.5})
	return function(sensor_input)
		network:activate(sensor_input)

		local up, left, right, down
		local output_layer = #network
		up = network[output_layer].cells[1].signal > 0.5
		if network[output_layer].cells[1].signal < 0.5 then
			down = map_range(0.5, 0.0, 0.0, 1.0, network[output_layer].cells[1].signal)
			up = 0.0
		else
			down = 0.0
			up = map_range(0.5, 1.0, 0.0, 1.0, network[output_layer].cells[1].signal)
		end

		if network[output_layer].cells[2].signal < 0.5 then
			left = map_range(0.5, 0.0, 0.0, 1.0, network[output_layer].cells[2].signal)
			right = 0.0
		else
			left = 0.0
			right = map_range(0.5, 1.0, 0.0, 1.0, network[output_layer].cells[2].signal)
		end
		return up, down, left, right
	end
end
tick = 0
function love.update(dt)
	tick = tick + 1
	if th:update(tick) == true then
		print(th:computeFitness())
		testPopulation()
		tick = 0
	end
end

function love.quit()
	for i = 1, #path, 2 do
		print(path[i] / scale, path[i + 1] / scale)
	end
end

function cross_breed(braina, brainb)
	local child = luann:new({#sensors, 16, 2}, 5, 1)

	for layer_num = 1, #child do
		for cell_num = 1, #child[layer_num].cells do
			for weight_num = 1, #child[layer_num].cells[cell_num].weights do
				local new_weight = 0.0
				if math.random(0, 1) == 1 then
					new_weight = braina[layer_num].cells[cell_num].weights[weight_num]
				else
					new_weight = brainb[layer_num].cells[cell_num].weights[weight_num]
				end
    
				if math.random() < 0.05 then
					new_weight = new_weight + math.random() * 4 - 2 -- mutate
				end
				child[layer_num].cells[cell_num].weights[weight_num] = new_weight
			end
		end
	end
	return child
end

-- Start with 2 random parents
local _, parent_a = debug.getupvalue(getNewANNBrain(), 1)
local _, parent_b = debug.getupvalue(getNewANNBrain(), 1)

function testPopulation()
	local brains = {}
	for i = 1, 50 do
		local t = 0
		local b = getNewANNBrain()
		if math.random() > 0.02 then -- 98% chance we will breed the 2, else get a random new one
			if math.random(0, 1) == 1 then
				debug.setupvalue(b, 1, cross_breed(parent_a, parent_b))
			else
				debug.setupvalue(b, 1, cross_breed(parent_b, parent_a))
			end
		end
		local h = TestHarness:new(sensors, b)
		while h:update(t) == false do
			t = t + 1
		end
		-- Do brain surgery and save the brain and fitness
		brains[#brains + 1] = { func = h.inputCallback, fitness = h:computeFitness() }
		--if h:computeFitness() > 2300.0 then break end
		h:destroy()
		h = nil
	end
	table.sort(brains, function(a, b) return not (a.fitness < b.fitness) end)
	-- Get the best one
	th = TestHarness:new(sensors, brains[1].func)
	_, parent_a = debug.getupvalue(brains[1].func, 1)
	_, parent_b = debug.getupvalue(brains[2].func, 1)
	print(brains[1].fitness)
	print(brains[2].fitness)
	dtGraph:update(1.0, brains[1].fitness)

	local average = 0
	for _, brain in ipairs(brains) do
		average = average + brain.fitness
	end
	average = average / #brains
	avGraph:update(1.0, average)
end

function love.keypressed(key)
	if key == 'space' then
		--local x, y = smartcar.car.body:getWorldCenter()
		--path[#path + 1] = x * scale
		--path[#path + 1] = y * scale
	elseif key == 'a' then
		testPopulation()
		tick = 0
	end
end
