--[[
--	SotA - DKP Loot Assistant
--	Unit: sota-lootassistant.lua
--	
--	Автоматический помощник для управления лутом:
--	- Сканирование эпиков при открытии лута
--	- Запуск аукционов SOTA для предметов
--	- Автоматическая выдача предметов победителям
--]]

-- Глобальная таблица отсканированного лута
SOTA_ScannedLoot = {}

-- Конфигурация (сохраняется между сессиями через SavedVariables)
SOTA_CONFIG_LA_MinQuality = SOTA_CONFIG_LA_MinQuality or 4  -- По умолчанию: эпики
SOTA_CONFIG_LA_AutoOpen = SOTA_CONFIG_LA_AutoOpen or 1      -- Автооткрытие окна
SOTA_CONFIG_LA_ExcludeQuest = SOTA_CONFIG_LA_ExcludeQuest or 1  -- Исключать квестовые предметы

-- История лута (опционально для статистики)
SOTA_LootHistory = SOTA_LootHistory or {}

-- Режим отладки
SOTA_LA_DebugMode = SOTA_LA_DebugMode or false

-- Флаг: открыто ли окно лута
local LootWindowOpen = false

-- Предметы в текущем трейде (для удаления после успешного завершения)
local ItemsInTrade = {}

-- Флаг успешного завершения трейда (оба игрока нажали Accept)
local TradeAccepted = false

--[[
--	======================
--	МОДУЛЬ: LootScanner
--	======================
--]]

-- Генерация уникального ключа для предмета
local function GenerateLootKey(itemId, slot)
	return string.format("%d_%d_%d", itemId, slot, time())
end

-- Парсинг itemId из itemLink
local function ExtractItemId(link)
	if not link then return nil end
	local _, _, itemId = string.find(link, "item:(%d+):")
	return tonumber(itemId)
end

-- Нормализация ссылки на предмет (для сравнения с чат‑сообщениями)
local function NormalizeItemLink(link)
	if not link then return nil end
	-- Вытащить часть Hitem:... до первого |h
	local itemString = string.match(link, "H(item:%d+:[^|]*)|h")
	return itemString or link
end

-- Добавление предмета в список по itemLink
function SOTA_LA_AddItemFromLink(link)
	if not link or link == "" then
		localEcho("[Loot Assistant] Пустой линк предмета")
		return
	end

	local itemId = ExtractItemId(link)
	if not itemId then
		-- В Classic иногда ссылки могут быть кастомными; не блокируем UI, просто логируем
		localEcho("[Loot Assistant] Не удалось извлечь itemId из ссылки: "..tostring(link))
		itemId = 0
	end

	local name, _, quality, _, _, _, _, _, texture = GetItemInfo(itemId)
	if not name then
		name = link
	end

	-- Фильтр по качеству
	if quality and quality < SOTA_CONFIG_LA_MinQuality then
		localEcho("[Loot Assistant] Качество предмета ниже фильтра, не добавляем")
		return
	end

	local lootKey = GenerateLootKey(itemId, 0)

	SOTA_ScannedLoot[lootKey] = {
		itemId   = itemId,
		link     = link,
		normLink = NormalizeItemLink(link),
		name     = name,
		quality  = quality or 0,
		slot     = 0, -- из сумки, не из лута босса
		texture  = texture or "Interface\\Icons\\INV_Misc_QuestionMark",
		quantity = 1,
		winner   = nil,
		status   = "pending",
		sessionId = tostring(time()),
		timestamp = time()
	}

	localEcho(string.format("[Loot Assistant] Добавлен предмет: %s", name))
	SOTA_LA_RefreshList()
	
	-- Автоматически открыть окно если есть предметы
	if SOTA_CONFIG_LA_AutoOpen == 1 then
		SOTA_LA_OpenWindow()
	end
end

