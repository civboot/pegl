-- Lua syntax in PEGL
--
-- I used http://parrot.github.io/parrot-docs0/0.4.7/html/languages/lua/doc/lua51.bnf.html
-- as a reference

local civ = require'civ'
local pegl = require'pegl'
local add = table.insert

local Pat, Or, Many = pegl.Pat, pegl.Or, pegl.Many
local Empty, EOF = pegl.Empty, pegl.EOF
local PIN, UNPIN = pegl.PIN, pegl.UNPIN

local stmt = Or{}
local name = Pat('%w+', 'name')
local num = Or{
  Pat('0x[a-fA-F0-9]+', 'hex'),
  Pat('[0-9]+', 'dec'),
}

-- uniary and binary operations
op1 = Or{'-', 'not', '#'}
op2 = Or{
  -- Technically only a `name` can be after `.`
  -- check in later pass if necessary.
  '.',

  -- standard binops
  '+'  ,  '-'   ,  '*'  ,  '/'   ,  '^'   ,  '%'   ,  '..'  ,
  '<'  ,  '<='  ,  '>'  ,  '>='  ,  '=='  ,  '~='  ,
  'and'  ,  'or',
}

-----------------
-- Expression (exp)

-- We do exp a little different from the BNF. We create an `exp1` which is a
-- non-operated expression and then have `exp` implement a list of expression
-- operations.
--
-- The BNF uses a (confusing IMO) recursive definition which weaves
-- exp with var and prefixexp. Our definition deviates significantly because
-- you cannot do non-progressive recursion in recursive-descent (or PEG):
-- recursion is fine ONLY if you make "progress" (attempt to parse some tokens)
-- before you recurse.
--
-- We don't have quite as much of a "complete" parsing here: a checking pass
-- will need to ensure that when you use `exp = exp` that the left-hand `exp`
-- is actually a valid variable (exp . name | exp [ exp ] | name).
--
-- exp1 ::=  nil       |  false      |  true       |  ...        |
--           Number    | unop exp    | String      | tbl         |
--           function  | name
local exp1 = Or{name='exp', 'nil', 'false', 'true', '...', num};
add(exp1, {op1, exp1})

local exp = {name='exp'}    -- defined just below
add(exp1, {'(', exp, ')', kind='group'})

local call     = Or{name='call'} -- function call (defined much later)
local methcall = {':', name, call, kind='methcall'}
local index    = {'[', exp, ']', kind='index'}
local postexp  = Or{methcall, index, call}
extend(exp,      {exp1, Many{op2, exp1}, Many{postexp}})

-- laststat ::= return [explist1]  |  break
-- block    ::= {stat [`;´]} [laststat[`;´]]
local explist  = {exp, Many{',', exp}}
local laststmt = Or{{'return', explist, kind='return'}, 'break'}
local block = {stmt, Maybe(';'), laststmt, Maybe(';'), name='block'}

-----------------
-- String (+exp1)

local quoteImpl = function(p, char, pat, kind)
  p:skipEmpty()
  local l, c = p.l, p.c
  if not p:consume(char) then return end
  while true do
    local c1, c2 = p.line:find(pat, p.c)
    if c2 then
      p.c = c2 + 1
      local bs = string.match(p.line:sub(c1, c2), pat)
      if civ.isEven(#bs) then
        return Token{l=l, c=c, l2=p.l, c2=c2, kind=kind}
      end
    else
      if p.line:sub(#p.line) == '\\' then
        p:incLine(); if p:isEof() then error("Expected "..kind..", reached EOF") end
      else error("Expected "..kind..", reached end of line") end
    end
  end
end

local singleStr = function(p) return quoteImpl(p, "'", "(\\*)'", 'singleStr') end
local doubleStr = function(p) return quoteImpl(p, '"', '(\\*)"', 'doubleStr') end
local bracketStr = function(p)
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
local str   = Or{singleStr, doubleStr, bracketStr}
add(exp1, str)

-----------------
-- Table (+exp1)

-- field ::= `[´ exp `]´ `=´ exp  |  Name `=´ exp  |  exp
local fieldsep = Or{',', ';'}
local field = Or{name='field',
  {UNPIN, '[', exp, ']', '=', exp},
  {UNPIN, name, '=', exp},
  exp,
}
-- fieldlist ::= field {fieldsep field} [fieldsep]
-- tableconstructor ::= `{´ [fieldlist] `}´
local fieldlist = {name='fieldlist', field, Many{fieldsep, field}, Maybe(fieldsep)}
local tbl = {kind='tbl', '{', fieldlist, '}'}
add(exp1, tbl)

-- fully define function call
-- call ::=  `(´ [explist1] `)´  |  tableconstructor  |  String
extend(call, {{'(', explist, ')'}, tbl, str})

-----------------
-- Function (+exp1)

-- namelist ::= Name {`,´ Name}
-- parlist1 ::= namelist [`,´ `...´]  |  `...´
-- funcbody ::= `(´ [parlist1] `)´ block end
-- function ::= `function` funcbody
local namelist = {name, Many{',', name}}
local parlist = Or{{namelist, Maybe{',', '...'}}, '...'}
local fnbody = {'(', parlist, ')', block, 'end'}
local fn = {'function', fnbody, kind='fn'}
add(exp1, fn)
add(exp1, name)


-----------------
-- Statement (stmt)

local elseif_  = {'elseif', exp, 'then', block, kind='elseif'}
local else_    = {'else', block, kind='else'}
local funcname = {name, Many{'.', name}, Maybe{':', name}, kind='funcname'}

extend(stmt, {
  -- do block end
  {'do', block, 'end', kind='do'},

  -- while exp do block end
  {'while', exp, 'do', block, 'end', kind='while'},

  -- repeat block until exp
  {'repeat', block, 'until', exp, kind='repeat'},

  -- if exp then block {elseif exp then block} [else block] end
  {'if', exp, 'then', block, Many{elseif_}, else_, kind='if'},

  -- for Name `=´ exp `,´ exp [`,´ exp] do block end
  {kind='fori',
    UNPIN, 'for', name, '=', PIN, exp, ',', exp, Maybe{',', exp}, 'do',
    block, 'end',
  },

  -- for namelist in explist1 do block end
  {kind='for',
    'for', namelist, 'in', explist, 'do', block, 'end'
  },

  -- funcname ::= Name {`.´ Name} [`:´ Name]
  -- function funcname funcbody
  {'function', funcname, fnbody, kind='fndef'},

  -- local function Name funcbody
  {'local', 'function', name, fnbody, kind='fnlocal'},

  -- local namelist [`=´ explist1]
  {'local', namelist, Maybe{'=', explist}, kind='varlocal'},

  -- varlist `=´ explist
  -- Check pass: check that all items in first explist are var-like
  {UNPIN, explist, '=', explist, kind='varset'},

  -- catch-all exp
  -- Check pass: only a fncall is actually valid syntax
  {exp, kind='stmtexp'},
})

return {
  exp=exp, exp1=exp1, stmt=stmt,
  num=num, str=str,
  fncall=fncall,
  field=field,
}
