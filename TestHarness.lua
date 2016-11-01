local Car = require("Car")
local Track = require("Track")
local luann = require("luann")

local TestHarness = {}

function TestHarness:new(sensors, inputCallback)
	local harness = {}

	harness.world = love.physics.newWorld(0, 0, true)
	harness.track = Track:new(harness.world)
	harness.car = Car:new(harness.world)
	harness.sensors = sensors
	harness.isDone = false
	harness.inputCallback = inputCallback
	harness.totalTime = 0.0
	harness.positions = {}

	--local destroyFix = nil
	harness.world:setCallbacks(
	nil, nil,
	-- function (fixture1, fixture2, contact)
		-- if destroyFix and (fixture1 == destroyFix) or (fixture2 == destroyFix) then
			-- destroyFix:getUserData()()
			-- destroyFix = nil
			-- isDone = true
		-- end
	-- end,
	nil, 
	function (fixture1, fixture2, contact, normalimpulse, tangentimpulse)
		local impactForce = Vector(normalimpulse, tangentimpulse)
		if impactForce:len() > 4.0 then
			--if type(fixture1:getUserData()) == "function" then
			--	destroyFix = fixture1
			--elseif type(fixture2:getUserData()) == "function" then
			--	destroyFix = fixture2
			--end
			harness.isDone = true
		end
	end)

	setmetatable(harness, self)
	self.__index = self

	return harness
end

function TestHarness:destroy()
	self.inputCallback = nil
	self.positions = nil
	self.sensors = nil

	self.track:destroy()
	self.track = nil
	self.car:destroy()
	self.car = nil
	self.world:setCallbacks(nil, nil, nil, nil)
	self.world:destroy()
	self.world = nil
end

function TestHarness:draw()
	--self:isGoingBackwards()
	-- Move to the center of the screen
	local w, h = love.window.getMode()
	love.graphics.push()
	love.graphics.translate(w / 2, h / 2)

	-- Move to the car's location
	local x, y = self.car.body:getWorldCenter()
	love.graphics.translate(-x * scale, -y * scale) -- why negative?

	-- Draw stuff
	self.car:draw()
	self.track:draw()

	for _, sensor in ipairs(self.sensors) do
		local v1 = Vector(self.car.body:getWorldPoint(sensor[1]:unpack()))
		local v2 = sensor.hit or Vector(self.car.body:getWorldPoint(sensor[2]:unpack()))
		love.graphics.setColor(255, 255, 255, 90)
		love.graphics.line(v1.x * scale, v1.y * scale, v2.x * scale, v2.y * scale)
		if sensor.hit then
			love.graphics.setPointSize(5)
			love.graphics.points(sensor.hit.x * scale, sensor.hit.y * scale)
		end
	end

	for _, point in ipairs(self.positions) do
		love.graphics.points(point.x, point.y)
	end
	love.graphics.pop()
end

function TestHarness:savePosition()
	local x, y = self.car.body:getWorldCenter()
	self.positions[#self.positions + 1] = Vector(x * scale, y * scale)
end

function TestHarness:computeFitness()
	local totalDist = 0.0
	for i = 2, #self.positions do
		totalDist = totalDist + self.positions[i - 1]:distance(self.positions[i])
	end
	return totalDist
end

function TestHarness:isStalled()
	-- Check if the car hasn't traveld far enough in the past few seconds
	if #self.positions > 4 then
		local a = self.positions[#self.positions - 2]
		local b = self.positions[#self.positions - 1]
		local c = self.positions[#self.positions]
		local totalDist = a:distance(b) + b:distance(c)
		return totalDist < 10.0
	end

	return false
end

function TestHarness:isGoingBackwards()
	if #self.positions > 4 then
		print(Vector(self.car.body:getWorldCenter()))
		print(self.positions[#self.positions - 4])
		-- local a = self.positions[#self.positions - 4] - (Vector(self.car.body:getWorldCenter()) * scale)
		-- local vel = Vector(self.car.body:getLinearVelocity())
		-- local ang = self.car.body:getAngle()
		-- print(math.abs(math.deg(a:angle())))
		-- print(math.deg(ang))
	end

	return false
end

function TestHarness:update(tick)
	-- Twice a second save the cars position
	if tick % 30 == 1 then
		self:savePosition()
	end

	-- Fixed physics timestep of 1/60 of a second
	self.world:update(1/60)

	-- A few things can make the test stop:
	-- * It hits a wall (collision)
	-- * It hasn't moved X meters within Y amount of time
	-- * Z amount of time has passed
	-- * It is going "backwards"?

	-- See if it is finished
	if self.isDone or tick == 60 * 40 or self:isStalled() then
		self:savePosition() -- save the last position
		return true
	end

	-- Check the sensors
	local sensor_inputs = {}
	for i, sensor in ipairs(self.sensors) do
		local v1 = Vector(self.car.body:getWorldPoint(sensor[1]:unpack()))
		local v2 = Vector(self.car.body:getWorldPoint(sensor[2]:unpack()))
		local closest = 1.0
		sensor.hit = nil
		self.world:rayCast(v1.x, v1.y, v2.x, v2.y, function(fixture, x, y, xn, yn, fraction)
			if fixture:getUserData() ~= true then return 1 end
			closest = fraction
			sensor.hit = Vector(x, y)
			return fraction
		end)
		sensor_inputs[i] = closest
	end

	-- Pass the sensor data to the callback func to see what the car should do
	self.car:update(self.inputCallback(sensor_inputs))

	return false
end

return TestHarness