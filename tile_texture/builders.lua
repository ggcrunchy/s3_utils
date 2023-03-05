--- Tile builders.

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
local assert = assert

-- Modules --
local bezier3 = require("spline_ops.bezier3")
local convert = require("spline_ops.cubic.convert")
local sampling = require("tektite_core.number.sampling")
local shapes = require("s3_utils.tile_texture.shapes")
local tile_texture_flags = require("s3_utils.tile_texture.flags")
local tile_texture_prims = require("s3_utils.tile_texture.prims")
local tile_texture_utils = require("s3_utils.tile_texture.utils")

-- Exports --
local M = {}

--
--
--

local Funcs = {}

-- Assumptions:
  -- We emit edges along the bottom or right side, if available
    -- these are ordered left-to-right or top-to-bottom, respectively
    -- when we fetch them, these will be on the top or left, respectively
    -- similarly we emit a u-value corresponding to the left or top element

  -- The "long" side (here, 1->2) of the (curvilinear) trapezoid is on top:

     --    _------------o 2
     --   /  _----------o
     --  /  /  _--------o 4
     -- o  o  o
     -- 1     3

  -- Called as trapezoid(1->3, 2->4), using the u-values for 1 and 2, respectively

  -- Similarly, 1->2 denotes the flat side of a triangle or nub

     -- 1       2     1       2
     -- o-o-o-o-o     o-o-o-o-o
     --  \     /      | | | | |
     --   \   /        \ \ / /
     --    \ /          \ - /
     --     o            -o-
     --     3             3

  -- In some orientations, these shapes will have edges along the top or bottom sides
  -- This motivates the ordering mentioned above, and occasional reversals (elements backward; 1 - u)
  -- Such edges are emitted, then may be fetched by cells to the right or below:
  
  --        A       B
  --        o-------o
  -- o C                 E o
  -- |                     |
  -- |          o M        |
  -- |                     |
  -- o D                 F o
  --        o-------o
  --        G       H
  
  -- If a predecessor is available, it is used; otherwise the edge is generated
  -- A generated edge goes top-to-bottom from 0 to 1, or left-right from 1 to 0
  -- M is generated for each of the T shapes as well as the 4-way

-- as per trapezoid diagram (no predecessors)
function Funcs.UpperLeft (sources, _)
  -- bottom: G->H
  local bottom = tile_texture_utils.GetEdge(sources, nil, "bottom")

  -- right: E->F
  local right = tile_texture_utils.GetEdge(sources, nil, "right")

  tile_texture_utils.CornerCurve(sources, bottom, right, "up", "right")

  return bottom, right -- emit to top, left
end

--
--
--

-- 90-degree clockwise rotation of trapezoid diagram
function Funcs.UpperRight (sources, _, left)
  -- left: C->D
  left = tile_texture_utils.GetEdge(sources, left, "left")

  -- bottom: reverse(G->H)
  local bottom = tile_texture_utils.GetEdge(sources, nil, "bottom", "reverse")

  tile_texture_utils.CornerCurve(sources, left, bottom, "right", "down")

  return bottom, nil -- emit to top
end

--
--
--

-- 90-degree counterclockwise rotation of trapezoid diagram
function Funcs.LowerLeft (sources, top, _)
  -- top: A->B    
  top = tile_texture_utils.GetEdge(sources, top, "top")

  -- right: reverse(E->F)
  local right = tile_texture_utils.GetEdge(sources, nil, "right", "reverse")

  tile_texture_utils.CornerCurve(sources, right, top, "left", "up")

  return nil, right -- emit to left
end

--
--
--

-- 180-degree rotation of trapezoid diagram
function Funcs.LowerRight (sources, top, left)
  -- top: reverse(A->B)
  top = tile_texture_utils.GetEdge(sources, top, "top", "reverse")

  -- left: reverse(C->D)
  left = tile_texture_utils.GetEdge(sources, left, "left", "reverse")

  tile_texture_utils.CornerCurve(sources, top, left, "down", "left")

  -- emits nothing
end

--
--
--

-- 90-degree clockwise rotation of nub diagram (no predecessors)
function Funcs.LeftNub (sources, _)
  -- right: E->F
  local right = tile_texture_utils.GetEdge(sources, nil, "right")
  
  tile_texture_utils.NubOnEdge(sources, right, "left", "right")

  return nil, right -- emit to left
end

--
--
--

-- 90-degree counterclockwise rotation of nub diagram
function Funcs.RightNub (sources, _, left)
  -- left: reverse(C->D)
  left = tile_texture_utils.GetEdge(sources, left, "left", "reverse")

  tile_texture_utils.NubOnEdge(sources, left, "right", "left")

  -- emits nothing
end

--
--
--

-- 180-degree rotation of nub diagram (no predecessors)
function Funcs.TopNub (sources, _)
  -- bottom: reverse(G->H)
  local bottom = tile_texture_utils.GetEdge(sources, nil, "bottom", "reverse")

  tile_texture_utils.NubOnEdge(sources, bottom, "up", "down")
  
  return bottom -- emit to top
