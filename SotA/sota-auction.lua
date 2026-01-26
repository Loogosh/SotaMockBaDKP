
--	State machine:
local STATE_NONE				= 0
local STATE_AUCTION_RUNNING		= 10
local STATE_AUCTION_PAUSED		= 20
local STATE_AUCTION_COMPLETE	= 30
local STATE_PAUSED				= 90

local RAID_STATE_DISABLED		= 0
local RAID_STATE_ENABLED		= 1

-- Max # of bids shown in the AuctionUI
local MAX_BIDS					= 10
-- List of valid bids: { Name, DKP, BidType(MS=1,OS=2), Class, RankName, RankIndex }
local IncomingBidsTable			= { };

-- Working variables:
local RaidState					= RAID_STATE_DISABLED
local AuctionedItemLink			= ""
local AuctionedItemMsg			= ""
local AuctionState				= STATE_NONE



function SOTA_GetSecondCounter()
	return Seconds;
end

function SOTA_GetAuctionState()
	return AuctionState;
end

function SOTA_SetAuctionState(auctionState, seconds)
	if not seconds then
		seconds = 0;
	end
	AuctionState = auctionState;
	SOTA_setSecondCounter(seconds);
end



--[[
--	Start the auction, and set state to STATE_STARTING
--	Parameters:
--	itemLink: a Blizzard itemlink to auction.
--	Since 0.0.1
--]]
function SOTA_StartAuction(msg)
	local rank = SOTA_GetRaidRank(UnitName("player"));
	if rank < 1 then
		localEcho("You need to be Raid Assistant or Raid Leader to start auctions.");
		return;
	end

	AuctionedItemMsg = msg;
	
	local t={}; 
	local i=1;
    for w in string.gfind(msg, "%S+") do
        t[i] = w
        i = i + 1
    end
	
	SOTA_Minimum_Bid = tonumber(t[1]);

	local _, _, itemId = string.find(msg, "item:(%d+):")
	if not itemId then
		localEcho("Item was not found: ".. itemId);
		return;
	end
	local j, f = string.find(msg, "|.*")
	local itemLink = string.sub(msg, j, f)
	local itemName, _, itemQuality, _, _, _, _, _, itemTexture = GetItemInfo(itemId);
	AuctionedItemLink = itemLink;
	
	SOTA_RequestMaster();
	
	local frame = getglobal("AuctionUIFrameItem");
	if frame then
		local rgb = SOTA_GetQualityColor(itemQuality);	
		local inf = getglobal(frame:GetName().."ItemName");
		inf:SetText(itemName);
		inf:SetTextColor( (rgb[1]/255), (rgb[2]/255), (rgb[3]/255), 1);
		
		local tf = getglobal(frame:GetName().."ItemTexture");
		if tf then
			tf:SetTexture(itemTexture);
		end
	end
	

	IncomingBidsTable = { };
	SOTA_UpdateBidElements();
	SOTA_OpenAuctionUI();

	SOTA_SetAuctionState(STATE_AUCTION_RUNNING, SOTA_CONFIG_AuctionTime);
end



