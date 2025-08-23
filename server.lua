RegisterNetEvent("ds-radio-filter:server:radioTalking", function(talking)
    local src = source
    local currentChannel = Player(src).state.radioChannel
    local players = exports['pma-voice']:getPlayersInRadioChannel(currentChannel)
    local talkingPlayerPed = GetPlayerPed(src)
    local talkingPlayerCoords = GetEntityCoords(talkingPlayerPed)

    for playerId, _ in pairs(players) do
        if playerId ~= src then
            -- send the talking status directly
            TriggerClientEvent("ds-radio-filter:client:remoteTalking", playerId, src, talking, currentChannel,
                talkingPlayerCoords)
        end
    end
end)
