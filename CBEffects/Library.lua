--[[
CBEffects/Library.lua

The main CBEffects library.

Version 2.0.1
--]]

local CBEffects = {}
CBEffects.calcDeltaTime = true

--Set up random generator
math.randomseed(os.time())
local mrand = math.random

--Localization
local ParticleHelper = require("s3_utils.CBEffects.ParticleHelper")
ParticleHelper.setCalcDeltaTime(CBEffects.calcDeltaTime)

local masterPresets				 =  ParticleHelper.presets
local masterPhysics				 =  ParticleHelper.physics
local masterFunctions			 =  ParticleHelper.functions
	local pointInRect					 =  masterFunctions.pointInRect
	local fnn									 =  masterFunctions.fnn
	local lengthOf						 =  masterFunctions.lengthOf
	local pointsAlongLine			 =  masterFunctions.pointsAlongLine
	local forcesByAngle				 =  masterFunctions.forcesByAngle
	local either							 =  masterFunctions.either
	local inRadius						 =  masterFunctions.inRadius
	local inRect							 =  masterFunctions.inRect
	local getValue						 =  masterFunctions.getValue
	local newTitle						 =  masterFunctions.newTitle

local transition_to				 =  transition.to
local transition_cancel		 =  transition.cancel
local timer_pwd						 =  timer.performWithDelay
local pairs								 =  pairs
local type								 =  type
local table_insert				 =  table.insert

--CBEffects Public Function Localization
local NewVent
local NewField
local VentGroup
local FieldGroup
local DemoPreset

local NilVentGroup
local NilFieldGroup
local NilDemoPreset

local Render
local VentX
local FieldX

