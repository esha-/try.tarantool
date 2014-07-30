#!usr/bin/env tarantool
-- This is script for starting or testing try.tarantool
local log = require('log')
local client = require('http.client')
local yaml = require('yaml')

box.cfg{
	admin = '3313',
	--logger = 'test_try.log'
}

print(package.path)
--package.path = package.path .. ";./?.lua"
local try = require('try_tarantool')

-- Append argment 1 if you want testing for try.tarantool or 0 if don't want
test = 1
try.start(test)

if test == 0 then
	log.info('Started try.tarantool.org')
else
	log.info('Try test is starting')
	
	--client.get('http://localhost:12345/tarantool?command=box.cfg')
	
	-- Check requests for one user (one cookie) 
	for i = 1, 6, 1 do
		log.info(yaml.encode(client.request('GET', 'http://localhost:12345/tarantool?command='..i, nil, {headers = {cookie = 'id='..i}}).body)) 
	end
	
	
	--Check users limit fot one ip adress
	for i = 100, 106, 1 do
		log.info(client.get('http://localhost:12345/tarantool?command='..i).body)
	end
end
