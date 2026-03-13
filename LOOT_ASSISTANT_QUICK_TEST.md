# DKP Loot Assistant - Команды для тестирования

## Быстрое тестирование без лута

### Вариант 1: Простая команда (работает)

```lua
/script SOTA_ScannedLoot = {}
/script local t = SOTA_ScannedLoot; t["test1"] = {itemId=19019, link="\124cffff8000\124Hitem:19019:0:0:0\124h[Thunderfury]\124h\124r", name="Thunderfury", quality=5, slot=1, texture="Interface\\Icons\\INV_Sword_39", winner=nil, status="pending", sessionId="123", timestamp=time()}
/script SOTA_LA_RefreshList()
/la show
```

### Вариант 2: Через функцию (самый надежный)

Добавьте эту функцию в конец `sota-lootassistant.lua`:

```lua
-- Тестовая функция для создания фейкового лута
function SOTA_LA_CreateTestLoot()
	SOTA_ScannedLoot = {}
	
	-- Thunderfury
	SOTA_ScannedLoot["test1"] = {
		itemId = 19019,
		link = string.char(124).."cffff8000"..string.char(124).."Hitem:19019:0:0:0"..string.char(124).."h[Thunderfury, Blessed Blade of the Windseeker]"..string.char(124).."h"..string.char(124).."r",
		name = "Thunderfury",
		quality = 5,
		slot = 1,
		texture = "Interface\\Icons\\INV_Sword_39",
		winner = nil,
		status = "pending",
		sessionId = "test_session",
		timestamp = time()
	}
	
	-- Brutality Blade
	SOTA_ScannedLoot["test2"] = {
		itemId = 18832,
		link = string.char(124).."cffa335ee"..string.char(124).."Hitem:18832:0:0:0"..string.char(124).."h[Brutality Blade]"..string.char(124).."h"..string.char(124).."r",
		name = "Brutality Blade",
		quality = 4,
		slot = 2,
		texture = "Interface\\Icons\\INV_Sword_27",
		winner = nil,
		status = "pending",
		sessionId = "test_session",
		timestamp = time()
	}
	
	-- Bonereaver's Edge
	SOTA_ScannedLoot["test3"] = {
		itemId = 17076,
		link = string.char(124).."cffa335ee"..string.char(124).."Hitem:17076:0:0:0"..string.char(124).."h[Bonereaver's Edge]"..string.char(124).."h"..string.char(124).."r",
		name = "Bonereaver's Edge",
		quality = 4,
		slot = 3,
		texture = "Interface\\Icons\\INV_Axe_12",
		winner = nil,
		status = "pending",
		sessionId = "test_session",
		timestamp = time()
	}
	
	localEcho("[Loot Assistant] Создано 3 тестовых предмета")
	SOTA_LA_OpenWindow()
	SOTA_LA_RefreshList()
end

-- Добавить в slash команды
SLASH_SOTALATEST1 = "/latest"
SlashCmdList["SOTALATEST"] = function()
	SOTA_LA_CreateTestLoot()
end
```

Затем используйте:
```
/reload
/latest
```

### Вариант 3: Упрощенная версия (без цветов)

```lua
/script SOTA_ScannedLoot = {}

/script SOTA_ScannedLoot["test1"] = {itemId=19019, link="[Thunderfury]", name="Thunderfury", quality=5, slot=1, texture="Interface\\Icons\\INV_Sword_39", winner=nil, status="pending", sessionId="123", timestamp=time()}

/script SOTA_ScannedLoot["test2"] = {itemId=18832, link="[Brutality Blade]", name="Brutality Blade", quality=4, slot=2, texture="Interface\\Icons\\INV_Sword_27", winner=nil, status="pending", sessionId="123", timestamp=time()}

/script SOTA_LA_RefreshList()
/la show
```

## Пошаговое тестирование

### Шаг 1: Проверка загрузки
```lua
/dump SOTA_LA_OpenWindow
```
Должно вернуть: `function`

### Шаг 2: Создать пустую таблицу
```lua
/script SOTA_ScannedLoot = {}
```

### Шаг 3: Добавить простой предмет
```lua
/script SOTA_ScannedLoot.test1 = {itemId=19019, name="Test Item", quality=4, slot=1, status="pending", timestamp=time()}
```

### Шаг 4: Открыть окно
```lua
/la show
```

### Шаг 5: Обновить список
```lua
/script SOTA_LA_RefreshList()
```

## Альтернатива: Тестирование с реальным лутом

Если у вас есть доступ к тестовому серверу:

1. Станьте Master Looter
2. Используйте команду `.additem` (если есть GM права):
```
.additem 19019  # Thunderfury
.additem 18832  # Brutality Blade
```
3. Положите предметы на землю
4. Откройте лут как ML

## Отладка ошибки

Если всё равно ошибка, проверьте:

```lua
-- Проверить, загружен ли модуль
/dump SOTA_ScannedLoot

-- Проверить функцию обновления
/dump SOTA_LA_RefreshList

-- Проверить UI фрейм
/dump getglobal("SOTA_LootAssistantFrame")
```

## Примечание

Проблема была в том, что символ `|` (pipe) в WoW используется для цветовых кодов и ссылок на предметы. В командах через `/script` его нужно экранировать как `\124` (ASCII код) или использовать `string.char(124)`.