-- NewVent()
function NewVent(params)
	local params  =  params
	local preset = masterPresets.vents[params.preset] or masterPresets.vents.default
	local vent

	params.physics = params.physics or {}

	vent = {
		particle = {},
		velAngles = {},
	--Normal Parameters
		x								 = fnn( params.x, preset.x, 0 ),
		y								 = fnn( params.y, preset.y, 0 ),
		build            = fnn( params.build, preset.build, function()return display.newRect(0, 0, 10, 10) end ),
		color            = fnn( params.color, preset.color, {{1, 1, 1}} ),
		iterateColor		 = fnn( params.iterateColor, preset.iterateColor, false ),
		curColor				 = fnn( params.curColor, preset.curColor, 1 ),
		colorIncr				 = fnn( params.colorIncr, preset.colorIncr, 1 ),
		hasColor				 = fnn( params.hasColor, preset.hasColor, true ),
		isActive				 = fnn( params.isActive, preset.isActive, true ),
		title						 = fnn( params.title, preset.title, "vent" ),
		emitDelay        = fnn( params.emitDelay, preset.emitDelay, 500 ),
		perEmit          = fnn( params.perEmit, preset.perEmit, 5 ),
		emissionNum      = fnn( params.emissionNum, preset.emissionNum, 50 ),
		lifeSpan	       = fnn( params.lifeSpan, preset.lifeSpan, 1000 ),
		alpha            = fnn( params.alpha, preset.alpha, 1),
		startAlpha       = fnn( params.startAlpha, preset.startAlpha, 0 ),
		endAlpha         = fnn( params.endAlpha, preset.endAlpha, 0 ),
		lifeStart        = fnn( params.lifeStart, preset.lifeStart, 1000),
		fadeInTime       = fnn( params.fadeInTime, preset.fadeInTime, 500 ),
		onCreation       = fnn( params.onCreation, preset.onCreation, function()end ),
		onDeath	      	 = fnn( params.onDeath, preset.onDeath, function()end ),
		onUpdate				 = fnn( params.onUpdate, preset.onUpdate, function()end ),
		propertyTable    = fnn( params.propertyTable, preset.propertyTable, {} ),
		scale						 = fnn( params.scale, preset.scale, 1 ),
		scaleX					 = fnn( params.scaleX, params.scale or preset.scaleX, preset.scaleX, 1),
		scaleY					 = fnn( params.scaleY, params.scale or preset.scaleY, preset.scaleY, 1),
		parentGroup			 = fnn( params.parentGroup ), -- The fnn() call is not needed; it just makes the line of values look a lot nicer
		positionType     = fnn( params.positionType, preset.positionType, "alongLine"),
		pointList				 = fnn( params.pointList, preset.pointList, {{0,0},{5,5},{10,10},{20,20}} ),
		iteratePoint		 = fnn( params.iteratePoint, preset.iteratePoint, false ),
		curPoint				 = fnn( params.curPoint, preset.curPoint, 1 ),
		pointIncr				 = fnn( params.pointIncr, preset.pointIncr, 1 ),
		point1         	 = fnn( params.point1, preset.point1, {0,0} ),
		point2         	 = fnn( params.point2, preset.point2, {500, 0} ),
		offsetAlongLine	 = fnn( params.offsetAlongLine, preset.offsetAlongLine, false ),
		lineDensity			 = fnn( params.lineDensity, preset.lineDensity, "total" ),
		posRadius        = fnn( params.posRadius, preset.posRadius, 10 ),
		posInner         = fnn( params.posInner, preset.posInner, 1 ),
		rectLeft         = fnn( params.rectLeft, preset.rectLeft, 0 ),
		rectTop          = fnn( params.rectTop, preset.rectTop, 0 ),
		rectWidth        = fnn( params.rectWidth, preset.rectWidth, 50 ),
		rectHeight       = fnn( params.rectHeight, preset.rectHeight, 50 ),
		rotateTowardVel  = fnn( params.rotateTowardVel, preset.rotateTowardVel, false ),
		towardVelOffset  = fnn( params.towardVelOffset, preset.towardVelOffset, 0 ),
		onVentInit			 = fnn( params.onVentInit, preset.onVentInit, function()end ),
		
		--Physics Parameters
		linearDamping    = fnn( params.physics.linearDamping, preset.physics.linearDamping, 1 ),
		xDamping				 = fnn( params.physics.xDamping, fnn(params.physics.linearDamping, preset.physics.linearDamping, 1), preset.physics.xDamping, preset.physics.linearDamping ),
		yDamping				 = fnn( params.physics.yDamping, fnn(params.physics.linearDamping, preset.physics.linearDamping, 1), preset.physics.yDamping, preset.physics.linearDamping ),
		density          = fnn( params.physics.density, preset.physics.density, 1 ),
		velocity         = fnn( params.physics.velocity, preset.physics.velocity, 15 ),
		angularVelocity  = fnn( params.physics.angularVelocity, preset.physics.angularVelocity, 0 ),
		angularDamping   = fnn( params.physics.angularDamping, preset.physics.angularDamping, 0 ),
		sizeX            = fnn( params.physics.sizeX, preset.physics.sizeX, 0.01 ),
		sizeY            = fnn( params.physics.sizeY, preset.physics.sizeY, 0.01 ),
		maxX             = fnn( params.physics.maxX, preset.physics.maxX, 3 ),
		maxY             = fnn( params.physics.maxY, preset.physics.maxY, 3 ),
		minX             = fnn( params.physics.minX, preset.physics.minX, 0.1 ),
		minY             = fnn( params.physics.minY, preset.physics.minY, 0.1 ),
		velFunction      = fnn( params.physics.velFunction, preset.physics.velFunction, function()end ),
		useFunction      = fnn( params.physics.useFunction, preset.physics.useFunction, false ),
		relativeToSize	 = fnn( params.physics.relativeToSize, preset.physics.relativeToSize, false ),
		divisionDamping  = fnn( params.physics.divisionDamping, preset.physics.divisionDamping, true ),
		autoAngle      	 = fnn( params.physics.autoAngle, preset.physics.autoAngle, false ),
		angles           = fnn( params.physics.angles, preset.physics.angles, {1} ),
		preCalculate		 = fnn( params.physics.preCalculate, preset.physics.preCalculate, true ),
		iterateAngle		 = fnn( params.physics.iterateAngle, preset.physics.iterateAngle, false ),
		curAngle				 = fnn( params.physics.curAngle, preset.physics.curAngle, 1 ),
		angleIncr				 = fnn( params.physics.angleIncr, preset.physics.angleIncr, 1 ),
		gravX            = fnn( params.physics.gravityX, preset.physics.gravityX, 0 ),
		gravY            = fnn( params.physics.gravityY, preset.physics.gravityY, 9.8 )
	}
	
	--Set Up Angles
	if vent.autoAngle then
		for w = 1, #vent.angles do
			for a = vent.angles[w][1], vent.angles[w][2] do
				if vent.preCalculate then
					table_insert(vent.velAngles, forcesByAngle(vent.velocity, a))
				else
					table_insert(vent.velAngles, a)
				end
			end
		end
	else
		if vent.preCalculate then
			for a = 1, #vent.angles do
				table_insert(vent.velAngles, forcesByAngle(vent.velocity, vent.angles[a]))
			end
		else
			for a = 1, #vent.angles do
				table_insert(vent.velAngles, vent.angles[a])
			end
		end
	end

	--ParticlePhysics Creation
	vent.pPhysics = masterPhysics.createPhysics()
	vent.pPhysics.start()
	vent.pPhysics.setGravity(vent.gravX * vent.scale, vent.gravY * vent.scale)
	vent.pPhysics.parentVent = vent
	vent.pPhysics.useDivisionDamping = vent.divisionDamping
	
	--Completion & Miscellaneous Variables
	vent.roundNum				 =  0
	vent.content				 =  display.newGroup()
	vent.content.x			 = fnn( params.contentX, preset.contentX, 0 )
	vent.content.y			 = fnn( params.contentY, preset.contentY, 0 ) 
	vent.pointTable			 =  pointsAlongLine(vent.point1[1] * vent.scaleX, vent.point1[2] * vent.scaleY, vent.point2[1] * vent.scaleX, vent.point2[2] * vent.scaleY, vent.lineDensity)
	if vent.parentGroup then vent.parentGroup:insert(vent.content)  end
	if not vent.hasColor then vent.color = {{1,1,1}} end -- Check for hasColor

	-- Emit Function
	vent.emit = function()
		for l = 1, vent.perEmit do
			vent.roundNum = l -- Number that tells which particle is being emitted
			
			local e = newTitle()
			while vent.particle[e] do e = newTitle() end
			-- Create and Set Up Particle
			vent.particle[e] = vent.build(vent)
			
			vent.particle[e]._ventTitle = e
			vent.particle[e].xScale = vent.scaleX
			vent.particle[e].yScale = vent.scaleY
				
			-- Add ParticlePhysics
			vent.pPhysics.addBody(vent.particle[e], {
				xbL = getValue(vent.maxX) * vent.scaleX,
				ybL = getValue(vent.maxY) * vent.scaleY,
				xbS = getValue(vent.minX) * vent.scaleX,
				ybS = getValue(vent.minY) * vent.scaleY,
				sizeX = getValue(vent.sizeX) * vent.scaleX,
				sizeY = getValue(vent.sizeY) * vent.scaleY,
				rotateToVel = getValue(vent.rotateTowardVel),
				offset = getValue(vent.towardVelOffset)
			})
			-- Finish up ParticlePhysics values
			vent.particle[e]._particlephysics.collided = false
			vent.particle[e]._particlephysics.xDamping = getValue(vent.xDamping)
			vent.particle[e]._particlephysics.yDamping = getValue(vent.yDamping)
			vent.particle[e]._particlephysics.angularDamping = getValue(vent.angularDamping)
			vent.particle[e]._particlephysics.angularVelocity = getValue(vent.angularVelocity)
			vent.particle[e]._lifeSpan = getValue(vent.lifeSpan)
			vent.particle[e]._lifeStart = getValue(vent.lifeStart)
			vent.particle[e].alpha = getValue(vent.startAlpha)
			-- Transfer values from vent's propertyTable
			for k, v in pairs(vent.propertyTable) do vent.particle[e][k] = vent.propertyTable[k] end
			
			if not vent.pPhysics.useDivisionDamping then
				vent.particle[e]._particlephysics.xDamping = vent.particle[e]._particlephysics.xDamping * vent.scaleX
				vent.particle[e]._particlephysics.yDamping = vent.particle[e]._particlephysics.yDamping * vent.scaleY
			end
				
			-- Position Particle
			if "inRadius" == vent.positionType then
				vent.particle[e].x, vent.particle[e].y = inRadius(vent.x, vent.y, vent.posRadius * vent.scale, vent.posInner * vent.scale)
			elseif "alongLine" == vent.positionType then
				local pPoint = either(vent.pointTable)
				vent.particle[e].x, vent.particle[e].y = pPoint[1] * vent.scaleX, pPoint[2] * vent.scaleY
				if vent.offsetAlongLine then vent.particle[e]:translate(vent.x, vent.y) end
			elseif "inRect" == vent.positionType then
				vent.particle[e].x, vent.particle[e].y = inRect(vent.x, vent.y, vent.rectLeft * vent.scaleX, vent.rectTop * vent.scaleY, vent.rectWidth * vent.scaleX, vent.rectHeight * vent.scaleY)
			elseif "atPoint" == vent.positionType then
				vent.particle[e].x, vent.particle[e].y = vent.x, vent.y
			elseif "fromPointList" == vent.positionType then
				if vent.iteratePoint then
					local pointX, pointY = vent.pointList[vent.curPoint][1] * vent.scaleX, vent.pointList[vent.curPoint][2] * vent.scaleY
					vent.particle[e].x, vent.particle[e].y = pointX + vent.x, pointY + vent.y
					vent.curPoint = (((vent.curPoint + vent.pointIncr) - 1) % (#vent.pointList)) + 1 -- Update curPoint
				else
					local point = either(vent.pointList) -- Choose random point
					vent.particle[e].x, vent.particle[e].y = vent.x + point[1] * vent.scaleX, vent.y + point[2] * vent.scaleY
				end
			elseif type(vent.positionType) == "function" then
				vent.particle[e].x, vent.particle[e].y = vent.positionType(vent.particle[e], vent, vent.content)
			end
				
			-- Color
			-- "Normal" display object
			if vent.particle[e]["setFillColor"] then
				vent.particle[e]._physicsColor = vent.particle[e]["setFillColor"]
--[=[
			-- Text object
			elseif vent.particle[e]["setTextColor"] then
				vent.particle[e]._physicsColor = vent.particle[e]["setTextColor"]
			-- Line object
			elseif vent.particle[e]["setColor"] then
				vent.particle[e]._physicsColor = vent.particle[e]["setColor"]
--]=]
			-- Group or other object
			else
				vent.particle[e]._physicsColor = function() end -- Make sure no errors occur
			end
			
			-- Set initial color
			if type(vent.color) == "table" then
				local pColor
				if vent.iterateColor then
					pColor = vent.color[vent.curColor]
						
					-- Update curColor
					vent.curColor = (((vent.curColor + vent.colorIncr) - 1) % (#vent.color)) + 1
				else
					pColor = either(vent.color)
				end
				vent.particle[e]._colorSet = {r = pColor[1] or 0, g = pColor[2] or pColor[1], b = pColor[3] or pColor[1], a = pColor[4] or 1}
				vent.particle[e]:_physicsColor(vent.particle[e]._colorSet[1], vent.particle[e]._colorSet[2], vent.particle[e]._colorSet[3], vent.particle[e]._colorSet[4])
			elseif type(vent.color) == "function" then
				vent.particle[e]:_physicsColor(vent.color())
			end
			-- Add colorChange function
			vent.particle[e].colorChange = function(colorTo, time, delay, trans)
				if vent.particle[e]._colorTrans then transition_cancel(vent.particle[e]._colorTrans) end
				if colorTo then
					vent.particle[e]._colorTrans = transition_to(vent.particle[e]._colorSet, {r = colorTo[1] or vent.particle[e]._colorSet.r, g = colorTo[2] or vent.particle[e]._colorSet.g, b = colorTo[3] or vent.particle[e]._colorSet.b, a = colorTo[4] or vent.particle[e]._colorSet.a, time = time or 1000, delay = delay or 0, transition = trans or easing.linear})
				end
			end
			
			-- Particle Kill Function
			--Destroy a particle
			vent.particle[e]._kill = function()
				-- Cancel transitions
				if vent.particle[e]._colorTrans then transition_cancel(vent.particle[e]._colorTrans) end; if vent.particle[e]._fadeInTrans then transition_cancel(vent.particle[e]._fadeInTrans) end; if vent.particle[e]._fadeOutTrans then transition_cancel(vent.particle[e]._fadeOutTrans) end
				display.remove(vent.particle[e])
				vent.pPhysics.removeBody(vent.particle[e])
				vent.particle[e] = nil
			end
			
			-- Set Particle Velocity
			if vent.useFunction == true then
				local xVel, yVel = vent.velFunction(vent.particle[e], vent, vent.content)
				vent.particle[e]:setLinearVelocity(xVel * vent.scaleX, yVel * vent.scaleY)
			else
				if not vent.iterateAngle then -- Pick a random angle
					if vent.preCalculate == true then
						vent.particle[e].angleTable = either(vent.velAngles)
						vent.particle[e]:setLinearVelocity(vent.particle[e].angleTable.x * vent.scaleX, vent.particle[e].angleTable.y * vent.scaleY)
					else
						vent.particle[e].angle = either(vent.velAngles)
						vent.particle[e].velTable = forcesByAngle(vent.velocity, vent.particle[e].angle)
						vent.particle[e]:setLinearVelocity(vent.particle[e].velTable.x * vent.scaleX, vent.particle[e].velTable.y * vent.scaleY)
					end
				else
					if vent.preCalculate == true then -- Pick the next angle in sequence
						vent.particle[e].angleTable = vent.velAngles[vent.curAngle]
						vent.particle[e]:setLinearVelocity(vent.particle[e].angleTable.x * vent.scaleX, vent.particle[e].angleTable.y * vent.scaleY)
					else
						vent.particle[e].angle = vent.velAngles[vent.curAngle]
						vent.particle[e].velTable = forcesByAngle(vent.velocity, vent.particle[e].angle)
						vent.particle[e]:setLinearVelocity(vent.particle[e].velTable.x * vent.scaleX, vent.particle[e].velTable.y * vent.scaleY)
					end
					-- Update curAngle
					vent.curAngle = (((vent.curAngle + vent.angleIncr) - 1) % (#vent.velAngles)) + 1
				end
			end

			-- Add Particle Transitions
			-- Create the particle's fade in transition
			vent.particle[e]._fadeInTrans = transition_to(vent.particle[e], {alpha = vent.alpha, time = vent.fadeInTime})
			-- Create the particle's fade out transition
			vent.particle[e]._fadeOutTrans = transition_to(vent.particle[e], {alpha = vent.endAlpha, time = vent.particle[e]._lifeSpan, delay = vent.particle[e]._lifeStart + vent.fadeInTime, onComplete = function() vent.onDeath(vent.particle[e], vent) vent.particle[e]._kill() end})
				
			-- Finish Up
			vent.onCreation(vent.particle[e], vent, vent.content)
			vent.content:insert(vent.particle[e])
				
		end
		vent.roundNum = 0 -- Reset roundNum
	end
	
	-- Reset Points
	vent.resetPoints = function()
		vent.pointTable = pointsAlongLine(vent.point1[1] * vent.scaleX, vent.point1[2] * vent.scaleY, vent.point2[1] * vent.scaleX, vent.point2[2] * vent.scaleY, vent.lineDensity)
	end
	
	-- Reset Angles
	vent.resetAngles = function()
		if vent.autoAngle then
			for w = 1, #vent.angles do
				for a = vent.angles[w][1], vent.angles[w][2] do
					if vent.preCalculate then
						table_insert(vent.velAngles, forcesByAngle(vent.velocity, a))
					else
						table_insert(vent.velAngles, a)
					end
				end
			end
		else
			if vent.preCalculate then
				for a = 1, #vent.angles do
					table_insert(vent.velAngles, forcesByAngle(vent.velocity, vent.angles[a]))
				end
			else
				for a = 1, #vent.angles do
					table_insert(vent.velAngles, vent.angles[a])
				end
			end
		end
	end
	
	-- Set
	vent.set = function(params)
		for k, v in pairs(params) do
			vent[k] = params[k]
		end
	end

	-- Start
	vent.start = function()
		if vent.particleTimer then timer.cancel(vent.particleTimer) end
		vent.particleTimer = timer_pwd(vent.emitDelay, vent.emit, vent.emissionNum)
	end

	-- Stop
	vent.stop = function()
		if vent.particleTimer then timer.cancel(vent.particleTimer) end
	end

	-- Clean
	vent.clean = function()
		for k, v in pairs(vent.particle) do
			if vent.particle[k] then
				vent.particle[k]._kill()
			end
		end
	end

	-- Destroy
	vent.destroy = function()
		vent.clean()
		if vent.particleTimer then
			timer.cancel(vent.particleTimer)
			vent.particleTimer = nil
		end
		vent.pPhysics.cancel()
		vent.pPhysics = nil
		display.remove(vent.content)
		vent.content = nil
		for k, v in pairs(vent) do
			vent[k] = nil
		end
		vent = nil
		return true
	end

	vent.onVentInit(vent)

	return vent
end


-- NewField()
function NewField(params)
	local fieldParams = {}

	local preset = masterPresets.fields[params.preset] or masterPresets.fields["default"]

	fieldParams.shape								 = fnn( params.shape, preset.shape, "rect" )
	fieldParams.rectWidth						 = fnn( params.rectWidth, preset.rectWidth, 	100 )
	fieldParams.rectHeight					 = fnn( params.rectHeight, 	preset.rectHeight, 100 )
	fieldParams.x										 = fnn( params.x, preset.x, 0 )
	fieldParams.y										 = fnn( params.y, preset.y, 0 )
	fieldParams.radius							 = fnn( params.radius, preset.radius, 50 )
	fieldParams.points							 = fnn( params.points, preset.points, {0, 	0, 500, 500, 500, 0} )
	fieldParams.onCollision					 = fnn( params.onCollision, 	preset.onCollision, function()end )
	fieldParams.singleEffect		 		 = fnn( params.singleEffect, 	preset.singleEffect, false )
	fieldParams.onFieldInit					 = fnn( params.onFieldInit, 	preset.onFieldInit, function()end )

	local targetVent = params.targetVent
	fieldParams.targetPhysics = targetVent.pPhysics

	local field 										 = masterPhysics.createCollisionSensor(fieldParams)
	field.title											 = fnn(params.title, preset.title, "field")

	function field:set(params)
		for k, v in pairs(params) do
			field[k] = params[k]
		end
	end
	
	fieldParams.onFieldInit(field)
	
	return field
end


-- VentGroup()
function VentGroup(params)
	local master = {}
	local vent = {}
	local titleReference = {}

	local params = params or {}	
	local numVents = #params
		
	for i = 1, numVents do
		vent[i] = NewVent(params[i])
		titleReference[vent[i].title] = vent[i]
		master[vent[i].title] = vent[i].emit -- Add a convenience function to the master
	end


	-- master:startMaster()
	function master:startMaster()
		for i = 1, numVents do
			if vent[i] then
				if vent[i].isActive == true then
					vent[i].start()
				end
			end
		end
	end
	

	-- master:emitMaster()
	function master:emitMaster()
		for i = 1, numVents do
			if vent[i] then
				if vent[i].isActive == true then
					vent[i].emit()
				end
			end
		end
	end
	

	-- master:stopMaster()
	function master:stopMaster()
		for i = 1, numVents do
			if vent[i] then
				if vent[i].particleTimer then
					timer.cancel(vent[i].particleTimer)
				end
			end
		end
	end
	

	-- master:start()
	function master:start(...)
		for i = 1, #arg do
			local t = arg[i]
			if titleReference[t] then
				titleReference[t].start()
			elseif not titleReference[t] then
				print("master:start() - Missing vent \""..t.."\"")
			end
		end
	end


	-- master:emit()	
	function master:emit(...)
		for i = 1, #arg do
			local t = arg[i]
			if titleReference[t] then
				titleReference[t].emit()
			elseif not titleReference[t] then
				print("master:emit() - Missing vent \""..t.."\"")
			end
		end
	end
	

	-- master:stop()
	function master:stop(...)
		for i = 1, #arg do
			local t = arg[i]
			if titleReference[t] then
				if titleReference[t].particleTimer then
					timer.cancel(titleReference[t].particleTimer)
				end
			elseif not titleReference[t] then
				print("master:stop() - Missing vent \""..t.."\"")
			end
		end
	end
	

	-- master:get()
	function master:get(...)
		local getTable = {}
		for i = 1, #arg do
			local t = arg[i]
			if titleReference[t] then
				getTable[i] = titleReference[t]
			else
				getTable[i] = "master:get() - Missing vent \""..t.."\""
				print(getTable[i])
			end
		end
		return unpack(getTable)
	end
	

	-- master:clean()
	function master:clean(...)
		for i = 1, #arg do
			local t = arg[i]
			if titleReference[t] then
				titleReference[t].clean()
				titleReference[t].e = 1
			else
				print("master:clean() - Missing vent \""..t.."\"")
			end
		end
	end	
	

	-- master:destroy()
	function master:destroy(...)
		for i = 1, #arg do
			local t = arg[i]
			if titleReference[t] then
				master:clean(t)
				if titleReference[t].particleTimer then
					timer.cancel(titleReference[t].particleTimer)
					titleReference[t].particleTimer = nil
				end
				titleReference[t].pPhysics.cancel()
				titleReference[t].pPhysics = nil
				display.remove(titleReference[t].content)
				titleReference[t].content = nil
				for k, v in pairs(titleReference[t]) do
					titleReference[t][k] = nil
				end
				titleReference[t] = nil
				return true
			else
				print("master:destroy() - Missing vent \""..t.."\"")
			end
			t = nil
		end
	end
	

	-- master:destroyMaster()
	function master:destroyMaster()
		for i = 1, #vent do
			master:destroy(vent[i].title)
		end
		for k, v in pairs(master) do
			master[k] = nil
		end
		for k, v in pairs(titleReference) do
			titleReference[k] = nil
		end
		vent = nil
		master = nil
		titleReference = nil
		numVents = nil
	end
	

	-- master:move()
	function master:move(t, x, y)
		if titleReference[t] then
			titleReference[t].x, titleReference[t].y = x or display.contentCenterX, y or display.contentCenterY
		else
			print("master:move() - Missing vent \""..t.."\"")
		end
	end

	master.translate = master.move

	return master
end


-- FieldGroup()
function FieldGroup(params)
	local numFields = #params
	local master = {}
	local titleReference = {}
	
	for i = 1, numFields do
		master[i] = NewField(params[i])
		titleReference[master[i].title] = master[i]
	end

	-- master:move()
	function master:move(t, x, y)
		if titleReference[t] then
			titleReference[t].x, titleReference[t].y = x, y
		elseif not titleReference[t] then
			print("Missing field \""..t.."\"")
		end
	end
	
	master.translate = master.move


	-- master:start()
	function master:start(...)
		for i = 1, #arg do
			local t = arg[i]
			if titleReference[t] then
				titleReference[t]:start()
			elseif not titleReference[t] then
				print("Missing field \""..t.."\"")
			end	
		end
	end


	-- master:stop()
	function master:stop(...)
		for i = 1, #arg do
			local t = arg[i]
			if titleReference[t] then
				titleReference[t].stop()
			elseif not titleReference[t] then
				print("Missing field \""..t.."\"")
			end
		end
	end


	-- master:destroy()
	function master:destroy(...)
		for i = 1, #arg do
			if titleReference[arg[i]] then
				titleReference[arg[i]].cancel()
				titleReference[arg[i]] = nil
			elseif not titleReference[arg[i]] then
				print("Missing field \""..arg[i].."\"")
			end
		end
	end
	

	-- master:startMaster()
	function master:startMaster()
		for i = 1, #master do
			master[i]:start()
		end
	end


	-- master:stopMaster()
	function master:stopMaster()
		for i = 1, #master do
			master[i]:stop()
		end
	end


	-- master:destroyMaster()
	function master:destroyMaster()
		for i = 1, #master do
			master:destroy(master[i].title)
		end
		for k, v in pairs(master) do
			master[k] = nil
		end
		master = nil
	end


	-- master:get()
	function master:get(...)
		local getTable = {}
		for i = 1, #arg do
			local t = arg[i]
			if titleReference[t] then
				getTable[i] = titleReference[t]
			else
				getTable[i] = "Missing field \""..t.."\""
				print(getTable[i])
			end
		end
		return unpack(getTable)
	end

	return master
end


--Builds and returns a preset Vent without parameter additions and starts it; for browsing presets
function DemoPreset(preset)
	local presetVent = NewVent{
		preset = preset
	}
	presetVent:start()
	return presetVentGroup
end


-- TODO: Update the dummy functions for NewVent and NewField
--Returns a fake VentGroup that does nothing
function NilVentGroup(params)
	local master = {}; local vent = {}; local titleReference = {}; local numVents = #params; for i = 1, numVents do vent[i] = {} vent[i].pPhysics = {start = function()end,pause = function()end,cancel = function()end,setGravity = function()end,addBody = function()end,removeBody = function()end} vent[i].title = fnn(params[i].title,params[i].preset,"vent"..i) titleReference[vent[i].title] = vent[i] vent[i].content = {} vent[i].emit = function()end vent[i].resetPoints = function()end vent[i].set = function()end master[vent[i].title] = vent[i].emit end function master:startMaster()end function master:emitMaster()end function master:stopMaster()end function master:start()end function master:emit()end function master:stop()end function master:get(...) local getTable = {} for i = 1, #arg do local t = arg[i] if titleReference[t] then getTable[i] = titleReference[t] else getTable[i] = "Missing vent \""..t.."\"" print(getTable[i]) end end return unpack(getTable) end function master:clean()end function master:destroy(...) for i = 1, #arg do local t = arg[i] if titleReference[t] then titleReference[t] = nil return true else print("Missing vent \""..t.."\"") end end end function master:destroyMaster() for i = 1, #vent do master:destroy(vent[i].title) end for k, v in pairs(master) do master[k] = nil end master = nil end function master:translate()end return master
end


--Returns a fake FieldGroup that does nothing
local function NilFieldGroup(params)
	local numFields = #params local field = {} local titleReference = {} for i = 1, numFields do field[i] = {} field[i].title = fnn(params[i].title, params[i].preset, "field"..i) titleReference[field[i].title] = field[i] end function field:translate()end function field:start()end function field:stop()end function field:destroy(...) for i = 1, #arg do local t = arg[i] if titleReference[t] then titleReference[t] = nil elseif not titleReference[t] then print("Missing field \""..t.."\"") end end end function field:startMaster()end function field:stopMaster()end function field:destroyMaster() for i = 1, #field do field:destroy(field[i].title) end for k, v in pairs(field) do field[k] = nil end field = nil end function field:get(...) local getTable = {} for i = 1, #arg do local t = arg[i] if titleReference[t] then getTable[i] = titleReference[t] else getTable[i] = "Missing field \""..t.."\"" print(getTable[i]) end end return unpack(getTable) end return field
end


--Demo preset, fake version
local function NilDemoPreset(preset) 
	local presetVentGroup = NilVentGroup{{preset = preset}} return presetVentGroup
end


--Change the render type
function Render(renderType)
	if renderType == "hidden" then
		print("CBE.Render(\"hidden\") does nothing at the moment")
		-- The nil functions are still in the workings for versions 2.0+
		--CBEffects.VentGroup = NilVentGroup
		--CBEffects.FieldGroup = NilFieldGroup
		--CBEffects.DemoPreset = NilDemoPreset
	else
		CBEffects.VentGroup = VentGroup
		CBEffects.FieldGroup = FieldGroup
		CBEffects.DemoPreset = DemoPreset
	end
end


-- Auto detect function call for vents
function VentX(params)
	if #params > 0 and type(params[1]) == "table" then
		return CBE.VentGroup(params)
	elseif #params == 0 then
		return CBE.NewVent(params)
	end
end


-- Auto detect function call for fields
function FieldX(params)
	if #params > 0 and type(params[1]) == "table" then
		return CBE.FieldGroup(params)
	elseif #params == 0 then
		return CBE.NewField(params)
	end
end


CBEffects.NewVent = NewVent
CBEffects.NewField = NewField
CBEffects.VentGroup = VentGroup
CBEffects.FieldGroup = FieldGroup
CBEffects.DemoPreset = DemoPreset
CBEffects.Render = Render
CBEffects.VentX = VentX
CBEffects.FieldX = FieldX

return CBEffects