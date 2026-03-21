-- local comms = require("comms")
local type iter_func_type = function(any): (function, any, any)
local record module 
    copy: function (any, ? iter_func_type): any
    copy_no_functions: function(any): any
end
global COPY: function(any, ? iter_func_type): any = module.copy
global CLONE: function(any, ? iter_func_type): any = module.copy

return module
