#!/usr/bin/env tarantool
box.cfg{
    primary_port        = os.getenv("PRIMARY_PORT"),
    admin_port          = "3313",
}

function hello1 (self)
    res = self.req:param('a')
    print (res)
    return self:render({ text = res })
end

function hello (self)
	return self:render({ file = './public/index.html' })
end

server = require('box.http.server')
httpd = server.new('127.0.0.1', '12345', {app_dir = '.'})
--httpd:route({ path = '/', file = 'index.html'})
httpd:route({ path = '/tarantool'}, "module#hello")
httpd:start()