-- Сканирование текущего лута
function SOTA_LA_OnLootOpened()
	local numItems = GetNumLootItems()
	if not numItems or numItems == 0 then return end
	
	local scannedCount = 0
	
	for slot = 1, numItems do
		local texture, itemName, quantity, quality, locked, isQuestItem, questId, isActive = GetLootSlotInfo(slot)
		local link = GetLootSlotLink(slot)
		
		if link and quality then
			-- Фильтр по качеству
			local shouldInclude = (quality >= SOTA_CONFIG_LA_MinQuality)
			
			-- Фильтр квестовых предметов
			if shouldInclude and SOTA_CONFIG_LA_ExcludeQuest == 1 and isQuestItem then
				shouldInclude = false
			end
			
			if shouldInclude then
				local itemId = ExtractItemId(link)
				if itemId then
					local lootKey = GenerateLootKey(itemId, slot)
					
					SOTA_ScannedLoot[lootKey] = {
						itemId = itemId,
						link = link,
						name = itemName,
						quality = quality,
						slot = slot,
						texture = texture,
						quantity = quantity,
						winner = nil,
						status = "pending",  -- pending, rolling, finished, given
						sessionId = tostring(time()),
						timestamp = time()
					}
					
					scannedCount = scannedCount + 1
				end
			end
		end
	end
	
	if scannedCount > 0 then
		localEcho(string.format("[Loot Assistant] Отсканировано предметов: %d", scannedCount))
		
		-- Автоматическое открытие окна
		if SOTA_CONFIG_LA_AutoOpen == 1 then
			SOTA_LA_OpenWindow()
		end
	end
end

-- Обновление slot индексов после выдачи предметов
function SOTA_LA_OnLootSlotCleared(slot)
	-- После выдачи предмета все слоты выше сдвигаются вниз
	for key, entry in pairs(SOTA_ScannedLoot) do
		if entry.slot > slot then
			entry.slot = entry.slot - 1
		elseif entry.slot == slot then
			-- Предмет был выдан/взят
			if entry.status == "given" then
				-- Уже помечен как выданный, всё ОК
			else
				-- Предмет взят не через наш интерфейс
				entry.status = "taken"
			end
		end
	end
	
	SOTA_LA_RefreshList()
end

-- Закрытие окна лута
function SOTA_LA_OnLootClosed()
	LootWindowOpen = false
	
	-- Помечаем предметы, которые ещё не выданы
	for key, entry in pairs(SOTA_ScannedLoot) do
		if entry.status == "finished" then
			-- Предмет выигран, но не выдан из окна лута - нужен трейд
			entry.needsTrade = true
		end
	end
end

-- Получение отсканированного лута для UI
function SOTA_LA_GetScannedLoot()
	return SOTA_ScannedLoot
end

-- Очистка старого лута (опционально)
function SOTA_LA_ClearOldLoot()
	local currentTime = time()
	local threshold = 3600 -- 1 час
	
	for key, entry in pairs(SOTA_ScannedLoot) do
		if entry.status == "given" and (currentTime - entry.timestamp) > threshold then
			SOTA_ScannedLoot[key] = nil
		end
	end
end


--[[
--	======================
--	МОДУЛЬ: SOTAIntegration
--	======================
--]]

-- Запуск аукциона для предмета
function SOTA_LA_StartRollForItem(lootKey)
	local entry = SOTA_ScannedLoot[lootKey]
	if not entry then
		localEcho("[Loot Assistant] Ошибка: предмет не найден")
		return false
	end
	
	if entry.status ~= "pending" then
		localEcho("[Loot Assistant] Предмет уже в обработке")
		return false
	end
	
	-- Проверка прав
	local rank = SOTA_GetRaidRank(UnitName("player"))
	if rank < 1 then
		localEcho("[Loot Assistant] Нужно быть помощником или лидером рейда")
		return false
	end
	
	-- Формируем команду для SOTA_StartAuction
	-- Формат: [минбид] itemlink или просто itemlink (минбид 100 по умолчанию)
	local msg = entry.link
	
	-- Запускаем аукцион через SOTA
	SOTA_StartAuction(msg)
	
	-- Обновляем статус
	entry.status = "rolling"
	SOTA_LA_RefreshList()
	
	return true
end

-- Запуск аукциона для первого pending-предмета (по времени добавления)
function SOTA_LA_StartFirstPending()
	local items = {}
	for key, entry in pairs(SOTA_ScannedLoot) do
		if entry.status == "pending" then
			table.insert(items, { key = key, entry = entry })
		end
	end

	if table.getn(items) == 0 then
		localEcho("[Loot Assistant] Нет предметов для разрола")
		return
	end

	table.sort(items, function(a, b)
		return (a.entry.timestamp or 0) < (b.entry.timestamp or 0)
	end)

	local firstKey = items[1].key
	SOTA_LA_StartRollForItem(firstKey)