end

--
--
--

-- as per nub diagram
function Funcs.BottomNub (sources, top, _)
  -- top: G->H
  top = tile_texture_utils.GetEdge(sources, top, "top")

  tile_texture_utils.NubOnEdge(sources, top, "down", "up")

  -- emits nothing
end

--
--
--

function Funcs.Horizontal (sources, _, left)
  -- For current purposes, like a straightened trapezoid:

  -- 1          2
  -- o----------o
  -- |          |
  -- |          |
  -- o----------o
  -- 3          4

  -- left: C->D / (1->3)
  left = tile_texture_utils.GetEdge(sources, left, "left")

  -- right: E->F / (2->4)
  local right = tile_texture_utils.GetEdge(sources, nil, "right")

  shapes.Rectangle(sources, left, right, tile_texture_utils.GetProp("rectangle_count"))

  return nil, right -- emit to left
end

--
--
--

function Funcs.Vertical (sources, top, _)
  -- 90-degree counterclockwise rotation of horizontal
  -- top: A->B (2->4)
  top = tile_texture_utils.GetEdge(sources, top, "top")

  -- bottom: G->H (1->3)
  local bottom = tile_texture_utils.GetEdge(sources, nil, "bottom")

  shapes.Rectangle(sources, bottom, top, tile_texture_utils.GetProp("rectangle_count"))

  return bottom, nil -- emit to top
end

--
--
--

function Funcs.TopT (sources, _, left)
  -- 1                       2
  -- o-----------------------o
  -- ! \         U         / !
  -- !  ---             ---  !
  -- !     \     3     /     !
  -- !      -----o-----      !
  -- !          / \          !
  -- !  V     --   --    W   !
  -- !       / !   ! \       !
  -- !    --- /     \ ---    !
  -- o---/  Y !  X  ! Z  \---o
  -- 4       /       \       5
  --         !       !
  --         o-------o
  --         6       7
  local mid, mx, my = tile_texture_utils.GetMiddle(sources)

  -- left: reverse(C->D)
  local vl, vr = tile_texture_utils.TriangleTowardMiddle(sources, left, "left", mid, mx, my, "reverse")

  -- right: E->F
  local wl, wr, right = tile_texture_utils.TriangleTowardMiddle(sources, nil, "right", mid, mx, my)

  -- top: C->E
  tile_texture_prims.SetEdgeNormal(0, -1)
  shapes.Triangle(sources, vr, wl, mid)

  -- bottom: reverse(G->H)
  local xl, xr, bottom = tile_texture_utils.TriangleTowardMiddle(sources, nil, "bottom", mid, mx, my, "reverse")

  tile_texture_utils.CornerTriangles(sources, xr, vl, mid)
  tile_texture_utils.CornerTriangles(sources, wr, xl, mid)
  
  return bottom, right -- emit to top, left
end

--
--
--

-- 180-degree rotation of TopT
function Funcs.BottomT (sources, top, left)
  local mid, mx, my = tile_texture_utils.GetMiddle(sources)

  -- right: reverse(C->D)
  local wl, wr = tile_texture_utils.TriangleTowardMiddle(sources, left, "left", mid, mx, my, "reverse")

  -- left: E->F
  local vl, vr, left2 = tile_texture_utils.TriangleTowardMiddle(sources, nil, "right", mid, mx, my)

  -- top: F->D
  tile_texture_prims.SetEdgeNormal(0, 1)
  shapes.Triangle(sources, vr, wl, mid)

  -- bottom: A->B
  local xl, xr = tile_texture_utils.TriangleTowardMiddle(sources, top, "top", mid, mx, my)

  tile_texture_utils.CornerTriangles(sources, xr, vl, mid)
  tile_texture_utils.CornerTriangles(sources, wr, xl, mid)

  return nil, left2 -- emit to left
end

--
--
--

-- 90-degree counterclockwise rotation of TopT
function Funcs.LeftT (sources, top, _)
  local mid, mx, my = tile_texture_utils.GetMiddle(sources)

  -- right: A->B
  local wl, wr = tile_texture_utils.TriangleTowardMiddle(sources, top, "top", mid, mx, my)

  -- left: reverse(G->H)
  local vl, vr, left = tile_texture_utils.TriangleTowardMiddle(sources, nil, "bottom", mid, mx, my, "reverse")

  -- top: D->F
  tile_texture_prims.SetEdgeNormal(-1, 0)
  shapes.Triangle(sources, vr, wl, mid)

  -- bottom: E->F
  local xl, xr, bottom = tile_texture_utils.TriangleTowardMiddle(sources, nil, "right", mid, mx, my)

  tile_texture_utils.CornerTriangles(sources, xr, vl, mid)
  tile_texture_utils.CornerTriangles(sources, wr, xl, mid)

  return left, bottom -- emit to top, left
