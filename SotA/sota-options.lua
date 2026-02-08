--[[
--	SotA - State of the Art DKP Addon
--	By Mimma <VanillaGaming.org>
--
--	Unit: sota-options.lua
--	This holds the options (configuration) dialogue of SotA plus
--	underlying functionality to support changing the options.
--]]

local SOTA_MAX_MESSAGES			= 15
local ConfigurationDialogOpen	= false;

-- SOTA_EchoEvent moved to sota-core.lua to ensure it's available when needed

-- Инициализация при загрузке файла
-- Убеждаемся, что функции доступны сразу после загрузки
if not SOTA_getConfigurableMessage then
	-- Функция будет определена ниже, но мы проверяем её доступность
end


function SOTA_GetEventText(eventName)
	if not SOTA_GetConfigurableTextMessages then
		return nil;
	end
	
	local messages = SOTA_GetConfigurableTextMessages();
	
	-- Проверяем, что messages не nil и является таблицей
	if not messages or table.getn(messages) == 0 then
		-- Если сообщения не инициализированы, инициализируем их
		if SOTA_VerifyEventMessages then
			SOTA_VerifyEventMessages();
		end
		if SOTA_GetConfigurableTextMessages then
			messages = SOTA_GetConfigurableTextMessages();
		end
		-- Если все еще nil или пусто, возвращаем nil
		if not messages or table.getn(messages) == 0 then
			return nil;
		end
	end

	for n = 1, table.getn(messages), 1 do
		if(messages[n][1] == eventName) then
			return messages[n];
		end;
	end

	return nil;
end;


--[[
--	Get configurable message and fill out placeholders:
--	Parameters:
--	%i: Item, %d: DKP, %b: Bidder, %r: Rank, $1,$2,$3: params (percent, players in range, players in queue etc)
--	Automatic gathered:
--	%m: Min DKP, %s: SotA master
--]]
function SOTA_getConfigurableMessage(msgKey, item, dkp, bidder, rank, param1, param2, param3)

	local msgInfo = SOTA_GetEventText(msgKey);

	if(not msgInfo) then
		localEcho("*** Oops, SOTA_CONFIG_Messages[".. msgKey .."] was not found");
		return nil;
	end;

	if not(item)	then item = ""; end;
	if not(dkp)		then dkp = ""; end;
	if not(bidder)	then bidder = ""; end;
	if not(rank)	then rank = ""; end;
	if not(param1)	then param1 = ""; end;
	if not(param2)	then param2 = ""; end;
	if not(param3)	then param3 = ""; end;

	local msg = msgInfo[3];
	msg = string.gsub(msg, "$i", ""..item);
	msg = string.gsub(msg, "$d", ""..dkp);
	msg = string.gsub(msg, "$b", ""..bidder);
	msg = string.gsub(msg, "$r", ""..rank);
	
	-- Защита от nil: SOTA_GetMinimumBid может вернуть nil
	local minBid = SOTA_GetMinimumBid();
	if minBid then
		msg = string.gsub(msg, "$m", ""..minBid);
	else
		msg = string.gsub(msg, "$m", "0");
	end
	
	msg = string.gsub(msg, "$s", UnitName("player"));
	msg = string.gsub(msg, "$1", ""..param1);
	msg = string.gsub(msg, "$2", ""..param2);
	msg = string.gsub(msg, "$3", ""..param3);
	
	return { msgInfo[1], msgInfo[2], msg };
end;

function SOTA_SetConfigurableMessage(event, channel, message)
	--echo("Saving new message: Event: "..event..", Channel: "..channel..", Message: "..message);
	if not SOTA_GetConfigurableTextMessages then
		return;
	end
	
	local messages = SOTA_GetConfigurableTextMessages();
	
	-- Проверяем, что messages не nil
	if not messages then
		messages = { };
	end

	for n=1,table.getn(messages),1 do
		if(messages[n][1] == event) then
			messages[n] = { event, channel, message };
			SOTA_SetConfigurableTextMessages(messages);
			return;
		end;
	end;
end;

--[[
--	Copy the updated frame pos to frame siblings.
--	Since: 1.2.0
--]]
function SOTA_UpdateFramePos(frame)
	local framename = frame:GetName();

	if(framename ~= "FrameConfigBidding") then
		FrameConfigBidding:SetAllPoints(frame);
	end
	if(framename ~= "FrameConfigBossDkp") then
		FrameConfigBossDkp:SetAllPoints(frame);
	end
	if(framename ~= "FrameConfigMiscDkp") then
		FrameConfigMiscDkp:SetAllPoints(frame);
	end
	if(framename ~= "FrameConfigMessage") then
		FrameConfigMessage:SetAllPoints(frame);
	end
	if(framename ~= "FrameConfigBidRules") then
		FrameConfigBidRules:SetAllPoints(frame);
	end
	if(framename ~= "FrameConfigSyncCfg") then
		FrameConfigSyncCfg:SetAllPoints(frame);
	end
end;

function SOTA_IsConfigurationDialogOpen()
	return ConfigurationDialogOpen;
end

function SOTA_OpenConfigurationUI()
	-- Убеждаемся, что сообщения инициализированы
	if not SOTA_CONFIG_Messages or (type(SOTA_CONFIG_Messages) == "table" and table.getn(SOTA_CONFIG_Messages) == 0) then
		SOTA_VerifyEventMessages();
	end

	ConfigurationDialogOpen = true;
	SOTA_RefreshBossDKPValues();

	SOTA_OpenBiddingConfig();
end

function SOTA_CloseConfigurationUI()
	SOTA_CloseAllConfig();

	ConfigurationDialogOpen = false;
end

function SOTA_CloseAllConfig()
	FrameConfigBidding:Hide();
	FrameConfigBossDkp:Hide();
	FrameConfigItemDkp:Hide();
	FrameConfigMiscDkp:Hide();
	FrameConfigMessage:Hide();
	FrameConfigBidRules:Hide();
	FrameConfigSyncCfg:Hide();
end;

function SOTA_SaveRules_OnClick()
	SOTA_CONFIG_BIDRULES = SOTA_GetBidRules();
end;

function SOTA_ToggleConfigurationUI()
	if ConfigurationDialogOpen then
		SOTA_CloseConfigurationUI();
	else
		SOTA_OpenConfigurationUI();
	end;
end;

function SOTA_OpenBiddingConfig()
	SOTA_CloseAllConfig();
	FrameConfigBidding:Show();
end

function SOTA_OpenBossDkpConfig()
	SOTA_CloseAllConfig();
	FrameConfigBossDkp:Show();
end

function SOTA_OpenItemDkpConfig()
	SOTA_CloseAllConfig();
	SOTA_RefreshItemDKPValues();
	FrameConfigItemDkp:Show();
end

function SOTA_OpenMiscDkpConfig()
	SOTA_CloseAllConfig();
	FrameConfigMiscDkp:Show();
end

function SOTA_OpenMessageConfig()
	SOTA_CloseAllConfig();
	-- Убеждаемся, что сообщения инициализированы
	SOTA_VerifyEventMessages();
	-- Обновляем список сообщений в UI
	SOTA_UpdateTextList();
	FrameConfigMessage:Show();
end