end

-- Сохранение в историю
function SOTA_LA_SaveToHistory(entry)
	local sessionId = entry.sessionId or tostring(time())
	
	if not SOTA_LootHistory[sessionId] then
		SOTA_LootHistory[sessionId] = {
			date = date("%Y-%m-%d %H:%M:%S"),
			zone = GetRealZoneText() or "Unknown",
			items = {}
		}
	end
	
	SOTA_LootHistory[sessionId].items[entry.itemId] = {
		link = entry.link,
		winner = entry.winner,
		bid = entry.bidAmount or 0,
		timestamp = time()
	}
end


--[[
--	======================
--	МОДУЛЬ: TradeAssistant
--	======================
--]]

-- Поиск индекса игрока в рейде
function SOTA_LA_FindRaidMemberIndex(playerName)
	local numMembers = GetNumRaidMembers()
	if numMembers == 0 then
		-- Проверяем группу
		numMembers = GetNumPartyMembers()
		if numMembers > 0 then
			for i = 1, numMembers do
				local name = UnitName("party"..i)
				if name == playerName then
					return i
				end
			end
			-- Проверяем самого игрока
			if UnitName("player") == playerName then
				return 0  -- Индекс для игрока в группе
			end
		end
	else
		-- Рейд
		for i = 1, numMembers do
			local name, rank, subgroup, level, class = GetRaidRosterInfo(i)
			if name == playerName then
				return i
			end
		end
	end
	
	return nil
end

-- Прямая выдача предмета из окна лута
function SOTA_LA_GiveItemFromLoot(lootKey)
	local entry = SOTA_ScannedLoot[lootKey]
	if not entry then
		localEcho("[Loot Assistant] Ошибка: предмет не найден")
		return
	end
	
	if entry.status ~= "finished" or not entry.winner then
		localEcho("[Loot Assistant] Предмет ещё не разыгран или нет победителя")
		return
	end
	
	-- Проверяем, открыто ли окно лута
	if GetNumLootItems() == 0 then
		localEcho("[Loot Assistant] Окно лута закрыто. Используйте трейд для выдачи.")
		entry.needsTrade = true
		SOTA_LA_RefreshList()
		return
	end
	
	-- Находим индекс победителя в рейде
	local candidateIndex = SOTA_LA_FindRaidMemberIndex(entry.winner)
	if not candidateIndex then
		localEcho(string.format("[Loot Assistant] Игрок %s не найден в рейде/группе", entry.winner))
		return
	end
	
	-- Выдаём предмет
	GiveMasterLoot(entry.slot, candidateIndex)
	
	-- Обновляем статус
	entry.status = "given"
	
	-- Удаляем предмет из списка после выдачи
	SOTA_ScannedLoot[lootKey] = nil
	SOTA_LA_RefreshList()
	
	-- Логируем в чат
	SendChatMessage(string.format("Выдан %s → %s", entry.link, entry.winner), "RAID")
	localEcho(string.format("[Loot Assistant] Выдан %s игроку %s и удален из списка", entry.name, entry.winner))
end

-- Поиск предмета в сумках
function SOTA_LA_FindItemInBags(itemId)
	for bag = 0, 4 do
		local slots = GetContainerNumSlots(bag)
		if slots then
			for slot = 1, slots do
				local link = GetContainerItemLink(bag, slot)
				if link then
					local id = ExtractItemId(link)
					if id == itemId then
						return bag, slot
					end
				end
			end
		end
	end
	return nil, nil
end

-- Обработка открытия трейда
function SOTA_LA_OnTradeShow()
	local partner = UnitName("npc")
	if not partner then
		partner = UnitName("target")
	end
	
	if not partner then return end
	
	-- Находим предметы для этого игрока
	local itemsForPartner = {}
	for key, entry in pairs(SOTA_ScannedLoot) do
		if entry.winner == partner and (entry.status == "finished" or entry.needsTrade) then
			table.insert(itemsForPartner, {key = key, entry = entry})
		end
	end
	
	if table.getn(itemsForPartner) > 0 then
		-- Показываем хелпер (будет в UI)
		SOTA_LA_ShowTradeHelper(partner, itemsForPartner)
	end
