local DATA = {
	round_chips = 0
}

local webserver = SMODS.load_file("libs/server.lua", "Sabotage")();

local webserverThread = love.thread.newThread(webserver);
webserverThread:start();

local gameToWebChannel = love.thread.getChannel("gameToWebChannel")
local webToGameChannel = love.thread.getChannel("webToGameChannel")

local game_update_ref = Game.update
function Game:update(dt)
    local ret = game_update_ref(self, dt)
    -- things and such
	if(G.GAME.chips_text and (DATA.round_chips == nil or DATA.round_chips ~= G.GAME.chips_text)) then
		sendInfoMessage("Chips Text: " .. G.GAME.chips_text, "Sabotage");
		DATA.round_chips = G.GAME.chips_text;
		gameToWebChannel:push(G.GAME.chips_text);
	end

    if(G.STATE == G.STATES.DRAW_TO_HAND) then
        sendInfoMessage("Draw to hand", "Sabotage");
    end

    local message = webToGameChannel:pop()
    if message then
        if(message.type == "chips") then
            G.E_MANAGER:add_event(Event({
                trigger = "ease",
                delay = 2,
                ref_table = G.GAME,
                ref_value = "chips",
                ease_to = G.GAME.chips + message.value,
            }))
        end
    end

    return ret
end    

