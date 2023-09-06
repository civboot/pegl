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
  '+'  ,  '-'   ,  '*'  ,  '/'   ,  '^'   ,  '%'   ,  '..'  ,
  '<'  ,  '<='  ,  '>'  ,  '>='  ,  '=='  ,  '~='  ,
  'and'  ,  'or',
  -- Technically only a `name` can be after `.`,
  -- check in lint pass if necessary.
  '.',
}

-- We do exp a little different from the BNF. We create an `exp1`
-- which is a non-operated expression and then have `exp` implement a list
-- of expression operations.
--
-- The BNF uses a (confusing IMO) recursive definition which weaves
-- exp with var and prefixexp. Our definition deviates significantly.
--
-- exp1 ::=  nil       |  false    |  true       |  Number            |
--           String    |  `...´    | tbl         |  function          |
--           prefixexp |    exp binop exp        |  unop exp
local exp1 = Or{name='exp', 'nil', 'false', 'true', '...', num};
add(exp1, {op1, exp1})

local args = Or{} -- function args, i.e. a function call
local exp = {exp1, Many{op2, exp1}, Many{args}}
local explist = {Many{exp, ','}, exp}

-- laststat ::= return [explist1]  |  break
-- block    ::= {stat [`;´]} [laststat[`;´]]
local laststmt = Or{{'return', explist}, 'break'}
local block = {name='block', stmt, Maybe(';'), laststmt, Maybe(';')}

-----------------
-- String (+exp)

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
-- add(exp, str)

-- -----------------
-- -- Table (+exp)
-- 
-- -- field ::= `[´ exp `]´ `=´ exp  |  Name `=´ exp  |  exp
-- local fieldsep = Or{',', ';'}
-- local field = Or{name='field',
--   {UNPIN, '[', exp, ']', '=', exp},
--   {UNPIN, name, '=', exp},
--   exp,
-- }
-- -- fieldlist ::= field {fieldsep field} [fieldsep]
-- -- tableconstructor ::= `{´ [fieldlist] `}´
-- local fieldlist = {name='fieldlist', field, Many{fieldsep, field}, Maybe(fieldsep)}
-- local tbl = {kind='tbl', '{', fieldlist, '}'}
-- add(exp, tbl)
-- 
-- -----------------
-- -- Function (+exp)
-- 
-- -- namelist ::= Name {`,´ Name}
-- -- parlist1 ::= namelist [`,´ `...´]  |  `...´
-- -- funcbody ::= `(´ [parlist1] `)´ block end
-- -- function ::= `function` funcbody
-- local namelist = {name, Many{',', name}}
-- local parlist = Or{{namelist, Maybe{',', '...'}}, '...'}
-- local fnbody = {'(', parlist, ')', block, 'end'}
-- local fn = {'function', fnbody, kind='fn'}
-- add(exp, fn)

-----------------
-- prefixexp (+exp)
-- args ::=  `(´ [explist1] `)´  |  tableconstructor  |  String
-- local args = Or{{'(', explist, ')'}, tbl, str}

-- local prefixexp = Or{
--   {UNPIN, exp, '.', PIN, name},
--   {'(', exp, ')'},
--   {UNPIN, exp, '[', PIN, exp, ']'},
-- }
-- 
-- -- var ::=  Name  |  prefixexp `[´ exp `]´  |  prefixexp `.´ Name
-- local prefixexp = Or{name='prefixexp'}
-- local var = Or{name='var',
--   name,
--   {prefixexp, '[', exp, ']'},
--   {prefixexp, '.', name}
-- }
-- 
-- -- varlist1 ::= var {`,´ var}
-- local varlist = {name='varlist', var, Many{',', var}}

-- functioncall ::=  prefixexp args  |  prefixexp `:´ Name args
-- local fncall = Or{name='fncall',
--   {prefixexp, args}, {prefixexp, ':', name, args}
-- }
-- 
-- -- prefixexp ::= var  |  functioncall  |  `(´ exp `)´
-- civ.extend(prefixexp, {var, fncall, {'(', exp, ')'}})
-- add(exp, prefixexp)

-- -----------------
-- -- Statement (stmt)
-- 
-- -- varlist1 `=´ explist1
-- add(stmt, {varlist, '=', explist, kind='varset'})
-- 
-- -- functioncall
-- add(stmt, fncall)
-- 
-- -- do block end
-- add(stmt, {'do', block, 'end', kind='do'})
-- 
-- -- while exp do block end
-- add(stmt, {'while', exp, 'do', block, 'end', kind='while'})
-- 
-- -- repeat block until exp
-- add(stmt, {'repeat', block, 'until', exp, kind='repeat'})
-- 
-- -- if exp then block {elseif exp then block} [else block] end
-- local elseif_ = {'elseif', exp, 'then', block}
-- add(stmt, {kind='if',
--   'if', exp, 'then', block, Many{elseif_}, Maybe{'else', block},
-- })
-- 
-- -- for Name `=´ exp `,´ exp [`,´ exp] do block end
-- add(stmt, {kind='fori',
--   'for', name, '=', exp, ',', exp, Maybe{',', exp}, 'do',
--   block, 'end',
-- })
-- 
-- -- for namelist in explist1 do block end
-- add(stmt, {kind='for',
--   'for', namelist, 'in', explist, 'do', block, 'end'
-- })
-- 
-- -- funcname ::= Name {`.´ Name} [`:´ Name]
-- -- function funcname funcbody
-- local funcname = {name, Many{'.', name}, Maybe{':', name}}
-- add(stmt, {'function', funcname, fnbody, kind='fndef'})
-- 
-- -- local function Name funcbody
-- add(stmt, {'local', 'function', name, fnbody})
-- 
-- -- local namelist [`=´ explist1]
-- add(stmt, {'local', namelist, '=', explist})

return {
  exp=exp, exp1=exp1, stmt=stmt,
  num=num, str=str,
  fncall=fncall,
  field=field,
}