end

-- Выдача предметов через трейд
function SOTA_LA_GiveItemsInTrade(partner, items)
	local tradeSlot = 1
	local givenCount = 0
	
	-- Очищаем список предметов в трейде
	ItemsInTrade = {}
	
	for _, itemData in ipairs(items) do
		local entry = itemData.entry
		local key = itemData.key
		local bag, slot = SOTA_LA_FindItemInBags(entry.itemId)
		
		if bag and slot then
			-- Берём предмет
			PickupContainerItem(bag, slot)
			
			-- Кладём в трейд
			if tradeSlot <= 6 then  -- Максимум 6 слотов в трейде
				ClickTradeButton(tradeSlot)
				tradeSlot = tradeSlot + 1
				
				-- Обновляем статус
				entry.status = "given"
				entry.needsTrade = false
				givenCount = givenCount + 1
				
				-- Запоминаем для удаления после трейда
				table.insert(ItemsInTrade, key)
			end
		else
			localEcho(string.format("[Loot Assistant] Предмет %s не найден в сумках", entry.name))
		end
	end
	
	if givenCount > 0 then
		localEcho(string.format("[Loot Assistant] Помещено в трейд: %d предметов", givenCount))
		SOTA_LA_RefreshList()
	end
end


--[[
--	======================
--	МОДУЛЬ: UI Functions
--	======================
--]]

-- Открыть окно Loot Assistant
function SOTA_LA_OpenWindow()
	local frame = getglobal("SOTA_LootAssistantFrame")
	if frame then
		frame:Show()
		SOTA_LA_RefreshList()
	end
end

-- Закрыть окно Loot Assistant
function SOTA_LA_CloseWindow()
	local frame = getglobal("SOTA_LootAssistantFrame")
	if frame then
		frame:Hide()
	end
end

-- Обновление списка предметов в UI
function SOTA_LA_RefreshList()
	SOTA_LA_UpdateItemList()
end

function SOTA_LA_UpdateItemList()
	-- Собираем все предметы в массив
	local items = {}
	for key, entry in pairs(SOTA_ScannedLoot) do
		table.insert(items, {key = key, entry = entry})
	end
	
	-- Сортируем по времени (новые сверху)
	table.sort(items, function(a, b)
		return a.entry.timestamp > b.entry.timestamp
	end)
	
	local numItems = table.getn(items)
	
	if numItems == 0 then
		-- Скрываем все кнопки
		for i = 1, 9 do
			local button = getglobal("SOTA_LootItem"..i)
			if button then
				button:Hide()
			end
		end
		return
	end

	-- Обновляем видимые элементы (без скроллинга)
	for i = 1, 9 do
		local index = i
		local button = getglobal("SOTA_LootItem"..i)
		
		if not button then
			localEcho("[Loot Assistant ERROR] Кнопка "..i.." не найдена! Проверьте XML.")
			return
		end
		
		if index <= numItems then
			local itemData = items[index]
			local entry = itemData.entry
			local key = itemData.key
			
			-- Формируем одну текстовую строку \"Имя (статус)\"
			local line = entry.name or "Неизвестно"
			local statusStr = ""
			if entry.status == "pending" then
				statusStr = "Ожидает разрола"
			elseif entry.status == "rolling" then
				statusStr = "Аукцион идёт..."
			elseif entry.status == "finished" then
				statusStr = "Победитель: "..(entry.winner or "?")
			elseif entry.status == "given" then
				statusStr = "Выдан: "..(entry.winner or "?")
			else
				statusStr = entry.status or ""
			end
			if statusStr ~= "" then
				line = line.." - "..statusStr
			end

		-- Устанавливаем текст (без иконок и отдельного статуса)
		local nameText = getglobal(button:GetName().."Text")
		if nameText then
			local qualityColor = SOTA_GetQualityColor(entry.quality)
			if qualityColor then
				nameText:SetTextColor(qualityColor[1]/255, qualityColor[2]/255, qualityColor[3]/255)
			else
				nameText:SetTextColor(1, 1, 1) -- Белый по умолчанию
			end
			nameText:SetText(line)
			nameText:Show()
		end
		
		-- Настраиваем кнопки
		local rollButton = getglobal(button:GetName().."_RollButton")
		local giveButton = getglobal(button:GetName().."_GiveButton")
		local removeButton = getglobal(button:GetName().."_RemoveButton")
		
		-- Кнопка Разрол
		if rollButton then
			if entry.status == "pending" then
				rollButton:Enable()
				rollButton:SetScript("OnClick", function()
					SOTA_LA_StartRollForItem(key)
				end)
				rollButton:Show()
			else
				rollButton:Hide()
			end
		end
		
		-- Кнопка Give
		if giveButton then
			if entry.status == "finished" and entry.winner then
				giveButton:Enable()
				giveButton:SetScript("OnClick", function()
					SOTA_LA_GiveItemFromLoot(key)
				end)
				giveButton:Show()
			else
				giveButton:Disable()
				giveButton:Show()
			end
		end
		
		-- Кнопка Remove
		if removeButton then
			removeButton:Enable()
			removeButton:SetScript("OnClick", function()
				SOTA_LA_RemoveItem(key)
			end)
			removeButton:Show()
		end
		
		-- Сохраняем itemId для тултипа
		button.itemId = entry.itemId
		
		button:Show()
		else
			button:Hide()
		end
	end