--[[
--	The big SOTA state machine.
--	Since 0.0.1
--]]
function SOTA_CheckAuctionState()
	local state = SOTA_GetAuctionState();
	
	debugEcho(string.format("SOTA_CheckAuctionState called, state = %d", STATE_AUCTION_PAUSED));

	if state == STATE_NONE or state == STATE_AUCTION_PAUSED then
		return;
	end
		
	if state == STATE_AUCTION_RUNNING then
		local secs = SOTA_GetSecondCounter();
		
		if secs == SOTA_CONFIG_AuctionTime then

			SOTA_EchoEvent(SOTA_MSG_OnOpen, AuctionedItemLink, SOTA_Minimum_Bid);
			-- SOTA_EchoEvent(SOTA_MSG_OnAnnounceBid, AuctionedItemLink, SOTA_GetMinimumBid());
			-- SOTA_EchoEvent(SOTA_MSG_OnAnnounceMinBid, AuctionedItemLink, SOTA_GetMinimumBid());
			-- SOTA_EchoEvent(SOTA_MSG_ExtraInfo, AuctionedItemLink, SOTA_GetMinimumBid());
		end


		if SOTA_CONFIG_AuctionTime > 0 then
			if secs == 10 then
				SOTA_EchoEvent(SOTA_MSG_On10SecondsLeft, AuctionedItemLink);
			end

			if secs == 9 then
				SOTA_EchoEvent(SOTA_MSG_On9SecondsLeft, AuctionedItemLink);
			end
			if secs == 8 then
				SOTA_EchoEvent(SOTA_MSG_On8SecondsLeft, AuctionedItemLink);
			end
			if secs == 7 then
				SOTA_EchoEvent(SOTA_MSG_On7SecondsLeft, AuctionedItemLink);
			end
			if secs == 6 then
				SOTA_EchoEvent(SOTA_MSG_On6SecondsLeft, AuctionedItemLink);
			end
			if secs == 5 then
				SOTA_EchoEvent(SOTA_MSG_On5SecondsLeft, AuctionedItemLink);
			end
			if secs == 4 then
				SOTA_EchoEvent(SOTA_MSG_On4SecondsLeft, AuctionedItemLink);
			end
			if secs == 3 then
				SOTA_EchoEvent(SOTA_MSG_On3SecondsLeft, AuctionedItemLink);
			end
			if secs == 2 then
				SOTA_EchoEvent(SOTA_MSG_On2SecondsLeft, AuctionedItemLink);
			end
			if secs == 1 then
				SOTA_EchoEvent(SOTA_MSG_On1SecondLeft, AuctionedItemLink);
			end
			if secs < 1 then
				SOTA_FinishAuction(sender, dkp);	
			end
			
			Seconds = Seconds - 1;
		else
			Seconds = 1;
		end;
		
	end
	
	if state == STATE_COMPLETE then
		--	 We're idle
		state = STATE_NONE;
	end

	SOTA_RefreshButtonStates();
end


--[[
--	Handle incoming bid request.
--	Syntax: /sota bid|ms|os <dkp>|min|max
--	Since 0.0.1
--]]
function SOTA_HandlePlayerBid(sender, message)
	local playerInfo = SOTA_GetGuildPlayerInfo(sender);
	if not playerInfo then
		SOTA_whisper(sender, "Ты должен быть в гильдии, чтобы ставить!");
		return;
	end

	local unitId = SOTA_GetUnitIDFromGroup(sender);
	if not unitId then
		return;
	end

	local availableDkp = 1 * (playerInfo[2]);
	
	local cmd, arg
	local spacepos = string.find(message, "%s");
	if spacepos then
		_, _, cmd, arg = string.find(string.lower(message), "(%S+)%s+(.+)");
	else
		return;
	end	

	-- Default is MS - if OS bidding is enabled, check bidtype:
	local bidtype = nil;
	
	if SOTA_CONFIG_EnableOSBidding == 1 then
		bidtype = 1;
		if cmd == "os" then
			bidtype = 2;
		end
	end
	
	local minimumBid = SOTA_GetMinimumBid(bidtype);
	if not minimumBid then
		SOTA_whisper(sender, "Нельзя ставить на офф-спек, уже есть ставка на мейн-спек");
		return;
	end
	
	if SOTA_FirstBid then
		if bidtype == 2 then
			minimumBid = minimumBid / 2;
		end
	end

	--echo(string.format("Min.Bid=%d for bidtype=%s", minimumBid, bidtype));
	local userWentAllIn = false;
	local dkp = tonumber(arg)	
	if not dkp then
		if arg == "min" then
			dkp = minimumBid;
		elseif arg == "max" then
			dkp = availableDkp;
			userWentAllIn = true;
		else
			-- This was not following a legal format; skip message
			return;
		end
	end	

	if not (AuctionState == STATE_AUCTION_RUNNING) then
		SOTA_whisper(sender, "Сейчас нет аукциона - ставка проигнорирована");
		return;
	end	

	dkp = 1 * dkp

	local highestBid = SOTA_GetHighestBid(bidtype);

	local hiRankIndex = 0;
	local hiBid = SOTA_GetStartingDKP(bidtype);
	if highestBid then
		hiBid = highestBid[2];
		hiRankIndex = highestBid[6];
	end;

	local bidderClass = playerInfo[3];		-- Info for the player placing the bid.
	local bidderRank  = playerInfo[4];		-- This rank is by NAME
	local bidderRIdx  = playerInfo[7];		-- This rank is by NUMBER!

	if (dkp > availableDkp) then
		SOTA_whisper(sender, string.format("У тебя только %d ДКП - ставка проигнорирована.", availableDkp));
		return;
	end;

	if not(userWentAllIn) then
		if (dkp < minimumBid) then
			SOTA_whisper(sender, string.format("Нужно поставить %d ДКП - ставка проигнорирована.", minimumBid));
			return;
		end;
	else
		if (dkp < hiBid + 1) then
			SOTA_whisper(sender, string.format("ОЛЛ-ИН меньше или равен предыдущей ставке в %d ДКП - ОЛЛ-ИН проигнорирован.", hiBid));
			return;
		end;
	end;

	if Seconds < SOTA_CONFIG_AuctionExtension then
		Seconds = SOTA_CONFIG_AuctionExtension;
	end
	
	if userWentAllIn then
		if bidtype == 2 then
			SOTA_EchoEvent(SOTA_MSG_OnOffspecMaxBid, AuctionedItemLink, dkp, sender, bidderRank);
		else
			SOTA_EchoEvent(SOTA_MSG_OnMainspecMaxBid, AuctionedItemLink, dkp, sender, bidderRank);
		end;
	else
		if bidtype == 2 then
			SOTA_EchoEvent(SOTA_MSG_OnOffspecBid, AuctionedItemLink, dkp, sender, bidderRank);
		else
			SOTA_EchoEvent(SOTA_MSG_OnMainspecBid, AuctionedItemLink, dkp, sender, bidderRank);
		end;
	end;
	

	SOTA_RegisterBid(sender, dkp, bidtype, bidderClass, bidderRank, bidderRIdx);
	
		
