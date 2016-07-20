
local M = {}

local recording = 0

function M.on_input(self, action_id, action)
	if action_id == hash("1") and action.pressed then
    	if recording == 0 then
    		print("RECORDING")
    		msg.post("@system:", "start_record", { file_name = "/Users/mawe/defold_rec.ivf" } )
    		recording = 1
    	else
    		print("STOPPED RECORDING")
    		msg.post("@system:", "stop_record")
    		recording = 0
    	end
    end
end

return M