end

-- Удаление предмета из списка
function SOTA_LA_RemoveItem(lootKey)
	if SOTA_ScannedLoot[lootKey] then
		SOTA_ScannedLoot[lootKey] = nil
		SOTA_LA_RefreshList()
		localEcho("[Loot Assistant] Предмет удалён из списка")
	end
end

-- Выдать все разыгранные предметы
function SOTA_LA_GiveAll()
	local given = 0

	-- Если открыт трейд — пытаемся выдать через трейд текущему партнёру
	local partner = UnitName("npc") or UnitName("target")
	if partner then
		local itemsForPartner = {}
		for key, entry in pairs(SOTA_ScannedLoot) do
			if entry.winner == partner and (entry.status == "finished" or entry.needsTrade) then
				table.insert(itemsForPartner, { key = key, entry = entry })
			end
		end
		if table.getn(itemsForPartner) > 0 then
			SOTA_LA_GiveItemsInTrade(partner, itemsForPartner)
			return
		end
	end

	-- Иначе пробуем выдать все finished через GiveMasterLoot / fallback
	for key, entry in pairs(SOTA_ScannedLoot) do
		if entry.status == "finished" and entry.winner then
			SOTA_LA_GiveItemFromLoot(key)
			given = given + 1
		end
	end

	if given == 0 then
		localEcho("[Loot Assistant] Нет предметов со статусом 'finished' для выдачи")
	else
		localEcho(string.format("[Loot Assistant] Попытка выдать %d предмет(ов)", given))
	end
end

-- Запуск аукционов для всех pending предметов
function SOTA_LA_RollAllPending()
	-- Собираем все pending предметы
	RollQueue = {}
	for key, entry in pairs(SOTA_ScannedLoot) do
		if entry.status == "pending" then
			table.insert(RollQueue, key)
		end
	end
	
	if table.getn(RollQueue) == 0 then
		localEcho("[Loot Assistant] Нет предметов для разрола")
		return
	end
	
	localEcho(string.format("[Loot Assistant] Запуск аукционов для %d предметов...", table.getn(RollQueue)))
	
	-- Запускаем первый аукцион сразу
	if RollQueue[1] then
		SOTA_LA_StartRollForItem(RollQueue[1])
		table.remove(RollQueue, 1)
		RollQueueTimer = ROLL_QUEUE_DELAY
	end
end

-- Обработка очереди аукционов (вызывается из OnUpdate)
function SOTA_LA_ProcessRollQueue(elapsed)
	if table.getn(RollQueue) == 0 then return end
	
	RollQueueTimer = RollQueueTimer - elapsed
	
	if RollQueueTimer <= 0 then
		-- Проверяем, завершился ли предыдущий аукцион
		local state = SOTA_GetAuctionState()
		if state == STATE_NONE or state == STATE_AUCTION_COMPLETE then
			-- Запускаем следующий
			if RollQueue[1] then
				SOTA_LA_StartRollForItem(RollQueue[1])
				table.remove(RollQueue, 1)
				RollQueueTimer = ROLL_QUEUE_DELAY
			end
		else
			-- Аукцион ещё идёт, ждём
			RollQueueTimer = 1.0
		end
	end
