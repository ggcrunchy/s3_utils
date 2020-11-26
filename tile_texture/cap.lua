--- Module that generates cap-style paraboloid geometry, e.g. for the two ends of a capsule.

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

local CapState = {}

CapState.__index = CapState

--
--
--

--- DOCME
function CapState:__call (params)
	local to_tip_ux, to_tip_uy = assert(self.m_to_tip_ux, "Missing base-to-tip displacement"), self.m_to_tip_uy
	local normal_from_tangent = assert(self.m_normal_from_tangent, "Missing orientation")

    local builder, callback, normals_group = params.builder, params.callback, params.normals_group
    local layer_count, slice_count, updater = params.layer_count, builder:GetColumnCount(), self.m_updater

    assert(slice_count > 0, "Invalid slice count")
	assert(updater and updater("begin", layer_count, slice_count), "Base is not ready")

    local into_normals, into_knots, into_vertices = params.into_normals, params.into_knots, params.into_vertices

	local base, grow = self.m_to_tip_base, self.m_to_tip_grow
	local ddispx, ddispy = to_tip_ux * grow, to_tip_uy * grow
	local to_cpx, to_cpy = to_tip_ux * base + (layer_count - 1) * ddispx, to_tip_uy * base + (layer_count - 1) * ddispy

    local koffset = #into_knots
    local offset = 2 * koffset

	local knot1, x1, y1, index1 = updater() -- peek at first result
	local tip_knot, j1, j2 = self.m_tip_knot or 1 - knot1, 0, slice_count

	if index1 then
		j1, j2 = 1, j2 - 1
	end

	if callback then
		callback("begin_cap", into_knots, into_normals, into_vertices)
	end

	local pos1, pos2, tan1, tan2 = self.m_pos1, self.m_pos2, self.m_tan1, self.m_tan2

    for i = 1, layer_count do
		if callback then
			callback("layer", i, layer_count)
		end

		local _, x2, y2, index2 = updater() -- TODO: come up with way to incorporate knot2 (the omitted variable here)

        pos1.x, pos1.y, tan1.x, tan1.y = x1, y1, to_cpx, to_cpy
        pos2.x, pos2.y, tan2.x, tan2.y = x2, y2, -to_cpx, -to_cpy

        local frac = 1 - (i - 1) / layer_count
        local fknot = knot1 + frac * (tip_knot - knot1)

		if index1 then
			builder:SetLowerLeft(index1)
		end

        for j = j1, j2 do
            local t = j / slice_count
            local px, py = curve.GetPosition("hermite", pos1, pos2, tan1, tan2, t)
            local tx, ty = curve.GetTangent("hermite", pos1, pos2, tan1, tan2, t)
            local len, unx, uny = sqrt(tx^2 + ty^2 + 1e-8), normal_from_tangent(tx, ty)
			local scale = frac / len

			unx, uny = unx * scale, uny * scale

			if normals_group then
				local tobject

				if 1 + unx^2 + uny^2 ~= 1 then
					tobject = display.newLine(normals_group, px, py, px + unx * 5, py + uny * 5)

					tobject.strokeWidth = 1

					tobject:setStrokeColor(1, 0, 0, .4)
				else
					tobject = display.newCircle(normals_group, px, py, 1)

					tobject:setFillColor(1, 0, 0, .4)
				end
			end

            into_vertices[offset + 1] = px
            into_vertices[offset + 2] = py
            into_normals[offset + 1] = unx
            into_normals[offset + 2] = uny

            local s = 2 * abs(.5 - t)

            into_knots[koffset + 1] = s * knot1 + (1 - s) * fknot -- TODO: this (and fknot) probably bogus if knot1 ~= knot2, see above note

			if callback then
				callback("curve", koffset, offset, j, slice_count)
			end

			offset, koffset = offset + 2, koffset + 1

			if j > 0 then
				if i > 1 then
					builder:EmitQuad()
				else
					builder:EmitBottomEdge()
				end
			end
        end

		if index2 then
			builder:SetLowerRight(index2)

			if i > 1 then
				builder:EmitQuad()
			else
				builder:EmitBottomEdge()
			end
		end

		to_cpx, to_cpy = to_cpx - ddispx, to_cpy - ddispy
		knot1, x1, y1, index1 = updater() -- use in next loop or as middle point
    end

    local mid_index = index1

    if not mid_index then
        into_vertices[offset + 1] = x1
        into_vertices[offset + 2] = y1
        into_normals[offset + 1] = 0
        into_normals[offset + 2] = 0
        into_knots[koffset + 1] = knot1

		if callback then
			callback("midpoint", offset, koffset)
		end

        mid_index = koffset + 1
    end

	if normals_group then
		local tobject = display.newCircle(normals_group, x1, y1, 1)

		tobject:setFillColor(1, 0, 0, .4)
	end

	for _ = 1, slice_count do
		builder:SetLowerRight(mid_index) -- n.b. conceptually this is lower-left, but use lower-right since left flags are unset
		builder:EmitTriangle()
	end

	if callback then
		callback("end_cap")
	end

	updater("clear")

	self.m_updater = nil
