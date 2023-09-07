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
M.Token.__fmt = function(t, f)
  if t.kind then extend(f, {'Token(', t.kind, ')'})
  else civ.tblFmt(t, f) end
end

M.RootSpec = struct('RootSpec', {
  -- function(p): skip empty space
  -- default: skip whitespace
  {'skipEmpty', civ.Fn},
  {'dbg', Bool, false},
})

M.Parser = struct('Parser', {
  'dat', 'l', 'c', 'line', 'lines',
  {'root', M.RootSpec},
  {'dbgIndent', Int, 0},
})

M.fmtSpec = function(s, f)
  if type(s) == 'string' then
    return add(f, string.format("%q", s))
  end
  if type(s) == 'function' then
    return add(f, civ.fnToStr(s))
  end
  if s.name or s.kind then
    add(f, '<'); add(f, s.name or s.kind); add(f, '>')
    return
  end
  add(f, civ.tyName(s));
  f:levelEnter('{')
  for i, sub in ipairs(s) do
    M.fmtSpec(sub, f);
    if i < #s then f:sep(' ') end
  end
  f:levelLeave('}')
end
M.specToStr = function(s, set)
  local set = set or {}
  if set.pretty == nil then set.pretty = true end
  local f = civ.Fmt{set=set}; M.fmtSpec(s, f); return f:toStr()
end

local function newSpec(name, fields)
  local st = civ.struct(name, fields)
  st['#attr'] = {list = true}
  st.__index = civ.listIndex
  st.__fmt = M.fmtSpec
  return st
end

local FIELDS = {
  {'kind', civ.Str, false},
  {'name', civ.Str, false}, -- for fmt only
}
M.Pat = newSpec('Pat', {'pattern', 'kind', 'name'})
civ.constructor(M.Pat, function(ty_, pattern, kind)
  return setmetatable({kind=kind, pattern=pattern}, M.Pat)
end)

M.Or = newSpec('Or', FIELDS)
M.Maybe = function(spec) return M.Or{spec, M.Empty} end
M.Many = newSpec('Many', {
  {'kind', civ.Str, false}, {'min', civ.Num, 0},
  {'name', civ.Str, false},
})
M.Seq = newSpec('Seq', FIELDS)
M.Not = newSpec('Not', FIELDS)

-- Used in Seq to "pin" or "unpin" the parser, affecting when errors
-- are thrown.
M.PIN   = {name='PIN'}
M.UNPIN = {name='UNPIN'}

-- Denotes a missing node. When used in a spec simply returns Empty.
-- Example: Or{Integer, String, Empty}
M.EmptyTy = civ.struct('Empty', FIELDS)
M.Empty = M.EmptyTy{kind='Empty'}
M.EmptyNode = {kind='Empty'}

-- Denotes the end of the file
M.EofTy = civ.struct('EOF', FIELDS)
M.EOF = M.EofTy{kind='EOF'}
M.EofNode = {kind='EOF'}

-- Skip all whitespace
M.RootSpec['#defaults'].skipEmpty = function(p)
  while true do
    if p:isEof() then return end
    if p.c > #p.line then p:incLine()
    else
      local c, c2 = string.find(p.line, '^%s', p.c)
      if not c then return end
      p.c = c2 + 1
    end
  end
end

local UNPACK_SPECS = Set{M.Tbl, M.Seq, M.Many, M.Or}
local function shouldUnpack(spec, t)
  local r = (
    type(t) == 'table'
    and UNPACK_SPECS[ty(spec)]
    and ty(t) ~= M.Token
    and not rawget(spec, 'kind')
    and not rawget(t, 'kind')
  )
  return r
end

-- Create node with optional kind
local function node(spec, t, kind)
  if type(t) ~= 'boolean' and t and kind then
    if type(t) == 'table' and not t.kind then
      t.kind = kind
    else t = {t, kind=kind} end
  end
  if t and shouldUnpack(spec, t) and #t == 1 then
    t = t[1]
  end
  return t
end

local function patImpl(p, kind, pattern, plain)
  local t = p:consume(pattern, plain)
  if t then
    p:dbgMatched(kind or pattern)
    t.kind = kind
  end
  return t
end

local SPEC = {}


local function _seqAdd(p, out, spec, t)
  if type(t) == 'boolean' then -- skip
  elseif shouldUnpack(spec, t) then
    p:dbgUnpack(spec, t)
    extend(out, t)
  else add(out, t) end
end

local function parseSeq(p, seq)
  local out, pin = {}, nil
  p:dbgEnter(seq)
  for i, spec in ipairs(seq) do
    if     spec == M.PIN   then pin = true;  goto continue
    elseif spec == M.UNPIN then pin = false; goto continue
    end
    local t = p:parse(spec)
    if not t then
      p:dbgMissed(spec)
      p:dbgLeave()
      return p:checkPin(pin, spec)
    end
    _seqAdd(p, out, spec, t)
    pin = (pin == nil) and true or pin
  ::continue::end
  local out = node(seq, out, seq.kind)
  p:dbgLeave(out)
  return out
end

