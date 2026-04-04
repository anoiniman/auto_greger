local enum ValidLevel
    "debug"
    "info"
    "warning"
    "error"
    "fatal"
end

local record comms_def
    recieve: function(): {boolean, string, table}
    setup_listener: function()
    controller_send: function(any): {any}
    inject_post_exit: function(any)
    robot_send: function(ValidLevel, string): string
    send_unexpected: function(?boolean)
    cls_nself: function()
    send_command: function(...: string)
    screen_print: function()
    log: function(string | number, string)
end

global NLOG: function(string, string)
global LOG: function(string, string)

return comms_def
