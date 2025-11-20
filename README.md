This will Greg for You!

## Installation Intrunctions
### Pre-Requesites
Be on GTNH, and have a opencomputers robot with the <necessary> modules as shown in the video:
>2x Inventory Expansion
>1x Inventory Controller
>1x Geolyzer
>1x Combustion Generator
>1x Module Expansion Slot
etc.
Be mindful that in order for all modules to be equipable, you may not have a floppy disc drive installed on the robot, you must deconstruct/reconstruct the robot after installing OpenOS.
Also, make sure that you have enough RAM and disc-space, you WILL need the full complement of 2MB of RAM.
If you want to use remote functionalities through remember to properly link the 2 tunnel-card together, one for the robot, another for the remote computer terminal.
Make sure that OpenOS is installed.


### Installing
Copy the following into the clipboard: 
```
wget -f "https://raw.githubusercontent.com/anoiniman/auto_greger/refs/heads/master/installer.lua" installer.lua
```
Make sure that you are cd'ed into your /home folder using ``cd /home``
Now, inside GTNH, and right-clicked onto the pre-prepared robot, press the middle-mouse button so as to paste, and press enter to run the command.

Afterwards type the following:
```
installer robot all
```

For the installation of "prompt" software download the installer as described previously, and then run the following:
```
installer controller all
```

## Usage Instructions
For a complete list of all possible commands, reading the source code is recomended, particularly: "./robot/robo_main.lua", "./robot/eval/eval_main.lua", "./robot/eval/debug.lua" and "./controller/prompt.lua".
Simply cd into the installed folder inside your /home directory and run "robo_main"/"prompt".

### Controller
Type ``comm`` in order to activity remote guidance mode.
``print_mode`` allows robot responses to be printed imediatly, alternative you may press the enter-key in order to poll for a response.
Pressing 'q' while in "print_mode" will exit print_mode and allow you to input commands once again.
Type ``exit`` once in comm mode in order to stop dictating commands to the robot.
While in comm mode everything else you type other than the above mentioned commands will be sent to the robot as a robot command for the robot to interpret.


### Robot
``auto_run`` Unlocks the robot from manual control, only works when run from the robot itself
While running in "auto" holding 'q' will eventually re-lock the robot into manual mode, alternativly you may send the ``block`` command from your controll computer.
``debug move \[north|south|west|east\] <int>`` In order to manually move into a certain cardinal direction x times.
``start_reason`` in order to enable reasoning module.
``reason_once`` in order to enable reasoning module ONCE and only ONCE.

I might expand the explanation later on, but for now just read the source code in order to get a full command list.