end



function SOTA_RegisterBid(playername, bid, bidtype, playerclass, rankname, rankindex)
	-- if bidtype == 2 then
	-- 	SOTA_whisper(playername, string.format("Твоя ставка на ОС %d ДКП была зарегистрирована", bid) );
	-- else
	-- 	SOTA_whisper(playername, string.format("Твоя ставка на МС %d ДКП была зарегистрирована", bid) );
	-- end

	IncomingBidsTable = SOTA_RenumberTable(IncomingBidsTable);
	
	IncomingBidsTable[table.getn(IncomingBidsTable) + 1] = { playername, bid, bidtype, playerclass, rankname, rankindex };

	-- Sort by DKP, then BidType (so MS bids are before OS bids)
	SOTA_SortTableDescending(IncomingBidsTable, 2);
	if SOTA_CONFIG_EnableOSBidding == 1 then
		SOTA_SortTableAscending(IncomingBidsTable, 3);
	end
 
	SOTA_UpdateBidElements();
end


function SOTA_UnregisterBid(playername, bid)
	playername = SOTA_UCFirst(playername);
	bid = 1 * bid;

	local bidInfo;
	for n=1,table.getn(IncomingBidsTable), 1 do
		bidInfo = IncomingBidsTable[n];
		if bidInfo[1] == playername and 1*(bidInfo[2]) == bid then
			table.remove(IncomingBidsTable, n);

			IncomingBidsTable = SOTA_RenumberTable(IncomingBidsTable);
			
			SOTA_UpdateBidElements();
			SOTA_ShowSelectedPlayer();
			return;
		end
	end
end

function SOTA_GetBidInfo(playername, bid)
	playername = SOTA_UCFirst(playername);
	bid = 1 * bid;

	local bidInfo;
	for n=1,table.getn(IncomingBidsTable), 1 do
		bidInfo = IncomingBidsTable[n];
		if bidInfo[1] == playername and 1*(bidInfo[2]) == bid then
			return bidInfo;
		end
	end

	return nil;
end


function SOTA_AcceptBid(playername, bid)
	if playername and bid then
		playername = SOTA_UCFirst(playername);
		bid = 1 * bid;
	
		AuctionUIFrame:Hide();
		
		SOTA_EchoEvent(SOTA_MSG_OnComplete, AuctionedItemLink, bid, playername);
		
		SOTA_SubtractPlayerDKP(playername, bid);		
	end
