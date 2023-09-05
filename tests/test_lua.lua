require'civ':grequire()
grequire'pegl'
grequire'pegl.lua'

local KW = function(kw) return {kw, kind=kw} end

test('easy', nil, function()
  assertParse('  nil\n', {nil_}, {KW('nil')})
  assertParse('true  \n false', {bool, bool}, {KW('true'), KW('false')})
  assertParse('42  0x3A', {num, num}, {
    {kind='num', {kind='dec', '42'}},
    {kind='num', {kind='hex', '0x3A'}},
  })
end)

test('quote', nil, function()
  assertParse(' "hi there" ', {doubleQuote}, {
    {kind='doubleQuote', '"hi there"'},
  })
  assertParse([[  'yo\'ya'  ]], {singleQuote}, {
    {kind='singleQuote', [['yo\'ya']]}
  })
end)

