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

box.cfg{
    admin_port = "3313",
    --logger="tarantool_server.log";
}

local server = require('http.server')

-- Table with information about linux containers with tarantool and socket

local ipt = {}
local lxc = {}
local sock = {}

-- Get conteiner host

function get_container (user_id)
    local host = nil
	local lxc_id = nil
    local ip ='0'
    local t = {}

    if lxc then --Check availability linux conteiner for user_id 
        for k,v in pairs(lxc) do
            if k == user_id then
                host = v.host
            end
        end
    end
    if not host then
	log.info('%s: getting host',user_id)

--Start new linux container

	local file = io.popen('sudo /usr/local/try-tarantool-org/container/tool.sh start')
	inf = file:read("*a")
	file:close()
	inf = json.decode(inf)
		host = inf[1]['NetworkSettings']['IPAddress']
		lxc_id = inf[1]['ID']
		log.info('%s: container ID = %s ', user_id, lxc_id)
        t = {host = host, ip = ip, lxc_id = lxc_id}
        lxc[user_id] = t
        for k,v in pairs(t) do print(k,v) end
    end
	print (host, lxc_id)
    return host, lxc_id
end

-- Function remove container

local function remove_container(lxc_id)
	log.info(lxc_id)
	local file = io.popen(' sudo /usr/local/try-tarantool-org/container/tool.sh stop '..lxc_id)
	file:close()
	for k,v in pairs(lxc) do
		if v.lxc_id == lxc_id then 
			log.info('%s: Remove container with ID = %s', k, lxc_id)
			lxc[k] = nil
		end
	end 
end

-- Function remove all container that not used

function remove()
while 1 do
	log.info('Started remove unused container')
	t = os.time()
	for k,v in pairs(lxc) do
		print(v.time, t)
		if (v.time - t) <= -4 then
			remove_container(v.lxc_id)
		end
	end
	log.info('Stopped remove unused conainer')
	fiber.sleep(1800)
end
end

-- Socket connection to linux container with tarantool 

local function get_socket(self, user_id, socket_host)
	local s = nil	
	local port = '3313'
	
	for k,v in pairs(lxc) do
		if k == user_id and v.socket then
			s = v.socket
			log.info('%s: Got socket', user_id)
		end
	end
	if not s then
		local i = 0
		while (i <= 10) do
			s = socket.tcp_connect(socket_host, port, 100)
			log.info('%s: Started socket on host %s port %s', user_id, socket_host, port)
			if s then break end 
			i = i + 1 
		end
	end
	for k,v in pairs(lxc) do
		if k == id then
			v.socket = s
			v.time = os.time()
		end
	end
	if s then log.info ('%s: Had connection', user_id) else log.info('%s: Hasnt') end 
	return s
end

-- Get answer from tarantool to the command request

function get_answer (self, user_id, socket_host, lxc_id)
    local s = get_socket(self, user_id, socket_host)
	if not s then -- Check available socket connection for user_id and remove this container 
		data = 'errors'
		--data='Sorry! Server have problem. Please update web pages.'
		log.info(data)
		remove_container(lxc_id)
		return data
	end 
	local command = self.req:param('command')
    log.info('%s: Getting command <%s>', user_id, command)
    s:write(command..'\n')
    local data = s:readline(4096,{'\n...\n'})
    log.info('%s: Had answer:\n %s', user_id, data)
    return data
end

-- Handler for request from try.tarantool page   

function handler (self)
	local user_ip = self.req.peer.host
	local host = nil
	local lxc_id = nil
	
	for k,v in pairs(ipt)  do  -- Check ip limits (5 user)
		if k == user_ip then 
			v = v + 1
			if v == 5 then
				return self:render({ text = 'Sorry! Users limit exceeded! Please, close some session.' })
			end
		end
	end

    local id = self:cookie('id')  -- Set or get cookie   
    if id == nil then
		log.info ('Set cookie for ip = '..user_ip)
		math.randomseed(tonumber(require('fiber').time64()))
        id = user_ip..tostring(math.random(0, 65000))
	    --id = digest.sha1_hex(math.random(0, 65000))
        self:cookie({ name = 'id', value = id, expires = '+1y' })
    end
	log.info('user_id = '..id)
    log.info(id..': started and get answer')
	host, lxc_id = get_container(id)
	print (host, lxc_id)
    data = get_answer(self, id, host, lxc_id)
    --log.info('%s',yaml.encode(self))
    print (data)
    return self:render({ text = data })
end

-- Start tarantool server

server_host = '188.93.56.54'
server_port = '12345'
log.info('Started http server at host = %s and port = %s ', server_host, server_port)
httpd = server.new(server_host, server_port, {app_dir = '.'})

-- Start fiber for remove unused containers

remove = fiber.create(remove)

httpd:route({ path = '', file = '/index.html'})
--httpd:route({ path = '/tarantool'}, "module#hello")
httpd:route({ path = '/tarantool' }, handler)
httpd:start()