end


function SOTA_HandlePlayerPass(playername)
	if (SOTA_CONFIG_AllowPlayerPass == 0) then
		SOTA_whisper(playername, "Нельзя паснуть, если ты сделал ставку!");
		return;
	end;

	if not(AuctionState == STATE_AUCTION_RUNNING) then
		SOTA_whisper(playername, "Сейчас ничего не происходит, пас проигнорирован");
		return;
	end;


	IncomingBidsTable = SOTA_RenumberTable(IncomingBidsTable);
	local size = table.getn(IncomingBidsTable);

	if (size == 0) then
		SOTA_whisper(playername, "Нет ставок на этот аукцион, чтобы паснуть");
		return;
	end;

	local lastbid = IncomingBidsTable[1];
	if not(playername == lastbid[1]) then
		SOTA_whisper(playername, "Можно паснуть только если ты поставил больше всех!");
		return;
	end;

	if (size > 1) then
		local nextbid = IncomingBidsTable[2];
		raidEcho(string.format("%s паснул; наивысшая ставка теперь у %s - %d ДКП", playername, nextbid[1], nextbid[2]));
	else
		raidEcho(string.format("%s паснул; Теперь нет активных ставок", playername));
	end;

	SOTA_UnregisterBid(lastbid[1], lastbid[2]);		
end;



--
--	UI functions
--
function SOTA_OpenAuctionUI()
	SOTA_ClearSelectedPlayer();
	AuctionUIFrame:Show();
end


function SOTA_AuctionUIInit()
	--	Initialize top <n> bids
	for n=1, MAX_BIDS, 1 do
		local entry = CreateFrame("Button", "$parentEntry"..n, AuctionUIFrameTableList, "SOTA_BidTemplate");
		entry:SetID(n);
		if n == 1 then
			entry:SetPoint("TOPLEFT", 4, -4);
		else
			entry:SetPoint("TOP", "$parentEntry"..(n-1), "BOTTOM");
		end
	end
end;


--[[
--	Show top <n> in bid window
--]]
function SOTA_UpdateBidElements()
	local bidder, bid, playerclass, rank;
	for n=1, MAX_BIDS, 1 do
		if table.getn(IncomingBidsTable) < n then
			bidder = "";
			bid = "";
			bidcolor = { 64, 255, 64 };
			playerclass = "";
			rank = "";
		else
			local cbid = IncomingBidsTable[n];
			bidder = cbid[1];
			bidcolor = { 64, 255, 64 };
			if cbid[3] == 2 then
				bidcolor = { 255, 255, 96 };
			end
			bid = string.format("%d", cbid[2]);
			playerclass = cbid[4];
			rank = cbid[5];
		end

		local color = SOTA_GetClassColorCodes(playerclass);

		local frame = getglobal("AuctionUIFrameTableListEntry"..n);
		getglobal(frame:GetName().."Bidder"):SetText(bidder);
		getglobal(frame:GetName().."Bidder"):SetTextColor((color[1]/255), (color[2]/255), (color[3]/255), 255);
		getglobal(frame:GetName().."Bid"):SetTextColor((bidcolor[1]/255), (bidcolor[2]/255), (bidcolor[3]/255), 255);
		getglobal(frame:GetName().."Bid"):SetText(bid);
		getglobal(frame:GetName().."Rank"):SetText(rank);

		SOTA_RefreshButtonStates();
		frame:Show();
	end
end


function SOTA_GetSelectedBid()
	local selectedBid = nil;
	
	local frame = getglobal("AuctionUIFrameSelected");
	local bidder = getglobal(frame:GetName().."Bidder"):GetText();
	local bid = getglobal(frame:GetName().."Bid"):GetText();

	if bidder and bid then
		selectedBid = { bidder, bid };
	end

	return selectedBid;
end


