local DATA = {
	round_chips = 0
}

local web = SMODS.load_file("libs/web.lua", "Sabotage")();
local json = assert(love.filesystem.load("/Mods/BalatroSabotage/libs/json/json.lua"))()

local webThread = love.thread.newThread(web);
webThread:start(SMODS.current_mod.path);

local gameToWebServerDataChannel = love.thread.getChannel("gameToWebServerDataChannel")
local webServerToGameDataChannel = love.thread.getChannel("webServerToGameChannel")

local game_update_ref = Game.update

local done = 0
local hasDrawn = false;
local lastState = nil;
local busy = false;
function Game:update(dt)
    local ret = game_update_ref(self, dt)
    -- things and such
	if(G.GAME.chips_text and (DATA.round_chips == nil or DATA.round_chips ~= G.GAME.chips_text)) then
		sendInfoMessage("Chips Text: " .. G.GAME.chips_text, "Sabotage");
		DATA.round_chips = G.GAME.chips_text;
	end

    if G.STATE ~= lastState then
        lastState = G.STATE;
        sendInfoMessage("State: " .. G.STATE, "Sabotage");
        gameToWebServerDataChannel:push({field = "state", value = lastState})
    end


    local message = webServerToGameDataChannel:pop()
    if message and not busy then
        if G.STATE == G.STATES.SELECTING_HAND then
            if message == "requestCards" then
                if G.STATE == 1 then
                    local cards = {}
                    for i=1, #G.hand.cards do
                        cards[i] = G.P_CARDS[G.hand.cards[i].config.card_key].name
                    end
                    gameToWebServerDataChannel:push({field = "cards", value = cards})
                end
            elseif message == "flip" then
                busy = true;
                sendInfoMessage("Flipping card", "Sabotage");
                G.hand.cards[1]:flip();
                play_sound("card1")
                G.E_MANAGER:add_event(Event({
                    trigger = 'after',
                    delay = 0.25,
                    func = function()
                        G.hand:shuffle();
                        play_sound("paper1")
                        return true;
                    end
                }))
                G.E_MANAGER:add_event(Event({
                    trigger = 'after',
                    delay = 1,
                    func = function()
                        G.hand.cards[3]:flip();
                        play_sound("card1")
                        return true;
                    end
                }))
                G.E_MANAGER:add_event(Event({
                    trigger = 'after',
                    delay = 0.25,
                    func = function()
                        G.hand:shuffle();
                        play_sound("paper1")
                        return true;
                    end
                }))
                G.E_MANAGER:add_event(Event({
                    trigger = 'after',
                    delay = 1,
                    func = function()
                        G.hand.cards[5]:flip();
                        play_sound("card1")
                        return true;
                    end
                }))
                G.E_MANAGER:add_event(Event({
                    trigger = 'after',
                    delay = 0.25,
                    func = function()
                        G.hand:shuffle();
                        play_sound("paper1")
                        sendInfoMessage("Flipped card", "Sabotage");
                        busy = false;
                        return true;
                    end
                }))
                
            end
        end
    end

    return ret
end    

local event
event = Event {
    blockable = false,
    blocking = false,
    pause_force = true,
    no_delete = true,
    trigger = "after",
    delay = 0.5,
    timer = "UPTIME",
    func = function()
        webServerToGameDataChannel:push("requestCards")
        event.start_timer = false
    end
}
G.E_MANAGER:add_event(event)


