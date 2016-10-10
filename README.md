* This repository was a part of the the game jam A Game By Its Cover, and
there exists a [dev blog](https://forum.defold.com/t/a-game-by-its-cover-pastel-riders/2458) about it.

Even though this entry was never finished in time for the jam, I continued to develop it since I
still had a few ideas I wanted to try out, and eventually it will become a finished game.

* Play

Control the blue car with WASD 


* Structure

Here is roughly what the scripts do (subject to change)

level.script - controls the logic of the ingame session.
player.script - controls the player (both user, and ai)

autonomous*.lua - different versions of how to calculate the ai for the vehicles
waypoints.lua - helper functions to calculate path related queries
trainer.lua - logic to help modifying the waypoints before trying to generate a good race line
util.lua - some helper functions
constants.lua - the commonly reused constants 


DEBUG KEYS:
0 - Toggle zoom
1 - Togle video recording
Space - Toggle pause




* Links

Here are some interesting links I read during this project

[Steering Behaviors For Autonomous Characters](http://www.red3d.com/cwr/steer/gdc99/)

[Autonomous Agents](http://natureofcode.com/book/chapter-6-autonomous-agents/)

[Physics of Racing Series](http://www.miata.net/sport/Physics/)

[Genetic Algorithm Experiment](http://guillaumebouchetepitech.github.io/geneticAlgorithm_experiment/carDemo/src_html/index.html)

** Credits

http://www.1001fonts.com/conthrax-font.html
