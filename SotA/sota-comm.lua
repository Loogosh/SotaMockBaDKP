--[[
--	SotA Communication Module
--	Handles addon-to-addon communication using SendAddonMessage
--	Protocol: version;msgType;key=value;key2=value2...
--]]

-- Addon message prefixes
MDKP_SRV_PREFIX = "MDKP_SRV"  -- Server → Client messages
MDKP_CLT_PREFIX = "MDKP_CLT"  -- Client → Server messages
MDKP_PROTOCOL_VERSION = "1"

-- Track which clients have the addon (responded to HELLO)
local MDKP_KnownClients = {}

--[[
--	Initialize communication module
--	Called from SOTA_OnLoad()
--]]
function SOTA_InitCommunication()
	-- Register addon message prefixes
	RegisterAddonMessagePrefix(MDKP_SRV_PREFIX)
	RegisterAddonMessagePrefix(MDKP_CLT_PREFIX)
	
	debugEcho("MDKP Communication module initialized")
end

--[[
--	Parse addon message format: "version;msgType;key=value;key2=value2..."
--	Returns: version, msgType, payload table
--]]
function SOTA_ParseAddonMessage(msg)
	if not msg or msg == "" then
		return nil, nil, {}
	end
	
	local parts = {}
	local index = 1
	for part in string.gfind(msg, "([^;]+)") do
		parts[index] = part
		index = index + 1
	end
	
	if table.getn(parts) < 2 then
		return nil, nil, {}
	end
	
	local version = parts[1]
	local msgType = parts[2]
	local payload = {}
	
	-- Parse key=value pairs from remaining parts
	for i = 3, table.getn(parts) do
		local k, v = string.match(parts[i], "([^=]+)=(.+)")
		if k and v then
			payload[k] = v
		end
	end
	
	return version, msgType, payload
end

--[[
--	Build addon message from components
--	Returns: formatted message string
--]]
function SOTA_BuildAddonMessage(msgType, payload)
	local msg = MDKP_PROTOCOL_VERSION .. ";" .. msgType
	
	if payload then
		for k, v in pairs(payload) do
			msg = msg .. ";" .. k .. "=" .. tostring(v)
		end
	end
	
	return msg
end

--[[
--	Send addon message to raid/party with fallback to text chat
--	Parameters:
--		msgType: type of message (AUCTION_START, BID_UPDATE, etc.)
--		payload: table of key-value pairs
--		fallbackMsgInfo: msgInfo for publicEcho (only for OnOpen/OnComplete)
--]]
function SOTA_SendAddonMessage(msgType, payload, fallbackMsgInfo)
	local msg = SOTA_BuildAddonMessage(msgType, payload)
	
	-- Send via addon channel
	local channel = "RAID"
	if not SOTA_IsInRaid(true) then
		channel = "PARTY"
	end
	
	SendAddonMessage(MDKP_SRV_PREFIX, msg, channel)
	
	debugEcho("Sent addon message: " .. msgType)
	
	-- Send fallback to chat ONLY for OnOpen and OnComplete
	if fallbackMsgInfo and (msgType == "AUCTION_START" or msgType == "AUCTION_END") then
		publicEcho(fallbackMsgInfo)
	end
end

--[[
--	Send whisper via addon message
--	Used for bid confirmations and direct communication
--]]
function SOTA_SendAddonWhisper(msgType, payload, target)
	local msg = SOTA_BuildAddonMessage(msgType, payload)
	SendAddonMessage(MDKP_SRV_PREFIX, msg, "WHISPER", target)
end

--[[
--	Mark a client as having the addon (for future optimizations)
--]]
function SOTA_RegisterAddonClient(playerName, version)
	MDKP_KnownClients[playerName] = {
		version = version,
		lastSeen = time()
	}
	debugEcho("Registered addon client: " .. playerName .. " v" .. version)
end

--[[
--	Check if a client has the addon
--]]
function SOTA_HasAddonClient(playerName)
	return MDKP_KnownClients[playerName] ~= nil
end

--[[
--	Send auction start notification via addon
--]]
function SOTA_SendAuctionStart(itemLink, itemId, minBid, auctionTime)
	local _, itemName = GetItemInfo(itemId)
	
	local payload = {
		itemId = itemId,
		name = itemName or "Unknown",
		minBid = minBid,
		time = auctionTime
	}
	
	SOTA_SendAddonMessage("AUCTION_START", payload, nil)
end

--[[
--	Send auction end notification via addon
--]]
function SOTA_SendAuctionEnd(itemLink, itemId, winner, bid)
	local _, itemName = GetItemInfo(itemId)
	
	local payload = {
		itemId = itemId,
		name = itemName or "Unknown",
		winner = winner,
		bid = bid
	}
	
	SOTA_SendAddonMessage("AUCTION_END", payload, nil)
end

--[[
--	Send bid update notification via addon
--]]
function SOTA_SendBidUpdate(bidder, bid, bidType, rank)
	local payload = {
		bidder = bidder,
		bid = bid,
		type = (bidType == 1 and "ms" or "os"),
		rank = rank or ""
	}
	
	SOTA_SendAddonMessage("BID_UPDATE", payload, nil)
end

--[[
--	Send auction pause notification
--]]
function SOTA_SendAuctionPause()
	SOTA_SendAddonMessage("AUCTION_PAUSE", nil, nil)
end

--[[
--	Send auction resume notification
--]]
function SOTA_SendAuctionResume()
	SOTA_SendAddonMessage("AUCTION_RESUME", nil, nil)
end

--[[
--	Send auction cancel notification
--]]
function SOTA_SendAuctionCancel()
	SOTA_SendAddonMessage("AUCTION_CANCEL", nil, nil)
end

--[[
--	Send timer update (for countdown)
--]]
function SOTA_SendTimerUpdate(seconds)
	local payload = { seconds = seconds }
	SOTA_SendAddonMessage("TIMER", payload, nil)
end
