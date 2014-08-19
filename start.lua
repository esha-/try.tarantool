#!usr/bin/env tarantool
-- This is script for starting or testing try.tarantool
local log = require('log')
local client = require('http.client')
local yaml = require('yaml')

box.cfg{
    log_level = 5,
    --logger = 'test_try.log'
}

print(package.path)
local try = require('try_tarantool')

try.start()

