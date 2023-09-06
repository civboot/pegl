require'civ':grequire()
grequire'pegl'
grequire'pegl.lua'

local KW = function(kw) return {kw, kind=kw} end

test('easy', nil, function()
  assertParse('  nil\n', {exp1}, {KW('nil')}, true)
  assertParse(
    'true  \n false', {exp, exp}, {KW('true'), KW('false')})
  assertParse('42  0x3A', {num, num}, {
    {kind='dec', '42'},
    {kind='hex', '0x3A'},
  })
end)

test('str', nil, function()
  assertParse(' "hi there" ', {str}, {
    {kind='doubleStr', '"hi there"'},
  })
  assertParse([[  'yo\'ya'  ]], {str}, {
    {kind='singleStr', [['yo\'ya']]}
  })
  -- assertParseError([[  'yo\'ya"  ]], {exp},
  --   'Expected singleStr, reached end of line'
  -- )

  assertParse([[  'single'  ]], {str}, {
    {kind='singleStr', [['single']]}
  })
end)

test('field', nil, function()
  -- assertParse(' hi="x" ', {field},  {{
  --   {kind='name', 'hi'}, KW('='), {kind='doubleStr', '"x"'},
  -- }})
  -- assertParse(' 44 ', {field},  {{kind='dec',  '44'}, })
  -- assertParse(' hi ', {field},  {{kind='name', 'hi'}, })
  -- assertParse('[hi] = 4', {field},   {
  --   {
  --     KW('['), {'hi', kind='name'}, KW(']'),
  --     KW('='), {'4', kind='dec'},
  --   },
  -- })
end)

test('table', nil, function()
  -- assertParse('{}', {exp}, {
  --   {kind='table',
  --     KW('{'),
  --     KW('}'),
  --   },
  -- }, true)
  -- assertParse('{4}', {table_}, {
  --   {kind='table',
  --     KW('{'),
  --     {kind='item', {kind='dec', '4'}}, {kind='Empty'},
  --     KW('}'),
  --   },
  -- }, true)

  -- assertParse('{4, x="hi"}', {table_}, {
  --   {kind='table',
  --     KW('{'),
  --     {kind='item', {kind='dec', '4'}}, KW(','),
  --     {kind='item',
  --       {kind='name', 'x'}, KW('='), {kind='doubleStr', '"hi"'}},
  --     {kind='Empty'},
  --     KW('}'),
  --   },
  -- }, true)
end)


