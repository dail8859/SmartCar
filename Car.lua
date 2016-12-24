-- http://www.iforce2d.net/b2dtut/top-down-car

require "Vector"
Tire = require "Tire"

function math.clamp(low, n, high) return math.min(math.max(n, low), high) end

local Car = {}

function Car:new(world)
	local car = {}

	car.body = love.physics.newBody(world, 0, 0, "dynamic")
	car.shape = love.physics.newPolygonShape(
		 1.5,   0,
		   3, 2.5,
		 2.8, 5.5,
		   1,  10,
		  -1,  10,
		-2.8, 5.5,
		  -3, 2.5,
		-1.5,   0
	)
	car.fixture = love.physics.newFixture(car.body, car.shape, 0.1)
	car.fixture:setFriction(1.0)
	--car.fixture:setUserData(function() car.isBroken = true end)

	local maxForwardSpeed = 300
	local maxBackwardSpeed = -100

	local backTireMaxDriveForce = 950
	local frontTireMaxDriveForce = 400

	-- Controls how much they "slide", high values allow better correction, thus less slippage
	local backTireMaxLateralImpulse = 9
	local frontTireMaxLateralImpulse = 9

	car.wheels = {}
	local tires = { Tire:new(world, -3.0,  8.5), Tire:new(world, 3.0,  8.5), Tire:new(world, -3.0, 0.75), Tire:new(world, 3.0, 0.75) }
	tires[1]:setCharacteristics(maxForwardSpeed, maxBackwardSpeed, frontTireMaxDriveForce, frontTireMaxLateralImpulse)
	tires[2]:setCharacteristics(maxForwardSpeed, maxBackwardSpeed, frontTireMaxDriveForce, frontTireMaxLateralImpulse)
	tires[3]:setCharacteristics(maxForwardSpeed, maxBackwardSpeed, backTireMaxDriveForce, backTireMaxLateralImpulse)
	tires[4]:setCharacteristics(maxForwardSpeed, maxBackwardSpeed, backTireMaxDriveForce, backTireMaxLateralImpulse)

	for i, tire in ipairs(tires) do
		local joint = love.physics.newRevoluteJoint(car.body, tire.body, tire.body:getX(), tire.body:getY(), false)
		joint:setLimitsEnabled(true)
		joint:setLimits(0.0, 0.0)
		car.wheels[i] = {}
		car.wheels[i].origPos = Vector(tire.body:getX(), tire.body:getY())
		car.wheels[i].tire = tire
		car.wheels[i].joint = joint
		--tire.fixture:setUserData(function() car:removeTire(joint) end)
	end

	car.wheels[1].isSteerable = true
	car.wheels[2].isSteerable = true
	-- car.wheels[3].isSteerable = true
	-- car.wheels[4].isSteerable = true
	-- car.wheels[3].flipSteering = true
	-- car.wheels[4].flipSteering = true

	setmetatable(car, self)
	self.__index = self

	return car
end

function Car:destroy()
	for _, wheel in ipairs(self.wheels) do
		wheel.joint:destroy()
	end

	self.fixture:setUserData(nil)
	self.fixture:destroy()
	self.fixture = nil
	self.body:destroy()
	self.body = nil
	for _, wheel in ipairs(self.wheels) do
		wheel.tire:destroy()
	end
	self.wheels = nil
end

function Car:draw()
	for _, wheel in ipairs(self.wheels) do
		wheel.tire:draw()
	end

	local points = {self.shape:getPoints()}
	for i = 1, #points, 2 do
		local x, y = self.body:getWorldPoint(points[i], points[i + 1])
		points[i] = x  * scale
		points[i + 1] = y * scale
	end
	love.graphics.polygon("line", points)
	love.graphics.setColor(216, 191, 216, 100)
	love.graphics.polygon("fill", points)
	love.graphics.setColor(216, 191, 216, 255)
	love.graphics.polygon("line", points)
end

function Car:update(up, down, left, right)
	-- Update all tires
	for _, wheel in ipairs(self.wheels) do
		wheel.tire:updateFriction()
	end

	if self.isBroken then 
		up = 0.0
		down = 0.0
	end

	for _, wheel in ipairs(self.wheels) do
		wheel.tire:updateDrive(up, down)
	end

	if self.isBroken then return end

	-- control steering
	local lockAngle = math.rad(35)
	local turnSpeedPerSec = math.rad(320) -- from lock to lock in 0.25 sec
	local turnPerTimeStep = turnSpeedPerSec / 60.0
	local desiredAngle = 0

	-- left and right can be between 0.0 and 1.0
	desiredAngle = (left * -lockAngle) + (right * lockAngle)

	local angleNow = 0
	for i, wheel in ipairs(self.wheels) do
		if wheel.isSteerable then
			angleNow = wheel.joint:getJointAngle()
			break -- only need 1 joint since they are all the same
		end
	end

	local angleToTurn = desiredAngle - angleNow
	angleToTurn = math.clamp(-turnPerTimeStep, angleToTurn, turnPerTimeStep)
	local newAngle = angleNow + angleToTurn

	for i, wheel in ipairs(self.wheels) do
		if wheel.isSteerable then
			if wheel.flipSteering then
				wheel.joint:setLimits(-newAngle, -newAngle)
			else
				wheel.joint:setLimits(newAngle, newAngle)
			end
		end
	end

	-- Try to make a broken joint cause extra drag
	-- for i, wheel in ipairs(self.wheels) do
	-- 	if wheel.joint:isDestroyed() then
	-- 		local vel = Vector(self.body:getLinearVelocity())
	-- 		if vel:len() > 0 then
	-- 			local a = vel:angleBetween(wheel.origPos:rotated(self.body:getAngle()))
	-- 			local drag = math.sin(a) * vel * 5
	-- 			self.body:applyAngularImpulse(drag:len())
	-- 			print(a)
	-- 		end
	-- 	end
	-- end
end

function Car:removeTire(jointToRemove)
	for i, wheel in ipairs(self.wheels) do
		if jointToRemove and wheel.joint == jointToRemove then
			print("removing " .. i)
			wheel.isSteerable = false
			jointToRemove:destroy()
			wheel.tire.fixture:setUserData(nil)
			wheel.tire:setCharacteristics(0, 0, 0, 10)
			self.isBroken = true
			self.body:setLinearDamping(1.0)
			self.body:setAngularDamping(0.25)
			break
		end
	end

	for _, wheel in ipairs(self.wheels) do
		wheel.tire.body:setLinearDamping(0.5)
	end
end

return Car
