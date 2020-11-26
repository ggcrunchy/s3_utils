--- Module that generates geometry by sweeping a cylindrical cap along an arc.

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
local abs = math.abs
local assert = assert
local setmetatable = setmetatable
local sqrt = math.sqrt
local type = type

-- Modules --
local curve = require("spline_ops.cubic.curve")

-- Solar2D globals --
local display = display

-- Exports --
local M = {}

--
--
--

local SweptArcState = {}

SweptArcState.__index = SweptArcState

--
--
--

local function ComputeFromCurve (state, into_vertices, into_normals, into_knots, koffset, index, count, normals_group, scale1, scale2, callback)
	local t = index / count
	local poffset, s, px, py, tx, ty = 2 * koffset, 1 - t, state.m_get_position_and_tangent(state, t)

	into_vertices[poffset + 1] = px
	into_vertices[poffset + 2] = py

	local scale, unx, uny = (s * scale1 + t * scale2) / sqrt(tx^2 + ty^2 + 1e-8), state.m_normal_from_tangent(tx, ty) -- n.b. guard against slight undercalculations in denominator

	unx, uny = unx * scale, uny * scale

	if normals_group then
		local tobject

		if 1 + unx^2 + uny^2 ~= 1 then
			tobject = display.newLine(normals_group, px, py, px + unx * 5, py + uny * 5)

			tobject.strokeWidth = 1

			tobject:setStrokeColor(0, 1, 0, .4)
		else
			tobject = display.newCircle(normals_group, px, py, 1)

			tobject:setFillColor(0, 1, 0, .4)
		end
	end

	into_knots[koffset + 1] = s * state.m_knot1 + t * state.m_knot2
	into_normals[poffset + 1] = unx
	into_normals[poffset + 2] = uny
	-- implicit unz = sin(theta), i.e. unz^2 = 1 - scale^2

	if callback then
		callback("curve", koffset, poffset, index, count)
	end

	-- also consider recording the arc length and then doing another pass to arc length-parametrize everything
	-- this could improve the look in its own right, but would also allow some tessellation, e.g. the "Grading created from tessellated footprint" seen here:
	--
	-- https://knowledge.autodesk.com/support/civil-3d/learn-explore/caas/CloudHelp/cloudhelp/2016/ENU/Civil3D-UserGuide/files/GUID-D4B1DB47-0412-4CA7-B36E-A4EC77529CD1-htm.html
	--
	-- We would expect to grow as we go out, so could find the triangle bases as s-delta (i.e. arc length / n) minus previous-s-delta.
	--
	-- A crude approximation:
	--
	-- O ------ O ------ O
	-- |        |\        \
	-- |        | \        \
	-- |        |  \        \
	-- O ------ O - O ------ O
	--
	-- What would this do with more than one layer? Maybe put a quad below the triangle, then a new triangle to the right, so we get a larger triangle forming?
	--
	-- The builder is not set up to handle this: here we would advance "above" by 1 but add 2 "below". It would be a powerful addition, but sounds difficult.

end

