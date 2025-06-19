-- #!/bin/bash
package.path = "./virtual/?.lua;" .. package.path
-- print(package.path)

require("robo_main")
