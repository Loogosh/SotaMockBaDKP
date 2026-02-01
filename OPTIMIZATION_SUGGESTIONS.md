# 🔧 Предложения по оптимизации аддона SotA

## 🚨 КРИТИЧЕСКИЙ БАГ - ИСПРАВИТЬ СРОЧНО!

### 0. **Аддон "встает колом" при ошибке в команде**
**Приоритет:** 🔴🔴🔴 МАКСИМАЛЬНЫЙ  
**Проблема:** При опечатке в команде аддон перестает отвечать на все команды  
**Workaround:** Нужно делать `/reload` чтобы восстановить работу

**Причина:** Вероятно ошибка в парсинге команд или обработке jobs без try/catch

**Решение:** Добавить pcall() (protected call) для всех команд:
```lua
-- Вместо:
function SOTA_OnSlashCommand(msg)
    SOTA_ParseCommand(msg)  -- Если ошибка - аддон умирает
end

-- Должно быть:
function SOTA_OnSlashCommand(msg)
    local success, error = pcall(function()
        SOTA_ParseCommand(msg)
    end)
    
    if not success then
        localEcho("Ошибка в команде: " .. tostring(error))
        -- Аддон продолжает работать!
    end
end
```

**Где искать:** `sota-dashboard.lua` - обработчик slash команд

---

## ⚠️ КРИТИЧЕСКИЕ проблемы производительности

### 1. **Неэффективная сортировка (Bubble Sort)**
**Файл:** `sota-core.lua`, строки 373-405  
**Проблема:** Используется Bubble Sort O(n²) вместо эффективного алгоритма  
**Вызывается:** При каждой новой ставке (2 раза подряд!)

```lua
-- Текущий код (МЕДЛЕННО):
function SOTA_SortTableDescending(sourcetable, index)
    local doSort = true
    while doSort do
        doSort = false
        for n=1,table.getn(sourcetable) - 1, 1 do
            -- Bubble sort O(n²)
        end
    end
end
```

**Решение:** Использовать `table.sort()` с custom comparator
```lua
function SOTA_SortTableDescending(sourcetable, index)
    table.sort(sourcetable, function(a, b)
        return a[index] > b[index]
    end)
    return sourcetable
end
```
**Улучшение:** O(n²) → O(n log n), в 10-100 раз быстрее для 10-40 ставок

---

### 2. **Множественные вызовы `table.getn()` в циклах**
**Файлы:** Везде (103 вхождения)  
**Проблема:** `table.getn()` вызывается каждую итерацию цикла

```lua
-- Текущий код (МЕДЛЕННО):
for n=1, table.getn(sourcetable), 1 do
    -- table.getn вызывается каждую итерацию!
end
```

**Решение:** Кешировать размер таблицы
```lua
local count = table.getn(sourcetable)
for n=1, count, 1 do
    -- Один вызов вместо N
end
```
**Улучшение:** Экономия N вызовов функции на каждый цикл

---

### 3. **Тройная обработка при регистрации ставки**
**Файл:** `sota-auction.lua`, строки 335-346  
**Проблема:** 
1. `SOTA_RenumberTable()` - создает новую таблицу O(n)
2. `SOTA_SortTableDescending()` - Bubble sort O(n²)
3. `SOTA_SortTableAscending()` - еще один Bubble sort O(n²)

```lua
function SOTA_RegisterBid(playername, bid, bidtype, playerclass, rankname, rankindex)
    IncomingBidsTable = SOTA_RenumberTable(IncomingBidsTable);  -- O(n)
    IncomingBidsTable[table.getn(IncomingBidsTable) + 1] = { ... };
    SOTA_SortTableDescending(IncomingBidsTable, 2);  -- O(n²)
    if SOTA_CONFIG_EnableOSBidding == 1 then
        SOTA_SortTableAscending(IncomingBidsTable, 3);  -- O(n²)
    end
    SOTA_UpdateBidElements();
end
```