--[[

	Given a grid cell, we can choose one of the corners and the other opposite it, along with
	an orientation. As we traverse layers these corners will step inward. We also have tangents
	to generate the Hermite curve that will interpolate the corners. A crude clockwise example:

             +
            /!\
             ! TAN #2
             !
       <=====@ (x2, y2) -----------------O
      STEP #2|\                          |
	         | \                         |
	         |  \                        |
	         |   |                       |
	         |    \   C                  |
	         |     \_  U                 |
	         |       \  R                |
	         |        \  V               |
	         |         -- E              |
	         |           \____           |
	         |                \_________ |
	         |                          \|
	         O---------------------<=====@ (x1, y1)
                                  TAN #1 !
                                         ! STEP #1
                                        \!/
                                         +

	The following tabulates the step and tangent directions for all eight situations.

    Orientation: clockwise

				STEP #1 | STEP #2 |  TAN #1 |  TAN #2
				-------------------------------------
    (<, <):     (0, -1) | (+1, 0) | (+1, 0) | (0, +1)
    (>, >):     (0, +1) | (-1, 0) | (-1, 0) | (0, -1)
    (<, >):     (-1, 0) | (0, -1) | (0, -1) | (+1, 0)
    (>, <):     (+1, 0) | (0, +1) | (0, +1) | (-1, 0)
 
    where the pair (<, <) is shorthand for (x1 < x2, y1 < y2), and likewise for the rest.
 
    Orientation: counterclockwise

				STEP #1 | STEP #2 |  TAN #1 |  TAN #2
				-------------------------------------
    (<, <):     (-1, 0) | (0, +1) | (0, +1) | (+1, 0)
    (>, >):     (+1, 0) | (0, -1) | (0, -1) | (-1, 0)
    (<, >):     (0, +1) | (+1, 0) | (+1, 0) | (0, -1)
    (>, <):     (0, -1) | (-1, 0) | (-1, 0) | (0, +1)

	Some observations:

		* In any of these directions, one component will be 0 and the other -1 or +1
		* With (<, <) or (>, >), STEP #1 is non-0 in a certain component: y when clockise,
          x otherwise; these roles are flipped when the pair's members differ
		* So we use x when (clockwise and differ) or (counter-clockwise and same)
		* Furthermore, one of the pair's members will be one-to-one with the component's
		  sign, e.g. when clockwise (<, ?) leads to -1 and (>, ?) gives us +1
		* STEP #2 is a 90-degree rotation (of the same orientation) of its STEP #1
		* STEP #1 = -TAN #2
		* STEP #2 = +TAN #1

]]

local function RotateCW (tx, ty)
    return -ty, tx
end

local function RotateCCW (tx, ty)
    return ty, -tx
end

local function TowardOffset (state, pos, dx, dy)
	if dx ~= 0 then
		return pos.x + dx * state.m_horz_tangent_scale, 0
	else
		return 0, pos.y + dy * state.m_vert_tangent_scale
	end
end

local function HermiteGetter (state, t)
	local pos1, pos2, tan1, tan2 = state.m_pos1, state.m_pos2, state.m_tan1, state.m_tan2
	local px, py = curve.GetPosition("hermite", pos1, pos2, tan1, tan2, t)
	local tx, ty = curve.GetTangent("hermite", pos1, pos2, tan1, tan2, t)

	return px, py, tx, ty
end

local function LineGetter (state, t)
	local s, pos1, pos2 = 1 - t, state.m_pos1, state.m_pos2

	return s * pos1.x + t * pos2.x, s * pos1.y + t * pos2.y, pos2.x - pos1.x, pos2.y - pos1.y
end

local function GetCurveValues (state, builder)
	local pos1, pos2 = state.m_pos1, state.m_pos2

	state.m_knot1, pos1.x, pos1.y, state.m_index1 = state.m_updater1()
	state.m_knot2, pos2.x, pos2.y, state.m_index2 = state.m_updater2()

	local dx, dy = pos2.x - pos1.x, pos2.y - pos1.y
	local xless, yless, step1x, step1y = dx > 0, dy > 0
	local same_sign, clockwise, non0 = xless == yless, state.m_orientation == "clockwise"

	if clockwise then
		non0 = xless and -1 or 1
	else
		non0 = yless and -1 or 1
	end

	if same_sign == clockwise then
		step1x, step1y = 0, non0
	else
		step1x, step1y = non0, 0
	end

	local rotate = clockwise and RotateCW or RotateCCW
	local step2x, step2y = rotate(step1x, step1y)

	if state.m_get_position_and_tangent ~= LineGetter then
		-- At t = 1/2, a Hermite curve's position is (P1 + P2) / 2 + (T1 - T2) / 8, with T1 and
		-- T2 being scaled along TAN #1 and TAN #2 respectively. Furthermore, from the analysis
		-- above, these can be rephrased in terms of the STEPs, so T1 - T2 = k1 * STEP #2 + k2 *
		-- STEP #1, where coefficients k1 and k2 are chosen to land us on the point P1 + DiffX *
		-- HorzTangentScale + DiffY * VertTangentScale, with Diff? being P2 - P1 projected onto
		-- the x- and y-axes respectively.
		dx, dy = abs(dx), abs(dy) -- n.b. now we only care if non-0

		local ox1, oy1 = TowardOffset(state, pos1, step2x * dx, step2y * dy) -- proportional to TAN #1...
		local ox2, oy2 = TowardOffset(state, pos2, step1x * dx, step1y * dy) -- ...and to -TAN #2, but following it backward
		local ox, oy = ox1 + ox2, oy1 + oy2

		local tan1, tan2 = state.m_tan1, state.m_tan2
		local mx, my = (pos1.x + pos2.x) / 2, (pos1.y + pos2.y) / 2
		local tx, ty = 8 * (ox - mx), 8 * (oy - my)

		tan1.x, tan1.y = abs(step2x) * tx, abs(step2y) * ty -- see note for dx and dy
		tan2.x, tan2.y = -abs(step1x) * tx, -abs(step1y) * ty
	end

	state.m_updater1("step", step1x, step1y)
	state.m_updater2("step", step2x, step2y)

	if state.m_index1 then
		builder:SetLowerLeft(state.m_index1)
	end
