local DATA = {
	round_chips = 0
}

local webserver = SMODS.load_file("libs/server.lua", "Sabotage")();
local web = SMODS.load_file("libs/web.lua", "Sabotage")();

local webThread = love.thread.newThread(web);
local webserverThread = love.thread.newThread(webserver);
webThread:start(SMODS.current_mod.path);
webserverThread:start();

local gameToWebServerDataChannel = love.thread.getChannel("gameToWebServerDataChannel")
local webToGameChannel = love.thread.getChannel("webToGameChannel")

local game_update_ref = Game.update

local done = 0
function Game:update(dt)
    local ret = game_update_ref(self, dt)
    -- things and such
	if(G.GAME.chips_text and (DATA.round_chips == nil or DATA.round_chips ~= G.GAME.chips_text)) then
		sendInfoMessage("Chips Text: " .. G.GAME.chips_text, "Sabotage");
		DATA.round_chips = G.GAME.chips_text;
	end

    if(G.STATE == G.STATES.DRAW_TO_HAND) then
        local txt = "";
        
        if(done > 4) then
            sendDebugMessage(inspect(G.deck.cards[1].config), "Sabotage");
        end
        
        done = done + 1;
        for i = 1, #G.deck.cards do
            local card = G.deck.cards[i];
        end
        gameToWebServerDataChannel:push({field = "cards", value = txt});
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



