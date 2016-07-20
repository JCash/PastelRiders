
local M = {}

M.TILE_SIZE = 32

M.GAME_STATE_SPLASH = 0
M.GAME_STATE_INGAME = 1


M.PLAYER_MESSAGE_ACCELERATE = hash("accelerate")
M.PLAYER_MESSAGE_BRAKE 		= hash("brake")
M.PLAYER_MESSAGE_LEFT 		= hash("left")
M.PLAYER_MESSAGE_RIGHT 		= hash("right")
M.PLAYER_MESSAGE_BOOST 		= hash("boost")
M.PLAYER_MESSAGE_SPIN 		= hash("spin")


-- Put functions in this file to use them in several other scripts.
-- To get access to the functions, you need to put:
-- require "my_directory.my_file"
-- in any script using the functions.

return M