--[[
--	Refresh button states
--]]
function SOTA_RefreshButtonStates()
	local isAuctionRunning = (SOTA_GetAuctionState() == STATE_AUCTION_RUNNING);
	local isAuctionPaused = (SOTA_GetAuctionState() == STATE_AUCTION_PAUSED);

	local isBidderSelected = true;
	local selectedBid = SOTA_GetSelectedBid();
	if not selectedBid then
		isBidderSelected = false;
	end	

	if isBidderSelected then
		if isAuctionRunning or isAuctionPaused then
			getglobal("AcceptBidButton"):Disable();
		else
			getglobal("AcceptBidButton"):Enable();
		end		
		getglobal("CancelBidButton"):Enable();
	else
		getglobal("AcceptBidButton"):Disable();
		getglobal("CancelBidButton"):Disable();
	end
	
	if isAuctionRunning or isAuctionPaused then
		getglobal("CancelAuctionButton"):Enable();
		getglobal("RestartAuctionButton"):Enable();
		getglobal("FinishAuctionButton"):Enable();
		if isAuctionPaused then
			getglobal("PauseAuctionButton"):Enable();
			getglobal("PauseAuctionButton"):SetText("Продолжить аук");
		else
			getglobal("PauseAuctionButton"):Enable();
			getglobal("PauseAuctionButton"):SetText("Остановить аук");
		end
	else
		getglobal("CancelAuctionButton"):Enable();
		getglobal("RestartAuctionButton"):Enable();
		getglobal("FinishAuctionButton"):Disable();
		getglobal("PauseAuctionButton"):Disable();
		getglobal("PauseAuctionButton"):SetText("Остановить аук");
	end	
end


--[[
--	Accept a player bid
--	Since 0.0.3
--]]
function SOTA_AcceptSelectedPlayerBid()
	local selectedBid = SOTA_GetSelectedBid();
	if not selectedBid then
		return;
	end

	SOTA_AcceptBid(selectedBid[1], selectedBid[2]);
end


--[[
--	Cancel a player bid
--	Since 0.0.3
--]]
function SOTA_CancelSelectedPlayerBid()
	local selectedBid = SOTA_GetSelectedBid();
	if not selectedBid then
		return;
	end
	
	local previousBid = SOTA_GetHighestBid();
	
	SOTA_UnregisterBid(selectedBid[1], selectedBid[2]);
	
	local highestBid = SOTA_GetHighestBid();
	local bid = 0;
	if highestBid then
		bid = highestBid[2]
	end
	
	if not (previousBid[2] == bid) then
		if bid == 0 then
			bid = SOTA_GetMinimumBid();
			warnEcho(string.format("[SotA] Ставка %s была отменена, минимальная ставка: %d ДКП", previousBid[1], SOTA_Minimum_Bid));
			return;
		end
		warnEcho(string.format("[SotA] Ставка %s была отменена, наивысшая ставка теперь у %s - %d ДКП", previousBid[1], highestBid[1], bid));
	end
end


--[[
--	Pause the Auction
--	Since 0.0.3
--]]
function SOTA_PauseAuction()
	local state = SOTA_GetAuctionState();	
	local secs = SOTA_GetSecondCounter();
	
	if state == STATE_AUCTION_RUNNING then
		SOTA_SetAuctionState(STATE_AUCTION_PAUSED, secs);
		SOTA_EchoEvent(SOTA_MSG_OnPause, AuctionedItemLink);
	end
	
	if state == STATE_AUCTION_PAUSED then
		SOTA_SetAuctionState(STATE_AUCTION_RUNNING, secs + SOTA_CONFIG_AuctionExtension);
		SOTA_EchoEvent(SOTA_MSG_OnResume, AuctionedItemLink);
	end

	SOTA_RefreshButtonStates();
end


--[[
--	Finish the Auction
--	Since 0.0.3
--]]
function SOTA_FinishAuction()
	local state = SOTA_GetAuctionState();
	if state == STATE_AUCTION_RUNNING or state == STATE_AUCTION_PAUSED then
		--publicEcho(string.format("Auction for %s is over", AuctionedItemLink));
		--publicEcho(SOTA_getConfigurableMessage(SOTA_MSG_OnClose, AuctionedItemLink));
		SOTA_EchoEvent(SOTA_MSG_OnClose, AuctionedItemLink);

		SOTA_SetAuctionState(STATE_AUCTION_COMPLETE);
		
		-- Check if a player was selected; if not, select highest bid:
		if table.getn(IncomingBidsTable) > 0 then
			local selectedBid = SOTA_GetSelectedBid();
			if not selectedBid then
				SOTA_ShowSelectedPlayer(IncomingBidsTable[1][1], IncomingBidsTable[1][2]);
			end
		end
	end
	
	SOTA_RefreshButtonStates();
