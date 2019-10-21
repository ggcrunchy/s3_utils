--- Useful synonyms for branch-free ops described in [Avoiding Shader Conditionals](http://theorangeduck.com/page/avoiding-shader-conditionals).

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

-- Modules --
local includer = require("corona_utils.includer")

-- Exports --
local M = {}

--
--
--

--- DOCME
M.RELATIONAL = includer.AddSnippet[[

    #define WHEN_EQ(x, y) (1. - abs(sign(x - y)))
    #define WHEN_NE(x, y) abs(sign(x - y))
    #define WHEN_GT(x, y) max(sign(x - y), 0.)
    #define WHEN_LT(x, y) max(sign(y - x), 0.)
    #define WHEN_GE(x, y) (1. - WHEN_LT(x, y))
    #define WHEN_LE(x, y) (1. - WHEN_GT(x, y))
]]

--- DOCME
M.LOGICAL = includer.AddSnippet[[

    #define LOGICAL_AND (a, b) (a * b)
    #define LOGICAL_NOT (a) (1. - a)
    #define LOGICAL_OR (a, b) min(a + b, 1.)
    #define LOGICAL_XOR (a, b) mod(a + b, 2.)
]]

return M