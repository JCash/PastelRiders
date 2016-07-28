
local M = {}

M.TILE_SIZE = 32

M.NUM_DIRECTIONS = 64

M.GAME_STATE_SPLASH = 0
M.GAME_STATE_INGAME = 1

M.LEVEL_MESSAGE_INIT        = hash("level_init")
M.LEVEL_MESSAGE_PLAYER_TIME = hash("player_time")
M.LEVEL_MESSAGE_LAP_TIME    = hash("lap_time")

M.PLAYER_MESSAGE_ACCELERATE = hash("accelerate")
M.PLAYER_MESSAGE_BRAKE      = hash("brake")
M.PLAYER_MESSAGE_LEFT       = hash("left")
M.PLAYER_MESSAGE_RIGHT      = hash("right")
M.PLAYER_MESSAGE_BOOST      = hash("boost")
M.PLAYER_MESSAGE_SPIN       = hash("spin")

M.PLAYER_MESSAGE_PAUSE      = hash("pause")

M.TIMER_TUMBLE		= 0.8

M.PHYSICS_MESSAGE_CONTACT   = hash("contact_point_response")
M.PHYSICS_MESSAGE_COLLISION = hash("collision_response")
M.PHYSICS_MESSAGE_TRIGGER   = hash("trigger_response")

M.PHYSICS_GROUP_PLAYER      = hash("player")
M.PHYSICS_GROUP_WORLD       = hash("world")
M.PHYSICS_GROUP_TRACK       = hash("track")
M.PHYSICS_GROUP_OIL         = hash("oil")
M.PHYSICS_GROUP_OBSTACLE    = hash("obstacle")
M.PHYSICS_GROUP_BONUS       = hash("bonus")
M.PHYSICS_GROUP_FINISH      = hash("finishline")

return M