--[[
CBEffects ParticleHelper Library

The master helper library.
--]]

local Tex

do
	local path = ...

	path = path:gsub("%.", "/")
	path = path:gsub("ParticleHelper", "textures/texture-%%i.png")

	function Tex (num)
		return path:format(num)
	end
end

-- Create public library
local ParticleHelper = {physics = {}, presets = {vents = {}, fields = {}}, functions = {}}

-- Localize
local mrand								= math.random
local rad									= math.rad
local cos									= math.cos
local deg									= math.deg
local sin									= math.sin
local pairs								= pairs
local type								= type
local letters							= "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz1234567890~!@#$%^&*()_+=-{}[]:;\"\'.,></?|"

local newImage						= display.newImage
local newImageRect				= display.newImageRect
local newRect							= display.newRect
local newCircle						= display.newCircle
local screen							= {width = display.contentWidth, height = display.contentHeight, centerX = display.contentCenterX, centerY = display.contentCenterY}

local getTimer						= system.getTimer
local timeFrac						= 1000 / 60 -- Samples in this library are based on 60 FPS, so we get 1 / 60 of a second for the time fraction
local runtime							= 0
local delta								= 0
local timePlus						= 0 -- Change this if you want to speed up ParticlePhysics

function ParticleHelper.setCalcDeltaTime(cdt)
	ParticleHelper.calcDeltaTime = cdt
	if not cdt then
		delta = 1
	end
end

-- Miscellaneous helper functions to be used with CBEffects.

