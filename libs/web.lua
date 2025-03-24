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
assert(server:bind('0.0.0.0', PORT))
server:listen(BACKLOG)

local WebServer = {};

local gameToWebServerDataChannel = love.thread.getChannel("gameToWebServerDataChannel")
local webServerToGameDataChannel = love.thread.getChannel("webServerToGameChannel")

-- stored data from thread channel messages for use in web server
WebServer.data = {
    state = nil,
    actions = {
        flip = {
            name = "Flippy",
            description = "Flip the card",
            enabled = true,
        }
    },
    cards = "",
}

WebServer.routes = {
    GET = {},
    POST = {},
}

WebServer.get = function(route, callback)
    WebServer.routes.GET[route] = callback
end

WebServer.post = function(route, callback)
    WebServer.routes.POST[route] = callback
end

WebServer.post("actions/flip", function()
    if(not WebServer.data.actions.flip.enabled) then
        return json.encode(WebServer.data)
    end

    webServerToGameDataChannel:push("flip")
    WebServer.data.actions.flip.enabled = false
    return json.encode(WebServer.data)
end)

WebServer.get("hand", function()
    return WebServer.data.cards
end)

WebServer.process = function()
    local client,err = server:accept()

	if client then
		local line, err = client:receive()
        if not err then
            local getPath = line:match("GET /(.*) HTTP/1.1")
            
            if getPath == "" or getPath == nil then
                getPath = "index.html"
                if WebServer.data.state == 1 then
                WebServer.data.actions.flip.enabled = true
                end
            end

            if WebServer.routes.GET[getPath] then
                local data = WebServer.routes.GET[getPath]()
                client:send("HTTP/1.1 200/OK\r\nContent-Type: text/html\r\n\r\n"..data)
                client:close()
                return
            end   
            
            local postPath = line:match("POST /(.*) HTTP/1.1")
            if WebServer.routes.POST[postPath] then
                local data = WebServer.routes.POST[postPath]()
                client:send("HTTP/1.1 200/OK\r\nContent-Type: text/html\r\n\r\n"..data)
                client:close()
                return
            end

            if getPath == "api" then
                --webServerToGameDataChannel:push("flip")
                local data = json.encode(WebServer.data)
                client:send("HTTP/1.1 200/OK\r\nContent-Type: application/json\r\n\r\n"..data)
                client:close()
                return
            end
            
            local type = getPath:match(".*%.(.*)") or "html"
            local content = ""

            local file = love.filesystem.newFile("/Mods/BalatroSabotage/web/"..getPath)
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

local webCoroutine = coroutine.create(function()
    local maxRequests = 1
    while true do
        for i=1, maxRequests do
            WebServer.process()
        end
        coroutine.yield()
    end
end)

local ingestCoroutine = coroutine.create(function()
    while true do
        local message = gameToWebServerDataChannel:pop()
        if message then
            if not message.field or not message.value then
                print("Invalid message")
            else
                WebServer.data[message.field] = message.value
            end
        else
            coroutine.yield()
        end
    end
end)

WebServer.loop = function()
    while true do
        coroutine.resume(webCoroutine)
        coroutine.resume(ingestCoroutine)
    end
end

WebServer.loop()
]]