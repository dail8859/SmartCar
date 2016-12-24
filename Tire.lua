-- This file is part of SmartCar.
-- 
-- Copyright (C)2016 Justin Dailey <dail8859@yahoo.com>
-- 
-- SmartCar is free software; you can redistribute it and/or
-- modify it under the terms of the GNU General Public License
-- as published by the Free Software Foundation; either
-- version 2 of the License, or (at your option) any later version.
-- 
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
-- GNU General Public License for more details.
-- 
-- You should have received a copy of the GNU General Public License
-- along with SmartCar.  If not, see <http://www.gnu.org/licenses/>.

-- Most of this code was translated from:
-- http://www.iforce2d.net/b2dtut/top-down-car

require "Vector"

local Tire = {}

function Tire:new(world, x, y)
	local tire = {}

	tire.body = love.physics.newBody(world, x or 0, y or 0, "dynamic")
	tire.shape = love.physics.newRectangleShape(0.5 * 2, 1.25 * 2)
	tire.fixture = love.physics.newFixture(tire.body, tire.shape, 1)
	tire.fixture:setFriction(0.9)
	tire.dots = {}

	setmetatable(tire, self)
	self.__index = self

	return tire
end

function Tire:destroy()
	self.fixture:setUserData(nil)
	self.fixture:destroy()
	self.fixture = nil
	self.body:destroy()
	self.body = nil
end

function Tire:draw()
	local points = {self.shape:getPoints()}

	for i = 1, #points, 2 do
		local x, y = self.body:getWorldPoint(points[i], points[i + 1])
		points[i] = x  * scale
		points[i + 1] = y * scale
	end
	love.graphics.setColor(255, 255, 255)

	love.graphics.polygon("line", points)

	--local x, y = self.body:getWorldCenter()

	--love.graphics.setPointSize(3)
	--local newPos = Vector(self.body:getWorldPoint(x, y))
	--if #self.dots > 1 then
	--	if Vector.distance(Vector(x, y), Vector(self.dots[#self.dots].x, self.dots[#self.dots].y)) > 5 then
	--		self.dots[#self.dots + 1] = {x = x, y = y}
	--	end
	--else
	--	self.dots[#self.dots + 1] = newPos
	--end
    --
	--for _, dot in ipairs(self.dots) do
	--	love.graphics.points(dot.x, dot.y)
	--end
    --
	--while #self.dots > 20 do
	--	table.remove(self.dots, 1)
	--end
end

function Tire:setCharacteristics(maxForwardSpeed, maxBackwardSpeed, maxDriveForce, maxLateralImpulse)
	self.maxForwardSpeed = maxForwardSpeed
	self.maxBackwardSpeed = maxBackwardSpeed
	self.maxDriveForce = maxDriveForce
	self.maxLateralImpulse = maxLateralImpulse
end

function Tire:getLateralVelocity()
	local currentRightNormal = Vector(self.body:getWorldVector(1, 0))
	return Vector.dot(currentRightNormal, Vector(self.body:getLinearVelocity())) * currentRightNormal
end

function Tire:getForwardVelocity()
	local currentForwardNormal = Vector(self.body:getWorldVector(0, 1))
	return Vector.dot(currentForwardNormal, Vector(self.body:getLinearVelocity())) * currentForwardNormal
end

function Tire:updateFriction()
	self.body:applyAngularImpulse( 1.0 * 0.1 * self.body:getInertia() * -self.body:getAngularVelocity())

	-- forward linear velocity
	local forwardVel = self:getForwardVelocity()
	if forwardVel:len() > 0 then
		local currentForwardNormal = forwardVel:normalized()
		local currentForwardSpeed = forwardVel:len()
		local dragForceMagnitude = -0.25 * currentForwardSpeed
		dragForceMagnitude = dragForceMagnitude * 1.0
		local dragForce = 1.0 * dragForceMagnitude * currentForwardNormal
		self.body:applyForce(dragForce.x, dragForce.y)
		--self.body:applyForce(dragForce.x, dragForce.y)
	end
end

function Tire:updateDrive(up, down)
	-- find desired speed
	local desiredSpeed = (up * self.maxForwardSpeed) + (down * self.maxBackwardSpeed)

	-- find current speed in forward direction
	local currentForwardNormal = Vector(self.body:getWorldVector(0, 1))
	local currentSpeed = Vector.dot(self:getForwardVelocity(), currentForwardNormal)

	-- apply necessary force
	local force = 0

	if up > 0 or down > 0 then
		if desiredSpeed > currentSpeed then
			force = self.maxDriveForce
		elseif desiredSpeed < currentSpeed then
			force = -self.maxDriveForce * 0.5
		end
	end

	local speedFactor = currentSpeed / 120.0

	local driveImpulse = (force / 60.0) * currentForwardNormal
	if driveImpulse:len() > self.maxLateralImpulse then
		driveImpulse = driveImpulse * (self.maxLateralImpulse / driveImpulse:len())
	end

	local lateralFrictionImpulse = self.body:getMass() * -self:getLateralVelocity()
	local lateralImpulseAvailable = self.maxLateralImpulse
	lateralImpulseAvailable = lateralImpulseAvailable * 2.0 * speedFactor
	if lateralImpulseAvailable < 0.5 * self.maxLateralImpulse then
		lateralImpulseAvailable = 0.5 * self.maxLateralImpulse
	end

	if lateralFrictionImpulse:len() > lateralImpulseAvailable then
		lateralFrictionImpulse = lateralFrictionImpulse * (lateralImpulseAvailable / lateralFrictionImpulse:len())
	end

	local impulse = driveImpulse + lateralFrictionImpulse
	if impulse:len() > self.maxLateralImpulse then
		impulse = impulse * (self.maxLateralImpulse / impulse:len())
	end
	self.body:applyLinearImpulse(1.0 * impulse.x, 1.0 * impulse.y)
end

return Tire