local function parseOr(p, or_)
  p:skipEmpty()
  p:dbgEnter(or_)
  local state = p:state()
  for _, spec in ipairs(or_) do
    local t = p:parse(spec)
    if t then
      t = node(spec, t, or_.kind); p:dbgLeave(t)
      return t
    end
    p:setState(state)
  end
  p:dbgLeave()
end

civ.update(SPEC, {
  [civ.Str]=function(p, keyword) return patImpl(p, keyword, keyword, true) end,
  [M.Pat]=function(p, pat) return patImpl(p, pat.kind, pat.pattern, false) end,
  [M.EmptyTy]=function() return M.EmptyNode end,
  [M.EofTy]=function(p)
    p:skipEmpty(); if p:isEof() then return M.EofNode end
  end,
  [civ.Fn]=function(p, fn) p:skipEmpty() return fn(p) end,
  [M.Or]=parseOr,
  [M.Not]=function(p, spec) return not parseSeq(p, spec) end,
  [M.Seq]=parseSeq,
  [civ.Tbl]=function(p, seq) return parseSeq(p, M.Seq(seq)) end,
  [M.Many]=function(p, many)
    local out = {}
    local seq = copy(many); seq.kind = nil
    p:dbgEnter(many)
    while true do
      local t = parseSeq(p, seq)
      if not t then break end
      if ty(t) ~= M.Token and #t == 1 then add(out, t[1])
      else _seqAdd(p, out, many, t) end
    end
    if #out < many.min then
      out = nil
      p:dbgMissed(many, ' got count='..#out)
    end
    p:dbgLeave(many)
    return node(many, out, many.kind)
  end,
})

-- parse('hi + there', {Pat('\w+'), '+', Pat('\w+')})
-- Returns tokens: 'hi', {'+', kind='+'}, 'there'
M.parse=function(dat, spec, root)
  local p = M.Parser.new(dat, root)
  return p:parse(spec)
end

local function toStrTokens(dat, n)
  if not n then return nil end
  if SPEC[n] then
    return n
  end
  if ty(n) == M.Token then
    return node(Pat, dat:sub(n.l, n.c, n.l2, n.c2), n.kind)
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
M.parseStrs=function(dat, spec, root)
  local dat = defaultDat(dat)
  local node = M.parse(dat, spec, root)
  return toStrTokens(dat, node)
end

M.assertParse=function(dat, spec, expect, dbg)
  local result = M.parseStrs(dat, spec, RootSpec{dbg=dbg})
  civ.assertEq(expect, result, dbg)
end

M.assertParseError=function(dat, spec, errPat, plain)
  civ.assertError(
    function() M.parse(dat, spec) end,
    errPat, plain)
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
peek=function(p, pattern, plain)
  if p:skipEmpty() then return nil end
  local c, c2 = string.find(p.line, pattern, p.c, plain)
  if c == p.c then return M.Token{l=p.l, c=c, l2=p.l, c2=c2} end
end,
consume=function(p, pattern, plain)
  local t = p:peek(pattern, plain)
  if t then p.c = t.c2 + 1 end
  return t
end,
sub=function(p, t) -- t=token
  return p.dat:sub(t.l, t.c, t.l2, t.c2)
end,
incLine=function(p)
  p.l, p.c = p.l + 1, 1
  p.line = p.dat:getLine(p.l)
end,
isEof=function(p) return not p.line end,
skipEmpty=function(p)
  p.root.skipEmpty(p)
  return p:isEof()
end,
state   =function(p) return {l=p.l, c=p.c, line=p.line} end,
setState=function(p, st) p.l, p.c, p.line = st.l, st.c, st.line end,

parse=function(p, spec)
  return SPEC[ty(spec)](p, spec)
end,
checkPin=function(p, pin, expect)
  if not pin then return end
  if p.line then
    civ.errorf(
      "ERROR %s.%s, parser expected: %s\nGot: %s",
      p.l, p.c, expect, p.line:sub(p.c))
  else
    civ.errorf(
      "ERROR %s.%s, parser reached EOF but expected: %s",
      p.l, p.c, expect)
  end
end,

dbgEnter=function(p, spec)
  if not p.root.dbg then return end
  p:dbg('ENTER:%s', civ.fmt(spec))
  p.dbgIndent = p.dbgIndent + 1
end,
dbgLeave=function(p, n)
  if not p.root.dbg then return end
  p.dbgIndent = p.dbgIndent - 1
  p:dbg('LEAVE: %s', fmt(n or '((none))'))
end,
dbgMatched=function(p, spec)
  if not p.root.dbg then return end
  p:dbg('MATCH:%s', civ.fmt(spec))
end,
dbgMissed=function(p, spec, note)
  if not p.root.dbg then return end
  p:dbg('MISS:%s%s', civ.fmt(spec), (note or ''))
end,
dbgUnpack=function(p, spec, t)
  if not p.root.dbg then return end
  p:dbg('UNPACK: %s :: %s', fmt(spec), fmt(t))
end,
dbg=function(p, fmt, ...)
  if not p.root.dbg then return end
  local msg = sfmt(fmt, ...)
  pntf('%%%s %s (%s.%s)', string.rep('  ', p.dbgIndent), msg, p.l, p.c)
end,
})

return M
