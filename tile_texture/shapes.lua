--- Tile shapes.

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

-- Plugins --
local bit = require("plugin.bit")

-- Modules --
local tile_texture_flags = require("s3_utils.tile_texture.flags")
local tile_texture_norms = require("s3_utils.tile_texture.norms")
local tile_texture_prims = require("s3_utils.tile_texture.prims")

-- Cached module references --
local _Trapezoid_

-- Exports --
local M = {}

--
--
--

local PrevRow, CurRow = {}, {}

function M.GetFromPreviousRow (index)
  return index < PrevRow.n and PrevRow[index]
end

--
--
--

local NubEdgeFlags = tile_texture_flags.DummyFirst + tile_texture_flags.OmitLast + tile_texture_flags.DoNormals + tile_texture_flags.ReverseEdge

--
--
--

function M.Nub (sources, edge, nlayers, nouter, interp, flags)
  assert(interp, "Nub must use interpolator")

  --
  --
  --

  local left, right, lhalf = {}, {}, nlayers / 2

  for i = 1, lhalf do
    right[i] = edge[i]
  end

  local nright, nedge = #right, #edge

  for i = 1, nright do
    left[i] = edge[nedge - i + 1]
  end

  --
  --
  --

  _Trapezoid_(sources, left, right, nouter, interp, flags)

  --
  --
  --

  local n, is = PrevRow.n, sources.indices
  local ehalf, nhalf = (nedge + 1) / 2, (n + 1) / 2
  local x1, y1, u = tile_texture_prims.GetPoint(sources, edge[ehalf])
  local x2, y2 = tile_texture_prims.GetPoint(sources, PrevRow[nhalf])
  local nx, ny = tile_texture_prims.GetEdgeNormal()

  tile_texture_prims.SetEdgeNormal(0, 0)

  local mid_edge = tile_texture_prims.Edge(sources, x1, y1, u, x2, y2, .5, lhalf + 1, bit.bor(flags or 0, NubEdgeFlags))

  tile_texture_prims.SetEdgeNormal(nx, ny)

  mid_edge[1] = edge[ehalf]
  mid_edge[#mid_edge + 1] = PrevRow[nhalf]

  for i = 1, lhalf + 1 do
    tile_texture_prims.AddIndexedTriangle(is, PrevRow[i], PrevRow[i + 1], mid_edge[i])
    tile_texture_prims.AddIndexedTriangle(is, PrevRow[i + 1], mid_edge[i], mid_edge[i + 1])
    tile_texture_prims.AddIndexedTriangle(is, mid_edge[i], PrevRow[n - i + 1], PrevRow[n - i])
    tile_texture_prims.AddIndexedTriangle(is, mid_edge[i], mid_edge[i + 1], PrevRow[n - i])
  end
end

--
--
--

local function GetFirstRow ()
  local first = PrevRow.set and 2 or 1

  PrevRow.set = nil

  return first
end

--
--
--

function M.Rectangle (sources, left, right, cols, opts)
  local is, vs, uvs, npoints = sources.indices, sources.vertices, sources.uvs, #left

  assert(npoints == #right, "Unbalanced rectangle edges")

  --
  --
  --

  local normals, norm_npoints, nx, ny = sources.normals

  if normals then
    if opts then
      norm_npoints, nx, ny = opts.norm_npoints, opts.nx, opts.ny
    end

    norm_npoints = norm_npoints or npoints

    if not nx then
      nx, ny = tile_texture_prims.HalfNormals(normals, left[1], right[1])
    end
  end

  --
  --
  --

  local arc = opts and opts.arc or "full"

  for i = GetFirstRow(), npoints do
    local lx, ly, lu = tile_texture_prims.GetPoint(sources, left[i])
    local rx, ry, ru = tile_texture_prims.GetPoint(sources, right[i])

    --
    --
    --

    CurRow[1] = left[i]

    for j = 1, cols - 1 do
      CurRow[j + 1] = tile_texture_prims.AddLerpedPair(vs, lx, ly, rx, ry, j / cols)

      if normals then
        tile_texture_norms.Arc(normals, arc, nx, ny, i - 1, norm_npoints - 1)
      end

      tile_texture_prims.AddU(uvs, lu, ru, j / cols, true)
    end

    CurRow[cols + 1] = right[i]
    CurRow.n = cols + 1

    --
    --
    --

    if i > 1 then
      for j = 1, cols do
        tile_texture_prims.AddIndexedTriangle(is, PrevRow[j], PrevRow[j + 1], CurRow[j])
        tile_texture_prims.AddIndexedTriangle(is, CurRow[j], PrevRow[j + 1], CurRow[j + 1])
      end
    end

    --
    --
    --

    CurRow, PrevRow = PrevRow, CurRow
  end
end

--
--
--

function M.SetPrevRow (edge, n)
  for i = 1, n or #edge do
    PrevRow[i] = edge[i]
  end

  PrevRow.n, PrevRow.set = n or #edge, true
end

--
--
--

local function DefInterp (sources, lx, ly, rx, ry, t)
  return tile_texture_prims.AddLerpedPair(sources.vertices, lx, ly, rx, ry, t)
end

--
--
--

function M.Trapezoid (sources, left, right, ntop, interp, flags)
  interp = interp or DefInterp

  --
  --
  --

  local nlayers = #left

  assert(nlayers == #right, "Unbalanced trapezoid sides")

  ntop = ntop or nlayers

  assert(ntop >= nlayers)

  --
  --
  --

  local normals, ul, nx, ny = interp == DefInterp and sources.normals, left[1], tile_texture_prims.GetEdgeNormal()
  local do_interior = tile_texture_flags.HasFlag(flags, "Interior")
  local do_parabola = tile_texture_flags.HasFlag(flags, "Parabola")
  local is, uvs, npoints = sources.indices, sources.uvs, ntop + 1

  for i = GetFirstRow(), nlayers do
    local lx, ly, lu = tile_texture_prims.GetPoint(sources, left[i])
    local rx, ry, ru = tile_texture_prims.GetPoint(sources, right[i])
    local w = npoints - i

    --
    --
    --

    CurRow[1] = left[i]

    for j = 1, w - 1 do
      local t = j / w

      if normals then
        if do_interior then
          tile_texture_norms.Interior(normals, j + 1, w, i - 1, nlayers - 1, ul)
        else
          tile_texture_norms.Arc(normals, "forward", nx, ny, i - 1, nlayers - 1)
        end
      end

      CurRow[j + 1] = interp(sources, lx, ly, rx, ry, t, i, nlayers)

      tile_texture_prims.AddU(uvs, lu, ru, t, do_parabola)
    end

    CurRow[w + 1] = right[i]
    CurRow.n = w + 1

    --
    --
    --

    if i > 1 then
      for j = 1, w do
        tile_texture_prims.AddIndexedTriangle(is, PrevRow[j], PrevRow[j + 1], CurRow[j])
      end
      
      for j = 1, w - 1 do
        tile_texture_prims.AddIndexedTriangle(is, CurRow[j], PrevRow[j + 1], CurRow[j + 1])
      end

      tile_texture_prims.AddIndexedTriangle(is, PrevRow[w + 1], right[i - 1], right[i])
      tile_texture_prims.AddIndexedTriangle(is, CurRow[w], PrevRow[w + 1], right[i])
    end

    --
    --
    --

    CurRow, PrevRow = PrevRow, CurRow
  end
end

--
--
--

function M.Triangle (sources, left, right, mid, flags)
  local nlayers = #left

  _Trapezoid_(sources, left, right, nil, nil, flags)

  tile_texture_prims.AddIndexedTriangle(sources.indices, left[nlayers], right[nlayers], mid)
end

--
--
--

_Trapezoid_ = M.Trapezoid

return M