end


--[[
--	Cancel the Auction
--	Since 0.0.3
--]]
function SOTA_CancelAuction()
	local state = SOTA_GetAuctionState();
	if state == STATE_AUCTION_RUNNING or state == STATE_AUCTION_PAUSED then
		IncomingBidsTable = { }
		SOTA_SetAuctionState(STATE_AUCTION_NONE);
		--publicEcho("Auction was Cancelled");		
		--publicEcho(SOTA_getConfigurableMessage(SOTA_MSG_OnCancel, AuctionedItemLink));
		SOTA_EchoEvent(SOTA_MSG_OnCancel, AuctionedItemLink);
	end
	
	AuctionUIFrame:Hide();
end


--[[
--	Restart the Auction
--	Since 0.0.3
--]]
function SOTA_RestartAuction()
	SOTA_SetAuctionState(STATE_NONE);		
	SOTA_StartAuction(AuctionedItemMsg);
end



--[[
--	Show the selected (clicked) bidder information in AuctionUI.
--	Since 0.0.2
--]]
function SOTA_ShowSelectedPlayer(playername, bid)
	local bidInfo = nil
	if playername and bid then
		bidInfo = SOTA_GetBidInfo(playername, bid);	
	end
	
	local bidder, bid, playerclass, rank;
	if not bidInfo then
		bidder = "";
		bid = "";
		playerclass = "";
		rank = "";
	else
		bidder = bidInfo[1];
		bid = string.format("%d", bidInfo[2]);
		playerclass = bidInfo[3];
		rank = bidInfo[4];
	end
	
	local color = SOTA_GetClassColorCodes(playerclass);

	local frame = getglobal("AuctionUIFrameSelected");
	getglobal(frame:GetName().."Bidder"):SetText(bidder);
	getglobal(frame:GetName().."Bidder"):SetTextColor((color[1]/255), (color[2]/255), (color[3]/255), 255);
	getglobal(frame:GetName().."Bid"):SetText(bid);
	getglobal(frame:GetName().."Rank"):SetText(rank);

	SOTA_RefreshButtonStates();
end

function SOTA_ClearSelectedPlayer()
	local frame = getglobal("AuctionUIFrameSelected");
	getglobal(frame:GetName().."Bidder"):SetText("");
	getglobal(frame:GetName().."Bid"):SetText("");
	getglobal(frame:GetName().."Rank"):SetText("");
end


function SOTA_GetHighestBid(bidtype)
	if bidtype and bidtype == 1 then
		-- Find highest MS bid:
		for n=1, table.getn(IncomingBidsTable), 1 do
			if IncomingBidsTable[n][3] == 1 then
				return IncomingBidsTable[n];
			end
		end	
	else
		--	Find highest bid regardless of type.
		--	Note: This might be an MS bid - OS bidders will have to ignore this!
		if table.getn(IncomingBidsTable) > 0 then
			return IncomingBidsTable[1];
		end
	end

	return nil;
end


function SOTA_OnCancelBidClick(object)
	SOTA_CancelSelectedPlayerBid();
end

function SOTA_OnPauseAuctionClick(object)
	SOTA_PauseAuction();
end

function SOTA_OnFinishAuctionClick(object)
	SOTA_FinishAuction();
end

function SOTA_OnRestartAuctionClick(object)
	SOTA_RestartAuction();
end

function SOTA_OnAcceptBidClick(object)
	SOTA_AcceptSelectedPlayerBid();
end

function SOTA_OnCancelAuctionClick(object)
	SOTA_CancelAuction();
end

function SOTA_OnBidClick(object)
	local msgID = object:GetID();
	
	local bidder = getglobal(object:GetName().."Bidder"):GetText();
	if not bidder or bidder == "" then
		return;
	end	
	local bid = 1 * (getglobal(object:GetName().."Bid"):GetText());

	SOTA_ShowSelectedPlayer(bidder, bid);
end


