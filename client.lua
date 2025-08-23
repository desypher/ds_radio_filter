local radioSubmix = -1
local talkingPlayers = {}
local updateThreadRunning = false
local MIN_DIST = 3000.0
local MAX_DIST = 7000.0

-- Store player data including coordinates
local playerData = {} -- [serverId] = {coords = vector3, lastUpdate = timestamp}

local function createRadioSubmix()
	if radioSubmix ~= -1 then return end

	radioSubmix = CreateAudioSubmix("radio_submix")
	SetAudioSubmixEffectRadioFx(radioSubmix, 0)
	SetAudioSubmixEffectParamInt(radioSubmix, 0, `default`, 1)
	AddAudioSubmixOutput(radioSubmix, 0)
end

local function getEffectStrength(dist)
	if dist <= MIN_DIST then
		return 0.0
	elseif dist >= MAX_DIST then
		return 1.0
	else
		return (dist - MIN_DIST) / (MAX_DIST - MIN_DIST)
	end
end

local function cleanupRadioSubmix()
	if radioSubmix ~= -1 then
		for serverId, _ in pairs(talkingPlayers) do
			MumbleSetSubmixForServerId(serverId, -1)
		end
		radioSubmix = -1
		talkingPlayers = {}
		playerData = {}
	end
end

local function applyRadioEffectWithCoords(serverId, coords)
	if radioSubmix == -1 then return end

	local myPed = PlayerPedId()
	local myCoords = GetEntityCoords(myPed)
	local dist = #(myCoords - coords)

	MumbleSetSubmixForServerId(serverId, radioSubmix)



	local factor = getEffectStrength(dist)

	SetAudioSubmixEffectParamFloat(radioSubmix, 0, `freq_low`, 300.0 + (200.0 * factor))
	SetAudioSubmixEffectParamFloat(radioSubmix, 0, `freq_hi`, 6000.0 - (3500.0 * factor))
	SetAudioSubmixEffectParamFloat(radioSubmix, 0, `fudge`, 0.0 + (0.8 * factor))
	SetAudioSubmixEffectParamFloat(radioSubmix, 0, `rm_mod_freq`, 0.0 + (350.0 * factor))
	SetAudioSubmixEffectParamFloat(radioSubmix, 0, `rm_mix`, 0.16 + (0.6 * factor))
end

-- Fallback method using GetPlayerFromServerId for real-time updates
local function applyRadioEffect(serverId, distance)
	if radioSubmix == -1 then return end

	local player = GetPlayerFromServerId(serverId)
	if player == -1 then
		-- Use stored coordinates as fallback
		if playerData[serverId] and playerData[serverId].coords then
			applyRadioEffectWithCoords(serverId, playerData[serverId].coords)
		end
		return
	end

	MumbleSetSubmixForServerId(serverId, radioSubmix)

	local factor = getEffectStrength(distance)

	SetAudioSubmixEffectParamFloat(radioSubmix, 0, `freq_low`, 300.0 + (200.0 * factor))
	SetAudioSubmixEffectParamFloat(radioSubmix, 0, `freq_hi`, 6000.0 - (3500.0 * factor))
	SetAudioSubmixEffectParamFloat(radioSubmix, 0, `fudge`, 0.0 + (0.8 * factor))
	SetAudioSubmixEffectParamFloat(radioSubmix, 0, `rm_mod_freq`, 0.0 + (350.0 * factor))
	SetAudioSubmixEffectParamFloat(radioSubmix, 0, `rm_mix`, 0.16 + (0.6 * factor))
end

local function startUpdateThread()
	if updateThreadRunning then return end
	updateThreadRunning = true

	CreateThread(function()
		while updateThreadRunning do
			local myPed = PlayerPedId()
			local myCoords = GetEntityCoords(myPed)

			for serverId, _ in pairs(talkingPlayers) do
				local player = GetPlayerFromServerId(serverId)
				if player ~= -1 then
					-- Use real-time coordinates if player is found
					local ped = GetPlayerPed(player)
					local coords = GetEntityCoords(ped)
					local dist = #(myCoords - coords)

					-- Update stored coordinates
					playerData[serverId] = { coords = coords, lastUpdate = GetGameTimer() }

					applyRadioEffect(serverId, dist)
				elseif playerData[serverId] and playerData[serverId].coords then
					-- Use stored coordinates as fallback
					local dist = #(myCoords - playerData[serverId].coords)
					applyRadioEffectWithCoords(serverId, playerData[serverId].coords)
				end
			end

			Wait(1000)
		end
	end)
end

-- Modified event handler to accept coordinates
RegisterNetEvent("ds-radio-filter:client:remoteTalking", function(serverId, talking, channel, coords)
	local myChannel = LocalPlayer.state.radioChannel
	--Locked channels have full range
	if channel <= 10 then return end
	if channel ~= myChannel then return end

	if talking then
		talkingPlayers[serverId] = true

		-- Store player coordinates
		if coords then
			playerData[serverId] = { coords = coords, lastUpdate = GetGameTimer() }
		end

		-- Apply initial submix
		MumbleSetSubmixForServerId(serverId, radioSubmix)

		-- Apply initial effect using sent coordinates
		if coords then
			applyRadioEffectWithCoords(serverId, coords)
		end

		startUpdateThread()
	else
		talkingPlayers[serverId] = nil
		playerData[serverId] = nil
		MumbleSetSubmixForServerId(serverId, -1)

		if next(talkingPlayers) == nil then
			updateThreadRunning = false
		end
	end
end)

AddEventHandler("pma-voice:radioActive", function(radioTalking)
	--Locked channels have full range
	if LocalPlayer.state.radioChannel <= 10 then return end
	TriggerServerEvent("ds-radio-filter:server:radioTalking", radioTalking)
end)

AddEventHandler("onClientResourceStart", function(res)
	if res == GetCurrentResourceName() then
		createRadioSubmix()
	end
end)

AddEventHandler("onClientResourceStop", function(res)
	if res == GetCurrentResourceName() then
		cleanupRadioSubmix()
	end
end)