-- Create functions
local function angleBetween(srcX, srcY, dstX, dstY, offset) local angle = (deg(math.atan2(dstY - srcY, dstX - srcX))+90) + offset if (angle < 0) then angle = angle + 360 end return angle%360 end
local function formatForPolygon(obj, t) local polygon={} for i = 1, #t, 2 do polygon[#polygon + 1]={x = t[i]+obj.x, y = t[i + 1]+obj.y} end return polygon end
local function pointInPolygon(points, dot) local i, j=#points, #points local oddNodes = false for i = 1, #points do if ((points[i].y < dot.y and points[j].y >= dot.y or points[j].y< dot.y and points[i].y >= dot.y) and (points[i].x <= dot.x or points[j].x <= dot.x)) then if (points[i].x + (dot.y - points[i].y) / (points[j].y - points[i].y) * (points[j].x - points[i].x)<dot.x) then oddNodes = not oddNodes end end j = i end return oddNodes end
local function pointInRect(pointX, pointY, left, top, width, height) return pointX >= left and pointX <= left + width and pointY >= top and pointY <= top + height end
local function pointInCircle(pointX, pointY, centerX, centerY, radius) local dX, dY = pointX - centerX, pointY - centerY return dX * dX + dY * dY <= radius * radius end
local function fnn(...) for i = 1, #arg do if arg[i]~=nil then return arg[i] end end end
local function lengthOf(a, b, c, d) local width, height = c - a, d - b return (width * width + height * height)^0.5 end
local function pointsAlongLine(x1, y1, x2, y2, d) local points={} local diffX = x2 - x1 local diffY = y2 - y1 local distBetween local x, y = x1, y1 if d == "total" or not d then distBetween = lengthOf(x1, y1, x2, y2) else distBetween = d end local addX, addY = diffX / distBetween, diffY / distBetween for i = 1, distBetween do points[#points + 1]={x, y} x, y = x + addX, y + addY end return points end
local function forcesByAngle(totalForce, angle) local forces={} local radians=-rad(angle) forces.x = cos(radians) * totalForce forces.y = sin(radians) * totalForce return forces end
local function either(table) return table[mrand(#table)] end
local function inRadius(x, y, radius, innerRadius) local X local Y local inRad local Radius = radius * radius local finalX, finalY if (innerRadius) then inRad = innerRadius * innerRadius end if (inRad) then repeat X = mrand(-radius, radius) Y = mrand(-radius, radius) until X * X + Y * Y <= Radius and X * X + Y * Y >= inRad finalX, finalY = x + X, y + Y else repeat X = mrand(-radius, radius) Y = mrand(-radius, radius) until X * X + Y * Y <= Radius end return finalX, finalY end
local function inRect(x, y, rectLeft, rectTop, rectWidth, rectHeight) local X, Y repeat X, Y = mrand(rectLeft, rectLeft + rectWidth), mrand(rectTop, rectTop + rectHeight) until pointInRect(X, Y, rectLeft, rectTop, rectWidth, rectHeight) == true return X, Y end
local function getValue(t) if type(t) == "function" then return t() else return t end end
local function newTitle() local title="" for i = 1, 8 do local r = mrand(92) title = title..letters:sub(r, r) end return title end
local function clamp(t, l, h) return (t < l and l) or (t > h and h) or t end
local function updateDelta() local temp = getTimer() delta=((temp - runtime) / timeFrac) + timePlus runtime = temp end

-- Add functions to ParticleHelper
ParticleHelper.functions={
	pointInPolygon		= pointInPolygon,
	pointInRect				= pointInRect,
	pointInCircle			= pointInCircle,
	formatForPolygon	= formatForPolygon,
	angleBetween			= angleBetween,
	fnn								= fnn,
	lengthOf					= lengthOf,
	pointsAlongLine		= pointsAlongLine,
	forcesByAngle			= forcesByAngle,
	either						= either,
	inRadius					= inRadius,
	inRect						= inRect,
	getValue					= getValue,
	newTitle					= newTitle,
	clamp							= clamp,
	setPhysicsSpeed		= setPhysicsSpeed
}

-- ParticleHelper Mini Library: ParticlePhysics
--
-- createCollisionSensor() - Makes a sensor for particle collisions
-- createPhysics() - Uses a loop to move particles frame - by - frame


-- createCollisionSensor
local function createCollisionSensor(params)
	local cf={
		-- Collision Field Values
		onCollision						= params.onCollision or function() end,
		shape									= params.shape or "rect",
		x											= params.x or screen.centerX,
		y											= params.y or screen.centerY,
		rectLeft							= params.rectLeft or 0,
		rectTop								= params.rectTop or 0,
		rectWidth							= params.rectWidth or 100,
		rectHeight						= params.rectHeight or 100,
		radius								= params.radius or 200,
		points								= params.points or {0, 0, 500, 500, 500, 0},
		polygon								= {},
		targetPhysics					= params.targetPhysics,
		singleEffect					= params.singleEffect or false
	}

	cf.polygon = formatForPolygon(cf, cf.points)

	-- cf.check()
	function cf.check(t)
		if cf.targetPhysics._objects[t] then

			if cf.singleEffect then -- Only apply if not collided
				if not cf.targetPhysics._objects[t]._particlephysics.collided then
					cf.targetPhysics._objects[t]._particlephysics.collided = true
					if cf.shape == "rect" then
						-- Rectangular collision routines
						if pointInRect(cf.targetPhysics._objects[t].x, cf.targetPhysics._objects[t].y, cf.rectLeft + cf.x, cf.rectTop + cf.y, cf.rectWidth, cf.rectHeight) then
							cf.onCollision(cf.targetPhysics._objects[t], cf)
						end
					elseif cf.shape == "circle" then
						-- Circular collision routines
						if pointInCircle(cf.targetPhysics._objects[t].x, cf.targetPhysics._objects[t].y, cf.x, cf.y, cf.radius) then
							cf.onCollision(cf.targetPhysics._objects[t], cf)
						end
					elseif cf.shape == "polygon" then
						-- Polygonal collision routines
						if pointInPolygon(cf.polygon, cf.targetPhysics._objects[t]) then
							cf.onCollision(cf.targetPhysics._objects[t], cf)
						end
					end
				end

			else -- Multi - effect collision field
			
				if cf.shape == "rect" then
					-- Rectangle
					if pointInRect(cf.targetPhysics._objects[t].x, cf.targetPhysics._objects[t].y, cf.rectLeft + cf.x, cf.rectTop + cf.y, cf.rectWidth, cf.rectHeight) then
						cf.onCollision(cf.targetPhysics._objects[t], cf)
					end
				elseif cf.shape == "circle" then
					-- Circle
					if pointInCircle(cf.targetPhysics._objects[t].x, cf.targetPhysics._objects[t].y, cf.x, cf.y, cf.radius) then
						cf.onCollision(cf.targetPhysics._objects[t], cf)
					end
				elseif cf.shape == "polygon" then
					-- Polygon
					if pointInPolygon(cf.polygon, cf.targetPhysics._objects[t]) then
						cf.onCollision(cf.targetPhysics._objects[t], cf)
					end
				end

			end
		end
	end
	

	-- cf.start()
	function cf.start()
		cf.targetPhysics._fields[cf._phTitle].active = true
	end
	

	-- cf.stop()
	function cf.stop()
		cf.targetPhysics._fields[cf._phTitle].active = false
	end
	

	-- cf.cancel()
	function cf.cancel()
		if cf.targetPhysics and cf.targetPhysics._fields then
			cf.targetPhysics._fields[cf._phTitle] = nil -- Remove entry from targetPhysics if existent
		end

		for k, v in pairs(cf) do
			cf[k] = nil -- "deep clean"
		end
		cf = nil
		return true
	end


	-- ParticleHelper Title
	cf._phTitle = newTitle()
	cf.targetPhysics._fields[cf._phTitle]={check = cf.check, active = false}

	return cf
end


-- createPhysics()
local function createPhysics()
	local pPhysics={}
	local scale = 1

	pPhysics._fields={}
	pPhysics._objects={}
	pPhysics._gravityX = 0
	pPhysics._gravityY = 0
	pPhysics.useDivisionDamping = true
	

	-- pPhysics.setGravity()
	function pPhysics.setGravity(x, y)
		pPhysics._gravityX = x
		pPhysics._gravityY = y
	end


	-- pPhysics.setScale()
	function pPhysics.setScale(s)
		scale = s
	end


	-- pPhysics.addBody()
	function pPhysics.addBody(obj, params)
		local obj = obj
		local params = params or {}
				
		-- Object ParticlePhysics Private Values
		obj._particlephysics={
			velX							= params.velX or 0,
			velY							= params.velY or 0,
			linearDamping			= params.linearDamping or 1,
			angularDamping		= params.angularDamping or 0,
			angularVelocity		= params.angularVelocity or 0,
			sizeX							= params.sizeX or 0,
			sizeY							= params.sizeY or 0,
			xbS								= params.xbS or 0.1,
			ybS								= params.ybS or 0.1,
			xbL								= params.xbL or 3,
			ybL								= params.ybL or 3,
			rotateToVel				= params.rotateToVel or false,
			offset						= params.offset or 0,
			xDamping					= params.xDamping or 1,
			yDamping					= params.yDamping or 1,
			xDampingPrev			= params.xDamping or 1,
			yDampingPrev			= params.yDamping or 1,
			xDampingMultiple	= 1 / (params.xDamping or 1),
			yDampingMultiple	= 1 / (params.yDamping or 1),
			title							= newTitle(),
			prevX							= obj.x,
			prevY							= obj.y
		}
		obj._numUpdates			= 0

		-- obj:applyForce()
		function obj:applyForce(x, y) obj._particlephysics.velX, obj._particlephysics.velY = obj._particlephysics.velX + x, obj._particlephysics.velY + y end
		
		-- obj:setLinearVelocity()
		function obj:setLinearVelocity(x, y) obj._particlephysics.velX, obj._particlephysics.velY = x, y end
		
		-- obj:getLinearVelocity()
		function obj:getLinearVelocity() return obj._particlephysics.velX, obj._particlephysics.velY end
		
		-- obj:applyTorque()
		function obj:applyTorque(value) obj._particlephysics.angularVelocity = obj._particlephysics.angularVelocity + value end

		-- Add object to pPhysics object list
		pPhysics._objects[obj._particlephysics.title] = obj
	end
	

	-- pPhysics.removeBody()
	function pPhysics.removeBody(n)
		if n and n._particlephysics and n._particlephysics.title then
			pPhysics._objects[n._particlephysics.title] = nil
			n._particlephysics = nil
			return true
		end
	end
	
	-- physicsLoop()
	local function physicsLoop()
		for k, v in pairs(pPhysics._objects) do
			if pPhysics._objects[k] then
				pPhysics._objects[k]._numUpdates = pPhysics._objects[k]._numUpdates + 1
				
				-- Update particle's color
				if pPhysics._objects[k]._colorSet then
					pPhysics._objects[k]:_physicsColor(pPhysics._objects[k]._colorSet.r, pPhysics._objects[k]._colorSet.g, pPhysics._objects[k]._colorSet.b)
				end
	
				-- Gravity
				pPhysics._objects[k]._particlephysics.velX = pPhysics._objects[k]._particlephysics.velX + pPhysics._gravityX
				pPhysics._objects[k]._particlephysics.velY = pPhysics._objects[k]._particlephysics.velY + pPhysics._gravityY
				
				-- Damping
				if not pPhysics.useDivisionDamping then
					--Subtract for damping X
					if pPhysics._objects[k]._particlephysics.velX > 0 then 
						pPhysics._objects[k]._particlephysics.velX = clamp(pPhysics._objects[k]._particles.velX - pPhysics._objects[k]._particlephysics.xDamping, 0, math.huge)
					else
						pPhysics._objects[k]._particlephysics.velX = clamp(pPhysics._objects[k]._particles.velX + pPhysics._objects[k]._particlephysics.xDamping, -math.huge, 0)
					end

					--Subtract for damping Y
					if pPhysics._objects[k]._particlephysics.velY > 0 then
						pPhysics._objects[k]._particlephysics.velY = clamp(pPhysics._objects[k]._particlephysics.velY - pPhysics._objects[k]._particlephysics.yDamping, 0, math.huge)
					else
						pPhysics._objects[k]._particlephysics.velY = clamp(pPhysics._objects[k]._particlephysics.velY + pPhysics._objects[k]._particlephysics.yDamping, -math.huge, 0)
					end
				else

					-- Update dampingMultiple to use multiplication instead of division
					if pPhysics._objects[k]._particlephysics.xDamping~=pPhysics._objects[k]._particlephysics.xDampingPrev then
						pPhysics._objects[k]._particlephysics.xDampingMultiple = 1 / pPhysics._objects[k]._particlephysics.xDamping; pPhysics._objects[k]._particlephysics.xDampingPrev = pPhysics._objects[k]._particlephysics.xDamping
					end

					if pPhysics._objects[k]._particlephysics.yDamping~=pPhysics._objects[k]._particlephysics.yDampingPrev then
						pPhysics._objects[k]._particlephysics.yDampingMultiple = 1 / pPhysics._objects[k]._particlephysics.yDamping; pPhysics._objects[k]._particlephysics.yDampingPrev = pPhysics._objects[k]._particlephysics.yDamping
					end

					-- Apply damping
					pPhysics._objects[k]._particlephysics.velX = pPhysics._objects[k]._particlephysics.velX * pPhysics._objects[k]._particlephysics.xDampingMultiple
					pPhysics._objects[k]._particlephysics.velY = pPhysics._objects[k]._particlephysics.velY * pPhysics._objects[k]._particlephysics.yDampingMultiple
				end
				
				-- Rotation
				if pPhysics._objects[k]._particlephysics.rotateToVel == true then
					pPhysics._objects[k].rotation = angleBetween(pPhysics._objects[k]._particlephysics.prevX, pPhysics._objects[k]._particlephysics.prevY, pPhysics._objects[k].x, pPhysics._objects[k].y, pPhysics._objects[k]._particlephysics.offset)
				else
					pPhysics._objects[k]:rotate(pPhysics._objects[k]._particlephysics.angularVelocity * delta)
				end
				
				if pPhysics._objects[k]._particlephysics.angularVelocity > 0 then
					pPhysics._objects[k]._particlephysics.angularVelocity = clamp(pPhysics._objects[k]._particlephysics.angularVelocity - pPhysics._objects[k]._particlephysics.angularDamping, 0, math.huge)
				else
					pPhysics._objects[k]._particlephysics.angularVelocity = clamp(pPhysics._objects[k]._particlephysics.angularVelocity + pPhysics._objects[k]._particlephysics.angularDamping, -math.huge, 0)
				end
				
				-- xScale and yScale
				if (pPhysics._objects[k]._particlephysics.sizeX > 0 and pPhysics._objects[k].xScale <= pPhysics._objects[k]._particlephysics.xbL + pPhysics._objects[k]._particlephysics.sizeX) or (pPhysics._objects[k]._particlephysics.sizeX < 0 and pPhysics._objects[k].xScale >= pPhysics._objects[k]._particlephysics.xbS + pPhysics._objects[k]._particlephysics.sizeX) then pPhysics._objects[k].xScale = pPhysics._objects[k].xScale + pPhysics._objects[k]._particlephysics.sizeX end
				if (pPhysics._objects[k]._particlephysics.sizeY > 0 and pPhysics._objects[k].yScale <= pPhysics._objects[k]._particlephysics.ybL + pPhysics._objects[k]._particlephysics.sizeY) or (pPhysics._objects[k]._particlephysics.sizeY < 0 and pPhysics._objects[k].yScale >= pPhysics._objects[k]._particlephysics.ybS + pPhysics._objects[k]._particlephysics.sizeY) then pPhysics._objects[k].yScale = pPhysics._objects[k].yScale + pPhysics._objects[k]._particlephysics.sizeY end
				
				-- Check For Field Collisions
				for fk, fv in pairs(pPhysics._fields) do
					if pPhysics._fields[fk].active then
						pPhysics._fields[fk].check(pPhysics._objects[k]._particlephysics.title)
					end
				end

				-- Finish Up
				-- Update prevX and prevY
				pPhysics._objects[k]._particlephysics.prevX, pPhysics._objects[k]._particlephysics.prevY = pPhysics._objects[k].x, pPhysics._objects[k].y

				-- Move particles
				pPhysics._objects[k]:translate(pPhysics._objects[k]._particlephysics.velX * delta, pPhysics._objects[k]._particlephysics.velY * delta)

				-- Call the onUpdate function
				pPhysics.parentVent.onUpdate(pPhysics._objects[k], pPhysics.parentVent, pPhysics.parentVent.content)
			end
		end
	end
	

	-- pPhysics.start()
	function pPhysics.start()
		ParticleHelper.physics.set[pPhysics._phTitle].active = true
	end
	

	-- pPhysics.pause()
	function pPhysics.pause()
		ParticleHelper.physics.set[pPhysics._phTitle].active = false
	end
	

	-- pPhysics.iterate()
	function pPhysics.iterate()
		physicsLoop()
	end
	

	-- pPhysics.cancel()
	function pPhysics.cancel()
		ParticleHelper.physics.set[pPhysics._phTitle] = nil

		-- Clean up objects, fields, and the pPhysics table itself
		for k, v in pairs(pPhysics._objects) do pPhysics.removeBody(pPhysics._objects[k]) end 
		for k, v in pairs(pPhysics._fields) do pPhysics._fields[k].targetPhysics = nil end 
		for k, v in pairs(pPhysics) do pPhysics[k] = nil end
		
		pPhysics = nil
		scale = nil
		return true
	end
	

	-- ParticleHelper Title for the pPhysics
	pPhysics._phTitle = newTitle()
	ParticleHelper.physics.set[pPhysics._phTitle]={loop = physicsLoop, active = false}

	return pPhysics
end


-- Add functions
ParticleHelper.physics={
	createPhysics = createPhysics,
	createCollisionSensor = createCollisionSensor,
	set={}
}

-- ParticleHelper Mini Library: ParticlePresets
-- 
-- Contains data for the vent and field presets

-- Miscellaneous
local cloudTable={ Tex(1), Tex(2) }
local burnColors={{1, 1, 10/255},{1, 155/255, 10/255},{1, 10/255, 10/255}}
local function velNil()	return 0, 0 end


-- Build Functions for Presets
local function buildDefault() return newRect(0, 0, 20, 20) end
local function buildHyperspace() local b = newRect(0, 0, 10, 5) b:setReferencePoint(display.CenterLeftReferencePoint) return b end
local function buildPixelWheel() return newRect(0, 0, 50, 50) end
local function buildCircles() local size = mrand(5, 30) return newCircle(0, 0, size) end
local function buildEmbers() local size = mrand(10, 20) return newImageRect(Tex(5), size, size) end
local function buildFlame() local size = mrand(100, 300) return newImageRect(either(cloudTable), size, size) end
local function buildSmoke() local size = mrand(200, 300) return newImageRect(either(cloudTable), size, size) end
local function buildSteam() local size = mrand(50, 100) return newImageRect(either(cloudTable), size, size) end
local function buildSparks() local size = mrand(10,20) return newImageRect(Tex(5), size, size) end
local function buildRain() return newRect(0, 0, mrand(2,4), mrand(6,25)) end
local function buildConfetti() local width = mrand(10, 15) local height = mrand(10, 15) return newRect(0, 0, width, height) end
local function buildSnow() local size = mrand(10,40) return newImageRect(Tex(5), size, size) end
local function velSnow() return mrand(-1,1), mrand(10) end
local function buildBeams() local beam = newRect(0, 0, mrand(800), 20) beam:setReferencePoint(display.CenterLeftReferencePoint) return beam end
local function buildBurn() local size = mrand(50, 150) return newImageRect(Tex(5), size, size) end
local function onBurnCreation(p) p.colorChange(burnColors[mrand(2)], 200) end
local function buildFountain() local size = mrand(50, 80) return newImageRect(Tex(5), size, size) end
local function buildEvil() local size = mrand(80, 120) return newImageRect(Tex(5), size, size) end
local function buildLGun() return newImageRect(Tex(5), 150, 10) end
local function buildWisp() local s = mrand(20, 180)return newImageRect(Tex(5), s, s) end
local function buildFluid() local s = mrand(100, 400)return newImageRect(Tex(5), s, s) end
local function buildWater() return newImageRect(Tex(5), 160, 20) end
local function buildAurora() local p = newImageRect(Tex(5), mrand(80,150), mrand(160,550)) p:setReferencePoint(display.BottomCenterReferencePoint) return p end
local function buildPoison() local p = newImageRect(Tex(5), 40, 40) return p end


-- Vent Presets
ParticleHelper.presets.vents={
	["aurora"]				= {title = "aurora", x = 0, y = 0, isActive = true, build = buildAurora, color={{0, 255, 0}, {150, 255, 150}}, iterateColor = true, curColor = 1, emitDelay = 1, perEmit = 1, emissionNum = 0, lifeSpan = 1500, alpha = 0.2, startAlpha = 0, endAlpha = 0, onCreation = function()end, onDeath = function()end, propertyTable = {blendMode = "add"}, scale = 1.0, lifeStart = 0, fadeInTime = 500, iteratePoint = false, curPoint = 1, lineDensity = "total", pointList={{0, 0}, {1, 1}}, positionType = "alongLine", posRadius = 30, posInner = 1, point1 = {screen.width / 6, screen.centerY + (screen.height / 6)}, point2 = {screen.width - (screen.width / 6), screen.centerY + (screen.height / 6)}, rectLeft = 0, rectTop = screen.height / 3, rectWidth = screen.width, rectHeight = screen.height - (screen.height / 3), onUpdate = function()end, physics = {iterateAngle = false, xDamping = 0, yDamping = 0, velocity = 1, angularVelocity = 0, angularDamping = 0, velFunction = velNil, useFunction = false, autoAngle = false, angles = {0, 180}, preCalculate = true, sizeX = 0, sizeY=-0.002, minX = 0.1, minY = 0.1, maxX = 100, maxY = 100, gravityX = 0, gravityY = 0}, rotateTowardVel = false, towardVelOffset = 0}, 
	["beams"]					= {title = "beams", isActive = true, build = buildBeams, x = screen.centerX, y = screen.centerY, color={{255,  0,  0}, {0,  0,  255}}, iterateColor = false, curColor = 1, emitDelay = 1, perEmit = 1, emissionNum = 0, lifeSpan = 2000, alpha = 0.3, startAlpha = 0, endAlpha = 0, onCreation = function(p, v)p.rotation = angleBetween(p.x, p.y, v.x, v.y, 90)end, onDeath = function()end, propertyTable={}, scale = 1.0, lifeStart = 0, fadeInTime = 300, iteratePoint = false, curPoint = 1, lineDensity = "total", pointList={{0, 0}, {1, 1}}, positionType = "inRadius", posRadius = 30, posInner = 1, point1 = {0, -10}, point2 = {screen.width + 150, -10}, rectLeft = 0, rectTop = 0, rectWidth = screen.width, rectHeight = screen.height, onUpdate = function()end, physics = {iterateAngle = false, xDamping = 0, yDamping = 0, velocity = 0, angularVelocity = 0.04, angularDamping = 0, velFunction = velNil, useFunction = false, autoAngle = true, angles={{0, 10}}, preCalculate = true, sizeX = 0, sizeY = 0, minX = 0.1, minY = 0.1, maxX = 100, maxY = 100, gravityX = 0, gravityY = 0}, rotateTowardVel = false, towardVelOffset = 0}, 
	["burn"]					= {title = "burn", x = screen.centerX, y = screen.centerY, isActive = true, build = buildBurn, color={{0, 0, 255}}, iterateColor = false, curColor = 1, emitDelay = 30, perEmit = 3, emissionNum = 0, lifeSpan = 500, alpha = 1, startAlpha = 0, endAlpha = 0, onCreation = onBurnCreation, onDeath = function()end, propertyTable = {blendMode = "add"}, scale = 1.0, lifeStart = 0, fadeInTime = 500, iteratePoint = false, curPoint = 1, lineDensity = "total", pointList={{0, 0}, {1, 1}}, positionType = "atPoint", posRadius = 30, posInner = 1, point1 = {1, 1}, point2 = {2, 1}, rectLeft = 0, rectTop = 0, rectWidth = screen.width, rectHeight = screen.height, onUpdate = function()end, physics = {iterateAngle = false, xDamping = 0, yDamping = 0, velocity = 2, angularVelocity = 0, angularDamping = 0, velFunction = velNil, useFunction = false, autoAngle = true, angles={{80, 100}}, preCalculate = true, sizeX=-0.015, sizeY=-0.015, minX = 0.1, minY = 0.1, maxX = 100, maxY = 100, gravityX = 0, gravityY=-0.05}, rotateTowardVel = false, towardVelOffset = 0}, 
	["circles"]				= {title = "circles", isActive = true, build = buildCircles, x = 0, y = 0, color={{0, 0, 255}, {120, 120, 255}, {0, 0, 255}, {120, 120, 255}, {0, 0, 255}, {120, 120, 255}, {255, 0, 0}}, iterateColor = false, curColor = 1, emitDelay = 100, perEmit = 4, emissionNum = 0, lifeSpan = 1000, alpha = 1, endAlpha = 0, startAlpha = 0, onCreation = function()end, onDeath = function()end, propertyTable={}, scale = 1.0, lifeStart = 0, fadeInTime = 300, iteratePoint = false, curPoint = 1, lineDensity = "total", pointList={{0, 0}, {1, 1}}, positionType = "alongLine", posRadius = 30, posInner = 1, point1 = {100, screen.height}, point2 = {screen.width - 100, screen.height - 100}, rectLeft = 0, rectTop = 0, rectWidth = screen.width, rectHeight = screen.height, onUpdate = function()end, physics = {iterateAngle = false, xDamping = 0, yDamping = 0, velocity = 5, angularVelocity = 0.04, angularDamping = 0, velFunction = velNil, useFunction = false, autoAngle = true, angles={{75, 105}}, preCalculate = true, sizeX=-0.01, sizeY=-0.01, minX = 0.1, minY = 0.1, maxX = 100, maxY = 100, gravityX = 0, gravityY = 0}, rotateTowardVel = false, towardVelOffset = 0}, 
	["confetti"]			= {title = "confetti", isActive = true, build = buildConfetti, x = 0, y = 0, color={{1, 0, 0}, {0, 0, 1}, {1, 1, 0}, {0, 1, 0}}, iterateColor = false, curColor = 1, emitDelay = 1, perEmit = 2, emissionNum = 0, lifeSpan = 50, alpha = 1, startAlpha = 0, endAlpha = 0, onCreation = function()end, onDeath = function()end, propertyTable={}, scale = 1.0, lifeStart = 1900, fadeInTime = 100, iteratePoint = false, curPoint = 1, lineDensity = "total", pointList={{0, 0}, {1, 1}}, positionType = "alongLine", posRadius = 30, posInner = 1, point1 = {0, -10}, point2 = {screen.width + 150, -10}, rectLeft = 0, rectTop = 0, rectWidth = screen.width, rectHeight = screen.height, onUpdate = function()end, physics = {iterateAngle = false, xDamping = 0, yDamping = 0, velocity = 5, angularVelocity = 0.04, angularDamping = 0, velFunction = velNil, useFunction = false, autoAngle = true, angles={{200, 340}}, preCalculate = true, sizeX = 0, sizeY = 0, minX = 0.1, minY = 0.1, maxX = 100, maxY = 100, gravityX = 0, gravityY = 0.1}, rotateTowardVel = true, towardVelOffset = 0}, 
	["default"]				= {title = "default", x = screen.centerX, y = screen.centerY, isActive = true, build = buildDefault, color={{1, 1, 1}}, iterateColor = false, curColor = 1, emitDelay = 5, perEmit = 2, emissionNum = 0, lifeSpan = 1000, alpha = 1, startAlpha = 1, endAlpha = 0, onCreation = function()end, onDeath = function()end, propertyTable={}, scale = 1.0, lifeStart = 0, fadeInTime = 0, iteratePoint = false, curPoint = 1, lineDensity = "total", pointList={{0, 0}, {1, 1}}, positionType = "inRadius", posRadius = 30, posInner = 1, point1 = {1, 1}, point2 = {2, 1}, rectLeft = 0, rectTop = 0, rectWidth = screen.width, rectHeight = screen.height, onUpdate = function()end, physics = {iterateAngle = false, xDamping = 0, yDamping = 0, velocity = 2, angularVelocity = 0, angularDamping = 0, velFunction = velNil, useFunction = false, autoAngle = true, angles={{0, 360}}, preCalculate = true, sizeX = 0, sizeY = 0, minX = 0.1, minY = 0.1, maxX = 100, maxY = 100, gravityX = 0, gravityY = 0}, rotateTowardVel = false, towardVelOffset = 0}, 
	["embers"]				= {title = "embers", isActive = true, build = buildEmbers, x = 0, y = 0, color={{255, 255, 0}, {255, 255, 0}, {255, 255, 0}, {255, 255, 0}, {255, 0, 0}}, iterateColor = false, curColor = 1, emitDelay = 100, perEmit = 2, emissionNum = 0, lifeSpan = 1000, alpha = 1, startAlpha = 0, endAlpha = 0, onCreation = function()end, onDeath = function()end, propertyTable={}, scale = 1.0, lifeStart = 0, fadeInTime = 300, iteratePoint = false, curPoint = 1, lineDensity = "total", pointList={{0, 0}, {1, 1}}, positionType = "alongLine", posRadius = 30, posInner = 1, point1 = {100, screen.height}, point2 = {screen.width - 100, screen.height}, rectLeft = 0, rectTop = 0, rectWidth = screen.width, rectHeight = screen.height, onUpdate = function()end, physics = {iterateAngle = false, xDamping = 0, yDamping = 0, velocity = 5, angularVelocity = 0.04, angularDamping = 0, velFunction = velNil, useFunction = false, autoAngle = true, angles={{75, 105}}, preCalculate = true, sizeX = 0, sizeY = 0, minX = 0.1, minY = 0.1, maxX = 100, maxY = 100, gravityX = 0, gravityY = 0}, rotateTowardVel = false, towardVelOffset = 0}, 
	["evil"]					= {title = "evil", x = screen.centerX, y = screen.centerY, isActive = true, build = buildEvil, color={{100, 0, 100}, {0, 0, 180}, {80, 0, 60}}, iterateColor = false, curColor = 1, emitDelay = 10, perEmit = 1, emissionNum = 0, lifeSpan = 800, alpha = 1, startAlpha = 0, endAlpha = 0, onCreation = function()end, onDeath = function()end, propertyTable = {blendMode = "add"}, scale = 1.0, lifeStart = 0, fadeInTime = 1500, iteratePoint = false, curPoint = 1, lineDensity = "total", pointList={{0, 0}, {1, 1}}, positionType = "atPoint", posRadius = 30, posInner = 1, point1 = {1, 1}, point2 = {2, 1}, rectLeft = 0, rectTop = 0, rectWidth = screen.width, rectHeight = screen.height, onUpdate = function()end, physics = {iterateAngle = false, xDamping = 0, yDamping = 0, velocity = 1.5, angularVelocity = 0, angularDamping = 0, velFunction = velNil, useFunction = false, autoAngle = true, angles={{0, 360}}, preCalculate = true, sizeX=-0.005, sizeY=-0.005, minX = 0.2, minY = 0.2, maxX = 100, maxY = 100, gravityX = 0, gravityY = 0}, rotateTowardVel = false, towardVelOffset = 0}, 
	["flame"]					= {title = "flame", isActive = true, build = buildFlame, x = 0, y = 0, color={{255, 255, 0}, {255, 255, 0}, {255, 255, 0}, {255, 255, 0}, {200, 200, 0}, {200, 200, 0}, {255, 100, 0}}, iterateColor = false, curColor = 1, emitDelay = 100, perEmit = 2, emissionNum = 0, lifeSpan = 1000, alpha = 1, startAlpha = 0, endAlpha = 0, onCreation = function()end, onDeath = function()end, propertyTable = {blendMode = "screen"}, scale = 1.0, lifeStart = 500, fadeInTime = 300, iteratePoint = false, curPoint = 1, lineDensity = "total", pointList={{0, 0}, {1, 1}}, positionType = "alongLine", posRadius = 30, posInner = 1, point1 = {300, screen.height + 100}, point2 = {screen.width - 300, screen.height + 100}, rectLeft = 0, rectTop = 0, rectWidth = screen.width, rectHeight = screen.height, onUpdate = function()end, physics = {iterateAngle = false, xDamping = 0.2, yDamping = 0.2, velocity = 5, angularVelocity = 0.04, angularDamping = 0, velFunction = velNil, useFunction = false, autoAngle = true, angles={{75, 105}}, preCalculate = true, sizeX = 0.02, sizeY = 0.02, minX = 0.1, minY = 0.1, maxX = 1000, maxY = 1000, gravityX = 0, gravityY = 0}, rotateTowardVel = false, towardVelOffset = 0}, 
	["fluid"]					= {title = "fluid", x = 0, y = 0, isActive = true, build = buildFluid, color={{255, 0, 255}, {255, 0, 0}, {255, 0, 0}, {0, 0, 255}}, iterateColor = false, curColor = 1, emitDelay = 30, perEmit = 1, emissionNum = 0, lifeSpan = 800, alpha = 1, startAlpha = 0, endAlpha = 0, onCreation = function()end, onDeath = function()end, propertyTable = {blendMode = "add"}, scale = 1.0, lifeStart = 0, fadeInTime = 1500, iteratePoint = false, curPoint = 1, lineDensity = "total", pointList={{0, 0}, {1, 1}}, positionType = "inRect", posRadius = 30, posInner = 1, point1 = {1, 1}, point2 = {2, 1}, rectLeft = 200, rectTop = 200, rectWidth = screen.width / 1.75, rectHeight = screen.height / 1.75, onUpdate = function()end, physics = {iterateAngle = false, xDamping = 0, yDamping = 0, velocity = 0.5, angularVelocity = 0, angularDamping = 0, velFunction = velNil, useFunction = false, autoAngle = true, angles={{0, 360}}, preCalculate = true, sizeX = 0, sizeY = 0, minX = 0.1, minY = 0.1, maxX = 100, maxY = 100, gravityX = 0, gravityY = 0}, rotateTowardVel = false, towardVelOffset = 0}, 
	["fountain"]			= {title = "fountain", x = screen.centerX, y = screen.centerY + 250, isActive = true, build = buildFountain, color={{0, 218, 255}}, iterateColor = false, curColor = 1, emitDelay = 5, perEmit = 2, emissionNum = 0, lifeSpan = 500, alpha = 1, startAlpha = 0, endAlpha = 0, onCreation = function()end, onDeath = function()end, propertyTable = {blendMode = "screen"}, scale = 1.0, lifeStart = 0, fadeInTime = 500, iteratePoint = false, curPoint = 1, lineDensity = "total", pointList={{0, 0}, {1, 1}}, positionType = "atPoint", posRadius = 30, posInner = 1, point1 = {1, 1}, point2 = {2, 1}, rectLeft = 0, rectTop = 0, rectWidth = screen.width, rectHeight = screen.height, onUpdate = function()end, physics = {iterateAngle = false, xDamping = 0, yDamping = 0, velocity = 12, angularVelocity = 0, angularDamping = 0, velFunction = velNil, useFunction = false, autoAngle = true, angles={{70, 110}}, preCalculate = true, sizeX=-0.005, sizeY=-0.005, minX = 0.1, minY = 0.1, maxX = 100, maxY = 100, gravityX = 0, gravityY = 0.5}, rotateTowardVel = false, towardVelOffset = 0}, 
	["hyperspace"]		= {title = "hyperspace", isActive = true, build = buildHyperspace, x = screen.centerX, y = screen.centerY, color={{255, 255, 255}}, iterateColor = false, curColor = 1, emitDelay = 100, perEmit = 9, emissionNum = 0, lifeSpan = 1200, alpha = 0.5, startAlpha = 0, endAlpha = 1, onCreation = function()end, onDeath = function()end, propertyTable={}, scale = 1.0, lifeStart = 0, fadeInTime = 500, iteratePoint = false, curPoint = 1, lineDensity = "total", pointList={{0, 0}, {1, 1}}, positionType = "inRadius", posRadius = 1, posInner = 1, point1 = {100, screen.height}, point2 = {screen.width - 100, screen.height - 100}, rectLeft = 0, rectTop = 0, rectWidth = screen.width, rectHeight = screen.height, onUpdate = function()end, physics = {iterateAngle = false, xDamping=-0.1, yDamping=-0.1, velocity=-5, angularVelocity = 0, angularDamping = 0, velFunction = velNil, useFunction = false, autoAngle = true, angles={{0, 360}}, preCalculate = true, sizeX = 0.1, sizeY = 0, minX = 0.1, minY = 0.1, maxX = 100, maxY = 100, gravityX = 0, gravityY = 0}, rotateTowardVel = true, towardVelOffset = 90}, 
	["jitter"]				= {title = "jitter", x = screen.centerX, y = screen.centerY, isActive = true, build = buildPoison, color={{149, 255, 51}}, iterateColor = false, curColor = 1, emitDelay = 30, perEmit = 3, emissionNum = 0, lifeSpan = 500, alpha = 1, startAlpha = 0, endAlpha = 0, onCreation = function()end, onDeath = function()end, propertyTable = {blendMode = "screen"}, scale = 1.0, lifeStart = 0, fadeInTime = 1000, iteratePoint = false, curPoint = 1, lineDensity = "total", pointList={{0, 0}, {1, 1}}, positionType = "alongLine", posRadius = 30, posInner = 1, point1 = {screen.centerX - screen.centerX * 0.5, screen.centerY}, point2 = {screen.width - screen.centerX * 0.5, screen.centerY}, rectLeft = 0, rectTop = 0, rectWidth = screen.width, rectHeight = screen.height, onUpdate = function(p, v)p:applyForce(sin(p._numUpdates * 0.5 - 250),  0)end, physics = {iterateAngle = false, xDamping = 1, yDamping = 1, velocity = 2, angularVelocity = 0, angularDamping = 0, velFunction = velNil, useFunction = false, autoAngle = true, angles={{80, 100}}, preCalculate = true, sizeX=-0.005, sizeY=-0.005, minX = 0.1, minY = 0.1, maxX = 100, maxY = 100, gravityX = 0, gravityY=-0.005}, rotateTowardVel = false, towardVelOffset = 0}, 
	["lasergun"]			= {title = "lasergun", x = 0, y = screen.centerY, isActive = true, build = buildLGun, color={{255, 255, 0}}, iterateColor = false, curColor = 1, emitDelay = 100, perEmit = 1, emissionNum = 0, lifeSpan = 800, alpha = 1, startAlpha = 0, endAlpha = 1, onCreation = function()end, onDeath = function()end, propertyTable={}, scale = 1.0, lifeStart = 0, fadeInTime = 120, iteratePoint = false, curPoint = 1, lineDensity = "total", pointList={{0, 0}, {1, 1}}, positionType = "atPoint", posRadius = 30, posInner = 1, point1 = {1, 1}, point2 = {2, 1}, rectLeft = 0, rectTop = 0, rectWidth = screen.width, rectHeight = screen.height, onUpdate = function()end, physics = {iterateAngle = false, xDamping = 0, yDamping = 0, velocity = 30, angularVelocity = 0, angularDamping = 0, velFunction = velNil, useFunction = false, autoAngle = false, angles = {0}, preCalculate = true, sizeX = 0, sizeY = 0, minX = 0.2, minY = 0.2, maxX = 100, maxY = 100, gravityX = 0, gravityY = 0}, rotateTowardVel = false, towardVelOffset = 0}, 
	["rain"]					= {title = "rain", isActive = true, build = buildRain, x = 0, y = 0, color={{255, 255, 255}, {230, 230, 255}}, iterateColor = false, curColor = 1, emitDelay = 1, perEmit = 1, emissionNum = 0, lifeSpan = 2000, alpha = 0.3, startAlpha = 0.3, endAlpha = 0.3, onCreation = function()end, onDeath = function()end, propertyTable={}, scale = 1.0, lifeStart = 0, fadeInTime = 0, iteratePoint = false, curPoint = 1, lineDensity = "total", pointList={{0, 0}, {1, 1}}, positionType = "alongLine", posRadius = 30, posInner = 1, point1 = {0, -10}, point2 = {screen.width + 150, -10}, rectLeft = 0, rectTop = 0, rectWidth = screen.width, rectHeight = screen.height, onUpdate = function()end, physics = {iterateAngle = false, xDamping = 0, yDamping = 0, velocity = 10, angularVelocity = 0.04, angularDamping = 0, velFunction = velNil, useFunction = false, autoAngle = true, angles={{250, 260}}, preCalculate = true, sizeX = 0, sizeY = 0, minX = 0.1, minY = 0.1, maxX = 100, maxY = 100, gravityX = 0, gravityY = 0}, rotateTowardVel = false, towardVelOffset = 0}, 
	["smoke"]					= {title = "smoke", isActive = true, build = buildSmoke, x = 0, y = 0, color={{140/255}, {120/255}, {100/255}, {80/255}}, iterateColor = false, curColor = 1, emitDelay = 100, perEmit = 3, emissionNum = 0, lifeSpan = 1200, alpha = 1, startAlpha = 0, endAlpha = 0, onCreation = function()end, onDeath = function()end, propertyTable={}, scale = 1.0, lifeStart = 0, fadeInTime = 700, iteratePoint = false, curPoint = 1, lineDensity = "total", pointList={{0, 0}, {1, 1}}, positionType = "alongLine", posRadius = 30, posInner = 1, point1 = {200, screen.height - 100}, point2 = {screen.width - 200, screen.height - 100}, rectLeft = 0, rectTop = 0, rectWidth = screen.width, rectHeight = screen.height, onUpdate = function()end, physics = {iterateAngle = false, xDamping = 0.2, yDamping = 0.2, velocity = 6, angularVelocity = 0.04, angularDamping = 0, velFunction = velNil, useFunction = false, autoAngle = true, angles={{75, 105}}, preCalculate = true, sizeX = 0.015, sizeY = 0.015, minX = 0.1, minY = 0.1, maxX = 100, maxY = 100, gravityX = 0, gravityY = 0}, rotateTowardVel = false, towardVelOffset = 0}, 
	["snow"]					= {title = "snow", isActive = true, build = buildSnow, x = 0, y = 0, color={{255, 255, 255}, {230, 230, 255}}, iterateColor = false, curColor = 1, emitDelay = 1, perEmit = 1, emissionNum = 0, lifeSpan = 2000, alpha = 0.3, startAlpha = 0, endAlpha = 0, onCreation = function()end, onDeath = function()end, propertyTable={}, scale = 1.0, lifeStart = 0, fadeInTime = 300, iteratePoint = false, curPoint = 1, lineDensity = "total", pointList={{0, 0}, {1, 1}}, positionType = "alongLine", posRadius = 30, posInner = 1, point1 = {0, -10}, point2 = {screen.width + 150, -10}, rectLeft = 0, rectTop = 0, rectWidth = screen.width, rectHeight = screen.height, onUpdate = function()end, physics = {iterateAngle = false, xDamping = 0, yDamping = 0, velocity = 0, angularVelocity = 0.04, angularDamping = 0, velFunction = velSnow, useFunction = true, autoAngle = true, angles={{250, 260}}, preCalculate = true, sizeX = 0, sizeY = 0, minX = 0.1, minY = 0.1, maxX = 100, maxY = 100, gravityX = 0, gravityY = 0}, rotateTowardVel = false, towardVelOffset = 0}, 
	["sparks"]				= {title = "sparks", isActive = true, build = buildSparks, x = screen.centerX, y = screen.centerY, color={{1, 1, 1}, {230/255, 230/255, 1}}, iterateColor = false, curColor = 1, emitDelay = 1000, perEmit = 6, emissionNum = 0, lifeSpan = 1000, alpha = 1, startAlpha = 0, endAlpha = 0, onCreation = function()end, onDeath = function(p, v)v.perEmit = math.random(5, 15)end, propertyTable={}, scale = 1.0, lifeStart = 0, fadeInTime = 300, iteratePoint = false, curPoint = 1, lineDensity = "total", pointList={{0, 0}, {1, 1}}, positionType = "inRadius", posRadius = 30, posInner = 1, point1 = {100, screen.height}, point2 = {screen.width - 100, screen.height}, rectLeft = 0, rectTop = 0, rectWidth = screen.width, rectHeight = screen.height, onUpdate = function()end, physics = {iterateAngle = false, xDamping = 0, yDamping = 0, velocity = 5, angularVelocity = 0.04, angularDamping = 0, velFunction = velNil, useFunction = false, autoAngle = true, angles={{0, 360}}, preCalculate = true, sizeX = 0, sizeY = 0, minX = 0.1, minY = 0.1, maxX = 100, maxY = 100, gravityX = 0, gravityY = 0.5}, rotateTowardVel = false, towardVelOffset = 0}, 
	["steam"]					= {title = "steam", isActive = true, build = buildSteam, x = screen.centerX, y = screen.height, color={{255}, {230}, {200}}, iterateColor = false, curColor = 1, emitDelay = 50, perEmit = 10, emissionNum = 0, lifeSpan = 800, alpha = 1, startAlpha = 0, endAlpha = 0, onCreation = function()end, onDeath = function()end, propertyTable={}, scale = 1.0, lifeStart = 0, fadeInTime = 200, iteratePoint = false, curPoint = 1, lineDensity = "total", pointList={{0, 0}, {1, 1}}, positionType = "inRadius", posRadius = 30, posInner = 1, point1 = {100, screen.height - 100}, point2 = {screen.width - 100, screen.height - 100}, rectLeft = 0, rectTop = 0, rectWidth = screen.width, rectHeight = screen.height, onUpdate = function()end, physics = {iterateAngle = false, xDamping = 0, yDamping = 0, velocity = 12.5, angularVelocity = 0.04, angularDamping = 0, velFunction = velNil, useFunction = false, autoAngle = true, angles={{85, 95}}, preCalculate = true, sizeX = 0.05, sizeY = 0.05, minX = 0.1, minY = 0.1, maxX = 100, maxY = 100, gravityX = 0, gravityY = 0}, rotateTowardVel = false, towardVelOffset = 0}, 
	["water"]					= {title = "water", x = 0, y = 0, isActive = true, build = buildWater, color={{255, 255, 255}, {200, 200, 200}}, iterateColor = false, curColor = 1, emitDelay = 1, perEmit = 2, emissionNum = 0, lifeSpan = 500, alpha = 0.5, startAlpha = 0, endAlpha = 0, onCreation = function(particle) local a = (particle.y - (screen.height / 3))/500 + 0.05 if a <= 0.2 then particle.isVisible = false else particle.yScale = a end end, onDeath = function()end, propertyTable={}, scale = 1.0, lifeStart = 0, fadeInTime = 500, iteratePoint = false, curPoint = 1, lineDensity = "total", pointList={{0, 0}, {1, 1}}, positionType = "inRect", posRadius = 30, posInner = 1, point1 = {1, 1}, point2 = {2, 1}, rectLeft = 0, rectTop = screen.height / 3, rectWidth = screen.width, rectHeight = screen.height - (screen.height / 3), onUpdate = function(particle)local a = (particle.y - (screen.height / 3))/500 + 0.05 if a <= 0 then particle.xScale = 1 particle.isVisible = false else particle.yScale = a end end, physics = {iterateAngle = false, xDamping = 0, yDamping = 0, velocity = 1, angularVelocity = 0, angularDamping = 0, velFunction = velNil, useFunction = false, autoAngle = true, angles={{-20, 20}, {160, 200}}, preCalculate = true, sizeX = 0, sizeY = 0, minX = 0.1, minY = 0.1, maxX = 100, maxY = 100, gravityX = 0, gravityY = 0}, rotateTowardVel = false, towardVelOffset = 0}, 
	["waterfall"]			= {title = "waterfall", isActive = true, build = buildSteam, x = display.screenOriginX, y = 100, color={{255, 255, 255}, {230, 230, 255}, {222, 222, 255},  {230, 255, 255}}, iterateColor = false, curColor = 1, emitDelay = 50, perEmit = 3, emissionNum = 0, lifeSpan = 2000, alpha = 1, startAlpha = 0, endAlpha = 0, onCreation = function()end, onDeath = function()end, propertyTable={}, scale = 1.0, lifeStart = 0, fadeInTime = 200, iteratePoint = false, curPoint = 1, lineDensity = "total", pointList={{0, 0}, {1, 1}}, positionType = "inRadius", posRadius = 30, posInner = 1, point1 = {100, screen.height - 100}, point2 = {screen.width - 100, screen.height - 100}, rectLeft = 0, rectTop = 0, rectWidth = screen.width, rectHeight = screen.height, onUpdate = function()end, physics = {iterateAngle = false, xDamping = 0, yDamping = 0, velocity = 2.5, angularVelocity = 0.04, angularDamping = 0, velFunction = velNil, useFunction = false, autoAngle = true, angles={{0, 0}}, preCalculate = true, sizeX = 0.03, sizeY = 0.06, minX = 0.1, minY = 0.1, maxX = 5, maxY = 4, gravityX = 0, gravityY = 0.5}, rotateTowardVel = false, towardVelOffset = 0}, 
	["wisps"]					= {title = "wisps", x = screen.centerX, y = screen.height - (screen.height / 7), isActive = true, build = buildWisp, color={{255, 255, 0}, {0, 255, 0}}, iterateColor = false, curColor = 1, emitDelay = 30, perEmit = 1, emissionNum = 0, lifeSpan = 800, alpha = 1, startAlpha = 0, endAlpha = 0, onCreation = function()end, onDeath = function()end, propertyTable = {blendMode = "add"}, scale = 1.0, lifeStart = 0, fadeInTime = 1500, iteratePoint = false, curPoint = 1, lineDensity = "total", pointList={{0, 0}, {1, 1}}, positionType = "inRadius", posRadius = 30, posInner = 1, point1 = {1, 1}, point2 = {2, 1}, rectLeft = 0, rectTop = 0, rectWidth = screen.width, rectHeight = screen.height, onUpdate = function(particle,  vent)particle:applyForce((vent.x * 0.01) - (particle.x * 0.01),  0)end, physics = {iterateAngle = false, xDamping = 0, yDamping = 0, velocity = 1.5, angularVelocity = 0, angularDamping = 0, velFunction = velNil, useFunction = false, autoAngle = true, angles={{30, 150}}, preCalculate = true, sizeX = 0, sizeY = 0, minX = 0.1, minY = 0.1, maxX = 100, maxY = 100, gravityX = 0, gravityY=-0.02}, rotateTowardVel = false, towardVelOffset = 0}
}

-- Field Presets
ParticleHelper.presets.fields={
	["default"]				= {title = "default", shape = "circle", radius = 100, x = screen.centerX, y = screen.centerY, innerRadius = 1, rectLeft = 0, rectTop = 0, rectWidth = 100, rectHeight = 100, singleEffect = false, points = {0, 0, 500, 500, 500, 0}, onFieldInit = function(f)f.magnitude = 0.5 end, onCollision = function(p, f)p:applyForce((f.x - p.x) * f.magnitude,  (f.y - p.y) * f.magnitude)end}, 
	["out"]						= {title = "out", shape = "circle", radius = 100, x = screen.centerX, y = screen.centerY, innerRadius = 1, rectLeft = 0, rectTop = 0, rectWidth = 100, rectHeight = 100, singleEffect = false, points = {0, 0, 500, 500, 500, 0}, onFieldInit = function(f)f.magnitude = 0.5 end, onCollision = function(p, f)p:applyForce((p.x - f.x) * f.magnitude,  (p.y - f.y) * f.magnitude)end}, 
	["colorChange"]		= {title = "colorChange", shape = "rect", radius = 100, x = screen.centerX, y = screen.centerY, innerRadius = 1, rectLeft = 0, rectTop = 0, rectWidth = 512, rectHeight = 768, singleEffect = true, points = {0, 0, 500, 500, 500, 0}, onCollision = function(p, f)p.colorChange({0,  0,  255},  500,  0)end}, 
	["rotate"]				= {title = "rotate", shape = "circle", radius = 150, x = screen.centerX, y = screen.centerY, innerRadius = 1, rectLeft = 0, rectTop = 0, rectWidth = 512, rectHeight = 768, singleEffect = false, points = {0, 0, 500, 500, 500, 0}, onCollision = function(p, f)p:rotate(2)end}, 
	["stop"]					= {title = "stop", shape = "circle", radius = 150, x = screen.centerX, y = screen.centerY, innerRadius = 1, rectLeft = 0, rectTop = 0, rectWidth = 512, rectHeight = 768, singleEffect = false, points = {0, 0, 500, 500, 500, 0}, onCollision = function(p, f)p:setLinearVelocity(p._particlephysics.velX * 0.8, p._particlephysics.velY * 0.8)end}, 
}


-- Finish Up
function ParticleHelper._onEnterFrame()
	if ParticleHelper.calcDeltaTime then
		updateDelta()
	end
	
	for k, v in pairs(ParticleHelper.physics.set) do
		if ParticleHelper.physics.set[k].active then -- Update each pPhysics if active
			ParticleHelper.physics.set[k].loop()
		end
	end
end

Runtime:addEventListener("enterFrame", ParticleHelper._onEnterFrame)
updateDelta()

return ParticleHelper