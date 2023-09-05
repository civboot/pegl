-- rd: recursive descent parser

local civ = require'civ'
local gap = require'civ.gap'
local ty, extend = civ.ty, civ.extend
local add = table.insert

local M = {}
local sfmt = string.format

M.Token = struct('Token', {
  'kind',
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

M.Pat = civ.struct('Pat', {'pattern', 'kind'})
M.Pat.__index = civ.listIndex
civ.constructor(M.Pat, function(ty_, pattern, kind)
  return setmetatable({kind=kind, pattern=pattern}, M.Pat)
end)
M.Or = civ.struct('Or', {{'kind', civ.Str, false}, })
M.Or['#attr'] = {list = true}
M.Or.__index = civ.listIndex
M.Many = civ.struct('Many', {{'kind', civ.Str, false}, {'min', civ.Num, 0}})
M.Many['#attr'] = {list = true}
M.Many.__index = civ.listIndex

-- Used in Seq to "pin" or "unpin" the parser, affecting when errors
-- are thrown.
M.PIN   = {'PIN'}
M.UNPIN = {'UNPIN'}

-- Denotes a missing node. When used in a spec simply returns Empty.
-- Example: Or{Integer, String, Empty}
M.EmptyTy = civ.struct('Empty', {})
M.Empty = M.EmptyTy{}
M.EmptyNode = {kind='Empty'}

-- Denotes the end of the file
M.EofTy = civ.struct('EOF', {})
M.EOF = M.EofTy{}
M.EofNode = {kind='EOF'}

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
  if c == p.c then
    p.c = c2 + 1
    return M.Token{kind=kind, l=p.l, c=c, l2=p.l, c2=c2}
  end
end

local SPEC = {}
local function parseSpec(p, spec)
  return SPEC[ty(spec)](p, spec)
end

local function parseSeq(p, seq)
  local out, pin = {}, nil
  for i, spec in ipairs(seq) do
    if     spec == M.PIN   then pin = true;  goto continue
    elseif spec == M.UNPIN then pin = false; goto continue
    end
    local t = parseSpec(p, spec)
    if not t then return p:checkPin(pin, spec) end
    add(out, t)
    pin = (pin == nil) and true or pin
  ::continue::end
  return Node(out, seq.kind)
end

civ.update(SPEC, {
  [civ.Tbl]=parseSeq,
  [civ.Str]=function(p, keyword) return patImpl(p, keyword, keyword, true) end,
  [M.Pat]=function(p, pat) return patImpl(p, pat.kind, pat.pattern, false) end,
  [M.EmptyTy]=function() return M.EmptyNode end,
  [M.EofTy]=function(p)
    p:skipEmpty(); if p:isEof() then return M.EofNode end
  end,
  [civ.Fn]=function(p, fn) p:skipEmpty() return fn(p) end,
  [M.Or]=function(p, or_)
    p:skipEmpty()
    local lcs = p:lcs()
    for _, spec in ipairs(or_) do
      local t = parseSpec(p, spec)
      if t then return Node(t, or_.kind) end
      p.setLcs(lcs)
    end
  end,
  [M.Many]=function(p, many)
    local out = {kind=many.kind}
    local seq = copy(many); seq.kind = nil
    while true do
      local t = parseSeq(p, seq)
      if not t then break end
      if ty(t) ~= M.Token and #t == 1 then add(out, t[1])
      else add(out, t) end
    end
    if #out < many.min then return nil end
    return out
  end,
})

-- parse('hi + there', {Pat('\w+'), '+', Pat('\w+')})
-- Returns tokens: 'hi', {'+', kind='+'}, 'there'
M.parse=function(dat, spec, root)
  local p = M.Parser.new(dat, root)
  return parseSpec(p, spec)
end

local function toStrTokens(dat, n)
  if not n then return nil end
  if SPEC[n] then
    return n
  end
  if ty(n) == M.Token then
    return Node(dat:sub(n.l, n.c, n.l2, n.c2), n.kind)
  end
  local out = {kind=n.kind}
  for _, n in ipairs(n) do
    add(out, toStrTokens(dat, n))
  end
  return out
end; M.toStrTokens = toStrTokens

local function defaultDat(dat)
  if type(dat) == 'string' then return gap.Gap.new(dat)
  else return dat end
end

-- Parse and convert into StrTokens. Str tokens are
-- tables (lists) with the 'kind' key set.
--
-- This is primarily used for testing
M.parseStrs=function(dat, spec)
  local dat = defaultDat(dat)
  local node = M.parse(dat, spec)
  return toStrTokens(dat, node)
end

M.assertTokens=function(dat, spec, expect)
  local result = M.parseStrs(dat, spec)
  civ.assertEq(expect, result)
end

civ.methods(M.Parser, {
__tostring=function() return 'Parser()' end,
new=function(dat, root)
  dat = defaultDat(dat)
  return M.Parser{
    dat=dat, l=1, c=1, line=dat:getLine(1), lines=dat:len(),
    root=root or RootSpec{},
  }
end,
parse=function(p, spec)
  local specFn = SPEC[ty(spec)]
  return specFn(p, spec)
end,
isEof=function(p) return not p.line end,
skipEmpty=function(p)
  p.root.skipEmpty(p)
  return p:isEof()
end,
lcs   =function(p) return {p.l, p.c, p.line} end,
setLcs=function(p, lcs) p.l, p.c, p.line = lcs end,

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
