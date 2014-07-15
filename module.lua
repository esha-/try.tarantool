return {
hello = function(self)
	yaml  = require ('yaml')
	---print ('hy')
	command = self.req:param('command')
	print (command)
	res =require('console').eval(command)
	return self:render({ text = res })	
end
}