end

-- Показать хелпер для трейда
function SOTA_LA_ShowTradeHelper(partner, items)
	local frame = getglobal("SOTA_LA_TradeHelperFrame")
	if not frame then return end
	
	-- Обновляем информацию
	local infoText = getglobal(frame:GetName().."_Info")
	if infoText then
		local itemNames = {}
		for _, itemData in ipairs(items) do
			table.insert(itemNames, itemData.entry.name)
		end
		local text = string.format("Предметы для %s:\n\n%s", partner, table.concat(itemNames, "\n"))
		infoText:SetText(text)
	end
	
	-- Настраиваем кнопку "Выдать Всё"
	local giveButton = getglobal(frame:GetName().."_GiveAllButton")
	if giveButton then
		giveButton:SetScript("OnClick", function()
			SOTA_LA_GiveItemsInTrade(partner, items)
			frame:Hide()
		end)
	end
	
	frame:Show()
end

-- Обновить Trade Helper (альтернативная версия для динамического вызова)
function SOTA_LA_UpdateTradeHelper(partner, items)
	SOTA_LA_ShowTradeHelper(partner, items)
end


--[[
--	======================
--	СОБЫТИЯ
--	======================
--]]

-- Главный обработчик событий
function SOTA_LA_OnEvent(event)
	if event == "LOOT_OPENED" then
		LootWindowOpen = true
		SOTA_LA_OnLootOpened()
	elseif event == "LOOT_SLOT_CLEARED" then
		if arg1 then
			SOTA_LA_OnLootSlotCleared(arg1)
		end
	elseif event == "LOOT_CLOSED" then
		SOTA_LA_OnLootClosed()
	elseif event == "TRADE_SHOW" then
		SOTA_LA_OnTradeShow()
		-- Сбрасываем флаг при открытии нового трейда
		TradeAccepted = false
	elseif event == "TRADE_ACCEPT_UPDATE" then
		-- Проверяем что оба игрока подтвердили трейд
		-- arg1 = 1 если мы подтвердили, arg2 = 1 если партнер подтвердил
		if arg1 == 1 and arg2 == 1 then
			TradeAccepted = true
			if SOTA_LA_DebugMode then
				localEcho("[LA DEBUG] Обе стороны подтвердили трейд")
			end
		end
	elseif event == "TRADE_CLOSED" then
		-- Трейд завершен - удаляем предметы только если трейд был успешным
		if TradeAccepted and table.getn(ItemsInTrade) > 0 then
			local deletedCount = 0
			for _, key in ipairs(ItemsInTrade) do
				if SOTA_ScannedLoot[key] then
					SOTA_ScannedLoot[key] = nil
					deletedCount = deletedCount + 1
				end
			end
			
			if deletedCount > 0 then
				localEcho(string.format("[Loot Assistant] Удалено %d предметов после успешного трейда", deletedCount))
				SOTA_LA_RefreshList()
			end
		elseif table.getn(ItemsInTrade) > 0 and not TradeAccepted then
			-- Трейд был отменен - возвращаем предметы в статус "finished"
			for _, key in ipairs(ItemsInTrade) do
				if SOTA_ScannedLoot[key] then
					SOTA_ScannedLoot[key].status = "finished"
				end
			end
			localEcho("[Loot Assistant] Трейд отменен, предметы возвращены в список")
			SOTA_LA_RefreshList()
		end
		
		-- Очищаем списки
		ItemsInTrade = {}
		TradeAccepted = false
	end
end

-- Тестовая функция для создания фейкового лута
function SOTA_LA_CreateTestLoot()
	SOTA_ScannedLoot = {}
	
	-- Используем общий путь добавления, как из сумки
	SOTA_LA_AddItemFromLink(string.char(124).."cffff8000"..string.char(124).."Hitem:19019:0:0:0"..string.char(124).."h[Thunderfury, Blessed Blade of the Windseeker]"..string.char(124).."h"..string.char(124).."r")
	SOTA_LA_AddItemFromLink(string.char(124).."cffa335ee"..string.char(124).."Hitem:18832:0:0:0"..string.char(124).."h[Brutality Blade]"..string.char(124).."h"..string.char(124).."r")
	SOTA_LA_AddItemFromLink(string.char(124).."cffa335ee"..string.char(124).."Hitem:17076:0:0:0"..string.char(124).."h[Bonereaver's Edge]"..string.char(124).."h"..string.char(124).."r")
	
	localEcho("[Loot Assistant] Создано 3 тестовых предмета")
	SOTA_LA_OpenWindow()
