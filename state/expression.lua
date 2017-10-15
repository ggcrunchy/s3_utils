--- Glue expressions for complex predicates.

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

-- Exports --
local M = {}

--- DOCME
function M.Parse (expr)
	--
end

--- DOCME
function M.Validate (expr)
	--
end

--[[
--
--
-- ConditionNode_Parser.cpp
--
--
#include "stdafx.h"
#include "conditionnode.h"
#include "condition_components/conditioncomponents.h"
#include "entityhelpers.h"
#include "Lua_/Lua.h"

/// State of a condition glue expression parse
class ParseState {
public:
	ParseState (void);

	bool Parse (VisTypedEngineObject_cl * pObject, const VString & expr);

	const DynArray_cl<ConditionComponent_cl *> & GetComponents (void) const { return mComps; }
	const VString & GetStream (void) const { return mStream; }

private:
	void AddToken (char c) { mStream += c; }

	bool Error (const char * error, ...);
	bool ParseExpression (const char * str, DynArray_cl<int> & label_ranges);
	bool ParseKeyword (const char * word, int len);
	bool WasLabelOrRParen (void);

	// Implementation
	DynArray_cl<ConditionComponent_cl *> mComps;///< Components associated with labels
	VString mStream;///< Stream compiled during parse, or error string on failure
	bool mInError;	///< If true, an error occurred
};

/// Constructor
ParseState::ParseState (void) : mInError(false)
{
	mComps.Init(NULL);
}

/// Puts the parse state into an error mode and stores the error message
/// @param str Error string, which can include format codes
/// @param ... Additional error arguments
/// @return @b false, for convenience as return value
bool ParseState::Error (const char * str, ...)
{
	// Replace the stream with the error.
	va_list args;

	va_start(args, str);

	mStream.FormatArgList(str, args);

	va_end(args);

	// Put the state into error mode.
	mInError = true;

	return false;
}

/// Helper to process keywords and ensure expression integrity
/// @param word Pointer to beginning of word
/// @param len Length of word (as @a word in general will not be not null-terminated)
/// @return If true, the word is a keyword
bool ParseState::ParseKeyword (const char * word, int len)
{
	bool bFollow = WasLabelOrRParen();

	DO_ARRAY(struct {
		const char * mWord;	///< Keyword string
		char mToken;///< Keyword shorthand token
		bool mFollow;	///< If true, keyword must follow label / right parenthesis; otherwise, it cannot
	}, keywords, i,
		{ "and", '&', true },
		{ "or", '|', true },
		{ "not", '~', false }
	) {
		if (strncmp(word, keywords[i].mWord, len) != 0) continue;

		if (keywords[i].mFollow == bFollow) AddToken(keywords[i].mToken);

		else Error("Keyword '%s' %s follow a ')' or a label", keywords[i].mWord, keywords[i].mFollow ? "must" : "cannot");

		return true;
	}

	return false;
}

/// Expression parsing body; tokens are added to the stream
/// @param str String to parse
/// @param label_ranges [out] Storage for <begin, end> offset pairs for label substrings
/// @return If true, expression was well-formed
bool ParseState::ParseExpression (const char * str, DynArray_cl<int> & label_ranges)
{
	for (int i = 0, lindex = 0, parens = 0, begin = -1; ; ++i)
	{
		char ec = str[i];

		// Do non-label / non-keyword logic on encountering a space or parenthesis. The
		// null terminator is also handled here in case the expression ends with a label.
		if ('(' == ec || ')' == ec || isspace(ec) || !ec)
		{
			// If a word has been forming, stop doing so and classify it.
			if (begin != -1)
			{
				VASSERT(begin < i);

				// Check whether the word is a keyword and handle it if so. Otherwise, the
				// word is a label and its range is stored.
				if (!ParseKeyword(str + begin, i - begin))
				{
					if (WasLabelOrRParen()) return Error("Label cannot follow a ')' or another label (separate with 'and' / 'or')");

					label_ranges.GetDataPtr()[lindex++] = begin;
					label_ranges.GetDataPtr()[lindex++] = i - 1;

					AddToken('L');
				}

				// If a keyword error occurred, quit.
				else if (mInError) return false;

				// Stop forming word.
				begin = -1;
			}

			// Terminate the loop on the null character. Includes special case for empty expression.
			if (!ec)
			{
				if (parens > 0) return Error("Dangling '(': missing one or more ')' characters");
				if (i > 0 && !WasLabelOrRParen()) return Error("Last term must be a ')' or a label");

				break;
			}

			// In the case of either parenthesis, open or close the pair and append the token
			// to the stream. Spaces leave the stream intact.
			else if (!isspace(ec))
			{
				if ('(' == ec)
				{
					if (WasLabelOrRParen()) return Error("Label or ')' cannot precede a '('");

					++parens;
				}

				else
				{
					if (!WasLabelOrRParen()) return Error("Label or other ')' must precede a ')'");
					if (--parens < 0) return Error("Unbalanced ')': does not match a '('");
				}

				AddToken(ec);
			}
		}

		// Otherwise, continue the word or start a new one. Verification against the
		// previous token must wait until the word has been classified.
		else
		{
			if (-1 == begin) begin = i;

			if (ec != '_' && !isalnum(ec)) return Error("Label or keyword must contain only '_', letters, or digits");
		}
	}

	return true;
}

/// Common previous term case
/// @return If true, the last term was a label or a right parenthesis
bool ParseState::WasLabelOrRParen (void)
{
	return mStream.EndsWith(')') || mStream.EndsWith('L');
}

/// Parses an expression and builds a list of condition components matching embedded labels
/// @param pObject Once labels have been enumerated, condition lookup is performed in its component list
/// @param expr Expression to parse
/// @return If true, parse was successful or @a expr is empty
bool ParseState::Parse (VisTypedEngineObject_cl * pObject, const VString & expr)
{
	// An empty expression is trivially successful.
	if (expr.IsEmpty()) return true;

	// Try to parse the expression. The label range array size will be just enough when the
	// expression is just a single-character label, and otherwise is safely overestimated.
	DynArray_cl<int> label_ranges(expr.GetLength() * 2, -1);

	if (!ParseExpression(expr, label_ranges)) return false;

	// Cache labeled condition component indices. Again, the array is usually overestimated,
	// but will be filled if the list consists completely of condition components.
	DynArray_cl<ConditionComponent_cl *> comps(pObject->Components().Count(), NULL);

	unsigned comps_size = 0;

	for (unsigned i = 0; i < comps.GetSize(); ++i)
	{
		IVObjectComponent * pComp = pObject->Components().GetPtrs()[i];

		if (pComp && pComp->IsOfType(V_RUNTIME_CLASS(ConditionComponent_cl))) comps[comps_size++] = (ConditionComponent_cl *)pComp;
	}

	// Try to pair each label with a condition component.
	unsigned range_size = label_ranges.GetValidSize();

	VASSERT(range_size % 2 == 0);

	mComps.Resize(range_size / 2);

	for (unsigned i = 0; i < range_size; i += 2)
	{
		VString label;

		label.Left(expr.AsChar() + label_ranges[i], label_ranges[i + 1] - label_ranges[i] + 1);

		for (unsigned j = 0; j < comps_size; ++j)
		{
			if (!comps[j]->MatchesLabel(label)) continue;

			if (mComps.Get(i / 2)) return Error("Object has multiple condition components matching label: %s", label.AsChar());

			mComps.GetDataPtr()[i / 2] = comps[j];
		}

		// Check for failed matches.
		if (!mComps.Get(i / 2)) return Error("Object has no condition component matching label: %s", label.AsChar());
	}

	return true;
}

/// Processes a conditional expression and, on success, stores the results for further use
/// @param pObject Owner of any condition components referenced by the expression
/// @param expr Conditional expression that glues together 0 or more labeled condition components
/// @param result [in-out] On success, the results of the process
/// @return If true, processing succeeded
/// @remark An expression can be composed of the following terms: <b>(</b> <b>)</b> @b and @b or @b not
/// @remark Other words (i.e. any combination of letters, digits, and underscores) are interpreted as labels
/// @remark Given the above, the expression must compile as <b>return @a expr</b> in Lua
/// @remark Labels are ignored during compilation, being replaced by their condition's expansion
/// @remark Furthermore, if a label appears more than once, each instance is thus expanded
bool CompoundConditionNode_cl::ProcessExpression (VisTypedEngineObject_cl * pObject, const VString & expr, ProcessResult & result)
{
	// Attempt to parse the expression. On failure, save the error and quit.
	ParseState state;

	if (!state.Parse(pObject, expr))
	{
		result.mString = state.GetStream();

		return false;
	}

	// If the data is wanted, copy the component list and expand the stream.
	if (result.mGetData)
	{
		result.mComps = state.GetComponents();

		// Get the expression string rebuilt with format specifiers in place of the labels,
		// now that those are collected in-order in the components list.
		const VString & stream = state.GetStream();

		for (int i = 0, n = stream.GetLength(); i < n; ++i)
		{
			char cc = stream[i];

			// Labels (guard expansions with parentheses following a "not")
			if ('L' == cc)
			{
				result.mString += i > 0 && '~' == stream[i - 1] ? "(%s)" : "%s"; 

				++result.mCount;
			}

			// Keywords
			else if ('&' == cc)	result.mString += " and ";
			else if ('|' == cc)	result.mString += " or ";
			else if ('~' == cc)	result.mString += "not ";

			// Parentheses
			else result.mString += cc;
		}
	}

	return true;
}

/// Validates that the expression and condition components yield a valid condition node
/// @param pObject Owner of any condition components referenced by the expression
/// @param expr Conditional expression that glues together 0 or more labeled condition components
/// @param iParam [out] Validation argument, passed to FailValidation() on failure
/// @param bAllowEmpty If true, empty (trivially valid) expressions are accepted
void CompoundConditionNode_cl::ValidateExpression (VisTypedEngineObject_cl * pObject, const VString & expr, INT_PTR iParam, bool bAllowEmpty)
{
	if (!bAllowEmpty && expr.IsEmpty()) FailValidation(iParam, "Empty expression");

	else
	{
		ProcessResult result;

		result.mGetData = false;

		if (!ProcessExpression(pObject, expr, result)) FailValidation(iParam, "Failed to parse expression, \"%s\": %s", expr.AsChar(), result.mString.AsChar());
	}
}

/// Generates a condition node from an intermediate object
/// @param pObject Owner of any condition components referenced by the expression
/// @param expr Conditional expression that glues together 0 or more labeled condition components
/// @return Compound condition node with the given expression and fresh copies of the relevant components
CompoundConditionNode_cl * CompoundConditionNode_cl::FromObject (VisTypedEngineObject_cl * pObject, const VString & expr)
{
	CompoundConditionNode_cl * pNode = (CompoundConditionNode_cl *)Vision::Game.CreateEntity("CompoundConditionNode_cl", VisVector_cl());

	pNode->SetParentZone(pObject->GetParentZone());

	pNode->Expression = expr;

	CopyComponents(pObject, pNode, V_RUNTIME_CLASS(ConditionComponent_cl));

	return pNode;
}
--]]

-- TODO: better as LPEG?

-- Export the module.
return M