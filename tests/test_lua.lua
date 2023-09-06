require'civ':grequire()
grequire'pegl'
grequire'pegl.lua'

local KW = function(kw) return {kw, kind=kw} end

test('easy', nil, function()
  assertParse('  nil\n', {nil_}, {{'nil', kind='nil_'}})
  assertParse(
    'true  \n false',
    {bool, bool},
    {{KW('true'), kind='bool'}, {KW('false'), kind='bool'}})
  assertParse('42  0x3A', {num, num}, {
    {kind='num', {kind='dec', '42'}},
    {kind='num', {kind='hex', '0x3A'}},
  })
end)

test('str', nil, function()
  assertParse(' "hi there" ', {doubleStr}, {
    {kind='doubleStr', '"hi there"'},
  })
  assertParse([[  'yo\'ya'  ]], {singleStr}, {
    {kind='singleStr', [['yo\'ya']]}
  })
  assertParseError([[  'yo\'ya"  ]], {singleStr},
    'Expected singleStr, reached end of line'
  )

  assertParse([[  'single'  ]], {str}, {
    {kind='singleStr', [['single']]}
  }, true)
end)

test('key', nil, function()
  assertParse(' hi ', {name},  { {kind='name', 'hi'} })
  assertParse(' hi ', {value}, { {kind='value', {kind='name', 'hi'}} })
  assertParse(' hi ', {key},   { {kind='name', 'hi'} })
  assertParse('[hi]', {key},   {
    {KW('['), {kind='value', {'hi', kind='name'}}, KW(']')},
  })
end)

test('item', nil, function()
  assertParse('4', {item},   {
    {kind='item', {kind='value', {kind='num', {kind='dec', '4'}}}},
  })

  assertParse('x="hi"', {item},   {
    {kind='item',
      {kind='name', 'x'},
      KW('='),
      {kind='value', {kind='doubleStr', '"hi"'}},
    },
  })
end)

test('table', nil, function()
  assertParse('{}', {table_}, {
    {kind='table',
      KW('{'),
      {},
      KW('}'),
    },
  }, true)
end)