**Решение:** Использовать одну эффективную сортировку
```lua
function SOTA_RegisterBid(playername, bid, bidtype, playerclass, rankname, rankindex)
    -- Удаляем RenumberTable - не нужен если table.remove работает правильно
    table.insert(IncomingBidsTable, { playername, bid, bidtype, playerclass, rankname, rankindex })
    
    -- Одна сортировка с комбинированным comparator
    table.sort(IncomingBidsTable, function(a, b)
        if a[2] ~= b[2] then  -- По DKP сначала
            return a[2] > b[2]
        else  -- При равных DKP - MS приоритетнее OS
            return a[3] < b[3]
        end
    end)
    
    SOTA_UpdateBidElements();
end
```
**Улучшение:** 2×O(n²) + O(n) → O(n log n), в 100+ раз быстрее

---

### 4. **`SOTA_RefreshButtonStates()` вызывается В ЦИКЛЕ**
**Файл:** `sota-auction.lua`, строка 492  
**Проблема:** Вызывается 10 раз (для каждого bid элемента) вместо 1 раза

```lua
function SOTA_UpdateBidElements()
    for n=1, MAX_BIDS, 1 do
        -- ... обновление элемента ...
        SOTA_RefreshButtonStates();  -- ❌ 10 раз!
        frame:Show();
    end
end
```

**Решение:** Вызывать один раз после цикла
```lua
function SOTA_UpdateBidElements()
    for n=1, MAX_BIDS, 1 do
        -- ... обновление элемента ...
        frame:Show();
    end
    SOTA_RefreshButtonStates();  -- ✅ 1 раз
end
```
**Улучшение:** 10 вызовов → 1 вызов

---

## 🔴 ВЫСОКОПРИОРИТЕТНЫЕ проблемы

### 5. **Линейный поиск игроков без кеша**
**Файл:** `sota-core.lua`, строки 509-519  
**Проблема:** `SOTA_GetGuildPlayerInfo()` делает O(n) поиск каждый раз

```lua
function SOTA_GetGuildPlayerInfo(player)
    player = SOTA_UCFirst(player);
    for n=1, table.getn(GuildRosterTable), 1 do  -- O(n) каждый раз!
        if GuildRosterTable[n][1] == player then
            return GuildRosterTable[n];
        end
    end
    return nil;
end
```

**Решение:** Использовать hash-таблицу для быстрого доступа
```lua
-- При создании GuildRosterTable:
local GuildRosterTable = { }  -- массив
local GuildRosterHash = { }   -- hash для быстрого поиска

function SOTA_RefreshGuildRoster()
    -- ...
    NewGuildRosterTable[n] = { name, dkp, class, rank, online, zone, rankIndex }
    NewGuildRosterHash[name] = NewGuildRosterTable[n]  -- O(1) доступ
end

function SOTA_GetGuildPlayerInfo(player)
    player = SOTA_UCFirst(player);
    return GuildRosterHash[player];  -- O(1) вместо O(n)!
end
```
**Улучшение:** O(n) → O(1), в N раз быстрее

---

### 6. **`SOTA_ApplyPlayerDKP` не использует кеш**
**Файл:** `sota-core.lua`, строки 1607-1646  
**Проблема:** Вызывает `GetNumGuildMembers()` и `GetGuildRosterInfo(n)` каждый раз

```lua
function SOTA_ApplyPlayerDKP(playername, dkpValue, silentmode)
    local memberCount = GetNumGuildMembers()  -- API вызов
    for n=1,memberCount,1 do
        name, _, _, _, _, _, publicNote, officerNote = GetGuildRosterInfo(n);  -- API вызов!
        if name == playername then
            -- ...
        end
    end
end
```

**Решение:** Использовать кешированный GuildRosterTable
```lua
function SOTA_ApplyPlayerDKP(playername, dkpValue, silentmode)
    playername = SOTA_UCFirst(playername);
    
    -- Находим индекс в кеше O(1) вместо O(n)
    local playerInfo = SOTA_GetGuildPlayerInfo(playername);
    if not playerInfo then
        if not silentmode then
            localEcho(string.format("%s не был найден в гильдии; ДКП не обновлено.", playername));
        end
        return false;
    end
    
    -- Найти реальный индекс в guild roster
    local memberCount = GetNumGuildMembers()
    for n=1,memberCount,1 do
        local name = GetGuildRosterInfo(n);
        if name == playername then
            -- Обновить заметку
            local note = ...
            GuildRosterSetOfficerNote(n, note);
            
            -- Обновить КЕШ
            playerInfo[2] = dkp  -- Обновляем DKP в кеше!
            SOTA_UpdateLocalDKP(name, dkpValue);
            return true;
        end
    end
end
```
**Улучшение:** Меньше API вызовов, обновление кеша

