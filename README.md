# PEGL: PEG-like recursive descent Parser in Lua

> WARNING: PEGL is in development and is not yet ready for use.
> Initial (demo) implementation is done but PEGL is not yet used for
> any "real" parsing.

PEGL is PEG like recursive descent Parser written in Lua.

Recursive descent is simultaniously one of the (conceptually) simplest parsers
while also being the one of the most powerful. PEG is one of the simplest
parser-combinator languages, conceptually implementing a recursive descent
parser with a specific subset of features.

PEGL implements those features as a ultra-lightweight Lua library, maintaining
conciseness while avoiding any customized syntax.

## Resources
If you are completely new to parsers and especially if you want to write your
own language with an AST then I cannot recommend
[craftinginterpreters.com](http://www.craftinginterpreters.com) enough. Go check
it out before digging too deeply into PEGL.

## Introduction
A parser is a way to convert text into structured node objects so that
the text can be compiled or annotated by a program. For example you might want
to convert some source code like:

```
x = 1 + 2
```

Into something like:

```
{'x', '=', {'1', '+', '2'}}
```

A recursive descent parser does so via hand-rolled functions which typically
_recurse_ into eachother. Each function attempts to parse from the current
parser position using it's spec (which may be composed of calling other parsing
functions) and returns either the successfully parsed node or `nil` (or perhaps
raises an error if it finds a syntax error).  PEGL is a lua library for writing
the common-cases of a recursive descent parser in a (pure Lua) syntax similar to
PEG, while still being able to fallback to hand-rolled recursive descent when
needed.

Most traditional PEG parsers struggle with complicated syntax such as Lua's
`[===[raw string syntax]===]`, python's whitespace denoted syntax or C's
lookahead requirements (`(U2)*c**h`) -- recursive descent can solve alot of
these problems relatively easily and performantly.  However, recursive descent
parsers can be very verbse and sometimes difficult to scan. Below is a
comparison of the above example in both PEG, PEGL and a "traditional" (though
not very good) recursive descent implementation.

### Examples

PEG: most concise but harder to fallback to hand-rolled recursive descent
```
grammar = [[
num    <- '%d'
name   <- '%w'
setVar <- num '=' name
expr   <- setVar / ... other valid expressions
]]
p:parse(grammar)
```

PEGL: very concise and easy to fallback to hand-rolled recursive descent
```
Num    = Pat('%d+', 'num')
Name   = Pat('%w+', 'name')
SetVar = {Name, '=', Num, kind='setVar'}
Expr   = Or{SetVar, ... other valid expressions, kind='expr'}
p:parse(Expr)
```

Hand-rolled recursive descent: not very concise
```
-- Note: p=parser, an object which tracks the current position
-- in it's `state`

function parseNum(p)
  local num = p:consume('%d+') -- return result and advance position
  if num then -- found
    return {num, kind='num'} end
  end
end

function parseSetVar(p)
  local state = p.state()
  local name = p:consume('%w+')
  if not name then return end
  local eq, num = p:consume('='), parseNum(p)
  if not (eq and num) then
    -- didn't match, reset state and return
    p.setState(state)
    return
  end
  return {{name, kind='name'}, eq, num, kind='setVar'}
end

function expression(p)
  local expr = parseSetVar(p)
  if expr then return expr end
  -- ... other possible expressions
end

expression(p)
```
