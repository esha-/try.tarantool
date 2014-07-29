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
local socket = require('socket')
local yaml = require('yaml')
local os = require('os')

return { start = function() 
--[[box.cfg{
    admin_port = "3313",
    --logger="tarantool_server.log";
}--]]

local server = require('http.server')

-- Table with information about linux containers with tarantool and socket

local ipt = {}
local lxc = {}
local sock = {}

-- Function start container

local function start_container(user_id, user_ip)
	--[[local file = io.popen('sudo /usr/local/try-tarantool-org/container/tool.sh start')
	inf = file:read("*a")
	file:close()
	inf = json.decode(inf)
	host = inf[1]['NetworkSettings']['IPAddress']
	lxc_id = inf[1]['ID']--]]
	host = '127.0.0.1'
	lxc_id = '1'
	log.info('%s: Start container with ID = %s ', user_id, lxc_id)
	t = {host = host, ip = user_ip, lxc_id = lxc_id}
	lxc[user_id] = t
	for k,v in pairs(t) do print('\t',k,v) end
	return host, lxc_id
end

-- Function remove container

local function remove_container(lxc_id)
	log.info(lxc_id)
	local file = io.popen(' sudo /usr/local/try-tarantool-org/container/tool.sh stop '..lxc_id)
	file:close()
	for k,v in pairs(lxc) do
		if v.lxc_id == lxc_id then 
			lxc[k] = nil
			ipt[v.ip] = ipt[v.ip] - 1
			log.info('%s: Remove container with ID = %s', k, lxc_id)
		end
	for k,v in pairs(lxc) do 
	print (k, v)
	end
	end
end

-- Function remove all container that not used

function clear_lxc()
while 1 do
	log.info('Started remove unused container')
	t = os.time()
	for k,v in pairs(lxc) do
		print(v.time, t)
		if (t - v.time) >= 1800 then
			remove_container(v.lxc_id)
		end
	end
	log.info('Stopped remove unused conainer')
	fiber.sleep(1800)
end
end

-- Get conteiner host

function get_container (user_id, user_ip)
	local host = nil
	local lxc_id = nil
	local ip ='0'
	local t = {}
	
	if lxc[user_id] then --Check availability linux conteiner for user_id
		host = lxc[user_id].host
		lxc_id = lxc[user_id].lxc_id
		log.info('%s: User got container with host = %s', user_id, host) 
	end

	if not host then -- Start new linux continer
		host, lxc_id = start_container(user_id, user_ip)
		log.info('%s: User got new container with host = %s', usr_id, host)
	end
	return host, lxc_id
end

-- Socket connection to linux container with tarantool 

local function get_socket(self, user_id, socket_host)
	local s = lxc[user_id].socket	
	local port = '3313'
	if not s then
		fiber.sleep(0.3)
		local i = 0
		while (i <= 10) do
			s = socket.tcp_connect(socket_host, port, 100)
			log.info('%s: Started socket on host %s port %s', user_id, socket_host, port)
			if s then i = 11 else i = i + 1 end 
		end
	end
	lxc[user_id].socket = s
	lxc[user_id].time = os.time()
	log.info ('%s: Soket = %s', user_id, s)
	if s then log.info ('%s: Had connection', user_id) else log.info('%s: Hasnt socket', user_id) end 
	return s
end

-- Get answer from tarantool to the command request

function get_answer (self, user_id, socket_host, lxc_id)
    print('Start get answer')
	local s = get_socket(self, user_id, socket_host)
	if not s then -- Check available socket connection for user_id and remove this container 
		data = 'errors'
		---data = 'Sorry! Server have problem. Please update web pages.'
		log.info(data)
		--remove_container(lxc_id)
		return data
	end 
	local command = self.req:param('command')
    log.info('%s: Getting command <%s>', user_id, command)
    s:write(command..'\n')
    local data = s:readline(4096,{'\n%.%.%.\n'})
    log.info('%s: Had answer:\n %s', user_id, data)
    return data
end

-- Handler for request from try.tarantool page   

function handler (self)
	print ('This is handler')
	local user_ip = '127.0.0.1'
	local host = nil
	local lxc_id = nil
	if not ipt[user_ip] then ipt[user_ip] = 1 end
	log.info('user_ip = %s', user_ip)
    local user_id = self:cookie('id')  -- Set or get cookie   
    print (user_id)
	if user_id == nil then
		ipt[user_ip] = ipt[user_ip] + 1 -- Check limit (5 users) for one ip adress 
		log.info('Have %s session on this ip = %s', ipt[user_ip], user_ip) 
		if ipt[user_ip] >= 4 then
		data = 'Sorry! Users limit exceeded! Please, close some session'
		return self:render({ text = data })
		end
		log.info ('Set cookie for ip = %s', user_ip)
		math.randomseed(tonumber(require('fiber').time64()))
       	user_id = user_ip..'//'..tostring(math.random(0, 65000))
	   	--id = digest.sha1_hex(math.random(0, 65000))
       	self:cookie({ name = 'id', value = user_id, expires = '+1y' })
    end

	log.info('user_id = %s', user_id)
    log.info('%s: Started and get answer', user_id)
	host, lxc_id = get_container(user_id, user_ip)
	data = get_answer(self, user_id, host, lxc_id)
    --log.info('%s',yaml.encode(self))
    return self:render({ text = data })
end

-- Start tarantool server

server_host = 'localhost'
server_port = '12345'
httpd = server.new(server_host, server_port, {app_dir = '.'})
log.info('Started http server at host = %s and port = %s ', server_host, server_port)

-- Start fiber for remove unused containers

--remove = fiber.create(clear_lxc)

httpd:route({ path = '', file = '/index.html'})
--httpd:route({ path = '/tarantool'}, "module#hello")
httpd:route({ path = '/tarantool' }, handler)
httpd:start()

end

}