end

local function RowBeforeLayers (state, into_vertices, into_normals, into_knots, i1, i2, builder, params)
	local count, offset, callback, omit_rest = builder:GetColumnCount(), builder:GetMaxIndex(), params.callback, params.omit == "rest"
	local emit_method, normals_group, scale1, scale2 = omit_rest and "EmitQuad" or "EmitBottomEdge", params.normals_group, 1, 1

	if omit_rest then
		scale1, scale2 = 1 - state.m_theta_coeff1, 1 - state.m_theta_coeff2
	end

	for i = i1, i2 do
		ComputeFromCurve(state, into_vertices, into_normals, into_knots, offset, i, count, normals_group, scale1, scale2, callback)

		if i > 0 then
			builder[emit_method](builder)
		end

		offset = offset + 1
	end

	if state.m_index2 then
		builder:SetLowerRight(state.m_index2)
		builder[emit_method](builder)
	end

	return offset
end

--- DOCME
function SweptArcState:__call (params)
	local layer_count, updater1, updater2 = self.m_layer_count, self.m_updater1, self.m_updater2

	assert(layer_count and layer_count > 1, "Missing layer count")
	assert(self.m_orientation, "Missing orientation")
	assert(updater1 and updater1("begin", layer_count), "Cap #1 is not ready")
	assert(updater2 and updater2("begin", layer_count), "Cap #2 is not ready")

	if self.m_get_position_and_tangent ~= LineGetter then
		assert(self.m_horz_tangent_scale and self.m_vert_tangent_scale, "Missing tangent scales")

		self.m_get_position_and_tangent = HermiteGetter
	end

	local builder = params.builder

	GetCurveValues(self, builder)

	local omit, last_layer = params.omit

	if omit == "rest" then
		last_layer = 0
	else
		last_layer = layer_count - (omit == "last" and 1 or 0)
	end

	local count, callback, normals_group = builder:GetColumnCount(), params.callback, params.normals_group
	local i1, i2 = self.m_index1 and 1 or 0, count - (self.m_index2 and 1 or 0)
	local into_vertices, into_normals, into_knots = params.into_vertices, params.into_normals, params.into_knots

	if callback then
		callback("begin_arc", into_knots, into_normals, into_vertices)
	end

	local offset = RowBeforeLayers(self, into_vertices, into_normals, into_knots, i1, i2, builder, params)

	for layer = 1, last_layer do
		if callback then
			callback("layer", layer, layer_count)
		end

		GetCurveValues(self, builder)

		local t = layer / layer_count
		local cos_theta1, cos_theta2 = 1 - self.m_theta_coeff1 * t, 1 - self.m_theta_coeff2 * t

		for i = i1, i2 do
			ComputeFromCurve(self, into_vertices, into_normals, into_knots, offset, i, count, normals_group, cos_theta1, cos_theta2, callback)

            if i > 0 then
                builder:EmitQuad()
            end

			offset = offset + 1
		end

		if self.m_index2 then
			builder:SetLowerRight(self.m_index2)
			builder:EmitQuad()
		end
	end

	if callback then
		callback("end_arc")
	end

	if not params.leave_updater1 then
		updater1("clear")

		self.m_updater1 = nil
	end

	if not params.leave_updater2 then
		updater2("clear")

		self.m_updater2 = nil
	end

	self.m_get_position_and_tangent = nil