end

--[[
--	======================
--	CALLBACKS ДЛЯ SOTA
--	======================
--]]

-- Callback: аукцион начался
function SOTA_LA_OnAuctionStart(itemLink, itemId, minBid)
	if SOTA_LA_DebugMode then
		localEcho(string.format("[LA] Callback OnStart: itemId=%s, minBid=%s", tostring(itemId), tostring(minBid)))
	end
	-- Опционально: можно обновить статус на "rolling" если предмет уже в списке
end

-- Callback: аукцион завершен
function SOTA_LA_OnAuctionComplete(itemLink, itemId, winner, bid)
	if not itemId or itemId == 0 then 
		if SOTA_LA_DebugMode then
			localEcho("[LA] Callback OnComplete: itemId пустой")
		end
		return 
	end
	
	if SOTA_LA_DebugMode then
		localEcho(string.format("[LA] Callback OnComplete: itemId=%d, winner=%s, bid=%d", itemId, winner, bid))
		localEcho("[LA] Предметы в ScannedLoot:")
		for key, entry in pairs(SOTA_ScannedLoot) do
			localEcho(string.format("  [%s] itemId=%s, status=%s, name=%s", key, tostring(entry.itemId), entry.status, entry.name))
		end
	end
	
	-- Найти предмет в списке по itemId
	for key, entry in pairs(SOTA_ScannedLoot) do
		if entry.itemId == itemId and (entry.status == "rolling" or entry.status == "pending") then
			entry.winner = winner
			entry.status = "finished"
			entry.bidAmount = bid
			
			localEcho(string.format("[Loot Assistant] Победитель: %s за %d ДКП (%s)", winner, bid, entry.name))
			SOTA_LA_RefreshList()
			SOTA_LA_SaveToHistory(entry)
			return
		end
	end
	
	if SOTA_LA_DebugMode then
		localEcho("[LA] Предмет не найден в ScannedLoot или неверный статус!")
	end
end

-- Callback: аукцион отменен
function SOTA_LA_OnAuctionCancel(itemLink, itemId)
	if not itemId or itemId == 0 then return end
	
	if SOTA_LA_DebugMode then
		localEcho(string.format("[LA] Callback OnCancel: itemId=%d", itemId))
	end
	
	for key, entry in pairs(SOTA_ScannedLoot) do
		if entry.itemId == itemId and entry.status == "rolling" then
			entry.status = "pending"
			localEcho(string.format("[Loot Assistant] Аукцион отменен: %s", entry.name))
			SOTA_LA_RefreshList()
			return
		end
	end
end

--[[
--	======================
--	SLASH КОМАНДЫ
--	======================
--]]