function SOTA_OpenBidRulesConfig()
	SOTA_SetBidRules();
	SOTA_CloseAllConfig();
	FrameConfigBidRules:Show();
end;

function SOTA_OpenSyncCfgConfig()
	SOTA_CloseAllConfig();
	SOTA_RequestUpdateConfigVersion();
	FrameConfigSyncCfg:Show();
end;

function SOTA_OnOptionAuctionTimeChanged(object)
	local slider = getglobal(object:GetName());
	if not slider then return; end
	
	SOTA_CONFIG_AuctionTime = tonumber(slider:GetValue()) or 20;
	
	local valueString = "".. SOTA_CONFIG_AuctionTime;
	if SOTA_CONFIG_AuctionTime == 0 then
		valueString = "(Без таймера)";
	end
	
	local textFrame = getglobal(object:GetName().."Text");
	if textFrame then
		textFrame:SetText(string.format("Время аукциона: %s сек", valueString));
	end
end

function SOTA_OnOptionAuctionExtensionChanged(object)
	local slider = getglobal(object:GetName());
	if not slider then return; end
	
	SOTA_CONFIG_AuctionExtension = tonumber(slider:GetValue()) or 8;
	
	local valueString = "".. SOTA_CONFIG_AuctionExtension;
	if SOTA_CONFIG_AuctionExtension == 0 then
		valueString = "(Без продления)";
	end
	
	local textFrame = getglobal(object:GetName().."Text");
	if textFrame then
		textFrame:SetText(string.format("Продление аукциона: %s сек", valueString));
	end
end

function SOTA_OnOptionDKPStringLengthChanged(object)
	local slider = getglobal(object:GetName());
	if not slider then return; end
	
	SOTA_CONFIG_DKPStringLength = tonumber(slider:GetValue()) or 5;
	
	local valueString = "".. SOTA_CONFIG_DKPStringLength;
	if SOTA_CONFIG_DKPStringLength == 0 then
		valueString = "(No limit)";
	end
	
	local textFrame = getglobal(object:GetName().."Text");
	if textFrame then
		textFrame:SetText(string.format("Длина строки DKP: %s", valueString));
	end
end

function SOTA_OnOptionMinimumDKPPenaltyChanged(object)
	local slider = getglobal(object:GetName());
	if not slider then return; end
	
	SOTA_CONFIG_MinimumDKPPenalty = tonumber(slider:GetValue()) or 50;
	
	local valueString = "".. SOTA_CONFIG_MinimumDKPPenalty;
	if SOTA_CONFIG_MinimumDKPPenalty == 0 then
		valueString = "(None)";
	end
	
	local textFrame = getglobal(object:GetName().."Text");
	if textFrame then
		textFrame:SetText(string.format("Минимальный штраф DKP: %s", valueString));
	end
end

function SOTA_RefreshBossDKPValues()
	local frame;
	local value;
	local valueString;
	local textFrame;
	
	frame = getglobal("FrameConfigBossDkp_20Mans");
	if frame then 
		value = SOTA_GetBossDKPValue("20Mans");
		frame:SetValue(value);
		valueString = string.format("20 mans (ZG, AQ20): %d DKP", value);
		textFrame = getglobal("FrameConfigBossDkp_20MansText");
		if textFrame then textFrame:SetText(valueString); end
	end
	frame = getglobal("FrameConfigBossDkp_MoltenCore");
	if frame then 
		value = SOTA_GetBossDKPValue("MoltenCore");
		frame:SetValue(value);
		valueString = string.format("Molten Core: %d DKP", value);
		textFrame = getglobal("FrameConfigBossDkp_MoltenCoreText");
		if textFrame then textFrame:SetText(valueString); end
	end
	frame = getglobal("FrameConfigBossDkp_Onyxia");
	if frame then 
		value = SOTA_GetBossDKPValue("Onyxia");
		frame:SetValue(value);
		valueString = string.format("Onyxia: %d DKP", value);
		textFrame = getglobal("FrameConfigBossDkp_OnyxiaText");
		if textFrame then textFrame:SetText(valueString); end
	end
	frame = getglobal("FrameConfigBossDkp_BlackwingLair");
	if frame then 
		value = SOTA_GetBossDKPValue("BlackwingLair");
		frame:SetValue(value);
		valueString = string.format("Blackwing Lair: %d DKP", value);
		textFrame = getglobal("FrameConfigBossDkp_BlackwingLairText");
		if textFrame then textFrame:SetText(valueString); end
	end
	frame = getglobal("FrameConfigBossDkp_AQ40");
	if frame then 
		value = SOTA_GetBossDKPValue("AQ40");
		frame:SetValue(value);
		valueString = string.format("Temple of Ahn'Qiraj: %d DKP", value);
		textFrame = getglobal("FrameConfigBossDkp_AQ40Text");
		if textFrame then textFrame:SetText(valueString); end
	end
	frame = getglobal("FrameConfigBossDkp_Naxxramas");
	if frame then 
		value = SOTA_GetBossDKPValue("Naxxramas");
		frame:SetValue(value);
		valueString = string.format("Naxxramas: %d DKP", value);
		textFrame = getglobal("FrameConfigBossDkp_NaxxramasText");
		if textFrame then textFrame:SetText(valueString); end
	end
	frame = getglobal("FrameConfigBossDkp_UpperKarazhan");
	if frame then 
		value = SOTA_GetBossDKPValue("UpperKarazhan");
		frame:SetValue(value);
		valueString = string.format("Upper Karazhan: %d DKP", value);
		textFrame = getglobal("FrameConfigBossDkp_UpperKarazhanText");
		if textFrame then textFrame:SetText(valueString); end
	end
	frame = getglobal("FrameConfigBossDkp_WorldBosses");
	if frame then 
		value = SOTA_GetBossDKPValue("WorldBosses");
		frame:SetValue(value);
		valueString = string.format("World Bosses: %d DKP", value);
		textFrame = getglobal("FrameConfigBossDkp_WorldBossesText");
		if textFrame then textFrame:SetText(valueString); end
	end
end