end

--
--
--

--- DOCME
function CapState:SetDisplacementToTip (ux, uy, base, grow)
	assert(ux and uy, "Expected unit displacement x- and y-components")
	assert(ux == 0 or uy == 0, "Expected one of the unit displacement components to be 0")
	assert(abs(ux) + abs(uy) == 1, "Expected one of the unit displacement components to be 1 or -1")
	assert(base, "Expected base displacement distance")
	assert(grow, "Expected displacement grow distance")

	self.m_to_tip_ux, self.m_to_tip_uy = ux, uy
	self.m_to_tip_base, self.m_to_tip_grow = base * 4, grow * 4 -- when T1 = -T2, at t = 1/2 the Hermite curve position is (P + Q) / 2 + T1 / 4
end

--
--
--

local function GetArray (v, err)
	assert(type(v) == "table", err)

	return v
end

local function MakeIndicesFunc ()
	local indices, knot_index, step, jump, knots, vertices, second

	return function(what, arg1, arg2, arg3)
		if what == "begin" then -- arg1: layer count, arg2: slice count
			if knots then
				knot_index, step = knot_index or 1, step or 1

				local nsteps = arg1 * 2

				if indices then
					jump = nsteps
				else
					jump = nsteps * step
				end

				return true
			end
		elseif what == "clear" then
			indices, knot_index, step, knots, vertices, second = nil
		elseif what == "set_index_and_step" then -- arg1: index?, arg2: step?
			knot_index, step = arg1, arg2
		elseif what == "set_sources" then -- arg1: knots, arg2: vertices, arg3: indices?
			knots, vertices, indices = arg1, arg2, arg3
		else -- assumed to be ready
			local kindex = knot_index

			if indices then
				kindex = indices[knot_index]
			end

			local knot, offset = assert(knots[kindex], "Missing knot"), (kindex - 1) * 2
			local vx, vy = vertices[offset + 1], vertices[offset + 2]

			assert(vx and vy, "Missing vertex component")

			if second then
				jump = jump - step
				knot_index, second = knot_index - jump, false
				jump = jump - step
			else
				knot_index, second = knot_index + jump, true
			end

			return knot, vx, vy, kindex
		end
	end
end

local function MakeInterpolatedFunc ()
	local knot1, knot2, knot_delta, x1, x2, xstep, y1, y2, ystep, second

	return function(what, arg1, arg2, arg3, arg4)
		if what == "begin" then -- arg1: layer count, arg2: slice count
			if x1 then
				knot1 = knot1 or 0
				knot2 = knot2 or knot1

				local nsteps = arg1 * 2

				knot_delta = (knot2 - knot1) / nsteps
				x2, y2 = x1 + nsteps * xstep, y1 + nsteps * ystep

				return true
			end
		elseif what == "clear" then
			knot1, x1, second = nil
		elseif what == "set_knots" then -- arg1: knot1, arg2: knot2?
			knot1, knot2 = arg1, arg2
		elseif what == "set_vertex_and_step" then -- arg1: x, arg2: y, arg3: xstep, arg4: ystep
			x1, y1, xstep, ystep = arg1, arg2, arg3, arg4
		else -- assumed to be ready
			if second then
				local knot, x, y = knot2, x2, y2

				knot1, x1, y1 = knot1 + knot_delta, x1 + xstep, y1 + ystep
				knot2, x2, y2 = knot2 - knot_delta, x2 - xstep, y2 - ystep
				second = false

				return knot, x, y
			else
				second = true

				return knot1, x1, y1
			end
		end
	end
