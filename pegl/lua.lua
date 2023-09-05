
local C = require'civ'
local pegl = require'pegl'

local Pat, Or, Many = pegl.Pat, pegl.Or, pegl.Many
local Empty, EOF = pegl.Empty, pegl.EOF

local nil_ = 'nil'
local bool = Or{'true', 'false'}
local num = Or{kind='num',
  Pat('0x[a-fA-F0-9]+', 'hex'),
  Pat('[0-9]+', 'dec'),
}

local quoteImpl = function(p, char, pat, kind)
  local l, c = p.l, p.c
  if not p:consume(char) then return end
  while true do
    local t = p:consume(pat)
    if t then
      local _, bs = string.match(p.line:sub(t.c, t.c2), pat)
      if C.isOdd(#bs) then
        t.l, t.c, t.kind = l, c, kind
        return t
      end
    else
      if p.line:sub(#p.line) == '\\' then
        p:incLine()
        if p:isEof() then error("Expected "..kind..", reached EOF") end
      else error("Expected "..kind..", reached newline") end
    end
  end
end

local singleQuote = function(p) return quoteImpl(p, "'", "(\\*)'", 'singleQuote') end
local doubleQuote = function(p) return quoteImpl(p, '"', '(\\*)"', 'doubleQuote') end

local rawQuote = function(p)
end