function SOTA_RefreshItemDKPValues()
	local itemList = SOTA_GetItemDKPList();
	if not itemList or table.getn(itemList) == 0 then
		return;
	end
	
	local frame;
	-- Убийство босса (из Boss DKP) - используем функцию для безопасного получения значений
	frame = getglobal("FrameConfigItemDkp_Kill_BWL");
	if frame then frame:SetText(SOTA_GetBossDKPValue("BlackwingLair") or 200); end
	frame = getglobal("FrameConfigItemDkp_Kill_AQ40");
	if frame then frame:SetText(SOTA_GetBossDKPValue("AQ40") or 300); end
	frame = getglobal("FrameConfigItemDkp_Kill_NAXX");
	if frame then frame:SetText(SOTA_GetBossDKPValue("Naxxramas") or 100); end
	frame = getglobal("FrameConfigItemDkp_Kill_KARA");
	if frame then frame:SetText(SOTA_GetBossDKPValue("UpperKarazhan") or 400); end
	
	-- Одежда
	if itemList[1] then
		frame = getglobal("FrameConfigItemDkp_Cloth_BWL");
		if frame then frame:SetText(itemList[1][2] or 200); end
		frame = getglobal("FrameConfigItemDkp_Cloth_AQ40");
		if frame then frame:SetText(itemList[1][3] or 400); end
		frame = getglobal("FrameConfigItemDkp_Cloth_NAXX");
		if frame then frame:SetText(itemList[1][4] or 100); end
		frame = getglobal("FrameConfigItemDkp_Cloth_KARA");
		if frame then frame:SetText(itemList[1][5] or 400); end
	end
	
	-- Пушка
	if itemList[2] then
		frame = getglobal("FrameConfigItemDkp_Gun_BWL");
		if frame then frame:SetText(itemList[2][2] or 500); end
		frame = getglobal("FrameConfigItemDkp_Gun_AQ40");
		if frame then frame:SetText(itemList[2][3] or 500); end
		frame = getglobal("FrameConfigItemDkp_Gun_NAXX");
		if frame then frame:SetText(itemList[2][4] or 300); end
		frame = getglobal("FrameConfigItemDkp_Gun_KARA");
		if frame then frame:SetText(itemList[2][5] or 500); end
	end
	
	-- Ванда
	if itemList[3] then
		frame = getglobal("FrameConfigItemDkp_Wand_BWL");
		if frame then frame:SetText(itemList[3][2] or 500); end
		frame = getglobal("FrameConfigItemDkp_Wand_AQ40");
		if frame then frame:SetText(itemList[3][3] or 500); end
		frame = getglobal("FrameConfigItemDkp_Wand_NAXX");
		if frame then frame:SetText(itemList[3][4] or 300); end
		frame = getglobal("FrameConfigItemDkp_Wand_KARA");
		if frame then frame:SetText(itemList[3][5] or 500); end
	end
	
	-- Кольца
	if itemList[4] then
		frame = getglobal("FrameConfigItemDkp_Ring_BWL");
		if frame then frame:SetText(itemList[4][2] or 500); end
		frame = getglobal("FrameConfigItemDkp_Ring_AQ40");
		if frame then frame:SetText(itemList[4][3] or 900); end
		frame = getglobal("FrameConfigItemDkp_Ring_NAXX");
		if frame then frame:SetText(itemList[4][4] or 500); end
		frame = getglobal("FrameConfigItemDkp_Ring_KARA");
		if frame then frame:SetText(itemList[4][5] or 900); end
	end
	
	-- Тринкет
	if itemList[5] then
		frame = getglobal("FrameConfigItemDkp_Trinket_BWL");
		if frame then frame:SetText(itemList[5][2] or 300); end
		frame = getglobal("FrameConfigItemDkp_Trinket_AQ40");
		if frame then frame:SetText(itemList[5][3] or 500); end
		frame = getglobal("FrameConfigItemDkp_Trinket_NAXX");
		if frame then frame:SetText(itemList[5][4] or 300); end
		frame = getglobal("FrameConfigItemDkp_Trinket_KARA");
		if frame then frame:SetText(itemList[5][5] or 500); end
	end
	
	-- Прочее
	if itemList[6] then
		frame = getglobal("FrameConfigItemDkp_Other_BWL");
		if frame then frame:SetText(itemList[6][2] or 200); end
		frame = getglobal("FrameConfigItemDkp_Other_AQ40");
		if frame then frame:SetText(itemList[6][3] or 500); end
		frame = getglobal("FrameConfigItemDkp_Other_NAXX");
		if frame then frame:SetText(itemList[6][4] or 500); end
		frame = getglobal("FrameConfigItemDkp_Other_KARA");
		if frame then frame:SetText(itemList[6][5] or 500); end
	end
end

function SOTA_SaveItemDKPValues()
	-- Сохраняем значения из EditBox'ов в конфиг
	if not SOTA_GetItemDKPList or not SOTA_SetBossDKPValue then
		return;
	end
	
	local itemList = SOTA_GetItemDKPList();
	if not itemList or table.getn(itemList) == 0 then
		return;
	end
	
	local frame;
	local value;
	
	-- Убийство босса (сохраняем в Boss DKP)
	frame = getglobal("FrameConfigItemDkp_Kill_BWL");
	if frame then
		value = tonumber(frame:GetText());
		if value then SOTA_SetBossDKPValue("BlackwingLair", value); end
	end
	frame = getglobal("FrameConfigItemDkp_Kill_AQ40");
	if frame then
		value = tonumber(frame:GetText());
		if value then SOTA_SetBossDKPValue("AQ40", value); end
	end
	frame = getglobal("FrameConfigItemDkp_Kill_NAXX");
	if frame then
		value = tonumber(frame:GetText());
		if value then SOTA_SetBossDKPValue("Naxxramas", value); end
	end
	frame = getglobal("FrameConfigItemDkp_Kill_KARA");
	if frame then
		value = tonumber(frame:GetText());
		if value then SOTA_SetBossDKPValue("UpperKarazhan", value); end
	end
	
	-- Одежда
	if itemList[1] then
		frame = getglobal("FrameConfigItemDkp_Cloth_BWL");
		if frame then itemList[1][2] = tonumber(frame:GetText()) or 200; end
		frame = getglobal("FrameConfigItemDkp_Cloth_AQ40");
		if frame then itemList[1][3] = tonumber(frame:GetText()) or 400; end
		frame = getglobal("FrameConfigItemDkp_Cloth_NAXX");
		if frame then itemList[1][4] = tonumber(frame:GetText()) or 100; end
		frame = getglobal("FrameConfigItemDkp_Cloth_KARA");
		if frame then itemList[1][5] = tonumber(frame:GetText()) or 400; end
	end
	
	-- Пушка
	if itemList[2] then
		frame = getglobal("FrameConfigItemDkp_Gun_BWL");
		if frame then itemList[2][2] = tonumber(frame:GetText()) or 500; end
		frame = getglobal("FrameConfigItemDkp_Gun_AQ40");
		if frame then itemList[2][3] = tonumber(frame:GetText()) or 500; end
		frame = getglobal("FrameConfigItemDkp_Gun_NAXX");
		if frame then itemList[2][4] = tonumber(frame:GetText()) or 300; end
		frame = getglobal("FrameConfigItemDkp_Gun_KARA");
		if frame then itemList[2][5] = tonumber(frame:GetText()) or 500; end
	end
	
	-- Ванда
	if itemList[3] then
		frame = getglobal("FrameConfigItemDkp_Wand_BWL");
		if frame then itemList[3][2] = tonumber(frame:GetText()) or 500; end
		frame = getglobal("FrameConfigItemDkp_Wand_AQ40");
		if frame then itemList[3][3] = tonumber(frame:GetText()) or 500; end
		frame = getglobal("FrameConfigItemDkp_Wand_NAXX");
		if frame then itemList[3][4] = tonumber(frame:GetText()) or 300; end
		frame = getglobal("FrameConfigItemDkp_Wand_KARA");
		if frame then itemList[3][5] = tonumber(frame:GetText()) or 500; end
	end
	
	-- Кольца
	if itemList[4] then
		frame = getglobal("FrameConfigItemDkp_Ring_BWL");
		if frame then itemList[4][2] = tonumber(frame:GetText()) or 500; end
		frame = getglobal("FrameConfigItemDkp_Ring_AQ40");
		if frame then itemList[4][3] = tonumber(frame:GetText()) or 900; end
		frame = getglobal("FrameConfigItemDkp_Ring_NAXX");
		if frame then itemList[4][4] = tonumber(frame:GetText()) or 500; end
		frame = getglobal("FrameConfigItemDkp_Ring_KARA");
		if frame then itemList[4][5] = tonumber(frame:GetText()) or 900; end
	end
	
	-- Тринкет
	if itemList[5] then
		frame = getglobal("FrameConfigItemDkp_Trinket_BWL");
		if frame then itemList[5][2] = tonumber(frame:GetText()) or 300; end
		frame = getglobal("FrameConfigItemDkp_Trinket_AQ40");
		if frame then itemList[5][3] = tonumber(frame:GetText()) or 500; end
		frame = getglobal("FrameConfigItemDkp_Trinket_NAXX");
		if frame then itemList[5][4] = tonumber(frame:GetText()) or 300; end
		frame = getglobal("FrameConfigItemDkp_Trinket_KARA");
		if frame then itemList[5][5] = tonumber(frame:GetText()) or 500; end
	end
	
	-- Прочее
	if itemList[6] then
		frame = getglobal("FrameConfigItemDkp_Other_BWL");
		if frame then itemList[6][2] = tonumber(frame:GetText()) or 200; end
		frame = getglobal("FrameConfigItemDkp_Other_AQ40");
		if frame then itemList[6][3] = tonumber(frame:GetText()) or 500; end
		frame = getglobal("FrameConfigItemDkp_Other_NAXX");
		if frame then itemList[6][4] = tonumber(frame:GetText()) or 500; end
		frame = getglobal("FrameConfigItemDkp_Other_KARA");
		if frame then itemList[6][5] = tonumber(frame:GetText()) or 500; end
	end
	
	SOTA_CONFIG_ItemDKP = itemList;
	localEcho("Item DKP настройки сохранены!");
