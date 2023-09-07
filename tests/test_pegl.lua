
require'civ':grequire()
grequire'civ.gap'
grequire'pegl'

local KW = function(kw) return {kw, kind=kw} end
local K = function(k) return {k, kind='key'} end

test('keywords', nil, function()
  assertParse{
    dat='hi there bob',
    spec=Seq{'hi', 'there', 'bob', EOF},
    expect={KW('hi'), KW('there'), KW('bob'), EofNode}
  }

  -- keyword search looks for token break
  assertParse{
    dat='hitherebob',
    spec=Seq{'hi', 'there', 'bob', EOF},
    expect=nil,
  }

  assertParse{
    dat='hi+there',
    spec=Seq{'hi', '+', 'there', EOF},
    expect={KW('hi'), KW('+'), KW('there'), EofNode},
    root=RootSpec{punc1=Set{'+'}},
  }
end)

test('key', nil, function()
  local kws = Key{keys=Set{'hi', 'there', 'bob'}, kind='kw'}
  assertParse{
    dat='hi there', spec={kws, kws},
    expect={{kind='kw', 'hi'}, {kind='kw', 'there'}},
  }
end)

test('pat', nil, function()
  assertParse{
    dat='hi there bob',
    spec={'hi', Pat('%w+'), 'bob', EOF},
    expect={KW('hi'), 'there', KW('bob'), EofNode},
  }
end)

test('or', nil, function()
  assertParse{
    dat='hi +-',
    spec={'hi', Or{'-', '+'}, Or{'-', '+', Empty}, Or{'+', Empty}, EOF},
    expect={KW('hi'), KW('+'), KW('-'), EmptyNode, EofNode},
    root=RootSpec{punc1=Set{'+', '-'}},
  }
end)

test('many', nil, function()
  assertParse{
    dat='hi there bob',
    spec=Seq{Many{Pat('%w+'), kind='words'}},
    expect={'hi', 'there', 'bob', kind='words'},
  }
end)

test('pin', nil, function()
  assertParseError{
    dat='hi there jane',
    spec={'hi', 'there', 'bob', EOF},
    errPat='expected: bob',
  }
  assertParseError{
    dat='hi there jane',
    spec={UNPIN, 'hi', 'there', PIN, 'bob', EOF},
    errPat='expected: bob',
  }

  assertParse{
    dat='hi there jane',
    spec=Seq{UNPIN, 'hi', 'there', 'bob', EOF},
    expect=nil,
  }
  assertParse{
    dat='hi there jane',
    spec=Seq{UNPIN, 'hi', 'there', 'bob', PIN, EOF},
    expect=nil,
  }
end)
