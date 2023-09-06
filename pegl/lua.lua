
local C = require'civ'
local pegl = require'pegl'

local Pat, Or, Many = pegl.Pat, pegl.Or, pegl.Many
local Empty, EOF = pegl.Empty, pegl.EOF
local PIN, UNPIN = pegl.PIN, pegl.UNPIN

local M = {}

M.expr = Or{}

M.name = Pat('%w+', 'name')
M.nil_ = Pat('nil', 'nil_')
M.bool = Or{'true', 'false', kind='bool'}
M.num = Or{kind='num',
  Pat('0x[a-fA-F0-9]+', 'hex'),
  Pat('[0-9]+', 'dec'),
}

M.quoteImpl = function(p, char, pat, kind)
  p:skipEmpty()
  local l, c = p.l, p.c
  if not p:consume(char) then return end
  while true do
    local c1, c2 = p.line:find(pat, p.c)
    if c2 then
      p.c = c2 + 1
      local bs = string.match(p.line:sub(c1, c2), pat)
      if C.isEven(#bs) then
        return Token{l=l, c=c, l2=p.l, c2=c2, kind=kind}
      end
    else
      if p.line:sub(#p.line) == '\\' then
        p:incLine(); if p:isEof() then error("Expected "..kind..", reached EOF") end
      else error("Expected "..kind..", reached end of line") end
    end
  end
end

M.singleStr = function(p) return quoteImpl(p, "'", "(\\*)'", 'singleStr') end
M.doubleStr = function(p) return quoteImpl(p, '"', '(\\*)"', 'doubleStr') end
M.bracketStr = function(p)
  p:skipEmpty()
  local l, c = p.l, p.c
  local start = p:consume('%[=*%['); if not start then return end
  local pat = '%]'..string.rep('=', start.c2 - start.c1 - 1)..'%]'
  while true do
    local c1, c2 = p.line:find(pat, p.c)
    if c2 then return Token{l=l, c=c, l2=p.l, c2=c2}
    else
      p:incLine()
      if p:isEof() then error(
        "Expected closing "..pat:gsub('%%', '')..", reached EOF"
      )end
    end
  end
end
M.str   = Or{M.singleStr, M.doubleStr, M.bracketStr}
M.value = Or{kind='value', M.nil_, M.bool, M.num, M.str, M.name}

M.key  = Or{
  {'[', M.value, ']'},
  M.name,
}
M.item = Or{kind='item',
  {UNPIN, M.key, '=', M.value},
  M.value,
}
M.table_  = {kind='table', '{', Many{
  M.item, Or{',', Empty},
}, '}'}

return M