end

--
--
--

--- DOCME
function SweptArcState:SetArcNormalHalfRange1 (is_half_arc)
	self.m_theta_coeff1 = is_half_arc and 1 or 2
end

--
--
--

--- DOCME
function SweptArcState:SetArcNormalHalfRange2 (is_half_arc)
	self.m_theta_coeff2 = is_half_arc and 1 or 2
end

--
--
--

local function GetArray (v, err)
	assert(type(v) == "table", err)

	return v
end

local function MakeIndicesFunc ()
	local indices, kindex, step, knots, vertices

	return function(what, arg1, arg2, arg3)
		if what then
			if what == "step" then
				kindex = kindex + step
			elseif what == "begin" then
				if knots then
					kindex, step = kindex or 1, step or 1

					return true
				end
			elseif what == "clear" then
				indices, kindex, step, knots, vertices = nil
			elseif what == "set_index_and_step" then -- arg1: first, arg2: step
				kindex, step = arg1, arg2
			elseif what == "set_sources" then -- arg1: knots, arg2: vertices, arg3: indices?
				knots = GetArray(arg1, "Expected knots array")
				vertices = GetArray(arg2, "Expected vertices array")
				indices = arg3 and GetArray(arg3, "Expected indices array")
			end
		else -- assumed to be ready
			local index = kindex

			if indices then
				index = indices[kindex]
			end

			local knot, offset = assert(knots[index], "Missing knot"), (index - 1) * 2
			local vx, vy = vertices[offset + 1], vertices[offset + 2]

			assert(vx and vy, "Missing vertex component")

			return knot, vx, vy, index
		end
	end
end

local function MakeInterpolatedFunc ()
	local index, knot1, knot2, x, y, step, xstep, ystep, layer_count = 0

	return function(what, arg1, arg2, arg3, arg4)
		if what then
			if what == "step" then -- arg1: axisx, arg2: axisy
				if step then
					x, y = x + arg1 * step, y + arg2 * step
				else
					x, y = x + xstep, y + ystep
				end
			elseif what == "begin" then -- arg1: layer count
				if knot1 and x then
					layer_count = arg1

					return true
				end
			elseif what == "clear" then
				index, knot1, x, step = 0
			elseif what == "set_knots" then -- arg1: knot1, arg2: knot2
				knot1 = assert(arg1, "Expected knot")
				knot2 = arg2
			elseif what == "set_vertex" then -- arg1: x, arg2: y, arg3: xstep / step, arg4: ystep / nil
				assert(arg1 and arg2, "Expected vertex x- and y-coordinates")

				if arg4 then
					assert(arg3 == 0 or arg4 == 0, "Expected one of the steps to be 0")
					assert(arg3 ~= 0 or arg4 ~= 0, "Expected one of the steps to be non-0")

					xstep, ystep = arg3, arg4
				else
					assert(arg3 and arg3 ~= 0, "Expected non-0 step")

					step = arg3
				end

				x, y = arg1, arg2
			end
		else -- assumed to be ready
			local vx, vy, knot = x, y

			if knot2 then
				local t = index / layer_count

				knot = (1 - t) * knot1 + t * knot2
			else
				knot = knot1
			end

			index = index + 1

			return knot, vx, vy
		end
	end
end

--
--
--

local function EnsureExpectedMode (state, updater, expected, set)
	if updater and updater ~= expected then
		local indexed = expected == state.m_get_indices1 or expected == state.m_get_indices2
		local mode, other = indexed and "indices" or "interpolated", indexed and "interpolated" or "indices"

		assert(false, "Command inconsistent with updater #" .. set .. ": previous operations assumed '" .. mode .. "' mode, but current one belongs to '" .. other .. "'")
	else
		return expected
	end
end

local function WithUpdater1 (state, mode)
	state.m_updater1 = EnsureExpectedMode(state, state.m_updater1, mode == "indices" and state.m_get_indices1 or state.m_get_interpolated1, "1")

	return state.m_updater1
