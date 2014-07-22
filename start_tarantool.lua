#!/usr/bin/env tarantool
-- This script for start and work try.tarantool.org. 
-- Try.tarantool is web pages with terminal that user can use
-- such us tarantool terminal and try tarantool uses cases 

local math = require('math')
local digest = require('digest')
local log = require('log')
local socket = require('socket')
local yaml = require('yaml')

box.cfg{
    admin_port = "3313",
    --logger="tarantool_server.log";
}

local server = require('http.server')

function hello1 (self)
    res = self.req:param('a')
    print (res)
    return self:render({ text = res })
end

-- Table with information about linux containers with tarantool and socket
local lxc = {}
local sock = {}

-- Get conteiner host
function get_container (id)
    local host = nil
    local ip ='0'
    local t = {}
    if lxc then
        for k,v in pairs(lxc) do
            if k == id then
                host = v.host
            end
        end
    end
    if not host then
        host = '10.0.3.100'
        t = {host = host, ip = ip}
        lxc[id] = t
        for k,v in pairs(t) do print(k,v) end
        print (lxc)
    end
    local host_def = '10.0.3.100'
    host = host_def
    return host
end

-- Socket connection to linux container with tarantool and
-- get answer from tarantool to the command request

function get_answer (self, socket_host, id)
    local port = '3313'
    log.info(id..': start connection on host = '.. socket_host)
    local i = 0
    while (i <= 5) do
        s = socket.tcp_connect(socket_host, port)
        log.info(id..': started soket')
        if s then 
            log.info(id..' : conection is open')
            break
        end 
        i = i + 1 
    end
    if not s then
        data = 'Sorry! Server have problem. Please update web page.'
        return data
    end
    local command = self.req:param('command')
    log.info(id..': getting command <'..command..'>')
    s:write(command..'\n')
    local data = s:readline(4000, {'\n...\n'})
    log.info(id..': had answer:\n'..data)
    return data
end

-- Handler for request from try.tarantool page   
function handler (self)
    local id = 0
    log.info('checked cookie')
    local id = self:cookie('id')
    log.info('id = ', id, '\n')
    if id == nil then
        id = digest.sha1_hex(math.random(0, 65000))
        self:cookie({ name = 'id', value = id, expires = '+1y' })
        log.info('set cookie = '..id)
    end
    log.info(id..'started getting answer')
    data = get_answer(self, get_container(id), id)
    --log.info('%s',yaml.encode(self))
    return self:render({ text = data })
end

server_host = '127.0.0.1'
server_port = '12345'
log.info('started http server at host = '..server_host..' and port = '..server_port)
httpd = server.new(server_host, server_port, {app_dir = '.'})
--httpd:route({ path = '/', file = 'index.html'})
--httpd:route({ path = '/tarantool'}, "module#hello")
httpd:route({ path = '/tarantool' }, handler)
httpd:start()