end

function SOTA_OnOptionBossDKPChanged(object)
	local sliderName = object:GetName();
	local slider = getglobal(sliderName);
	if not slider then return; end
	
	local value = tonumber(slider:GetValue());
	if not value then return; end
	
	local valueString = "";
	
	if not SOTA_SetBossDKPValue then
		return;
	end
	
	if sliderName == "FrameConfigBossDkp_20Mans" then
		SOTA_SetBossDKPValue("20Mans", value);
		valueString = string.format("20 mans (ZG, AQ20): %d DKP", value);
	elseif sliderName == "FrameConfigBossDkp_MoltenCore" then
		SOTA_SetBossDKPValue("MoltenCore", value);
		valueString = string.format("Molten Core: %d DKP", value);
	elseif sliderName == "FrameConfigBossDkp_Onyxia" then
		SOTA_SetBossDKPValue("Onyxia", value);
		valueString = string.format("Onyxia: %d DKP", value);
	elseif sliderName == "FrameConfigBossDkp_BlackwingLair" then
		SOTA_SetBossDKPValue("BlackwingLair", value);
		valueString = string.format("Blackwing Lair: %d DKP", value);
	elseif sliderName == "FrameConfigBossDkp_AQ40" then
		SOTA_SetBossDKPValue("AQ40", value);
		valueString = string.format("Temple of Ahn'Qiraj: %d DKP", value);
	elseif sliderName == "FrameConfigBossDkp_Naxxramas" then
		SOTA_SetBossDKPValue("Naxxramas", value);
		valueString = string.format("Naxxramas: %d DKP", value);
	elseif sliderName == "FrameConfigBossDkp_UpperKarazhan" then
		SOTA_SetBossDKPValue("UpperKarazhan", value);
		valueString = string.format("Upper Karazhan: %d DKP", value);
	elseif sliderName == "FrameConfigBossDkp_WorldBosses" then
		SOTA_SetBossDKPValue("WorldBosses", value);
		valueString = string.format("World Bosses: %d DKP", value);
	end

	local textFrame = getglobal(sliderName.."Text");
	if textFrame then
		textFrame:SetText(valueString);
	end
end

