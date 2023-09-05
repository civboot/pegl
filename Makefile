CC=gcc
FLAGS=-m32 -no-pie -g -rdynamic
DISABLE_WARNINGS=-Wno-pointer-sign -Wno-format
FILES=src/*.c tests/*.c
OUT=bin/tests

.PHONY: all test clean lua

LP = "./?.lua;../civlib/lua/?.lua;${LUA_PATH}"

all: test

test:
	LUA_PATH=${LP} lua tests/test_pegl.lua
