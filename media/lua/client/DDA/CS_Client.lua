-- DDA Client Helper
-- Requirements: Client-Server synchronization

local CS_Client = {}

--- Send a command to the server
--- @param command string Command name
--- @param args table|nil Arguments
function CS_Client.sendCommand(command, args)
    args = args or {}
    local player = getPlayer()
    if player then
        sendClientCommand(player, "DDA", command, args)
    end
end

return CS_Client