function SOTA_InitializeConfigSettings()
	-- ЛОГИКА: Переменные уже инициализированы в sota-core.lua с дефолтными значениями
	-- WoW загружает SavedVariables ПЕРЕД вызовом этой функции
	-- Если переменная была загружена из SavedVariables - она имеет значение (даже если 0)
	-- Если переменная НЕ была загружена - она остается с дефолтным значением из sota-core.lua
	-- Поэтому здесь мы проверяем только те переменные, которые могут быть nil:
	-- Используем == nil, а не "if not", чтобы не перезаписывать сохраненные 0 значения
	
	local loadedFromSaved = 0;
	local createdDefaults = 0;
	local savedVarsStatus = {};
	
	-- Pane 3: Misc DKP - проверяем на nil (если не загружено из SavedVariables)
	if SOTA_CONFIG_UseGuildNotes == nil then
		SOTA_CONFIG_UseGuildNotes = 0;
		createdDefaults = createdDefaults + 1;
		savedVarsStatus["SOTA_CONFIG_UseGuildNotes"] = "создано по умолчанию";
	else
		loadedFromSaved = loadedFromSaved + 1;
		savedVarsStatus["SOTA_CONFIG_UseGuildNotes"] = "загружено из SavedVariables";
	end
	if SOTA_CONFIG_MinimumBidStrategy == nil then
		SOTA_CONFIG_MinimumBidStrategy = 1;  -- По умолчанию: Минимальное увеличение на 100 ДКП
		createdDefaults = createdDefaults + 1;
		savedVarsStatus["SOTA_CONFIG_MinimumBidStrategy"] = "создано по умолчанию";
	else
		loadedFromSaved = loadedFromSaved + 1;
		savedVarsStatus["SOTA_CONFIG_MinimumBidStrategy"] = "загружено из SavedVariables";
	end
	if SOTA_CONFIG_DKPStringLength == nil then
		SOTA_CONFIG_DKPStringLength = 5;
		createdDefaults = createdDefaults + 1;
		savedVarsStatus["SOTA_CONFIG_DKPStringLength"] = "создано по умолчанию";
	else
		loadedFromSaved = loadedFromSaved + 1;
		savedVarsStatus["SOTA_CONFIG_DKPStringLength"] = "загружено из SavedVariables";
	end
	if SOTA_CONFIG_MinimumDKPPenalty == nil then
		SOTA_CONFIG_MinimumDKPPenalty = 50;
		createdDefaults = createdDefaults + 1;
		savedVarsStatus["SOTA_CONFIG_MinimumDKPPenalty"] = "создано по умолчанию";
	else
		loadedFromSaved = loadedFromSaved + 1;
		savedVarsStatus["SOTA_CONFIG_MinimumDKPPenalty"] = "загружено из SavedVariables";
	end

	-- Pane 1: Основные настройки - проверяем на nil
	-- Эти переменные уже инициализированы в sota-core.lua, но проверяем на всякий случай
	if SOTA_CONFIG_EnableOSBidding == nil then
		SOTA_CONFIG_EnableOSBidding = 1;
		createdDefaults = createdDefaults + 1;
		savedVarsStatus["SOTA_CONFIG_EnableOSBidding"] = "создано по умолчанию";
	else
		loadedFromSaved = loadedFromSaved + 1;
		savedVarsStatus["SOTA_CONFIG_EnableOSBidding"] = "загружено из SavedVariables";
	end
	if SOTA_CONFIG_EnableZoneCheck == nil then
		SOTA_CONFIG_EnableZoneCheck = 1;
		createdDefaults = createdDefaults + 1;
		savedVarsStatus["SOTA_CONFIG_EnableZoneCheck"] = "создано по умолчанию";
	else
		loadedFromSaved = loadedFromSaved + 1;
		savedVarsStatus["SOTA_CONFIG_EnableZoneCheck"] = "загружено из SavedVariables";
	end
	if SOTA_CONFIG_EnableOnlineCheck == nil then
		SOTA_CONFIG_EnableOnlineCheck = 1;
		createdDefaults = createdDefaults + 1;
		savedVarsStatus["SOTA_CONFIG_EnableOnlineCheck"] = "создано по умолчанию";
	else
		loadedFromSaved = loadedFromSaved + 1;
		savedVarsStatus["SOTA_CONFIG_EnableOnlineCheck"] = "загружено из SavedVariables";
	end
	if SOTA_CONFIG_AllowPlayerPass == nil then
		SOTA_CONFIG_AllowPlayerPass = 0;
		createdDefaults = createdDefaults + 1;
		savedVarsStatus["SOTA_CONFIG_AllowPlayerPass"] = "создано по умолчанию";
	else
		loadedFromSaved = loadedFromSaved + 1;
		savedVarsStatus["SOTA_CONFIG_AllowPlayerPass"] = "загружено из SavedVariables";
	end
	if SOTA_CONFIG_DisableDashboard == nil then
		SOTA_CONFIG_DisableDashboard = 0;  -- Исправлено: должно быть 0, а не 1
		createdDefaults = createdDefaults + 1;
		savedVarsStatus["SOTA_CONFIG_DisableDashboard"] = "создано по умолчанию";
	else
		loadedFromSaved = loadedFromSaved + 1;
		savedVarsStatus["SOTA_CONFIG_DisableDashboard"] = "загружено из SavedVariables";
	end
	if SOTA_CONFIG_OutputChannel == nil then
		SOTA_CONFIG_OutputChannel = WARN_CHANNEL;
		createdDefaults = createdDefaults + 1;
		savedVarsStatus["SOTA_CONFIG_OutputChannel"] = "создано по умолчанию";
	else
		loadedFromSaved = loadedFromSaved + 1;
		savedVarsStatus["SOTA_CONFIG_OutputChannel"] = "загружено из SavedVariables";
	end
	if SOTA_CONFIG_Messages == nil then
		SOTA_CONFIG_Messages = { };
		createdDefaults = createdDefaults + 1;
		savedVarsStatus["SOTA_CONFIG_Messages"] = "создано по умолчанию";
	else
		loadedFromSaved = loadedFromSaved + 1;
		savedVarsStatus["SOTA_CONFIG_Messages"] = "загружено из SavedVariables";
	end
	if SOTA_HISTORY_DKP == nil then
		SOTA_HISTORY_DKP = { };
		createdDefaults = createdDefaults + 1;
		savedVarsStatus["SOTA_HISTORY_DKP"] = "создано по умолчанию";
	else
		loadedFromSaved = loadedFromSaved + 1;
		savedVarsStatus["SOTA_HISTORY_DKP"] = "загружено из SavedVariables";
	end
	
	-- Проверяем AuctionTime и AuctionExtension (из SOTA.toc)
	-- Эти переменные инициализированы в sota-core.lua, поэтому они не будут nil
	-- WoW загружает SavedVariables ПЕРЕД выполнением кода, поэтому если они были сохранены,
	-- они будут иметь сохраненное значение, иначе - дефолтное из sota-core.lua
	-- Мы не можем точно определить, были ли они загружены, поэтому считаем их загруженными
	-- (это нормально, так как они всегда имеют значение)
	loadedFromSaved = loadedFromSaved + 1;
	savedVarsStatus["SOTA_CONFIG_AuctionTime"] = "инициализировано (дефолт или из SavedVariables)";
	loadedFromSaved = loadedFromSaved + 1;
	savedVarsStatus["SOTA_CONFIG_AuctionExtension"] = "инициализировано (дефолт или из SavedVariables)";
	
	-- Проверяем VersionNumber и VersionDate (из SOTA.toc)
	if SOTA_CONFIG_VersionNumber == nil then
		SOTA_CONFIG_VersionNumber = nil;  -- Может быть nil
		createdDefaults = createdDefaults + 1;
		savedVarsStatus["SOTA_CONFIG_VersionNumber"] = "создано по умолчанию (nil)";
	else
		loadedFromSaved = loadedFromSaved + 1;
		savedVarsStatus["SOTA_CONFIG_VersionNumber"] = "загружено из SavedVariables";
	end
	if SOTA_CONFIG_VersionDate == nil then
		SOTA_CONFIG_VersionDate = nil;  -- Может быть nil
		createdDefaults = createdDefaults + 1;
		savedVarsStatus["SOTA_CONFIG_VersionDate"] = "создано по умолчанию (nil)";
	else
		loadedFromSaved = loadedFromSaved + 1;
		savedVarsStatus["SOTA_CONFIG_VersionDate"] = "загружено из SavedVariables";
	end
	
	-- Проверяем таблицы BossDKP и ItemDKP
	local bossDkpLoaded = false;
	if SOTA_CONFIG_BossDKP and type(SOTA_CONFIG_BossDKP) == "table" and table.getn(SOTA_CONFIG_BossDKP) > 0 then
		bossDkpLoaded = true;
		loadedFromSaved = loadedFromSaved + 1;
		savedVarsStatus["SOTA_CONFIG_BossDKP"] = "загружено из SavedVariables";
	else
		createdDefaults = createdDefaults + 1;
		savedVarsStatus["SOTA_CONFIG_BossDKP"] = "создано по умолчанию";
	end
	
	local itemDkpLoaded = false;
	if SOTA_CONFIG_ItemDKP and type(SOTA_CONFIG_ItemDKP) == "table" and table.getn(SOTA_CONFIG_ItemDKP) > 0 then
		itemDkpLoaded = true;
		loadedFromSaved = loadedFromSaved + 1;
		savedVarsStatus["SOTA_CONFIG_ItemDKP"] = "загружено из SavedVariables";
	else
		createdDefaults = createdDefaults + 1;
		savedVarsStatus["SOTA_CONFIG_ItemDKP"] = "создано по умолчанию";
	end
	
	-- Инициализируем Boss DKP дефолтными значениями, если таблица пустая или не существует
	SOTA_GetBossDKPList();  -- Это применит дефолтные значения, если таблица пустая
	
	-- Инициализируем Item DKP дефолтными значениями, если таблица пустая или не существует
	SOTA_GetItemDKPList();  -- Это применит дефолтные значения, если таблица пустая
	
	-- Инициализируем сообщения дефолтными значениями, если таблица пустая или не существует
	SOTA_VerifyEventMessages();  -- Это заполнит дефолтными сообщениями, если таблица пустая

	
	local frame;
	frame = getglobal("FrameConfigBiddingMSoverOSPriority");
	if frame then frame:SetChecked(SOTA_CONFIG_EnableOSBidding); end
	frame = getglobal("FrameConfigBiddingEnableZonecheck");
	if frame then frame:SetChecked(SOTA_CONFIG_EnableZoneCheck); end
	frame = getglobal("FrameConfigBiddingEnableOnlinecheck");
	if frame then frame:SetChecked(SOTA_CONFIG_EnableOnlineCheck); end
	frame = getglobal("FrameConfigBiddingAllowPlayerPass");
	if frame then frame:SetChecked(SOTA_CONFIG_AllowPlayerPass); end
	frame = getglobal("FrameConfigBiddingDisableDashboard");
	if frame then frame:SetChecked(SOTA_CONFIG_DisableDashboard); end

	if SOTA_CONFIG_UseGuildNotes == 1 then
		frame = getglobal("FrameConfigMiscDkpPublicNotes");
		if frame then frame:SetChecked(1); end
	end

	frame = getglobal("FrameConfigMiscDkpMinBidStrategy".. SOTA_CONFIG_MinimumBidStrategy);
	if frame then frame:SetChecked(1); end
	frame = getglobal("FrameConfigMiscDkpDKPStringLength");
	if frame then frame:SetValue(SOTA_CONFIG_DKPStringLength); end
	frame = getglobal("FrameConfigMiscDkpMinimumDKPPenalty");
	if frame then frame:SetValue(SOTA_CONFIG_MinimumDKPPenalty); end
	frame = getglobal("FrameConfigBiddingAuctionTime");
	if frame then frame:SetValue(SOTA_CONFIG_AuctionTime); end
	frame = getglobal("FrameConfigBiddingAuctionExtension");
	if frame then frame:SetValue(SOTA_CONFIG_AuctionExtension); end
	
	SOTA_RefreshBossDKPValues();

	SOTA_VerifyEventMessages();
	
	--[[ Отладочные сообщения о загрузке настроек
	-- Выводим диагностическую информацию
	echo(SOTA_COLOUR_CHAT .. "========================================");
	localEcho(string.format("Настройки загружены. Загружено из SavedVariables: %d, создано по умолчанию: %d", loadedFromSaved, createdDefaults));
	echo(SOTA_COLOUR_CHAT .. "========================================");
	
	-- Если много переменных создано по умолчанию, предупреждаем о возможной проблеме
	if createdDefaults > 8 then
		localEcho("SOTA: ВНИМАНИЕ! Большинство настроек создано по умолчанию. Возможные причины:");
		localEcho("  1. Проверьте файл SOTA.toc - список ## SavedVariables должен быть правильным");
		localEcho("  2. Проверьте файл SOTA.lua в папке WTF\\Account\\<ваш_аккаунт>\\SavedVariables\\");
		localEcho("  3. Убедитесь, что в SOTA.toc нет опечаток в именах переменных (проверьте запятые)");
		localEcho("  4. Если файл SOTA.lua существует, проверьте его синтаксис на ошибки");
		localEcho("  5. Убедитесь, что имена переменных в SOTA.toc точно совпадают с именами в коде");
		localEcho("SOTA: Детали инициализации переменных (созданные по умолчанию):");
		for varName, status in pairs(savedVarsStatus) do
			if string.find(status, "создано по умолчанию") then
				localEcho(string.format("  - %s: %s", varName, status));
			end
		end
	elseif createdDefaults > 0 then
		localEcho("SOTA: Некоторые настройки созданы по умолчанию (это нормально при первом запуске):");
		for varName, status in pairs(savedVarsStatus) do
			if string.find(status, "создано по умолчанию") then
				localEcho(string.format("  - %s", varName));
			end
		end
	end
	--]]
