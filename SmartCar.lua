require "Vector"
local Car = require("Car")

local SmartCar = {}

function SmartCar:new(world, sensors, inputCallback)
	local smartcar = Car:new(world)

	smartcar.world = world
	smartcar.sensors = sensors
	smartcar.sensor_hits = {}
	smartcar.inputCallback = inputCallback

	smartcar.fixture:setUserData(self)
	for _, wheel in ipairs(smartcar.wheels) do
		wheel.tire.fixture:setUserData(self)
	end

	setmetatable(smartcar, self)
	self.__index = self

	return smartcar
end

function SmartCar:draw()
	-- Draw the sensors
	for i, sensor in ipairs(self.sensors) do
		local v1 = Vector(self.body:getWorldPoint(sensor[1]:unpack()))
		local v2 = self.sensor_hits[i] or Vector(self.body:getWorldPoint(sensor[2]:unpack()))
		love.graphics.setColor(255, 255, 255, 90)
		love.graphics.line(v1.x * scale, v1.y * scale, v2.x * scale, v2.y * scale)
		if self.sensor_hits[i] then
			love.graphics.setPointSize(5)
			love.graphics.points(self.sensor_hits[i].x * scale, self.sensor_hits[i].y * scale)
		end
	end

	Car.draw(self)
end

function SmartCar:destroy()
	Car.destroy(self)
end

function SmartCar:update()
	-- Check the sensors
	local sensor_inputs = {}
	for i, sensor in ipairs(self.sensors) do
		local v1 = Vector(self.body:getWorldPoint(sensor[1]:unpack()))
		local v2 = Vector(self.body:getWorldPoint(sensor[2]:unpack()))
		local closest = 1.0
		self.sensor_hits[i] = nil
		self.world:rayCast(v1.x, v1.y, v2.x, v2.y, function(fixture, x, y, xn, yn, fraction)
			if fixture:getUserData() == self then return 1 end
			closest = fraction
			self.sensor_hits[i] = Vector(x, y)
			return fraction
		end)
		sensor_inputs[i] = closest
	end

	-- Pass the sensor data to the callback func to see what the car should do
	Car.update(self, self.inputCallback(sensor_inputs))
end

return SmartCar
