
require'civ':grequire()
grequire'civ.gap'
grequire'pegl'

local KW = function(kw) return {kw, kind=kw} end

test('keywords', nil, function()
  assertTokens(
    'hi there bob',
    {'hi', 'there', 'bob', EOF},
    {KW('hi'), KW('there'), KW('bob'), EofNode})
end)

test('pat', nil, function()
  assertTokens(
    'hi there bob',
    {'hi', Pat('%w+'), 'bob', EOF},
    {KW('hi'), 'there', KW('bob'), EofNode})
end)

test('or', nil, function()
  assertTokens(
    'hi +-',
    {'hi', Or{'-', '+'}, Or{'-', '+', Empty}, Or{'+', Empty}, EOF},
    {KW('hi'), KW('+'), KW('-'), EmptyNode, EofNode})
end)

test('many', nil, function()
  assertTokens(
    'hi there bob',
    {Many{Pat('%w+'), kind='words'}},
    {{'hi', 'there', 'bob', kind='words'}})
end)