end


function SOTA_VerifyEventMessages()

	-- Syntax: [index] = { EVENT_NAME, CHANNEL, TEXT }
	-- Channel value: 0: Off, 1: RW, 2: Raid, 3: Guild, 4: Yell, 5: Say
	local defaultMessages = { 
		{ SOTA_MSG_OnOpen					, 1, "Начинается аукцион на $i. Минимальная ставка: $d ДКП." },
		{ SOTA_MSG_OnAnnounceBid			, 2, "Для совершения ставки по МС напишите /w $s bid <ваша ставка>" },
		{ SOTA_MSG_OnAnnounceMinBid			, 2, "Для совершения ставки по ОС напишите /w $s os <ваша ставка>" },
		{ SOTA_MSG_ExtraInfo				, 2, "Если есть ставка на МС, ставка на ОС не будет принята. Шаг ставки 100 ДКП" },
		{ SOTA_MSG_On10SecondsLeft			, 0, "Осталось 10 секунд для ставок на $i" },
		{ SOTA_MSG_On9SecondsLeft			, 0, "9" },
		{ SOTA_MSG_On8SecondsLeft			, 0, "8" },
		{ SOTA_MSG_On7SecondsLeft			, 0, "7" },
		{ SOTA_MSG_On6SecondsLeft			, 0, "6" },
		{ SOTA_MSG_On5SecondsLeft			, 0, "5" },
		{ SOTA_MSG_On4SecondsLeft			, 0, "4" },
		{ SOTA_MSG_On3SecondsLeft			, 0, "3" },
		{ SOTA_MSG_On2SecondsLeft			, 0, "2" },
		{ SOTA_MSG_On1SecondLeft			, 0, "1" },
		{ SOTA_MSG_OnMainspecBid			, 1, "$b поставил $d ДКП" },
		{ SOTA_MSG_OnOffspecBid				, 1, "$b поставил $d ДКП на офф-спек" },
		{ SOTA_MSG_OnMainspecMaxBid			, 1, "$b поставил $d ДКП на $i! Квартира залита!" },
		{ SOTA_MSG_OnOffspecMaxBid			, 1, "$b поставил $d ДКП на $i по офф-спеку! Квартира залита!" },
		{ SOTA_MSG_OnComplete				, 2, "$b выиграл аукцион на $i за $d ДКП. Легенда!" },
		{ SOTA_MSG_OnPause					, 2, "Аукцион на $i приостановлен" },
		{ SOTA_MSG_OnResume					, 2, "Аукцион на $i возобновлен" },
		{ SOTA_MSG_OnClose					, 1, "Аукцион на $i завершен" },
		{ SOTA_MSG_OnBidCancel				, 1, "Ставка $b была отменена, наивысшая ставка теперь $m" },
		{ SOTA_MSG_OnCancel					, 1, "Аукцион на $i был отменен" },
		{ SOTA_MSG_OnDKPAdded				, 1, "$d ДКП было добавлено $b" },
		{ SOTA_MSG_OnDKPAddedRaid			, 1, "$d ДКП было добавлено всем участникам рейда за убийство $1" },
		{ SOTA_MSG_OnDKPAddedRaidAttendance	, 1, "$d ДКП было добавлено всем участникам рейда за приход в $1. ГОЙДА!" },
		{ SOTA_MSG_OnDKPAddedRaidNoWipes	, 1, "$d ДКП было добавлено всем участникам рейда за завершение рейда без вайпов. Лучшие" },
		{ SOTA_MSG_OnDKPAddedRange			, 1, "$d ДКП было добавлено $1 игрокам в радиусе." },
		{ SOTA_MSG_OnDKPAddedQueue			, 1, "$d ДКП было добавлено $1 игрокам в радиусе (включая $2 в очереди)." },
		{ SOTA_MSG_OnDKPSubtract			, 1, "$d ДКП было снято с $b" },
		{ SOTA_MSG_OnDKPSubtractRaid		, 1, "$d ДКП было снято всем участникам рейда" },
		{ SOTA_MSG_OnDKPPercent				, 1, "$1 % ($d ДКП) было снято с $b" },
		{ SOTA_MSG_OnDKPShared				, 1, "$1 ДКП было распределено ($d ДКП на игрока)" },
		{ SOTA_MSG_OnDKPSharedQueue 		, 1, "$1 ДКП было распределено ($d ДКП на игрока плюс $2 в очереди)" },
		{ SOTA_MSG_OnDKPSharedRange 		, 1, "$1 ДКП было распределено между $2 игроками в радиусе ($d ДКП на игрока)" },
		{ SOTA_MSG_OnDKPSharedRangeQ		, 1, "$1 ДКП было распределено между $2 игроками в радиусе ($d ДКП на игрока, включая $3 в очереди)" },
		{ SOTA_MSG_OnDKPReplaced			, 1, "$1 был заменен на $2 ($d ДКП)" }
	}

	-- Merge default messages into saved messages; in case we added some new event names.
	if not SOTA_GetConfigurableTextMessages then
		return;
	end
	
	local messages = SOTA_GetConfigurableTextMessages();
	-- Если messages nil или пустая таблица - устанавливаем дефолтные значения
	if not messages or table.getn(messages) == 0 then
		-- Клонируем дефолтные сообщения
		local clonedMessages = { };
		for n=1, table.getn(defaultMessages), 1 do
			clonedMessages[n] = { defaultMessages[n][1], defaultMessages[n][2], defaultMessages[n][3] };
		end
		SOTA_SetConfigurableTextMessages(clonedMessages);
		return;
	end;

	--echo("--- Merging messages");
	for n=1,table.getn(defaultMessages), 1 do
		local foundMessage = false;
		for f=1,table.getn(messages), 1 do
			if(messages[f][1] == defaultMessages[n][1]) then
				foundMessage = true;