end

local function WithUpdater2 (state, mode)
	state.m_updater2 = EnsureExpectedMode(state, state.m_updater2, mode == "indices" and state.m_get_indices2 or state.m_get_interpolated2, "2")

	return state.m_updater2
end

--
--
--

--- DOCME
function SweptArcState:SetIndexAndStep1 (first, step)
	WithUpdater1(self, "indices")("set_index_and_step", first, step)
end


--
--
--

--- DOCME
function SweptArcState:SetIndexAndStep2 (first, step)
	WithUpdater2(self, "indices")("set_index_and_step", first, step)
end

--
--
--

--- DOCME
function SweptArcState:SetKnots1 (knot1, knot2)
	WithUpdater1(self, "interpolated")("set_knots", knot1, knot2)
end

--
--
--

--- DOCME
function SweptArcState:SetKnots2 (knot1, knot2)
	WithUpdater2(self, "interpolated")("set_knots", knot1, knot2)
end

--
--
--

--- DOCME
function SweptArcState:SetLayerCount (count)
	self.m_layer_count = count
end

--
--
--

local function EnsureExpectedGetterMode (state, mode)
	local getter, to_assign = state.m_get_position_and_tangent, mode == "line" and LineGetter or HermiteGetter

	if getter and getter ~= to_assign then
		local other = mode == "line" and "Hermite" or "line"

		assert(false, "Previous operators assumed '" .. mode .. "' getter mode, but current one belongs to '" .. other .. "'")
	end

	state.m_get_position_and_tangent = to_assign
end

--
--
--

--- DOCME
function SweptArcState:SetLineVertexAndStep1 (x, y, xstep, ystep)
	EnsureExpectedGetterMode(self, "line")
	WithUpdater1(self, "interpolated")("set_vertex", x, y, xstep, ystep)
end

--
--
--

--- DOCME
function SweptArcState:SetLineVertexAndStep2 (x, y, xstep, ystep)
	EnsureExpectedGetterMode(self, "line")
	WithUpdater2(self, "interpolated")("set_vertex", x, y, xstep, ystep)
end

--
--
--

--- DOCME
function SweptArcState:SetOrientation (orientation)
	assert(orientation == "clockwise" or orientation == "counter_clockwise", "Invalid orientation")

	self.m_orientation, self.m_normal_from_tangent = orientation, orientation == "clockwise" and RotateCW or RotateCCW
end

--
--
--

--- DOCME
function SweptArcState:SetSources1 (knots, vertices, indices)
	WithUpdater1(self, "indices")("set_sources", knots, vertices, indices)
end

--
--
--

--- DOCME
function SweptArcState:SetSources2 (knots, vertices, indices)
	WithUpdater2(self, "indices")("set_sources", knots, vertices, indices)
end

--
--
--

--- DOCME
function SweptArcState:SetTangentScales (hscale, vscale)
	self.m_horz_tangent_scale, self.m_vert_tangent_scale = hscale, vscale
end

--
--
--

--- DOCME
function SweptArcState:SetVertexAndStep1 (x, y, xstep)
	EnsureExpectedGetterMode(self, "Hermite")
	WithUpdater1(self, "interpolated")("set_vertex", x, y, xstep)
end

--
--
--

--- DOCME
function SweptArcState:SetVertexAndStep2 (x, y, ystep)
	EnsureExpectedGetterMode(self, "Hermite")
	WithUpdater2(self, "interpolated")("set_vertex", x, y, ystep)
end

--
--
--

--- DOCME
function M.NewState ()
	return setmetatable({
		m_pos1 = {}, m_tan1 = {}, m_theta_coeff1 = 2,
		m_pos2 = {}, m_tan2 = {}, m_theta_coeff2 = 2,
		m_get_indices1 = MakeIndicesFunc(), m_get_interpolated1 = MakeInterpolatedFunc(),
		m_get_indices2 = MakeIndicesFunc(), m_get_interpolated2 = MakeInterpolatedFunc()
	}, SweptArcState)
end

--
--
--

return M