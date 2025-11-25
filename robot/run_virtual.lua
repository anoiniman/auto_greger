-- #!/bin/bash
-- package.path = "../testing/virtual/?.lua;" .. package.path
package.path = "../shared/?.lua" .. package.path
package.path = "../virtual/interface/?.lua" .. package.path
-- print(package.path)

require("robo_main")
