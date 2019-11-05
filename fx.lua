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
local require = require

-- Modules --
local distort = require("s3_utils.snippets.operations.distort")
local frames = require("corona_utils.frames")

-- Corona globals --
local display = display
local easing = easing
local graphics = graphics
local transition = transition

-- Exports --
local M = {}

--
--
--

local ShimmerFill = { type = "image" }

local Shimmers = {}

do -- Shimmer effect
	local Loaded

	--- DOCME
	function M.Shimmer (group, x, y, radius, opts)
		Loaded = Loaded or not not require("s3_utils.kernel.shimmer")

		local shimmer, influence, spin = display.newCircle(group, x, y, radius)

		if opts then
			influence, spin = opts.influence, opts.spin
		end

		shimmer.m_spin = spin or 100

		distort.BindCanvasEffect(shimmer, ShimmerFill, "filter.screen.shimmer")

		if influence then
			shimmer.fill.effect.influence = influence
		end

		Shimmers[#Shimmers + 1] = shimmer

		return shimmer
	end
end

do -- Warp effects
	local function ClearMask (object)
		object:setMask(nil)
	end

	local function ScaleMask (body, object)
		object = object or body

		object.maskScaleX = body.width / 4
		object.maskScaleY = body.height / 2
	end

	local MaskIn = { time = 900, transition = easing.inQuad }

	--- Performs a "warp in" effect on an object (using its mask, probably set by @{WarpOut}).
	-- @pobject object Object to warp in.
	-- @callable on_complete Optional **onComplete** handler for the transition. If absent,
	-- a default clears the object's mask; otherwise, the handler should also do this.
	-- @treturn TransitionHandle A handle for pausing or cancelling the transition.
	function M.WarpIn (object, on_complete)
		ScaleMask(object, MaskIn)

		MaskIn.onComplete = on_complete or ClearMask

		local handle = transition.to(object, MaskIn)

		MaskIn.onComplete = nil

		return handle
	end

	local MaskOut = { maskScaleX = 0, maskScaleY = 0, time = 900, transition = easing.outQuad }

	--- Performs a "warp out" effect on an object, via masking.
	-- @pobject object Object to warp out.
	-- @callable on_complete Optional **onComplete** handler for the transition.
	-- @treturn TransitionHandle A handle for pausing or cancelling the transition.
	-- @see WarpIn
	function M.WarpOut (object, on_complete)
		object:setMask(graphics.newMask("s3_utils/assets/fx/WarpMask.png"))

		ScaleMask(object)

		MaskOut.onComplete = on_complete or nil

		local handle = transition.to(object, MaskOut)

		MaskOut.onComplete = nil

		return handle
	end
end

--
local function ShimmerForEach (func)
	return function(arg)
		local n = #Shimmers

		for i = n, 1, -1 do
			local shimmer = Shimmers[i]

			if shimmer.parent then
				func(shimmer, arg)
			else
				Shimmers[i] = Shimmers[n]
				n, Shimmers[n] = n - 1
			end
		end
	end
end

local RemoveShimmers = ShimmerForEach(display.remove)

local UpdateShimmerAlpha = ShimmerForEach(function(shimmer, alpha)
	shimmer.fill.effect.alpha = alpha
end)

local UpdateShimmers = ShimmerForEach(function(shimmer, dt)
	shimmer.rotation = shimmer.rotation + shimmer.m_spin * dt
end)

for k, v in pairs{
	-- Enter Frame --
	enterFrame = function()
		UpdateShimmers(frames.DiffTime())
	end,

	-- Leave Level --
	leave_level = function()
		RemoveShimmers()

		Shimmers = {}
	end,

	-- Set Canvas --
	set_canvas = distort.CanvasToPaintAttacher(ShimmerFill),

	-- Set Canvas Alpha --
	set_canvas_alpha = function(event)
		UpdateShimmerAlpha(event.alpha)
	end
} do
	Runtime:addEventListener(k, v)
end

return M