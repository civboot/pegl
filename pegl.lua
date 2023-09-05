-- rd: recursive descent parser

local civ = require'civ'
local ty, extend = civ.ty, civ.extend
local add = table.insert

local M = {}

M.Token = struct('Token', {
  {'kind', Str},
  {'l', Int}, {'c', Int},
  {'l2', Int}, {'c2', Int},
})

M.RootSpec = struct('RootSpec', {
  -- function(p): skip empty space
  -- default: skip whitespace
  {'skipEmpty', civ.Fn},
})
M.RootSpec.__index = civ.listIndex

M.Parser = struct('Parser', {
  'dat', 'l', 'c', 'line', 'lines',
  {'root', M.RootSpec},
})

M.Or = civ.struct('Or', {{'kind', civ.Str, false}, })
M.Or.__index = civ.listIndex
M.Pat = civ.struct('Pat', {'kind', 'pattern'}) -- Pat('kind', 'abc.*123')
M.Pat.__index = civ.listIndex
civ.constructor(M.Pat, function(ty_, kind, pattern)
  return setmetatable({kind=kind, pattern=pattern}, M.Pat)
end)

-- Named Node from function
M.FnKind = struct('FnKind', {{'kind', civ.Str}, {'fn', civ.Fn}})
M.__tostring = function(f) return f.name end

-- Used in Seq to "pin" or "unpin" the parser, affecting when errors
-- are thrown.
M.PIN   = {'PIN'}
M.UNPIN = {'UNPIN'}

-- Denotes a missing node. When used in a spec simply returns Empty.
-- Example: Or{Integer, String, Empty}
M.Empty = {kind='Empty'}
M.EOF   = {kind='EOF'} -- End of File Node

local function Maybe(spec) return M.Or{spec, M.Empty} end

-- Skip all whitespace
M.RootSpec['#defaults'].skipEmpty = function(p)
  while true do
    if not p.line then return end
    if p.c > #p.line then
      p.l, p.c = p.l + 1, 1
      p.line = p.dat:getLine(p.l)
    else
      local c, c2 = string.find(p.line, '^%s', p.c)
      if not c then return end
      p.c = c2 + 1
    end
  end
end

-- Create node with optional kind
local function Node(t, kind)
  if t and kind then return {t, kind=kind} end
  return t
end

local function patImpl(p, kind, pattern, plain)
  if p:skipEmpty() then return nil end
  local c, c2 = string.find(p.line, pattern, p.c, plain)
  if c == c2 then
    p.c = c2 + 1
    return M.Token{kind=kind, l=p.l, c=c, l2=p.l, c2=c2}
  end
end

local SPEC = {
  [M.Empty]=function() return M.Empty end,
  [civ.Str]=function(p, keyword)
    return patImpl(p, keyword, keyword, true)
  end,
  [M.Pat]=function(p, pat)
    return patImpl(p, pat.kind, pat.pattern, false)
  end,
  [civ.Fn]=function(p, fn)
    if p:skipEmpty() then return nil end
    return fn(p)
  end,
  [M.FnKind]=function(p, fnKind)
    if p:skipEmpty() then return nil end
    return Node(fnKind.fn(p), fnKind.kind)
  end,
  [M.Or]=function(p, or_)
    if p:skipEmpty() then
      if or_[1] == M.EOF then return p:eof() end
      return nil
    end
    local lcs = p.lcs()
    for _, spec in ipairs(or_) do
      local t = M.parseSpec(p, spec)
      if t then return Node(t, or_.kind) end
      p.setLcs(lcs)
    end
  end,
  -- Sequence
  [civ.Tbl]=function(p, seq)
    local tokens, pin = {}, nil
    for _, spec in ipairs(seq) do
      if     spec == M.PIN   then pin = true;  goto continue
      elseif spec == M.UNPIN then pin = false; goto continue
      end

      if p:skipEmpty() then
        if spec == M.EOF then return p:eof() end
        return p:checkPin(pin, spec)
      end

      local t = M.parseSpec(p, spec)
      if not t then return p:checkPin(pin, spec) end
      add(tokens, t)
      pin = (pin == nil) and true or pin
    ::continue::end
    return Node(tokens, seq.kind)
  end,
}

civ.methods(M.Parser, {
parse=function(p, spec)
  local specFn = SPEC[ty(spec)]
  return specFn(p, spec)
end,
eof=function(p) return M.Token{
  kind='EOF', l=p.l, c=1, l2=p.l, c2=1
}end,
skipEmpty=function(p)
  p.emptySpaceFn(p)
  if not p.line then return true end
end,
lcs   =function(p) return {p.l, p.c, p.l2, p.c2, p.line} end,
setLcs=function(p, lcs) p.l, p.c, p.l2, p.c2, p.line = lcs end,

parse=function(p, spec)
  return M.parseSpec(p, spec)
end,
checkPin=function(p, pin, expect)
  if not pin then return end
  if p.line then
    civ.errorf(
      "! Parse Error %s.%s, expected: %s\nGot: %s",
      p.l, p.c, expect, p.line:sub(p.c))
  else
    civ.errorf(
      "! Parse Error %s.%s, reached EOF but expected: %s",
      p.l, p.c, expect)
  end
end,
})

return M
