require'civ':grequire()
grequire'pegl'
grequire'pegl.lua'

local KW = function(kw) return {kw, kind=kw} end
local EMPTY = {kind='Empty'}

test('easy', nil, function()
  assertParse('42  0x3A', {num, num}, {
    {kind='dec', '42'},
    {kind='hex', '0x3A'},
  })
  assertParse('  nil\n', {exp1}, KW('nil'))
  assertParse(
    'true  \n false', {exp1, exp1}, {KW('true'), KW('false')})

  -- use exp instead
  assertParse('  nil\n', {exp}, KW('nil'))
end)

test('str', nil, function()
  assertParse(' "hi there" ', {str},
    {kind='doubleStr', '"hi there"'})
  assertParse([[  'yo\'ya'  ]], {str},
    {kind='singleStr', [['yo\'ya']]})
  assertParseError([[  'yo\'ya"  ]], {exp},
    'Expected singleStr, reached end of line'
  )
  assertParse([[  'single'  ]], {str},
    {kind='singleStr', [['single']]})
end)

test('field', nil, function()
  assertParse(' 44 ', {field},  {kind='field', {kind='dec',  '44'}})
  assertParse(' hi ', {field},  {kind='field', {kind='name', 'hi'}})
  assertParse(' hi="x" ', {field},  {kind='field',
    {kind='name', 'hi'}, KW('='), {kind='doubleStr', '"x"'},
  })
  assertParse('[hi] = 4', {field}, {kind='field',
    KW('['), {'hi', kind='name'}, KW(']'),
    KW('='), {'4', kind='dec'},
  })
end)

test('table', nil, function()
  assertParse('{}', {exp}, {kind='table',
    KW('{'), EMPTY, KW('}'),
  })
  assertParse('{4}', {exp}, {kind='table',
    KW('{'),
    {kind='field', {kind='dec', '4'}},
    EMPTY,
    KW('}'),
  })
  assertParse('{4, x="hi"}', {exp}, {kind='table',
    KW('{'),
    {kind='field', {kind='dec', '4'}},
    KW(','),
    {kind='field',
      {kind='name', 'x'}, KW('='), {kind='doubleStr', '"hi"'}},
    EMPTY,
    KW('}'),
  })
end)

test('fnValue', nil, function()
  assertParse('function() end', {exp}, {kind='fnvalue',
    KW('function'), KW('('), EMPTY, KW(')'),
    EMPTY,
    KW('end'),
  })
end)

local function testLuaPath(path)
  local f = io.open('pegl.lua', 'r')
  local text = f:read'*a'; f:close()

end

test('parseSrc', nil, function()

end)
