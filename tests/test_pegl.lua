
require'civ':grequire()
grequire'civ.gap'
grequire'pegl'

local KW = function(kw) return {kw, kind=kw} end

test('keywords', nil, function()
  assertParse(
    'hi there bob',
    Seq{'hi', 'there', 'bob', EOF},
    {KW('hi'), KW('there'), KW('bob'), EofNode})

  -- keyword search looks for token break
  assertParse(
    'hitherebob',
    Seq{'hi', 'there', 'bob', EOF},
    nil)

  assertParse(
    'hi+there',
    Seq{'hi', '+', 'there', EOF},
    {KW('hi'), KW('+'), KW('there'), EofNode})
end)

test('pat', nil, function()
  assertParse(
    'hi there bob',
    Seq{'hi', Pat('%w+'), 'bob', EOF},
    {KW('hi'), 'there', KW('bob'), EofNode})
end)

test('or', nil, function()
  assertParse(
    'hi +-',
    Seq{'hi', Or{'-', '+'}, Or{'-', '+', Empty}, Or{'+', Empty}, EOF},
    {KW('hi'), KW('+'), KW('-'), EmptyNode, EofNode})
end)

test('many', nil, function()
  assertParse(
    'hi there bob',
    Seq{Many{Pat('%w+'), kind='words'}},
    {'hi', 'there', 'bob', kind='words'})
end)

test('pin', nil, function()
  assertParseError(
    'hi there jane',
    Seq{'hi', 'there', 'bob', EOF},
    'expected: bob')
  assertParseError(
    'hi there jane',
    Seq{UNPIN, 'hi', 'there', PIN, 'bob', EOF},
    'expected: bob')

  assertParse(
    'hi there jane',
    Seq{UNPIN, 'hi', 'there', 'bob', EOF},
    nil)
  assertParse(
    'hi there jane',
    Seq{UNPIN, 'hi', 'there', 'bob', PIN, EOF},
    nil)
end)
