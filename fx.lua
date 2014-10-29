--- A library of special effects.

--
-- Permission is hereby granted, free of charge, to any person obtaining
-- a copy of this software and associated documentation files (the
-- "Software"), to deal in the Software without restriction, including
-- without limitation the rights to use, copy, modify, merge, publish,
-- distribute, sublicense, and/or sell copies of the Software, and to
-- permit persons to whom the Software is furnished to do so, subject to
-- the following conditions:
--
-- The above copyright notice and this permission notice shall be
-- included in all copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
-- EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
-- MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
-- IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
-- CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
-- TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
-- SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
--
-- [ MIT license: http://www.opensource.org/licenses/mit-license.php ]
--

-- Standard library imports --
local random = math.random
local remove = table.remove

-- Modules --
local cbe = require("s3_utils.CBEffects.Library")

-- Corona globals --
local display = display
local easing = easing
local graphics = graphics
local system = system
local transition = transition

-- Exports --
local M = {}

do -- Flag effect
end

-- Cached vents --
local Cache = {}

-- Active vents --
local Vents = {}

-- "enterFrame" listener --
Runtime:addEventListener("enterFrame", function(event)
	local time, n = event.time, #Vents

	for i = n, 1, -1 do
		local vent = Vents[i]

		if vent.m_time <= time then
			vent:stop()
			vent:clean()

			-- Backfill over removed vent.
			Vents[i] = Vents[n]
			n, Vents[n] = n - 1

			-- Stuff the event back in its cache.
			local cache = Cache[vent.m_type] or {}

			cache[#cache + 1] = vent

			Cache[vent.m_type] = cache
		end
	end
end)

-- Create or reuse a vent
local function Vent (params, group, x, y, time)
	local vtype, vent = params.preset
	local cache = Cache[vtype]

	-- Non-empty cache: fetch a vent.
	if #(cache or "") > 0 then
		vent = remove(cache)

		group:insert(vent.content)

		vent.content.x = x
		vent.content.y = y

	-- Create a new vent.
	else
		params.parentGroup = group
		params.contentX = x
		params.contentY = y

		vent = cbe.NewVent(params)

		vent.m_type, params.parentGroup = vtype
	end
		
	-- Add the vent to the active vents, setting an expire time.
	vent.m_time = system.getTimer() + time

	Vents[#Vents + 1] = vent

	return vent
end

do -- POOF! effect
	local ParticleParams = {
		preset = "smoke", physics = { xDamping = 2, yDamping = 3 },
		emitDelay = 100, fadeInTime = 400, perEmit = 3, scale = .3
	}

	--- A small poof! cloud.
	-- @pgroup group Display group that will hold display objects produced by effect.
	-- @number x Approximate x-coordinate of effect.
	-- @number y Approximate y-coordinate of effect.
	-- @treturn uint Death time of poof.
	function M.Poof (group, x, y)
		local time = random(400, 1100)
		local vent = Vent(ParticleParams, group, x, y, time)

		vent:start()

		return time
	end
end

do -- POW! effect
	-- Fade-out part of effect --
	local Done = { time = 100, delay = 50, alpha = .25, transition = easing.outExpo, onComplete = display.remove }

	-- Fade-in part of effect --
	local Params = {
		time = 350, alpha = 1, transition = easing.inOutExpo,

		onComplete = function(object)
			if object.parent then
				transition.to(object, Done)
			end
		end
	}

	-- Helper for common effect logic
	local function AuxPOW (object, xs, ys, rot)
		object.alpha = .25

		Params.xScale = xs
		Params.yScale = ys
		Params.rotation = rot

		transition.to(object, Params)
	end

	--- A quick "POW!" effect.
	-- @pgroup group Display group that will hold display objects produced by effect.
	-- @number x Approximate x-coordinate of effect.
	-- @number y Approximate y-coordinate of effect.
	function M.Pow (group, x, y)
		x = x + 32

		local star = display.newImage(group, "s3_utils/assets/fx/BonkStar.png", x, y)
		local word = display.newImage(group, "s3_utils/assets/fx/Pow.png", x, y)

		AuxPOW(star, 2, 2, 180)
		AuxPOW(word, 2, 2)
	end
end

do -- Ripple effect
end

do -- Sparkles effect
	local ParticleParams = {
		preset = "sparks", positionType = "atPoint", x = 0, y = 0,
		perEmit = 1, fadeInTime = 100, emitDelay = 1,
		physics = {
			xDamping = 1.02, -- Lose their X-velocity quickly
			gravityY = 0.1,
			velocity = 3
		},
		build = function()
			local size = random(40, 70)

			return display.newImageRect("s3_utils/assets/fx/sparkle_particle.png", size, size)
		end,
		onDeath = function() end -- Original "sparks" preset changes the perEmit onDeath, so we need to overwrite it
	}

	--- A small particle effect to indicate that the map has been tapped.
	-- @pgroup group Display group that will hold display objects produced by effect.
	-- @number x Approximate x-coordinate of effect.
	-- @number y Approximate y-coordinate of effect.
	-- @uint? time Time for sparkle effect; if absent, a reasonable default is used.
	function M.Sparkle (group, x, y, time)
		local vent = Vent(ParticleParams, group, x, y, time or random(250, 400))

		vent:start()
	end
end

do -- Warp effects
	-- Mask clearing onComplete
	local function ClearMask (object)
		object:setMask(nil)
	end

	-- Scales an object's mask relative to its body to get a decent warp look
	local function ScaleObject (body, object)
		object = object or body

		object.maskScaleX = body.width / 4
		object.maskScaleY = body.height / 2
	end

	-- Mask-in transition --
	local MaskIn = { time = 900, transition = easing.inQuad }

	--- Performs a "warp in" effect on an object (using its mask, probably set by @{WarpOut}).
	-- @pobject object Object to warp in.
	-- @callable on_complete Optional **onComplete** handler for the transition. If absent,
	-- a default clears the object's mask; otherwise, the handler should also do this.
	-- @treturn TransitionHandle A handle for pausing or cancelling the transition.
	function M.WarpIn (object, on_complete)
		ScaleObject(object, MaskIn)

		MaskIn.onComplete = on_complete or ClearMask

		local handle = transition.to(object, MaskIn)

		MaskIn.onComplete = nil

		return handle
	end

	-- Mask-out transition --
	local MaskOut = { maskScaleX = 0, maskScaleY = 0, time = 900, transition = easing.outQuad }

	--- Performs a "warp out" effect on an object, via masking.
	-- @pobject object Object to warp out.
	-- @callable on_complete Optional **onComplete** handler for the transition.
	-- @treturn TransitionHandle A handle for pausing or cancelling the transition.
	-- @see WarpIn
	function M.WarpOut (object, on_complete)
		object:setMask(graphics.newMask("s3_utils/assets/fx/WarpMask.png"))

		ScaleObject(object)

		MaskOut.onComplete = on_complete or nil

		local handle = transition.to(object, MaskOut)

		MaskOut.onComplete = nil

		return handle
	end
end

-- Export the module.
return M