end

--
--
--

local function EnsureExpectedMode (state, updater, expected)
	if not updater then
		state.m_updater = expected
	elseif updater ~= expected then
		local indexed = expected == state.m_get_indices
		local mode, other = indexed and "indices" or "interpolated", indexed and "interpolated" or "indices"

		assert(false, "Command inconsistent with updater : previous operations assumed '" .. mode .. "' mode, but current one belongs to '" .. other .. "'")
	end

	return expected
end

local function EnsureUpdater (state, mode)
	return EnsureExpectedMode(state, state.m_updater, mode == "indices" and state.m_get_indices or state.m_get_interpolated)
end

--
--
--

--- DOCME
function CapState:SetIndexAndStep (first, step)
	EnsureUpdater(self, "indices")("set_index_and_step", first, step)
end

--
--
--

--- DOCME
function CapState:SetKnots (knot1, knot2)
	EnsureUpdater(self, "interpolated")("set_knots", assert(knot1, "Expected knot"), knot2)
end

--
--
--

local function RotateCW (tx, ty)
    return -ty, tx
end

local function RotateCCW (tx, ty)
    return ty, -tx
end

--- DOCME
function CapState:SetOrientation (orientation)
	assert(orientation == "clockwise" or orientation == "counter_clockwise", "Invalid orientation")

	self.m_normal_from_tangent = orientation == "clockwise" and RotateCW or RotateCCW
end

--
--
--

--- DOCME
function CapState:SetSources (knots, vertices, indices)
	EnsureUpdater(self, "indices")("set_sources", GetArray(knots, "Expected knots array"), GetArray(vertices, "Expected vertices array"), indices and GetArray(indices, "Expected indices array"))
end

--
--
--

--- DOCME
function CapState:SetTipKnot (knot)
	self.m_tip_knot = knot
end

--
--
--

--- DOCME
function CapState:SetVertexAndStep (x, y, xstep, ystep)
	assert(x and y, "Expected vertex x- and y-coordinates")
	assert(xstep == 0 or ystep == 0, "Expected one of the steps to be 0")
	assert(xstep ~= 0 or ystep ~= 0, "Expected one of the steps to be non-0")

	EnsureUpdater(self, "interpolated")("set_vertex_and_step", x, y, xstep, ystep)
end

--
--
--

--- DOCME
function M.NewState ()
	return setmetatable({
		m_pos1 = {}, m_tan1 = {},
		m_pos2 = {}, m_tan2 = {},
		m_get_indices = MakeIndicesFunc(), m_get_interpolated = MakeInterpolatedFunc()
	}, CapState)
end

--
--
--

-- An example with 4 layers and the arc split into 3 parts:

-- A     B     C     D     E     F     G     H     I
-- X-----X-----X-----X-----X-----X-----X-----X-----X
-- |     |     |     |    / \    |     |     |     |
-- |     |     |     |   /   \   |     |     |     |
--  \     \     \     \ /     \ /     /     /     /
--   \     \     \   P x-------x Q   /     /     /
--    \     \     \   /         \   /     /     /
--     \     \     \ /           \ /     /     /
--      \     \   N x-------------x O   /     /
--       \     \   /               \   /     /
--        \     \ /                 \ /     /
--         \   L x-------------------x M   /
--          \   /                     \   /
--           \ /                       \ /
--          J x-------------------------x K

-- #1: AJBL | BLCN | CNDP | DPE
-- #2: JKLM | LMNO | NOPQ | PQE
-- #3: KIMH | MHOG | OGQF | QFE

-- we gather each row in a column, then move on to the next:
	-- column #1, row #1
	-- column #1, row #2
	-- ...
	-- column #4, row #3

--
--
--

return M