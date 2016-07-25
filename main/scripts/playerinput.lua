local constants = require("main/scripts/constants")

local M = {}

M.INPUT_KEY_UP = 1
M.INPUT_KEY_DOWN = 2
M.INPUT_KEY_LEFT = 3
M.INPUT_KEY_RIGHT = 4

player_input_keys = {}

function M.setup()
	local playerid = 1
    player_input_keys[playerid] = {}
    player_input_keys[playerid][M.INPUT_KEY_UP] = hash("up")
    player_input_keys[playerid][M.INPUT_KEY_DOWN] = hash("down")
    player_input_keys[playerid][M.INPUT_KEY_LEFT] = hash("left")
    player_input_keys[playerid][M.INPUT_KEY_RIGHT] = hash("right")
end

function M.on_input(playerid, player, action_id, action)

    if action_id == player_input_keys[playerid][M.INPUT_KEY_UP] then
    	msg.post(player, constants.PLAYER_MESSAGE_ACCELERATE, action)
    elseif action_id == player_input_keys[playerid][M.INPUT_KEY_DOWN] then
    	msg.post(player, constants.PLAYER_MESSAGE_BRAKE, action)
    elseif action_id == player_input_keys[playerid][M.INPUT_KEY_LEFT] then
    	msg.post(player, constants.PLAYER_MESSAGE_LEFT, action)
    elseif action_id == player_input_keys[playerid][M.INPUT_KEY_RIGHT] then
    	msg.post(player, constants.PLAYER_MESSAGE_RIGHT, action)
    	
    elseif action_id == hash("space") and action.pressed then
    	msg.post(player, constants.PLAYER_MESSAGE_PAUSE, action)
    end
end

return M