--				echo("Found msg: ".. messages[f][1]);
				break;
			end;
		end;

		if(not foundMessage) then
--			echo("Adding message: ".. defaultMessages[n][1]);
			messages[table.getn(messages)+1] = defaultMessages[n];
		end;
	end

	SOTA_SetConfigurableTextMessages(messages);
end;


function SOTA_HandleCheckbox(checkbox)
	local checkboxname = checkbox:GetName();

	--	Enable MS>OS priority:		
	if checkboxname == "FrameConfigBiddingMSoverOSPriority" then
		if checkbox:GetChecked() then
			SOTA_CONFIG_EnableOSBidding = 1;
		else
			SOTA_CONFIG_EnableOSBidding = 0;
		end
		return;
	end
		
	--	Enable RQ Zonecheck:		
	if checkboxname == "FrameConfigBiddingEnableZonecheck" then
		if checkbox:GetChecked() then
			SOTA_CONFIG_EnableZoneCheck = 1;
		else
			SOTA_CONFIG_EnableZoneCheck = 0;
		end
		return;
	end

	--	Enable RQ Onlinecheck:		
	if checkboxname == "FrameConfigBiddingEnableOnlinecheck" then
		if checkbox:GetChecked() then
			SOTA_CONFIG_EnableOnlineCheck = 1;
		else
			SOTA_CONFIG_EnableOnlineCheck = 0;
		end
		return;
	end

	--	Allow Player Pass:
	if checkboxname == "FrameConfigBiddingAllowPlayerPass" then
		if checkbox:GetChecked() then
			SOTA_CONFIG_AllowPlayerPass = 1;
		else
			SOTA_CONFIG_AllowPlayerPass = 0;
		end
		return;
	end

	--	Disable Dashboard:		
	if checkboxname == "FrameConfigBiddingDisableDashboard" then
		if checkbox:GetChecked() then
			SOTA_CONFIG_DisableDashboard = 1;
			SOTA_CloseDashboard();
		else
			SOTA_CONFIG_DisableDashboard = 0;
		end
		return;
	end
	
	--	Store DKP in Public Notes:		
	if checkboxname == "FrameConfigMiscDkpPublicNotes" then
		if checkbox:GetChecked() then
			SOTA_CONFIG_UseGuildNotes = 1;
		else
			SOTA_CONFIG_UseGuildNotes = 0;
		end
		return;
	end
	
	if checkbox:GetChecked() then		
		--	Bid type: Только 3 стратегии (0, 1, 2)
		if checkboxname == "FrameConfigMiscDkpMinBidStrategy0" then
			getglobal("FrameConfigMiscDkpMinBidStrategy1"):SetChecked(0);
			getglobal("FrameConfigMiscDkpMinBidStrategy2"):SetChecked(0);
			SOTA_CONFIG_MinimumBidStrategy = 0;
		elseif checkboxname == "FrameConfigMiscDkpMinBidStrategy1" then
			getglobal("FrameConfigMiscDkpMinBidStrategy0"):SetChecked(0);
			getglobal("FrameConfigMiscDkpMinBidStrategy2"):SetChecked(0);
			SOTA_CONFIG_MinimumBidStrategy = 1;
		elseif checkboxname == "FrameConfigMiscDkpMinBidStrategy2" then
			getglobal("FrameConfigMiscDkpMinBidStrategy0"):SetChecked(0);
			getglobal("FrameConfigMiscDkpMinBidStrategy1"):SetChecked(0);
			SOTA_CONFIG_MinimumBidStrategy = 2;
		end
	end
end

--[[
--	Сохранить настройки Bidding
--]]
function SOTA_SaveBiddingSettings()
	-- Настройки уже сохраняются автоматически при изменении через SOTA_HandleCheckbox и слайдеры
	-- Эта функция просто подтверждает сохранение
	localEcho("Настройки Bidding сохранены!");
end

--[[
--	Сохранить настройки Misc DKP
--]]
function SOTA_SaveMiscDKPSettings()
	-- Настройки уже сохраняются автоматически при изменении через SOTA_HandleCheckbox и слайдеры
	-- Эта функция просто подтверждает сохранение
	localEcho("Настройки Misc DKP сохранены!");
end


local currentEvent;
function SOTA_OnEventMessageClick(object)	
	local event = getglobal(object:GetName().."Event"):GetText();
	local channel = 1*getglobal(object:GetName().."Channel"):GetText();
	local message = getglobal(object:GetName().."Message"):GetText();

	currentEvent = event;

	if not message then
		message = "";
	end

