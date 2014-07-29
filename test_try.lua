#!usr/bin/env tarantool
-- This is script for testing try.tarantool
local log = require('log')
local client = require('http.client')

box.cfg{
	admin = '3313',
	--logger = 'test_try.log'
}

print(package.path)
--package.path = package.path .. ";./?.lua"
local try = require('example_try')

try.start()

log.info('Try test is starting')

for i = 1, 100, 1 do
log.info(client.get('http://localhost:12345/tarantool?command='..i).body)
end