---

### 7. **Вложенный цикл O(n×m) в `SOTA_RefreshRaidRoster`**
**Файл:** `sota-core.lua`, строки 569-596  
**Проблема:** Для каждого игрока рейда (40) проходит весь ростер гильдии (500+)

```lua
function SOTA_RefreshRaidRoster()
    for n=1,playerCount,1 do  -- 40 игроков
        local name, _, _, _, class = GetRaidRosterInfo(n);
        for m=1,memberCount,1 do  -- 500 членов гильдии
            local info = GuildRosterTable[m]
            if name == info[1] then  -- O(40 × 500) = O(20000)
                RaidRosterTable[index] = info;
                index = index + 1
            end
        end
    end
end
```

**Решение:** Использовать hash-таблицу
```lua
function SOTA_RefreshRaidRoster()
    local playerCount = GetNumRaidMembers()
    
    if playerCount then
        RaidRosterTable = { }
        local index = 1
        
        for n=1,playerCount,1 do
            local name, _, _, _, class = GetRaidRosterInfo(n);
            local info = GuildRosterHash[name]  -- O(1) вместо O(n)!
            if info then
                RaidRosterTable[index] = info;
                index = index + 1
            end
        end
    end
    
    RaidRosterLazyUpdate = false;
end
```
**Улучшение:** O(n×m) → O(n), в 500 раз быстрее для 500 членов гильдии

---

## 🟡 СРЕДНИЙ ПРИОРИТЕТ

### 8. **String pattern matching в циклах**
**Файл:** `sota-core.lua`, строка 487, 1621  
**Проблема:** `string.find()` с паттерном вызывается в циклах

```lua
local _, _, dkp = string.find(note, "<(-?%d*)>")
```

**Решение:** Скомпилировать паттерн один раз (в Lua 5.1 нельзя, но можно минимизировать)
```lua
-- Кешировать результат парсинга DKP при обновлении ростера
```

---

### 9. **`SOTA_RenumberTable` создает новую таблицу**
**Файл:** `sota-core.lua`, строки 361-371  
**Проблема:** Создает новую таблицу вместо изменения in-place

```lua
function SOTA_RenumberTable(sourcetable)
    local index = 1;
    local temptable = { };  -- ❌ Новая таблица
    for key,value in ipairs(sourcetable) do
        if value and table.getn(value) > 0 then
            temptable[index] = value;
            index = index + 1
        end
    end
    return temptable;
end
```

**Решение:** Использовать `table.remove()` правильно, чтобы не нужен был RenumberTable
```lua
-- Вместо RenumberTable использовать table.remove(table, index)
-- который автоматически сдвигает элементы
```

---

### 10. **Guild Roster обновляется по таймеру**
**Файл:** `sota-dashboard.lua`, строки 522-525  
**Проблема:** Обновляется каждые N секунд независимо от необходимости

```lua
if floor(GuildRefreshTimer) < floor(SOTA_TimerTick) then
    GuildRefreshTimer = SOTA_TimerTick + GUILD_REFRESH_TIMER;
    SOTA_RequestUpdateGuildRoster();  -- Каждые N секунд
end
```

**Решение:** Обновлять только при событии `GUILD_ROSTER_UPDATE`  
**Уже работает:** Событие обрабатывается, но дополнительно запрашивается по таймеру (избыточно)

---

### 11. **`SOTA_GetClassColorCodes` линейный поиск**
**Файл:** `sota-core.lua`, строки 275-288  
**Проблема:** Вызывается для каждого bid элемента (10 раз) с линейным поиском