end

--
--
--

-- 90-degree clockwise rotation of TopT
function Funcs.RightT (sources, top, left)
  local mid, mx, my = tile_texture_utils.GetMiddle(sources)

  -- right: reverse(G->H)
  local wl, wr, right = tile_texture_utils.TriangleTowardMiddle(sources, nil, "bottom", mid, mx, my, "reverse")

  -- left: A->B
  local vl, vr = tile_texture_utils.TriangleTowardMiddle(sources, top, "top", mid, mx, my)

  -- top: B->H
  tile_texture_prims.SetEdgeNormal(1, 0)
  shapes.Triangle(sources, vr, wl, mid)

  -- bottom: reverse(C->D)
  local xl, xr = tile_texture_utils.TriangleTowardMiddle(sources, left, "left", mid, mx, my, "reverse")

  tile_texture_utils.CornerTriangles(sources, xr, vl, mid)
  tile_texture_utils.CornerTriangles(sources, wr, xl, mid)

  return right, nil -- emit to top
end

--
--
--

-- takes TopT as point of departure, but top is new region U like bottom
function Funcs.FourWays (sources, top, left)
  local mid, mx, my = tile_texture_utils.GetMiddle(sources)

  -- left: reverse(C->D)
  local vl, vr = tile_texture_utils.TriangleTowardMiddle(sources, left, "left", mid, mx, my, "reverse")

  -- right: E->F
  local wl, wr, right = tile_texture_utils.TriangleTowardMiddle(sources, nil, "right", mid, mx, my)

  -- top: A->B
  local ul, ur = tile_texture_utils.TriangleTowardMiddle(sources, top, "top", mid, mx, my)

  tile_texture_utils.CornerTriangles(sources, vr, ul, mid)
  tile_texture_utils.CornerTriangles(sources, ur, wl, mid)

  -- bottom: reverse(G->H)
  local xl, xr, bottom = tile_texture_utils.TriangleTowardMiddle(sources, nil, "bottom", mid, mx, my, "reverse")

  tile_texture_utils.CornerTriangles(sources, xr, vl, mid)
  tile_texture_utils.CornerTriangles(sources, wr, xl, mid)

  return bottom, right -- emit to top, left
end

--
--
--

local function AuxGetProp (name, message)
  return assert(tile_texture_utils.GetProp(name), message)
end

--
--
--

local function PrepareCall ()
  local layer_count = AuxGetProp("layer_count", "Layer count missing")
  local corner_count = AuxGetProp("corner_count", "Corner count missing")
  local inside_curve_count = AuxGetProp("inside_curve_count", "Inside curve count missing")
  local x1 = AuxGetProp("x1", "x1 missing")
  local y1 = AuxGetProp("y1", "y1 missing")
  local x2 = AuxGetProp("x2", "x2 missing")
  local y2 = AuxGetProp("y2", "y2 missing")
  local offset = AuxGetProp("offset", "Offset missing")
  local tangent = AuxGetProp("tangent", "Tangent missing")
  local tstep = AuxGetProp("tangent_step", "Tangent step missing")

  assert(corner_count < layer_count)

  AuxGetProp("rectangle_count", "Rectangle count missing")
  AuxGetProp("outside_nub_count", "Outside nub count missing")

  --
  --
  --

  local outer_tangent = tangent + layer_count * tstep
  local b1, b2, b3, b4 = {}, {}, {}, {}
  local p1, p2, t1, t2 = { x = x1 }, { y = y2 }, { y = 0 }, { x = 0 }
  local p1y, p2x, t1x, t2y = y1 + offset, x2 - offset, outer_tangent, outer_tangent
  local dx, dy = (x2 - x1 - 2 * offset) / layer_count, (y2 - y1 - 2 * offset) / layer_count

  tile_texture_utils.SetProp("outer_tangent", outer_tangent)

  --
  --
  --

  local layers, outside_curve_count = {}, inside_curve_count + layer_count

  for _ = outside_curve_count, inside_curve_count, -1 do
    p1.y, t1.x, p1y, t1x = p1y, t1x, p1y + dy, t1x - tstep
    p2.x, t2.y, p2x, t2y = p2x, t2y, p2x - dx, t2y - tstep

    local set = sampling.New()

    convert.HermiteToBezier(p1, p2, t1, t2, b1, b2, b3, b4)
    bezier3.PopulateArcLengthLUT(set, b1, b2, b3, b4)

    layers[#layers + 1] = set
  end

  tile_texture_utils.SetProp("outside_curve_count", outside_curve_count)
  tile_texture_utils.SetProp("layers", layers)
end

--
--
--

function M.Call (what, sources, top, left)
  local func = Funcs[what]

  if func then
    local layers = tile_texture_utils.GetProp("layers")

    if not layers then
      PrepareCall()
    end

    return func(sources, top, left)
  end
end

--
--
--

return M