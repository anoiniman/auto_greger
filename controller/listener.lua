local comms = require("comms")
local os = require("os")

while true do
    os.sleep(0.1)
    local something, _, message_string = comms.recieve()
    if something == true then print(message_string) end
end