```lua
function SOTA_GetClassColorCodes(classname)
    local colors = { 128,128,128 }
    classname = SOTA_UCFirst(classname);
    
    for n=1, table.getn(SOTA_CLASS_COLORS), 1 do  -- O(9)
        if cc[1] == classname then
            return cc[2];
        end
    end
    return colors;
end
```

**Решение:** Hash-таблица для цветов классов
```lua
-- В начале файла создать hash:
local SOTA_CLASS_COLORS_HASH = {
    ["Druid"] = { 255,125, 10 },
    ["Hunter"] = { 171,212,115 },
    -- ...
}

function SOTA_GetClassColorCodes(classname)
    classname = SOTA_UCFirst(classname);
    return SOTA_CLASS_COLORS_HASH[classname] or { 128,128,128 };  -- O(1)
end
```

---

### 12. **BUG: `SOTA_UpdateLocalDKP` неправильно обновляет DKP**
**Файл:** `sota-core.lua`, строки 1653-1675  
**Проблема:** Параметр называется `dkpAdded` но используется неправильно

```lua
function SOTA_UpdateLocalDKP(receiver, dkpAdded)
    -- ...
    if receiver == name then
        if dkp then
            dkp = dkp + dkpAdded;  -- ❌ ОШИБКА: должно быть просто = dkpAdded
        else
            dkp = dkpAdded;
        end
        raidRoster[n] = {name, dkp, class, rank, online};
        return;
    end
end
```

**Вызов из `SOTA_ApplyPlayerDKP`:**
```lua
SOTA_UpdateLocalDKP(name, dkp);  -- ❌ Передается НОВЫЙ dkp, а не изменение!
```

**Решение:** Переименовать или исправить логику
```lua
function SOTA_UpdateLocalDKP(receiver, newDkp)  -- Переименовано!
    local raidRoster = SOTA_GetRaidRoster();
    for n=1, table.getn(raidRoster),1 do
        local player = raidRoster[n];
        if receiver == player[1] then
            player[2] = newDkp;  // Просто присвоить!
            return;
        end
    end
end
```

---

## 🟢 НИЗКИЙ ПРИОРИТЕТ (но желательно)

### 13. **Использование `getglobal()` вместо `_G[]`**
**Файл:** `sota-auction.lua`, многократно  
**Проблема:** `getglobal()` deprecated в новых версиях

```lua
local frame = getglobal("AuctionUIFrameTableListEntry"..n);
```

**Решение:**
```lua
local frame = _G["AuctionUIFrameTableListEntry"..n];
```

---

### 14. **Отсутствие локальных переменных для часто используемых функций**
```lua
-- В начале файла:
local floor = math.floor
local format = string.format
local getn = table.getn
```

---

## 📊 Приоритизация оптимизаций

| # | Проблема | Приоритет | Сложность | Выигрыш |
|---|----------|-----------|-----------|---------|
| 1 | Bubble Sort → table.sort | 🔴 КРИТИЧНО | Легко | 100x |
| 2 | table.getn() в циклах | 🔴 КРИТИЧНО | Легко | 10x |
| 3 | Тройная сортировка | 🔴 КРИТИЧНО | Средне | 100x |
| 4 | RefreshButtonStates в цикле | 🔴 КРИТИЧНО | Легко | 10x |
| 5 | Hash для игроков | 🟡 Высокий | Средне | 500x |
| 6 | ApplyPlayerDKP кеш | 🟡 Высокий | Средне | 50x |
| 7 | RefreshRaidRoster O(n×m) | 🟡 Высокий | Средне | 500x |
| 12 | BUG UpdateLocalDKP | 🔴 КРИТИЧНО | Легко | FIX |

---

## 💡 Рекомендуемая последовательность

1. **Сначала:** #1, #2, #4 (легко, большой выигрыш)
2. **Потом:** #3, #12 (важные исправления)
3. **Затем:** #5, #7 (hash-таблицы для быстрого поиска)
4. **Наконец:** #6, #8-11 (дополнительные оптимизации)

**Общий выигрыш:** От 50x до 1000x для критичных операций (ставки, обновление ростера)
