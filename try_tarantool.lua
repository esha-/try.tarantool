#!/usr/bin/env tarantool
-- This script for start and work try.tarantool.org. 
-- Try.tarantool is web pages with terminal that user can use
-- such us tarantool terminal and try tarantool uses cases 

local io = require('io')
local json = require('json')
local math = require('math')
local digest = require('digest')
local log = require('log')
local fiber = require('fiber')
local server = require('http.server')
local socket = require('socket')
local yaml = require('yaml')
local os = require('os')

local test = 0
local server_host = nil
local server_port = '11111'
local container_port = '3313'
local ip_limit = 5
local socket_timeout = 0.2
local start_lxc = 'sudo /usr/local/try-tarantool-org/container/tool.sh start ' 
local rm_lxc = 'sudo /usr/local/try-tarantool-org/container/tool.sh stop '

-- 'test' is mark for starting try.tarantool in test session on localhost

if test == 0 then 
	server_host = '188.93.56.54'
else 
	server_host = '127.0.0.1'
end

local function start(test)

local ipt = {} -- Table with information about users try.tarantool session on ip
local lxc = {} -- Table with information about user: id, ip, linux container host and id, last connection time

-- Function start container

local function start_container(user_id)
	local file = io.popen(start_lxc)
	local inf = file:read("*a")
	file:close()
	inf = json.decode(inf)
	local host = inf[1]['NetworkSettings']['IPAddress']
	local lxc_id = inf[1]['ID']
	log.info('%s: Start container with ID = %s ', user_id, lxc_id)
	local t = {host = host, ip = user_ip, lxc_id = lxc_id}
	lxc[user_id] = t
	for k,v in pairs(t) do print('\t',k,v) end
end

-- Function remove container

local function remove_container(user_id)
	local lxc_id = lxc[user_id].lxc_id
	log.info(lxc_id)
	print (rm_lxc..lxc_id)
	local file = io.popen(rm_lxc..lxc_id)
	file:close()
	ipt[lxc[user_id].ip] = ipt[lxc[user_id].ip] - 1
	log.info('%s: Remove container with ID = %s', user_id, lxc_id)
	lxc[user_id] = nil
	for k,v in pairs(lxc) do 
	print (k, v)
	end
end

-- Function remove all container that not used

local function clear_lxc()
while 1 do
	log.info('Started remove unused container')
	t = os.time()
	for k,v in pairs(lxc) do
		print(v.time, t)
		if (t - v.time) >= 1800 then
			remove_container(k)
		end
	end
	log.info('Stopped remove unused conainer')
	fiber.sleep(1800)
end
end

-- Handler for request from try.tarantool page   

function handler (self)
	log.info('Start handler')
	local user_ip = nil
	
	if test == 0 then
		user_ip = self.req.peer.host
	else
		user_ip = '127.0.0.1'
	end

	local host = nil
	local lxc_id = nil
	local t ={}
	local data = nil

	if not ipt[user_ip] then ipt[user_ip] = 0 end

    local user_id = self:cookie('id')  -- Set or get cookie with id information  
	
	if user_id == nil then
		log.info ('Set cookie for ip = %s', user_ip)
		math.randomseed(tonumber(require('fiber').time64()))
		user_id = user_ip..'//'..tostring(math.random(0, 65000))
		 --id = digest.sha1_hex(math.random(0, 65000))
		self:cookie({ name = 'id', value = user_id, expires = '+1y' })
	end 
	log.info('user_id = %s', user_id)

	print (lxc[user_id])

	if not lxc[user_id] then
		-- Check limit (5 users) for one ip adress 
		if ipt[user_ip] == ip_limit then
			data = 'Sorry! Users limit exceeded! Please, close some session'
			return self:render({ text = data })
		end
		ipt[user_ip] = ipt[user_ip] + 1 
		log.info('Have %s session on this ip = %s', ipt[user_ip], user_ip)	
		
		if test == 0 then
			-- Start new container for user
			host, lxc_id = start_container(user_id)
            log.info('%s: User got new container with host = %s', usr_id, lxc[user_id].host)
    	else
			lxc[user_id].host = 'localhost'
			lxc[user_id].lxc_id = '1'
		end
		
		local i = 0
 		while (i <= 10) do -- Start new socket connection
				lxc[user_id].socket = socket.tcp_connect(lxc[user_id].host, container_port)
				log.info('%s: Started socket on host %s port %s', user_id, lxc[user_id].host, container_port)
				if lxc[user_id].socket then break else i = i + 1 fiber.sleep(socket_timeout) end
 		end
		log.info ('%s: Soket = %s', user_id, lxc[user_id].socket)
	else
		--User get container from container table(lxc[])
		log.info('%s: User got container with host = %s', user_id, lxc[user_id].host)
	end

	-- Check that socket connection have
	if lxc[user_id].socket then
		log.info ('%s: Had socket connection', user_id) 
	else 
		log.info('%s: Hasnt socket conection', user_id)
	 	data = 'errors'
		if test == 1 then
			lxc[user_id] = nil
		else
			remove_container(user_id)
		end
		return self:render({ text = data })
	end

	-- Send message to tarantool in container and get answer
	log.info('%s: Started and get answer', user_id)
	local command = self.req:param('command')
	log.info('%s: Getting command <%s>', user_id, command)
	lxc[user_id].socket: write(command..'\n')
	data = lxc[user_id].socket:readline(4096,{'\n%.%.%.\n'})
	
	-- Write time last socket connection
	lxc[user_id].time = os.time()
	log.info('%s: Had answer:\n %s', user_id, data)
	
	return self:render({ text = data })
end

-- Start tarantool server

httpd = server.new(server_host, server_port, {app_dir = '.'})
log.info('Started http server at host = %s and port = %s ', server_host, server_port)

-- Start fiber for remove unused containers

if test == 0 then clear = fiber.create(clear_lxc) end

httpd:route({ path = '', file = '/index.html'})
httpd:route({ path = '/tarantool' }, handler)
httpd:start()

end

return {
start = function (test)
	start(test)
end
}
