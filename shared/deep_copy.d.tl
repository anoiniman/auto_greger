-- local comms = require("comms")
local type iter_func_type = function(any): (function, any, any)
local record module 
    copy: function<T>(T, ? iter_func_type): T
    copy_no_functions: function<T>(T): T
end
global COPY: function<T>(T, ? iter_func_type): T = module.copy
global CLONE: function<T>(T, ? iter_func_type): T = module.copy

return module
