require "Vector"

local Track = {}

local track_data = require("OvalTrack")

function Track:new(world)
	local track = {}

	--local x_offset = 120
	--local y_offset = -30
	--local s = 1.5
	local x_offset = 100
	local y_offset = 0
	local s = 1

	track.body = love.physics.newBody(world, 0, track_data.position.y, "static")
	track.shapes = {}
	track.fixtures = {}
	for _, fixture in ipairs(track_data.fixture) do
		if fixture.chain ~= nil then
			local points = {}
			for i = 1, #fixture.chain.vertices.x do
				points[#points + 1] = (fixture.chain.vertices.x[i] + x_offset) * s
				points[#points + 1] = (fixture.chain.vertices.y[i] + y_offset) * s
			end
			local shape = love.physics.newChainShape(false, points)
			if fixture.chain.nextVertex then
				shape:setNextVertex((fixture.chain.nextVertex.x + x_offset) * s, (fixture.chain.nextVertex.y + y_offset) * s)
			end
			if fixture.chain.prevVertex then
				shape:setPreviousVertex((fixture.chain.prevVertex.x + x_offset) * s, (fixture.chain.prevVertex.y + y_offset) * s)
			end
			track.shapes[#track.shapes + 1] = shape

			local f = love.physics.newFixture(track.body, shape, 1.0)
			f:setUserData(true)
			if fixture.chain.friction then f:setFriction(fixture.chain.friction) end
			-- f:setFriction(0.75)
			if fixture.chain.restitution then f:set(fixture.chain.restitution) end
			track.fixtures[#track.fixtures + 1] = f
		end
	end
	

	setmetatable(track, self)
	self.__index = self

	return track
end

function Track:destroy()
	for _, fixture in ipairs(self.fixtures) do
		fixture:setUserData(nil)
		fixture:destroy()
	end
	self.fixtures = nil
	self.body:destroy()
	self.body = nil
end

function Track:draw()
	love.graphics.setColor(0, 255, 0)
	for _, shape in ipairs(self.shapes) do
		local points = {shape:getPoints()}
		for i = 1, #points, 2 do
			local x, y = self.body:getWorldPoint(points[i], points[i + 1])
			points[i] = x  * scale
			points[i + 1] = y * scale
		end
		love.graphics.setColor(0, 255, 0)
		love.graphics.line(points)
	end

	--local points = {}
	--for i = 1, #waypoints, 2 do
	--	points[i] = waypoints[i] * scale
	--	points[i + 1] = waypoints[i + 1] * scale
	--end
	--points[#points + 1] = points[1]
	--points[#points + 1] = points[2]
	--love.graphics.line(points)
end

-- function Track:castRayAgainst(x1, y1, x2, y2, maxFraction)
-- 	for _, fixture in ipairs(self.fixtures) do
-- 		--print"attempt"
-- 		local xn, yn, fraction = fixture:rayCast(x1, y1, x2, y2, maxFraction, 1)
-- 		if xn ~= nil then
-- 			print(xn, yn, fraction)
-- 			return x1 + (x2 - x1) * fraction, y1 + (y2 - y1) * fraction
-- 			--break
-- 		end
-- 	end
-- 	return nil
-- end
-- 
-- function Track:startMonitoring(x, y)
-- 	nextWaypoint = 1
-- 	prevLoc = Vector(x, y)
-- end
-- 
-- function Track:monitor(x, y)
-- 	local wp = Vector(waypoints[nextWaypoint * 2 - 1] * scale, waypoints[nextWaypoint * 2] * scale)
-- 	love.graphics.points(wp.x, wp.y)
-- 	love.graphics.points(prevLoc.x, prevLoc.y)
-- 
-- 	local prevDist = prevLoc:distance(wp)
-- 	prevLoc = Vector(x,y)
-- 	local curDist = prevLoc:distance(wp)
-- 
-- 	if curDist <= prevDist then
-- 		-- Yay: we are getting closer
-- 		--return "getting closer"
-- 	else
-- 		-- We've gotten further away, see if we are closer
-- 		-- to the next waypoint or previous 
-- 		local wpNext = Vector(waypoints[(nextWaypoint + 1) * 2 - 1] * scale, waypoints[(nextWaypoint + 1) * 2] * scale)
-- 		love.graphics.points(wpNext.x, wpNext.y)
-- 		local nextDist = prevLoc:distance(wpNext)
-- 		if nextDist <= wp:distance(wpNext) then
-- 			nextWaypoint = nextWaypoint + 1
-- 			print "moving to next waypoint"
-- 		else
-- 			print "going backwards"
-- 		end
-- 	end
-- end

return Track
