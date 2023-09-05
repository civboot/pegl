require'civ':grequire()
grequire'pegl'
grequire'pegl.lua'

local KW = function(kw) return {kw, kind=kw} end

test('bool', nil, function()

  assertTokens(
    'true  \n false',
    {bool, bool},
    {'true', 'false'})
end)
