
local C = require'civ'
local pegl = require'pegl'

local Pat, Or, Many = pegl.Pat, pegl.Or, pegl.Many
local Empty, EOF = pegl.Empty, pegl.EOF

local M = {}

M.nil_ = 'nil'
M.bool = Or{'true', 'false'}
M.num = Or{kind='num',
  Pat('0x[a-fA-F0-9]+', 'hex'),
  Pat('[0-9]+', 'dec'),
}

M.quoteImpl = function(p, char, pat, kind)
  p:skipEmpty()
  pnt('! quoteImpl', char, pat, kind)
  local l, c = p.l, p.c
  if not p:consume(char, true) then
    pnt('!    no char')
    return
  end
  while true do
    local c1, c2 = p.line:find(pat, p.c)
    pnt('! quoteImpl:', c1, c2)
    if c2 then
      p.c = c2 + 1
      local bs = string.match(p.line:sub(c1, c2), pat)
      pntf('! token bs=%s,%s  %s.%s  %s.%s', #bs, isOdd(#bs), l, c, p.l, c2)
      if C.isEven(#bs) then
        return Token{l=l, c=c, l2=p.l, c2=c2, kind=kind}
      end
    else
      if p.line:sub(#p.line) == '\\' then
        p:incLine()
        if p:isEof() then error("Expected "..kind..", reached EOF") end
      else error("Expected "..kind..", reached newline") end
    end
  end
end

M.singleQuote = function(p) return quoteImpl(p, "'", "(\\*)'", 'singleQuote') end
M.doubleQuote = function(p) return quoteImpl(p, '"', '(\\*)"', 'doubleQuote') end

M.rawQuote = function(p)
end

return M