--	echo("** Event: "..event..", Channel: "..channel..", Message: "..message);

	local frame = getglobal("FrameEventEditor");
	getglobal(frame:GetName().."Message"):SetText(message);

	getglobal(frame:GetName().."CheckbuttonRW"):SetChecked(0);		
	getglobal(frame:GetName().."CheckbuttonRaid"):SetChecked(0);		
	getglobal(frame:GetName().."CheckbuttonGuild"):SetChecked(0);		
	getglobal(frame:GetName().."CheckbuttonYell"):SetChecked(0);		
	getglobal(frame:GetName().."CheckbuttonSay"):SetChecked(0);		

	if channel == 1 then
		getglobal(frame:GetName().."CheckbuttonRW"):SetChecked(1);		
	elseif channel == 2 then
		getglobal(frame:GetName().."CheckbuttonRaid"):SetChecked(1);		
	elseif channel == 3 then
		getglobal(frame:GetName().."CheckbuttonGuild"):SetChecked(1);		
	elseif channel == 4 then
		getglobal(frame:GetName().."CheckbuttonYell"):SetChecked(1);		
	elseif channel == 5 then
		getglobal(frame:GetName().."CheckbuttonSay"):SetChecked(1);		
	end
	-- Yes, channel can be disabled (0) = nothing is written.
	
	FrameEventEditor:Show();
	FrameEventEditorMessage:SetFocus();
end

function SOTA_OnEventCheckboxClick(checkbox)
	local checkboxname = checkbox:GetName();
	local frame = getglobal("FrameEventEditor");

	if checkboxname == "FrameEventEditorCheckbuttonRW" then
		if checkbox:GetChecked() then
			getglobal(frame:GetName().."CheckbuttonRaid"):SetChecked(0);		
			getglobal(frame:GetName().."CheckbuttonGuild"):SetChecked(0);		
			getglobal(frame:GetName().."CheckbuttonYell"):SetChecked(0);		
			getglobal(frame:GetName().."CheckbuttonSay"):SetChecked(0);		
		end;
	elseif checkboxname == "FrameEventEditorCheckbuttonRaid" then
		if checkbox:GetChecked() then
			getglobal(frame:GetName().."CheckbuttonRW"):SetChecked(0);		
			getglobal(frame:GetName().."CheckbuttonGuild"):SetChecked(0);		
			getglobal(frame:GetName().."CheckbuttonYell"):SetChecked(0);		
			getglobal(frame:GetName().."CheckbuttonSay"):SetChecked(0);		
		end;
	elseif checkboxname == "FrameEventEditorCheckbuttonGuild" then
		if checkbox:GetChecked() then
			getglobal(frame:GetName().."CheckbuttonRW"):SetChecked(0);		
			getglobal(frame:GetName().."CheckbuttonRaid"):SetChecked(0);		
			getglobal(frame:GetName().."CheckbuttonYell"):SetChecked(0);		
			getglobal(frame:GetName().."CheckbuttonSay"):SetChecked(0);		
		end;
	elseif checkboxname == "FrameEventEditorCheckbuttonYell" then
		if checkbox:GetChecked() then
			getglobal(frame:GetName().."CheckbuttonRW"):SetChecked(0);		
			getglobal(frame:GetName().."CheckbuttonRaid"):SetChecked(0);		
			getglobal(frame:GetName().."CheckbuttonGuild"):SetChecked(0);		
			getglobal(frame:GetName().."CheckbuttonSay"):SetChecked(0);		
		end;
	elseif checkboxname == "FrameEventEditorCheckbuttonSay" then
		if checkbox:GetChecked() then
			getglobal(frame:GetName().."CheckbuttonRW"):SetChecked(0);		
			getglobal(frame:GetName().."CheckbuttonRaid"):SetChecked(0);		
			getglobal(frame:GetName().."CheckbuttonGuild"):SetChecked(0);		
			getglobal(frame:GetName().."CheckbuttonYell"):SetChecked(0);		
		end;
	end;
end;

function SOTA_OnEventEditorSave()
	local event = currentEvent;
	local message = FrameEventEditorMessage:GetText();
	local channel = 0;

	local frame = getglobal("FrameEventEditor");
	
	if getglobal(frame:GetName().."CheckbuttonRW"):GetChecked() then
		channel = 1
	elseif getglobal(frame:GetName().."CheckbuttonRaid"):GetChecked() then
		channel = 2
	elseif getglobal(frame:GetName().."CheckbuttonGuild"):GetChecked() then
		channel = 3
	elseif getglobal(frame:GetName().."CheckbuttonYell"):GetChecked() then
		channel = 4
	elseif getglobal(frame:GetName().."CheckbuttonSay"):GetChecked() then
		channel = 5
	end;

	SOTA_SetConfigurableMessage(event, channel, message);

	SOTA_UpdateTextList();

	FrameEventEditor:Hide();
end;

function SOTA_OnEventEditorClose()
	FrameEventEditor:Hide();
end;

function SOTA_RefreshVisibleTextList(offset)
	--echo(string.format("Offset=%d", offset));
	if not SOTA_GetConfigurableTextMessages then
		return;
	end
	
	local messages = SOTA_GetConfigurableTextMessages();
	local msgInfo;
	
	-- Проверяем, что messages не nil
	if not messages then
		messages = { };
	end

	for n=1, SOTA_MAX_MESSAGES, 1 do
		msgInfo = messages[n + offset]
		if not msgInfo then
			msgInfo = { "", 0, "" }
		end
		
		local event = msgInfo[1];
		local channel = msgInfo[2];
		local message = msgInfo[3];
		
		--echo(string.format("-> Event=%s, Channel=%d, Text=%s", event, 1*channel, message));
		
		local frame = getglobal("FrameConfigMessageTableListEntry"..n);
		if(not frame) then
			echo("*** Oops, frame is nil");
			return;
		end;

		getglobal(frame:GetName().."Event"):SetText(event);
		getglobal(frame:GetName().."Channel"):SetText(channel);
		getglobal(frame:GetName().."Message"):SetText(message);
		
		frame:Show();
	end
end

function SOTA_UpdateTextList(frame)
--	FauxScrollFrame_Update(FrameConfigMessageTableList, SOTA_MAX_MESSAGES, 10, 20);
	-- Сначала убеждаемся, что сообщения инициализированы
	if SOTA_VerifyEventMessages then
		SOTA_VerifyEventMessages();
	end
	
	if not SOTA_GetConfigurableTextMessages then
		return;
	end
	
	-- Затем получаем актуальные сообщения
	local messages = SOTA_GetConfigurableTextMessages();
	
	-- Проверяем, что messages не nil
	if not messages then
		messages = { };
	end

	FauxScrollFrame_Update(FrameConfigMessageTableList, table.getn(messages), SOTA_MAX_MESSAGES, 20);
	local offset = FauxScrollFrame_GetOffset(FrameConfigMessageTableList);
	
	SOTA_RefreshVisibleTextList(offset);
end

function SOTA_InitializeTextElements()
	local entry = CreateFrame("Button", "$parentEntry1", FrameConfigMessageTableList, "SOTA_TextTemplate");
	entry:SetID(1);
	entry:SetPoint("TOPLEFT", 4, -4);
	for n=2, SOTA_MAX_MESSAGES, 1 do
		local entry = CreateFrame("Button", "$parentEntry"..n, FrameConfigMessageTableList, "SOTA_TextTemplate");
		entry:SetID(n);
		entry:SetPoint("TOP", "$parentEntry"..(n-1), "BOTTOM");
	end
end

-- Инициализация при загрузке файла
-- Убеждаемся, что сообщения инициализированы сразу после загрузки
if not SOTA_CONFIG_Messages or (type(SOTA_CONFIG_Messages) == "table" and table.getn(SOTA_CONFIG_Messages) == 0) then
	SOTA_VerifyEventMessages();
end