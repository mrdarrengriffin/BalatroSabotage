return [[
local socket = require("socket")
require("love.filesystem")

-- TODO: Fix why this Lovely TOML didn't work
local json = assert(love.filesystem.load("/Mods/BalatroSabotage/libs/json/json.lua"))()

--{{Options
---The port number for the HTTP server. Default is 80
PORT=81
---The parameter backlog specifies the number of client connections
-- that can be queued waiting for service. If the queue is full and
-- another client attempts connection, the connection is refused.
BACKLOG=5
--}}Options

-- create a TCP socket and bind it to the local host, at any port
server=assert(socket.tcp())
assert(server:bind("*", PORT))
server:listen(BACKLOG)

local WebServer = {};

-- stored data from thread channel messages for use in web server
WebServer.data = {
    cards = {},
}

WebServer.process = function()
    local client,err = server:accept()

	if client then
		local line, err = client:receive()
        if not err then
            local path = line:match("GET /(.*) HTTP/1.1")
            
            if path == "" or path == nil then
                path = "index.html"
            end

            if path == "api" then
                local data = json.encode(WebServer.data)
                client:send("HTTP/1.1 200/OK\r\nContent-Type: application/json\r\n\r\n"..data)
                client:close()
                return
            end
            
            local type = path:match(".*%.(.*)") or "html"
            local content = ""

            local file = love.filesystem.newFile("/Mods/BalatroSabotage/web/"..path)
            if file:open("r") then
                 content = content..file:read(file:getSize())
                client:send("HTTP/1.1 200/OK\r\nContent-Type: text/"..type.."\r\n\r\n"..content)
            else
                client:send("HTTP/1.1 404/Not Found\r\nContent-Type: text/html\r\n\r\n404 Not Found")
            end
        end
    end

	client:close()
end

local gameToWebServerDataChannel = love.thread.getChannel("gameToWebServerDataChannel")
function injestGameToWebServerData()
    local message = gameToWebServerDataChannel:pop()
    if message then
        if not message.field or not message.value then
            return
        end

        WebServer.data[message.field] = message.value
    end
end

WebServer.loop = function()
    while 1 do
        injestGameToWebServerData()
        WebServer.process()
    end
end

WebServer.loop()
]]