-- Slash команды
SLASH_SOTALA1 = "/lootassist"
SLASH_SOTALA2 = "/la"
SlashCmdList["SOTALA"] = function(msg)
	if msg == "show" or msg == "" then
		SOTA_LA_OpenWindow()
	elseif msg == "hide" then
		SOTA_LA_CloseWindow()
	elseif msg == "clear" then
		SOTA_ScannedLoot = {}
		SOTA_LA_RefreshList()
		localEcho("[Loot Assistant] Список лута очищен")
	elseif msg == "test" then
		SOTA_LA_CreateTestLoot()
	elseif msg == "debugmode" then
		SOTA_LA_DebugMode = not SOTA_LA_DebugMode
		localEcho("[Loot Assistant] Режим отладки: "..(SOTA_LA_DebugMode and "ВКЛЮЧЕН" or "ВЫКЛЮЧЕН"))
	elseif string.find(msg, "^setwinner ") then
		-- /la setwinner ИмяИгрока
		local winner = string.match(msg, "^setwinner%s+(%S+)")
		if winner then
			-- Найти первый rolling предмет и установить победителя
			for key, entry in pairs(SOTA_ScannedLoot) do
				if entry.status == "rolling" or entry.status == "pending" then
					entry.winner = winner
					entry.status = "finished"
					localEcho(string.format("[Loot Assistant] Установлен победитель %s для %s", winner, entry.name))
					SOTA_LA_RefreshList()
					SOTA_LA_SaveToHistory(entry)
					return
				end
			end
			localEcho("[Loot Assistant] Нет активных аукционов")
		else
			localEcho("[Loot Assistant] Использование: /la setwinner ИмяИгрока")
		end
	elseif msg == "debug" then
		-- Диагностика
		DEFAULT_CHAT_FRAME:AddMessage("=== DKP Loot Assistant DEBUG ===")
		
		-- Проверка фрейма
		local frame = getglobal("SOTA_LootAssistantFrame")
		DEFAULT_CHAT_FRAME:AddMessage("Фрейм: "..(frame and "OK" or "НЕ НАЙДЕН!"))
		if frame then
			DEFAULT_CHAT_FRAME:AddMessage("Видим: "..(frame:IsVisible() and "ДА" or "НЕТ"))
		end
		
		-- Проверка ScrollFrame
		local scrollFrame = getglobal("SOTA_LootAssistantFrame_ScrollFrame")
		DEFAULT_CHAT_FRAME:AddMessage("ScrollFrame: "..(scrollFrame and "OK" or "НЕ НАЙДЕН!"))
		
		-- Проверка данных
		local count = 0
		for k,v in pairs(SOTA_ScannedLoot) do 
			count = count + 1
			DEFAULT_CHAT_FRAME:AddMessage("  Item: "..v.name.." - "..v.status)
		end
		DEFAULT_CHAT_FRAME:AddMessage("Всего предметов: "..count)
		
		-- Проверка кнопок
		for i = 1, 3 do
			local button = getglobal("SOTA_LootItem"..i)
			DEFAULT_CHAT_FRAME:AddMessage("Кнопка "..i..": "..(button and "OK" or "НЕ СОЗДАНА"))
			if button then
				DEFAULT_CHAT_FRAME:AddMessage("  Видима: "..(button:IsVisible() and "ДА" or "НЕТ"))
				local txt = getglobal(button:GetName().."Text")
				DEFAULT_CHAT_FRAME:AddMessage("  FontString: "..(txt and "OK" or "НЕТ"))
				if txt then
					DEFAULT_CHAT_FRAME:AddMessage("  Текст: '"..(txt:GetText() or "пусто").."'")
					DEFAULT_CHAT_FRAME:AddMessage("  FontString видим: "..(txt:IsVisible() and "ДА" or "НЕТ"))
				end
			end
		end
	elseif msg == "help" then
		DEFAULT_CHAT_FRAME:AddMessage("=== DKP Loot Assistant ===")
		DEFAULT_CHAT_FRAME:AddMessage("/la show - Показать окно")
		DEFAULT_CHAT_FRAME:AddMessage("/la hide - Скрыть окно")
		DEFAULT_CHAT_FRAME:AddMessage("/la clear - Очистить список лута")
		DEFAULT_CHAT_FRAME:AddMessage("/la test - Создать тестовые предметы")
		DEFAULT_CHAT_FRAME:AddMessage("/la debug - Диагностика проблем")
		DEFAULT_CHAT_FRAME:AddMessage("/la debugmode - Включить/выключить debug логи")
		DEFAULT_CHAT_FRAME:AddMessage("/la setwinner ИмяИгрока - Установить победителя вручную")
	else
		localEcho("[Loot Assistant] Неизвестная команда. Используйте /la help")
	end
end

--[[
--	======================
--	ИНИЦИАЛИЗАЦИЯ
--	======================
--]]

-- Регистрация callbacks в SOTA
if SOTA_LA_Callbacks then
	SOTA_LA_Callbacks.onAuctionStart = SOTA_LA_OnAuctionStart
	SOTA_LA_Callbacks.onAuctionComplete = SOTA_LA_OnAuctionComplete
	SOTA_LA_Callbacks.onAuctionCancel = SOTA_LA_OnAuctionCancel
	localEcho("[Loot Assistant] Зарегистрирован в SOTA через callbacks")
else
	localEcho("[Loot Assistant] ПРЕДУПРЕЖДЕНИЕ: SOTA_LA_Callbacks не найден!")
end

-- Инициализация модуля
localEcho("[Loot Assistant] Модуль загружен. Используйте /la для управления")
