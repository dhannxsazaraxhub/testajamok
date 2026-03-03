-- =========================================================
-- ULTRA SMART AUTO KATA - WindUI Build v5.9
-- by dhann x sazaraaax
-- Fix: auto join meja, AFK Hop persist state, auto save cfg
-- =========================================================

-- ══════════════════════════════════════════════════════════
-- SECTION 1 : LOGGER
-- ══════════════════════════════════════════════════════════
local logBuffer    = {}
local MAX_LOGS     = 80
local logParagraph = nil
local logDirty     = false

local function pushLog(line)
    logBuffer[#logBuffer + 1] = line
    if #logBuffer > MAX_LOGS then table.remove(logBuffer, 1) end
    logDirty = true
end

local function flushLogUI()
    if not logDirty or not logParagraph then return end
    logDirty = false
    local s, display = math.max(1, #logBuffer - 19), {}
    for i = s, #logBuffer do display[#display + 1] = logBuffer[i] end
    pcall(function() logParagraph:SetDesc(table.concat(display, "\n")) end)
end

local function log(tag, ...)
    local parts = { "[" .. tag .. "]" }
    for _, v in ipairs({...}) do parts[#parts + 1] = tostring(v) end
    pushLog(table.concat(parts, " "))
end

local function logerr(tag, ...)
    local parts = { "[ERR][" .. tag .. "]" }
    for _, v in ipairs({...}) do parts[#parts + 1] = tostring(v) end
    pushLog("[!] " .. table.concat(parts, " "))
end

log("BOOT", "Script dimulai, game loaded:", game:IsLoaded())

-- ══════════════════════════════════════════════════════════
-- SECTION 2 : ANTI DOUBLE EXECUTE
-- ══════════════════════════════════════════════════════════
if _G.AutoKataActive then
    log("BOOT", "Instance lama ditemukan, destroy...")
    if type(_G.AutoKataDestroy) == "function" then pcall(_G.AutoKataDestroy) end
    task.wait(0.3)
end
_G.AutoKataActive  = true
_G.AutoKataDestroy = nil

-- ══════════════════════════════════════════════════════════
-- SECTION 3 : SAFE SPAWN
-- ══════════════════════════════════════════════════════════
local function safeSpawn(fn, ...)
    local args = {...}
    task.spawn(function()
        local ok, err = xpcall(
            function() fn(table.unpack(args)) end,
            function(e) return tostring(e) .. "\n" .. debug.traceback() end
        )
        if not ok then pushLog("[!] [CRASH] " .. tostring(err):sub(1, 150)) end
    end)
end

-- ══════════════════════════════════════════════════════════
-- SECTION 4 : SERVICES
-- ══════════════════════════════════════════════════════════
if not game:IsLoaded() then game.Loaded:Wait() end

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService   = game:GetService("TeleportService")
local Workspace         = game:GetService("Workspace")
local HttpService       = game:GetService("HttpService")
local Lighting          = game:GetService("Lighting")
local LocalPlayer       = Players.LocalPlayer

local CAN_SAVE = false
pcall(function()
    writefile("_ak_test.tmp","1"); readfile("_ak_test.tmp"); delfile("_ak_test.tmp")
    CAN_SAVE = true
end)
log("BOOT", "CAN_SAVE:", CAN_SAVE, "| Player:", LocalPlayer.Name)

pcall(function() if _G.DestroyDhannRunner then _G.DestroyDhannRunner() end end)
task.delay(0.5, function()
    local gui = LocalPlayer:FindFirstChild("PlayerGui"); if not gui then return end
    for _, name in ipairs({"DhannUltra","DhannClean"}) do
        local o = gui:FindFirstChild(name); if o then o:Destroy() end
    end
end)

-- ══════════════════════════════════════════════════════════
-- SECTION 5 : CONSTANTS
-- ══════════════════════════════════════════════════════════
local CONFIG_FILE     = "autokata_config.json"
local ADMIN_FILE      = "autokata_admin.json"
local RANKING_CACHE   = "autokata_ranking_cache.json"
local DISCORD_WEBHOOK = "https://discord.com/api/webhooks/1478097119079563396/gIxWk9eU5r5erugPGrMR1Y8ad039nSlDl8GP9pFKfZ41asWNjZvejtm1qpJHuESM2Z8j"
local WRONG_WORDS_URL = "https://raw.githubusercontent.com/fay23-dam/sazaraaax-script/refs/heads/main/wordworng/a3x.lua"
local RANKING_URL     = "https://raw.githubusercontent.com/fay23-dam/sazaraaax-script/refs/heads/main/wordworng/ranking_kata%20(1).json"
local INACTIVITY_TIMEOUT = 6
local MAX_RETRY_SUBMIT   = 6

local WORDLIST_LIST = { "Safety Anti Detek (KBBI)", "Ranking Kata (Kompetitif)" }
local WORDLIST_URLS = {
    ["Safety Anti Detek (KBBI)"]  = "https://raw.githubusercontent.com/danzzy1we/roblox-script-dump/refs/heads/main/WordListDump/KBBI_Final_Working.lua",
    ["Ranking Kata (Kompetitif)"] = "__RANKING__",
}
local SPEED_PRESETS = {
    Slow      = { min = 1500, max = 3000 },
    Fast      = { min = 500,  max = 1000 },
    Superfast = { min = 100,  max = 300  },
}
local ADMIN_IDS = {
    -- tambahkan userId admin: 123456789,
}

-- ══════════════════════════════════════════════════════════
-- SECTION 6 : CONFIG STATE
-- Semua setting + AFK Hop disimpan dalam satu tabel cfg.
-- ══════════════════════════════════════════════════════════
local cfg = {
    -- gameplay
    minDelay        = 500,
    maxDelay        = 1000,
    aggression      = 20,
    minLength       = 2,
    maxLength       = 12,
    initialDelay    = 0.0,
    submitDelay     = 1.0,
    activeWordlist  = "Safety Anti Detek (KBBI)",
    autoEnabled     = false,
    -- auto click
    autoClick       = false,
    autoClickDelay  = 1.5,
    -- auto join
    autoJoin        = false,
    tableMode       = "Semua",  -- "Semua" | "2P" | "4P" | "8P"
    -- afk hop
    afkHop          = false,
    afkHopTimeout   = 15,
}

-- ══════════════════════════════════════════════════════════
-- SECTION 7 : SAVE / LOAD CONFIG
-- ══════════════════════════════════════════════════════════
local function saveConfig()
    if not CAN_SAVE then return end
    local ok, enc = pcall(function() return HttpService:JSONEncode(cfg) end)
    if ok then pcall(writefile, CONFIG_FILE, enc) end
    log("CFG", "Saved")
end

local function loadConfig()
    if not CAN_SAVE then return end
    local ok, raw = pcall(readfile, CONFIG_FILE)
    if not ok or not raw or raw == "" then return end
    local ok2, data = pcall(function() return HttpService:JSONDecode(raw) end)
    if not ok2 or type(data) ~= "table" then return end
    for k, v in pairs(data) do
        if cfg[k] ~= nil and type(v) == type(cfg[k]) then cfg[k] = v end
    end
    log("CFG", "Loaded | autoEnabled=" .. tostring(cfg.autoEnabled)
        .. " afkHop=" .. tostring(cfg.afkHop)
        .. " autoJoin=" .. tostring(cfg.autoJoin))
end

-- Auto-load sebelum apapun diinit
loadConfig()

-- ══════════════════════════════════════════════════════════
-- SECTION 8 : ADMIN SYSTEM
-- ══════════════════════════════════════════════════════════
local MAINTENANCE = false
local BLACKLIST   = {}

local function adminSave()
    local bl = {}
    for uid in pairs(BLACKLIST) do bl[#bl+1] = uid end
    local ok, enc = pcall(function()
        return HttpService:JSONEncode({ maintenance = MAINTENANCE, blacklist = bl })
    end)
    if ok then pcall(writefile, ADMIN_FILE, enc) end
end

local function adminLoad()
    local ok, raw = pcall(readfile, ADMIN_FILE)
    if not ok or not raw or raw == "" then return end
    local ok2, data = pcall(function() return HttpService:JSONDecode(raw) end)
    if not ok2 or not data then return end
    if type(data.maintenance) == "boolean" then MAINTENANCE = data.maintenance end
    if type(data.blacklist) == "table" then
        for _, uid in ipairs(data.blacklist) do BLACKLIST[tonumber(uid)] = true end
    end
end

adminLoad()

local function isAdmin(player)
    if not player then return false end
    for _, id in ipairs(ADMIN_IDS) do if id == player.UserId then return true end end
    return false
end

local function checkAccess()
    adminLoad()
    if MAINTENANCE and not isAdmin(LocalPlayer) then
        task.wait(0.1); pcall(function() LocalPlayer:Kick("[AutoKata] Maintenance Mode.") end)
        return false
    end
    if BLACKLIST[LocalPlayer.UserId] then
        task.wait(0.1); pcall(function() LocalPlayer:Kick("[AutoKata] Kamu di-blacklist.") end)
        return false
    end
    return true
end

-- ══════════════════════════════════════════════════════════
-- SECTION 9 : DISCORD WEBHOOK
-- ══════════════════════════════════════════════════════════
local function maskStr(s, keep)
    s = tostring(s); keep = keep or 4
    if #s <= keep then return s end
    return s:sub(1, keep) .. string.rep("*", #s - keep)
end

local function sendDiscordMsg(lines)
    safeSpawn(function()
        local ok, enc = pcall(function()
            return HttpService:JSONEncode({
                content  = table.concat(lines, "\n"),
                username = "DhanxSaza Hub",
            })
        end)
        if not ok then return end
        pcall(function()
            HttpService:PostAsync(DISCORD_WEBHOOK, enc, Enum.HttpContentType.ApplicationJson)
        end)
        log("WEBHOOK", "Terkirim")
    end)
end

local function sendLoginNotif()
    local lp = LocalPlayer
    local ok, gn = pcall(function()
        return game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId).Name
    end)
    local gameName = ok and gn or tostring(game.PlaceId)
    local timeStr  = ""
    pcall(function() timeStr = os.date("!%Y-%m-%d %H:%M:%S") end)
    if timeStr == "" then timeStr = tostring(os.time()) end
    sendDiscordMsg({
        "✅ **DhanxSaza Hub**  - LOGIN",
        "User: `"    .. maskStr(lp.Name,              4) .. "`",
        "User ID: `" .. maskStr(tostring(lp.UserId),  3) .. "`",
        "Game: `"    .. gameName .. "`",
        "Time: `"    .. timeStr  .. "`",
        "DhanxSaza Hub",
    })
end

-- ══════════════════════════════════════════════════════════
-- SECTION 10 : WORDLIST SYSTEM
-- ══════════════════════════════════════════════════════════
local kataModule    = {}
local wordsByLetter = {}
local wrongWordsSet = {}
local rankingMap    = {}

local function flattenWordlist(result)
    if type(result.words) == "table" then
        local f = {}
        for w in pairs(result.words) do f[#f+1] = tostring(w) end
        return f
    end
    if type(result[1]) == "string" then return result end
    local f = {}
    for _, val in pairs(result) do
        if type(val) == "table" then for _, w in ipairs(val) do f[#f+1] = w end end
    end
    return f
end

local function applyWordlist(flat)
    local seen, unique = {}, {}
    for _, w in ipairs(flat) do
        local lw = string.lower(tostring(w))
        if not seen[lw] and #lw > 1 then seen[lw] = true; unique[#unique+1] = lw end
    end
    if #unique > 0 then kataModule = unique; wordsByLetter = {}; return true end
    return false
end

local function loadWordlistFromURL(url)
    local ok, response = pcall(function() return game:HttpGet(url) end)
    if not ok or not response or response == "" then
        logerr("WORDLIST", "HttpGet gagal:", url); return false
    end
    local fn = loadstring(response)
    if fn then
        local ok2, res = pcall(fn)
        if ok2 and type(res) == "table" and applyWordlist(flattenWordlist(res)) then
            log("WORDLIST", "Loaded direct:", #kataModule); return true
        end
    end
    local fixed = response:gsub("%[\"","{\""):gsub("\"%]","\"}")
                          :gsub("%[","{"):gsub("%]","}")
    local fn2 = loadstring(fixed)
    if fn2 then
        local ok3, res2 = pcall(fn2)
        if ok3 and type(res2) == "table" and applyWordlist(flattenWordlist(res2)) then
            log("WORDLIST", "Loaded fallback:", #kataModule); return true
        end
    end
    logerr("WORDLIST", "Gagal:", url); return false
end

local function buildIndex()
    wordsByLetter = {}
    for _, w in ipairs(kataModule) do
        local c = w:sub(1,1)
        if wordsByLetter[c] then wordsByLetter[c][#wordsByLetter[c]+1] = w
        else wordsByLetter[c] = {w} end
    end
    log("INDEX", #kataModule, "kata diindex")
end

local function downloadWrongWords()
    local ok, raw = pcall(function() return game:HttpGet(WRONG_WORDS_URL) end)
    if not ok or not raw then return end
    local fn = loadstring(raw); if not fn then return end
    local ok2, words = pcall(fn)
    if ok2 and type(words) == "table" then
        for _, w in ipairs(words) do
            if type(w) == "string" then wrongWordsSet[w:lower()] = true end
        end
        log("WRONGWORD", #words, "kata")
    end
end

local function loadRanking()
    table.clear(rankingMap)
    if CAN_SAVE then
        local ok, raw = pcall(readfile, RANKING_CACHE)
        if ok and raw and #raw > 100 then
            local ok2, data = pcall(function() return HttpService:JSONDecode(raw) end)
            if ok2 and type(data) == "table" then
                for _, v in ipairs(data) do
                    if type(v) == "table" and type(v.word) == "string" then
                        rankingMap[v.word:lower()] = tonumber(v.score) or 0
                    end
                end
                if next(rankingMap) then log("RANKING", "Dari cache"); return end
            end
        end
    end
    local ok, raw = pcall(function() return game:HttpGet(RANKING_URL) end)
    if not ok or not raw or raw == "" then log("RANKING", "Download gagal"); return end
    local ok2, data = pcall(function() return HttpService:JSONDecode(raw) end)
    if not ok2 or type(data) ~= "table" then return end
    local count = 0
    for _, v in ipairs(data) do
        if type(v) == "table" and type(v.word) == "string" then
            local w = v.word:lower()
            if w:match("^[a-z]+$") then rankingMap[w] = tonumber(v.score) or 0; count = count + 1 end
        end
    end
    log("RANKING", "Loaded:", count)
    if CAN_SAVE and count > 0 then
        local arr = {}
        for w, s in pairs(rankingMap) do arr[#arr+1] = {word=w, score=s} end
        local ok3, enc = pcall(function() return HttpService:JSONEncode(arr) end)
        if ok3 then pcall(writefile, RANKING_CACHE, enc) end
    end
end

-- Boot: load wordlist awal
do
    local url = WORDLIST_URLS[cfg.activeWordlist]
    if url == "__RANKING__" then url = WORDLIST_URLS["Safety Anti Detek (KBBI)"] end
    if not loadWordlistFromURL(url) or #kataModule == 0 then
        logerr("BOOT","Wordlist gagal dimuat!"); return
    end
    log("WORDLIST", "Boot:", cfg.activeWordlist, "|", #kataModule, "kata")
end

-- ══════════════════════════════════════════════════════════
-- SECTION 11 : BOOT SCRIPTS
-- ══════════════════════════════════════════════════════════
local function safeLoadstring(url)
    local ok, raw = pcall(function() return game:HttpGet(url) end)
    if not ok or not raw or raw == "" then return end
    local fn = loadstring(raw); if fn then pcall(fn) end
end
safeLoadstring("https://raw.githubusercontent.com/danzzy1we/gokil2/refs/heads/main/copylinkgithub.lua")
safeLoadstring("https://raw.githubusercontent.com/fay23-dam/sazaraaax-script/refs/heads/main/runner.lua")

-- ══════════════════════════════════════════════════════════
-- SECTION 12 : LOAD WINDUI
-- ══════════════════════════════════════════════════════════
log("WINDUI", "Loading...")
task.wait(3)
local _raw = ""
local _ok = pcall(function()
    _raw = game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua")
end)
if not _ok or _raw == "" then logerr("WINDUI","HttpGet gagal"); return end
local _fn, _fe = loadstring(_raw)
if not _fn then logerr("WINDUI","loadstring gagal:", _fe); return end
local _ok2, WindUI = pcall(_fn)
if not _ok2 or not WindUI then logerr("WINDUI","Init gagal:", WindUI); return end
log("WINDUI", "OK")

-- ══════════════════════════════════════════════════════════
-- SECTION 13 : REMOTES
-- ══════════════════════════════════════════════════════════
local remotes = ReplicatedStorage:WaitForChild("Remotes")

local function waitR(name, timeout)
    local r
    if timeout then pcall(function() r = remotes:WaitForChild(name, timeout) end)
    else r = remotes:WaitForChild(name) end
    if r then log("REMOTE", "OK:", name) end
    return r
end

local MatchUI         = waitR("MatchUI")
local SubmitWord      = waitR("SubmitWord")
local BillboardUpdate = waitR("BillboardUpdate")
local BillboardEnd    = waitR("BillboardEnd", 3)
local TypeSound       = waitR("TypeSound")
local UsedWordWarn    = waitR("UsedWordWarn")
local JoinTable       = waitR("JoinTable")
local LeaveTable      = waitR("LeaveTable")
local PlayerHit       = waitR("PlayerHit",     3)
local PlayerCorrect   = waitR("PlayerCorrect", 3)

local function fireBillboardEnd()
    if BillboardEnd then pcall(function() BillboardEnd:FireServer() end)
    else pcall(function() BillboardUpdate:FireServer("") end) end
end

-- ══════════════════════════════════════════════════════════
-- SECTION 14 : MATCH STATE
-- ══════════════════════════════════════════════════════════
local matchActive        = false
local isMyTurn           = false
local serverLetter       = ""
local usedWords          = {}
local opponentStreamWord = ""
local autoRunning        = false
local lastAttemptedWord  = ""
local lastRejectWord     = ""
local blacklistedWords   = {}
local lastTurnActivity   = 0

local function isUsed(w)    return usedWords[w:lower()] == true end
local function addUsed(w)   usedWords[w:lower()] = true end
local function resetUsed()  usedWords = {} end
local function blacklist(w) blacklistedWords[w:lower()] = true end
local function isBL(w)      return blacklistedWords[w:lower()] == true end

-- ══════════════════════════════════════════════════════════
-- SECTION 15 : SMART WORD SELECTOR
-- ══════════════════════════════════════════════════════════
local function getSmartWords(prefix)
    if #kataModule == 0 or prefix == "" then return {} end
    local lp     = prefix:lower()
    local bucket = (next(wordsByLetter) ~= nil) and wordsByLetter[lp:sub(1,1)] or kataModule
    if not bucket then return {} end

    local bestWord, bestScore = nil, -math.huge
    local results, fallback   = {}, {}

    for _, word in ipairs(bucket) do
        if word:sub(1, #lp) == lp
            and #word > #lp
            and not isUsed(word)
            and not wrongWordsSet[word]
            and not blacklistedWords[word]
        then
            local sc = rankingMap[word]
            if sc and sc > bestScore then bestScore = sc; bestWord = word end
            fallback[#fallback+1] = word
            local len = #word
            if len >= cfg.minLength and len <= cfg.maxLength then results[#results+1] = word end
        end
    end

    if bestWord then return { bestWord } end
    if #results == 0 then results = fallback end
    table.sort(results, function(a,b) return #a > #b end)
    return results
end

-- ══════════════════════════════════════════════════════════
-- SECTION 16 : VIRTUAL INPUT
-- ══════════════════════════════════════════════════════════
local VIM = nil
pcall(function() VIM = game:GetService("VirtualInputManager") end)

local KC = { a=Enum.KeyCode.A,b=Enum.KeyCode.B,c=Enum.KeyCode.C,d=Enum.KeyCode.D,
             e=Enum.KeyCode.E,f=Enum.KeyCode.F,g=Enum.KeyCode.G,h=Enum.KeyCode.H,
             i=Enum.KeyCode.I,j=Enum.KeyCode.J,k=Enum.KeyCode.K,l=Enum.KeyCode.L,
             m=Enum.KeyCode.M,n=Enum.KeyCode.N,o=Enum.KeyCode.O,p=Enum.KeyCode.P,
             q=Enum.KeyCode.Q,r=Enum.KeyCode.R,s=Enum.KeyCode.S,t=Enum.KeyCode.T,
             u=Enum.KeyCode.U,v=Enum.KeyCode.V,w=Enum.KeyCode.W,x=Enum.KeyCode.X,
             y=Enum.KeyCode.Y,z=Enum.KeyCode.Z }
local SC = { a=65,b=66,c=67,d=68,e=69,f=70,g=71,h=72,i=73,j=74,
             k=75,l=76,m=77,n=78,o=79,p=80,q=81,r=82,s=83,t=84,
             u=85,v=86,w=87,x=88,y=89,z=90 }

local function findTextBox()
    local gui = LocalPlayer:FindFirstChild("PlayerGui"); if not gui then return nil end
    local function find(p)
        for _, c in ipairs(p:GetChildren()) do
            if c:IsA("TextBox") then return c end
            local r = find(c); if r then return r end
        end
    end
    return find(gui)
end

local function focusTB()
    local tb = findTextBox()
    if tb then pcall(function() tb:CaptureFocus() end) end
end

local function getTBText()
    local tb = findTextBox(); return tb and (tb.Text or "") or ""
end

local function sendKey(char)
    local c = char:lower()
    if VIM then
        local kc = KC[c]
        if kc then
            pcall(function()
                VIM:SendKeyEvent(true, kc, false, game); task.wait(0.025)
                VIM:SendKeyEvent(false, kc, false, game)
            end)
        end
    elseif keypress and keyrelease then
        local sc = SC[c]; if sc then keypress(sc); task.wait(0.02); keyrelease(sc) end
    else
        pcall(function() local tb = findTextBox(); if tb then tb.Text = tb.Text .. c end end)
    end
end

local function sendBackspace()
    if VIM then
        pcall(function()
            VIM:SendKeyEvent(true, Enum.KeyCode.Backspace, false, game); task.wait(0.025)
            VIM:SendKeyEvent(false, Enum.KeyCode.Backspace, false, game)
        end)
    elseif keypress and keyrelease then
        keypress(8); task.wait(0.02); keyrelease(8)
    else
        pcall(function()
            local tb = findTextBox()
            if tb and #tb.Text > 0 then tb.Text = tb.Text:sub(1,-2) end
        end)
    end
end

local function deleteExtraChars(startLetter)
    local extra = #getTBText() - #startLetter
    if extra <= 0 then return end
    focusTB(); task.wait(0.04)
    for _ = 1, extra do sendBackspace(); task.wait(0.025) end
end

local function humanDelay()
    local mn = cfg.minDelay; local mx = cfg.maxDelay
    if mn > mx then mn = mx end
    task.wait(math.random(mn, mx) / 1000)
end

-- ══════════════════════════════════════════════════════════
-- SECTION 17 : AUTO CLICK
-- ══════════════════════════════════════════════════════════
local function doAutoClick()
    if not cfg.autoClick then return end
    task.wait(cfg.autoClickDelay)
    log("AUTOCLICK", "Backend berjalan...")

    local gui = LocalPlayer:FindFirstChild("PlayerGui")
    if gui then
        for _, obj in ipairs(gui:GetDescendants()) do
            if (obj:IsA("TextButton") or obj:IsA("ImageButton")) and obj.Visible then
                local name = obj.Name:lower()
                local text = (obj:IsA("TextButton") and obj.Text:lower()) or ""
                if name:find("play") or name:find("lagi") or name:find("again")
                   or name:find("continue") or name:find("close") or name:find("ok")
                   or text:find("main lagi") or text:find("play again") or text:find("lanjut")
                then
                    pcall(function()
                        if VIM then
                            local ap = obj.AbsolutePosition; local as = obj.AbsoluteSize
                            local cx = ap.X + as.X/2; local cy = ap.Y + as.Y/2
                            VIM:SendMouseMoveEvent(cx, cy, game);                task.wait(0.05)
                            VIM:SendMouseButtonEvent(cx, cy, 0, true,  game, 1); task.wait(0.05)
                            VIM:SendMouseButtonEvent(cx, cy, 0, false, game, 1)
                        else
                            obj.Activated:Fire()
                        end
                    end)
                    log("AUTOCLICK", "Klik:", obj.Name); return
                end
            end
        end
    end

    pcall(function()
        local vp = Workspace.CurrentCamera.ViewportSize
        if VIM then
            VIM:SendMouseButtonEvent(vp.X/2, vp.Y/2, 0, true,  game, 1); task.wait(0.08)
            VIM:SendMouseButtonEvent(vp.X/2, vp.Y/2, 0, false, game, 1)
        end
    end)
    log("AUTOCLICK", "Fallback tengah layar")
end

-- ══════════════════════════════════════════════════════════
-- SECTION 18 : SEAT MONITORING & CLEAR
-- ══════════════════════════════════════════════════════════
local function clearToStartWord()
    if serverLetter == "" then return end
    local cur = (lastAttemptedWord ~= "" and lastAttemptedWord)
             or (opponentStreamWord ~= "" and opponentStreamWord)
             or serverLetter
    while #cur > #serverLetter do
        cur = cur:sub(1, -2)
        pcall(function() BillboardUpdate:FireServer(cur) end)
        pcall(function() TypeSound:FireServer() end)
        task.wait(0.08)
    end
    fireBillboardEnd()
    lastAttemptedWord = ""
end

local currentTableName = nil
local tableTarget      = nil
local seatStates       = {}

local function getSeatPlayer(seat)
    if seat and seat.Occupant then
        local char = seat.Occupant.Parent
        if char then return Players:GetPlayerFromCharacter(char) end
    end
end

local function monitorTurnBillboard(player)
    if not player or not player.Character then return nil end
    local head = player.Character:FindFirstChild("Head");  if not head then return nil end
    local bb   = head:FindFirstChild("TurnBillboard");     if not bb   then return nil end
    local tl   = bb:FindFirstChildOfClass("TextLabel");    if not tl   then return nil end
    return { Billboard = bb, TextLabel = tl, LastText = "", Player = player }
end

local function setupSeatMonitoring()
    seatStates = {}; tableTarget = nil
    if not currentTableName then return end
    local tf = Workspace:FindFirstChild("Tables"); if not tf then return end
    tableTarget = tf:FindFirstChild(currentTableName); if not tableTarget then return end
    local sc = tableTarget:FindFirstChild("Seats"); if not sc then return end
    for _, seat in ipairs(sc:GetChildren()) do
        if seat:IsA("Seat") then seatStates[seat] = { Current = nil } end
    end
    log("SEAT", "Setup:", currentTableName)
end

local _startUltraAI  -- forward decl

-- Seat monitor loop
safeSpawn(function()
    while _G.AutoKataActive do
        local ok, err = pcall(function()
            if matchActive and tableTarget then
                if isMyTurn and cfg.autoEnabled and tick() - lastTurnActivity > INACTIVITY_TIMEOUT then
                    lastTurnActivity = tick(); autoRunning = false
                    safeSpawn(function() _startUltraAI() end)
                end
                for seat, state in pairs(seatStates) do
                    local plr = getSeatPlayer(seat)
                    if plr and plr ~= LocalPlayer then
                        if not state.Current or state.Current.Player ~= plr then
                            state.Current = monitorTurnBillboard(plr)
                        end
                        if state.Current then
                            local tl = state.Current.TextLabel
                            if tl then state.Current.LastText = tl.Text end
                            if not state.Current.Billboard or not state.Current.Billboard.Parent then
                                if state.Current.LastText ~= "" then addUsed(state.Current.LastText) end
                                state.Current = nil
                            end
                        end
                    else state.Current = nil end
                end
            end
        end)
        if not ok then log("SEATMON","Error:", tostring(err)) end
        task.wait(1/6)
    end
end)

LocalPlayer.AttributeChanged:Connect(function(attr)
    if attr ~= "CurrentTable" then return end
    currentTableName = LocalPlayer:GetAttribute("CurrentTable")
    if currentTableName then setupSeatMonitoring() else seatStates = {}; tableTarget = nil end
end)
currentTableName = LocalPlayer:GetAttribute("CurrentTable")
if currentTableName then setupSeatMonitoring() end

-- ══════════════════════════════════════════════════════════
-- SECTION 19 : AUTO ENGINE
-- ══════════════════════════════════════════════════════════
local function submitAndRetry(startLetter)
    for attempt = 1, MAX_RETRY_SUBMIT do
        if not matchActive or not cfg.autoEnabled then return false end
        if attempt > 1 then task.wait(0.2) end

        local words = {}
        for _, w in ipairs(getSmartWords(startLetter)) do
            if not isBL(w) then words[#words+1] = w end
        end
        if #words == 0 then return false end

        local sel = words[1]
        if #words > 1 and cfg.aggression < 100 then
            local topN = math.min(math.max(1, math.floor(#words * (1 - cfg.aggression/100))), #words)
            sel = words[math.random(1, topN)]
        end

        focusTB(); task.wait(0.05)
        local cur, aborted = startLetter, false
        for i = 1, #sel - #startLetter do
            if not matchActive or not cfg.autoEnabled then aborted = true; break end
            local ch = sel:sub(#startLetter + i, #startLetter + i)
            cur = cur .. ch
            pcall(function() sendKey(ch) end)
            pcall(function() TypeSound:FireServer() end)
            pcall(function() BillboardUpdate:FireServer(cur) end)
            task.wait(math.random(cfg.minDelay, cfg.maxDelay) / 1000)
        end
        if aborted or not matchActive or not cfg.autoEnabled then return false end

        if cfg.submitDelay > 0 then task.wait(cfg.submitDelay) end
        if not matchActive or not cfg.autoEnabled then return false end

        lastRejectWord = ""; lastAttemptedWord = sel
        pcall(function() SubmitWord:FireServer(sel) end)
        task.wait(0.35)

        if lastRejectWord == sel:lower() then
            blacklist(sel); deleteExtraChars(startLetter); task.wait(0.15)
        else
            addUsed(sel); lastAttemptedWord = ""; fireBillboardEnd(); return true
        end
    end
    blacklistedWords = {}; fireBillboardEnd(); return false
end

_startUltraAI = function()
    if autoRunning or not cfg.autoEnabled or not matchActive or not isMyTurn then return end
    if serverLetter == "" then
        local w = 0
        while serverLetter == "" and w < 5 do task.wait(0.1); w = w + 0.1 end
        if serverLetter == "" then return end
    end
    if autoRunning then return end
    autoRunning = true; lastTurnActivity = tick()
    if cfg.initialDelay > 0 then
        task.wait(cfg.initialDelay)
        if not matchActive or not isMyTurn then autoRunning = false; return end
    end
    humanDelay()
    pcall(function() submitAndRetry(serverLetter) end)
    autoRunning = false
end

-- ══════════════════════════════════════════════════════════
-- SECTION 20 : WINDUI WINDOW
-- ══════════════════════════════════════════════════════════
local Window = WindUI:CreateWindow({
    Title         = "Sambung-kata",
    Icon          = "zap",
    Author        = "by dhann x sazaraaax",
    Folder        = "SambungKata",
    Size          = UDim2.fromOffset(580, 490),
    Theme         = "Dark",
    Resizable     = true,
    HideSearchBar = true,
    User = {
        Enabled   = true,
        Anonymous = false,
        Callback  = function()
            WindUI:Notify({
                Title    = LocalPlayer.Name,
                Content  = "ID: " .. LocalPlayer.UserId .. " | Age: " .. LocalPlayer.AccountAge .. " hari",
                Duration = 4, Icon = "user",
            })
        end,
    },
})

if not checkAccess() then return end

local function notify(title, content, duration)
    WindUI:Notify({ Title = title, Content = content, Duration = duration or 2.5, Icon = "bell" })
end

-- ══════════════════════════════════════════════════════════
-- SECTION 21 : AUTO JOIN + AFK HOP SYSTEM
-- (dideklarasi dulu agar bisa dipakai di Destroy & UI)
-- ══════════════════════════════════════════════════════════
local SCAN_INTERVAL = 1.2

local autoJoinEnabled = false
local autoJoinThread  = nil
local currentJoinTable = nil

-- Refs untuk toggle UI (di-set setelah UI dibuat)
local uiAutoJoinToggle = nil
local uiAfkHopToggle   = nil

local afkHopEnabled  = false
local afkHopThread   = nil
local afkHopHopping  = false

-- ---------- helper seat / table ----------

local function getHumanoid()
    local char = LocalPlayer.Character
    if not char then return nil end
    return char:FindFirstChildOfClass("Humanoid")
end

local function isSeated()
    local h = getHumanoid(); return h ~= nil and h.SeatPart ~= nil
end

local function leaveSeat()
    local h = getHumanoid()
    if h and h.SeatPart then pcall(function() h.Sit = false end) end
end

-- Hitung berapa seat yang terisi (ada SeatWeld di dalam Seat)
local function countFilledSeats(model)
    local sf = model:FindFirstChild("Seats"); if not sf then return 0 end
    local n = 0
    for _, seat in ipairs(sf:GetChildren()) do
        if seat:IsA("Seat") and seat:FindFirstChild("SeatWeld") then
            n = n + 1
        end
    end
    return n
end

-- Hitung total seat di meja
local function countTotalSeats(model)
    local sf = model:FindFirstChild("Seats"); if not sf then return 0 end
    local n = 0
    for _, seat in ipairs(sf:GetChildren()) do
        if seat:IsA("Seat") then n = n + 1 end
    end
    return n
end

-- Cari ProximityPrompt aktif di meja (ada = meja masih bisa join)
local function findActivePrompt(model)
    for _, d in ipairs(model:GetDescendants()) do
        if d:IsA("ProximityPrompt") and d.Enabled then return d end
    end
    return nil
end

-- Fire prompt — tidak ada teleport, langsung fire
local function pressPrompt(model, prompt)
    log("AUTOJOIN","Fire prompt:", model.Name, "|", prompt:GetFullName())

    if fireproximityprompt then
        pcall(function() fireproximityprompt(prompt) end)
    else
        pcall(function() prompt:InputHoldBegin() end)
        task.wait(0.3)
        pcall(function() prompt:InputHoldEnd() end)
    end

    -- Tunggu konfirmasi duduk max 2.5 detik
    local t = 0
    while t < 2.5 do
        task.wait(0.1); t = t + 0.1
        if isSeated() then return true end
    end
    return false
end

-- Cek apakah ada player lain di meja mana pun
local function hasPlayerAtAnyTable()
    local tf = Workspace:FindFirstChild("Tables")
    if not tf then
        -- fallback: cek jumlah player di server
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer then return true end
        end
        return false
    end
    for _, model in ipairs(tf:GetChildren()) do
        if model:IsA("Model") then
            local sf = model:FindFirstChild("Seats")
            if sf then
                for _, seat in ipairs(sf:GetChildren()) do
                    if seat:IsA("Seat") and seat.Occupant then
                        local char = seat.Occupant.Parent
                        local plr = char and Players:GetPlayerFromCharacter(char)
                        if plr and plr ~= LocalPlayer then return true end
                    end
                end
            end
        end
    end
    return false
end

-- ---------- auto join ----------

local function stopAutoJoin()
    autoJoinEnabled  = false
    currentJoinTable = nil
    if autoJoinThread then pcall(task.cancel, autoJoinThread); autoJoinThread = nil end
end

local function startAutoJoin()
    stopAutoJoin()
    autoJoinEnabled = true
    log("AUTOJOIN","Loop dimulai | mode="..cfg.tableMode)

    autoJoinThread = task.spawn(function()
        while autoJoinEnabled and _G.AutoKataActive do
            pcall(function()
                -- Sudah duduk: cek apakah masih valid
                if currentJoinTable then
                    if not isSeated() then
                        log("AUTOJOIN","Keluar dari meja, reset target")
                        currentJoinTable = nil
                    end
                    return
                end

                if isSeated() then return end

                local tf = Workspace:FindFirstChild("Tables"); if not tf then return end

                -- Tentukan prioritas berdasarkan tableMode
                -- Format nama meja: Table_2P_1, Table_4P_2, Table_8P, dst
                local priorities
                if cfg.tableMode == "2P" then
                    priorities = {"2P"}
                elseif cfg.tableMode == "4P" then
                    priorities = {"4P"}
                elseif cfg.tableMode == "8P" then
                    priorities = {"8P"}
                else
                    -- "Semua": prioritas 8P > 4P > 2P
                    priorities = {"8P","4P","2P"}
                end

                local bestModel  = nil
                local bestFilled = -1
                local bestPrompt = nil

                for _, pri in ipairs(priorities) do
                    for _, model in ipairs(tf:GetChildren()) do
                        -- Cocokkan nama: Table_4P_1, Table_4P, Table_4P_2, dll
                        -- Gunakan pattern "_XP" agar tidak salah match (misal 2P tidak match 4P)
                        if model:IsA("Model") and model.Name:match("_"..pri) then
                            local prompt = findActivePrompt(model)
                            if prompt then
                                local filled = countFilledSeats(model)
                                local total  = countTotalSeats(model)

                                -- Ada player (SeatWeld ≥ 1) dan masih ada kursi kosong
                                if filled >= 1 and filled < total then
                                    log("AUTOJOIN","Kandidat:", model.Name,
                                        "filled="..filled.."/"..total)
                                    if filled > bestFilled then
                                        bestModel  = model
                                        bestFilled = filled
                                        bestPrompt = prompt
                                    end
                                end
                            end
                        end
                    end
                    if bestModel then break end
                end

                if bestModel then
                    log("AUTOJOIN","Join:", bestModel.Name, "filled="..bestFilled)
                    local ok = pressPrompt(bestModel, bestPrompt)
                    if ok then
                        currentJoinTable = bestModel.Name
                        log("AUTOJOIN","Berhasil duduk di:", bestModel.Name)
                    else
                        log("AUTOJOIN","Gagal duduk di:", bestModel.Name)
                    end
                else
                    log("AUTOJOIN","Tidak ada meja ["..cfg.tableMode.."] valid (ProximityPrompt + SeatWeld)")
                end
            end)
            task.wait(SCAN_INTERVAL)
        end
        log("AUTOJOIN","Loop selesai")
    end)
end

-- ---------- afk hop ----------

local function doHopServer()
    if afkHopHopping then return end
    afkHopHopping = true
    log("AFKHOP","Hop! Tidak ada player, pindah server...")
    pcall(notify, "[HOP]", "Pindah server...", 3)
    task.wait(1.5)

    -- Coba beberapa metode teleport
    local hopped = false
    if not hopped then
        hopped = pcall(function()
            local servers = TeleportService:GetJobsInfoAsync(game.PlaceId)
            if servers and #servers > 0 then
                -- Pilih server yang bukan server ini
                for _, s in ipairs(servers) do
                    if s.JobId ~= game.JobId then
                        TeleportService:TeleportToPlaceInstance(game.PlaceId, s.JobId, LocalPlayer)
                        return
                    end
                end
            end
        end)
    end

    if not hopped then
        hopped = pcall(function()
            TeleportService:Teleport(game.PlaceId, LocalPlayer)
        end)
    end

    if not hopped then
        log("AFKHOP","Semua metode teleport gagal, reset timer")
        afkHopHopping = false
    end
end

local function stopAfkHop()
    afkHopEnabled = false
    if afkHopThread then pcall(task.cancel, afkHopThread); afkHopThread = nil end
    afkHopHopping = false
    log("AFKHOP","Dinonaktifkan")
end

local function startAfkHop()
    stopAfkHop()
    afkHopEnabled = true
    afkHopHopping = false
    log("AFKHOP","Aktif | Timeout:", cfg.afkHopTimeout, "detik")

    afkHopThread = task.spawn(function()
        local noPlayerTimer = 0
        while afkHopEnabled and _G.AutoKataActive do
            pcall(function()
                if afkHopHopping then return end

                if matchActive or hasPlayerAtAnyTable() then
                    if noPlayerTimer > 0 then
                        log("AFKHOP","Player ditemukan, reset timer")
                        noPlayerTimer = 0
                    end
                    return
                end

                noPlayerTimer = noPlayerTimer + 2
                log("AFKHOP","Tidak ada player... ("..noPlayerTimer.."/"..cfg.afkHopTimeout.."s)")

                if noPlayerTimer >= cfg.afkHopTimeout then
                    noPlayerTimer = 0
                    doHopServer()
                end
            end)
            task.wait(2)
        end
        log("AFKHOP","Loop selesai")
    end)
end

-- ---------- Destroy ----------
_G.AutoKataDestroy = function()
    cfg.autoEnabled  = false
    autoRunning      = false
    matchActive      = false
    isMyTurn         = false
    pcall(stopAutoJoin)
    pcall(stopAfkHop)
    pcall(function() Window:Destroy() end)
    _G.AutoKataActive  = false
    _G.AutoKataDestroy = nil
end

-- ══════════════════════════════════════════════════════════
-- TAB MAIN
-- ══════════════════════════════════════════════════════════
local MainTab = Window:Tab({ Title = "Main", Icon = "home" })

local getWordsToggle, autoToggle

autoToggle = MainTab:Toggle({
    Title = "Aktifkan Auto", Desc = "Aktifkan mode auto play", Icon = "zap",
    Value = cfg.autoEnabled,
    Callback = function(v)
        cfg.autoEnabled = v
        if v then
            if getWordsToggle then getWordsToggle:Set(false) end
            notify("[ZAP] AUTO", "Auto ON - " .. cfg.activeWordlist, 3)
            if matchActive and isMyTurn and serverLetter ~= "" then safeSpawn(_startUltraAI) end
        else
            autoRunning = false
            notify("[ZAP] AUTO", "Auto OFF", 3)
        end
        saveConfig()
    end,
})

MainTab:Dropdown({
    Title = "Opsi Wordlist", Desc = "Pilih kamus kata", Icon = "database",
    Values = WORDLIST_LIST, Value = cfg.activeWordlist, Multi = false,
    Callback = function(sel)
        if not sel or sel == cfg.activeWordlist then return end
        cfg.activeWordlist = sel
        notify("[PKG] WORDLIST", "Loading " .. sel .. "...", 3)
        safeSpawn(function()
            if WORDLIST_URLS[sel] == "__RANKING__" then
                if not next(rankingMap) then
                    local w = 0
                    while not next(rankingMap) and w < 15 do task.wait(0.5); w = w + 0.5 end
                end
                local words = {}
                for word in pairs(rankingMap) do words[#words+1] = word end
                kataModule = words; buildIndex(); resetUsed()
                notify("[OK] RANKING", #kataModule .. " kata kompetitif", 4)
            else
                if loadWordlistFromURL(WORDLIST_URLS[sel]) then
                    buildIndex(); resetUsed()
                    notify("[OK] WORDLIST", sel .. " | " .. #kataModule .. " kata", 4)
                else
                    notify("[X] WORDLIST", "Gagal load!", 4)
                end
            end
            saveConfig()
        end)
    end,
})

MainTab:Slider({
    Title = "Aggression", Desc = "Agresivitas pemilihan kata", Icon = "trending-up",
    Value = { Min=0, Max=100, Default=cfg.aggression, Decimals=0, Suffix="%" },
    Callback = function(v) cfg.aggression = v; saveConfig() end,
})

local detikMode         = false
local minInput, maxInput, speedDrop

local function parseNum(str)
    if type(str) ~= "string" then return nil end
    return tonumber(str:gsub(",","."):match("^%s*(.-)%s*$"))
end

MainTab:Toggle({
    Title = "Detik Mode", Desc = "ON = input manual | OFF = preset speed", Icon = "clock", Value = false,
    Callback = function(v)
        detikMode = v
        if v then
            pcall(function() minInput:Unlock() end); pcall(function() maxInput:Unlock() end)
            pcall(function() speedDrop:Lock() end)
        else
            pcall(function() minInput:Lock() end); pcall(function() maxInput:Lock() end)
            pcall(function() speedDrop:Unlock() end)
        end
    end,
})

minInput = MainTab:Input({
    Title = "Min Delay (detik)", Desc = "Delay min antar ketukan (maks 5,0)", Icon = "timer", Placeholder = "0,5",
    Callback = function(raw)
        local n = parseNum(raw)
        if not n then notify("[X]","Min bukan angka valid",3); return end
        n = math.max(0, math.min(n, 5))
        if n > cfg.maxDelay/1000 then n = cfg.maxDelay/1000 end
        cfg.minDelay = math.floor(n*1000)
        notify("[OK] MIN DELAY", n .. " detik", 2); saveConfig()
    end,
})
pcall(function() minInput:Lock() end)

maxInput = MainTab:Input({
    Title = "Max Delay (detik)", Desc = "Delay max antar ketukan (maks 5,0)", Icon = "timer", Placeholder = "1,5",
    Callback = function(raw)
        local n = parseNum(raw)
        if not n then notify("[X]","Max bukan angka valid",3); return end
        n = math.max(0, math.min(n, 5))
        if n < cfg.minDelay/1000 then n = cfg.minDelay/1000 end
        cfg.maxDelay = math.floor(n*1000)
        notify("[OK] MAX DELAY", n .. " detik", 2); saveConfig()
    end,
})
pcall(function() maxInput:Lock() end)

speedDrop = MainTab:Dropdown({
    Title = "Kecepatan", Desc = "Preset kecepatan ngetik", Icon = "gauge",
    Values = {"Slow","Fast","Superfast"}, Value = "Fast", Multi = false,
    Callback = function(sel)
        if not sel then return end
        local p = SPEED_PRESETS[sel]
        if p then cfg.minDelay = p.min; cfg.maxDelay = p.max end
        notify("[ZAP] SPEED", sel, 2); saveConfig()
    end,
})

MainTab:Input({
    Title = "Jeda Awal (detik)", Desc = "Jeda sebelum bot mulai ngetik (maks 3,0)", Icon = "hourglass", Placeholder = "1,5",
    Callback = function(raw)
        local n = parseNum(raw); if not n then notify("[X]","Angka tidak valid",3); return end
        cfg.initialDelay = math.max(0, math.min(n, 3))
        notify("[OK] JEDA AWAL", cfg.initialDelay .. " detik", 2); saveConfig()
    end,
})

MainTab:Input({
    Title = "Jeda Submit (detik)", Desc = "Jeda setelah ngetik, sebelum submit (maks 5,0)", Icon = "timer", Placeholder = "1,0",
    Callback = function(raw)
        local n = parseNum(raw); if not n then notify("[X]","Angka tidak valid",3); return end
        cfg.submitDelay = math.max(0, math.min(n, 5))
        notify("[OK] JEDA SUBMIT", cfg.submitDelay .. " detik", 2); saveConfig()
    end,
})

MainTab:Slider({
    Title = "Min Word Length", Desc = "Panjang kata minimum", Icon = "type",
    Value = { Min=2, Max=20, Default=cfg.minLength, Decimals=0 },
    Callback = function(v) cfg.minLength = v; saveConfig() end,
})

MainTab:Slider({
    Title = "Max Word Length", Desc = "Panjang kata maksimum", Icon = "type",
    Value = { Min=5, Max=20, Default=cfg.maxLength, Decimals=0 },
    Callback = function(v) cfg.maxLength = v; saveConfig() end,
})

local statusPara = MainTab:Paragraph({ Title = "Status", Desc = "Menunggu..." })

local function updateStatus()
    if not matchActive then pcall(function() statusPara:SetDesc("Match tidak aktif | - | -") end); return end
    local name, turn = "-", "Menunggu..."
    if isMyTurn then
        name = "Anda"; turn = "Giliran Anda"
    else
        for _, st in pairs(seatStates) do
            if st.Current and st.Current.Billboard and st.Current.Billboard.Parent then
                name = st.Current.Player.Name; turn = "Giliran " .. name; break
            end
        end
    end
    pcall(function()
        statusPara:SetDesc(name .. " | " .. turn .. " | " .. (serverLetter ~= "" and serverLetter or "-"))
    end)
end

-- ══════════════════════════════════════════════════════════
-- TAB SELECT WORD
-- ══════════════════════════════════════════════════════════
local SelectTab = Window:Tab({ Title = "Select Word", Icon = "search" })

local getWordsEnabled = false
local maxWordsShow    = 50
local selectedWord    = nil
local wordDrop        = nil

local function refreshWordDrop()
    if not wordDrop then return end
    if not getWordsEnabled or not isMyTurn or serverLetter == "" then
        pcall(function() wordDrop:Refresh({}) end); selectedWord = nil; return
    end
    local words, limited = getSmartWords(serverLetter), {}
    for i = 1, math.min(#words, maxWordsShow) do limited[#limited+1] = words[i] end
    if #limited == 0 then pcall(function() wordDrop:Refresh({}) end); selectedWord = nil; return end
    pcall(function() wordDrop:Refresh(limited) end)
    selectedWord = limited[1]
    pcall(function() wordDrop:Set(limited[1]) end)
end

getWordsToggle = SelectTab:Toggle({
    Title = "Get Words", Desc = "Tampilkan daftar kata tersedia", Icon = "book-open", Value = false,
    Callback = function(v)
        getWordsEnabled = v
        if v then
            if autoToggle then autoToggle:Set(false) end
            notify("[ON] SELECT", "Get Words ON", 3)
        else notify("[OFF] SELECT", "Get Words OFF", 3) end
        refreshWordDrop()
    end,
})

SelectTab:Slider({
    Title = "Max Words", Desc = "Jumlah max kata ditampilkan", Icon = "hash",
    Value = { Min=1, Max=100, Default=50, Decimals=0 },
    Callback = function(v) maxWordsShow = v; refreshWordDrop() end,
})

wordDrop = SelectTab:Dropdown({
    Title = "Pilih Kata", Desc = "Pilih kata untuk diketik", Icon = "chevrons-up-down",
    Values = {}, Value = nil, Multi = false,
    Callback = function(opt) selectedWord = opt or nil end,
})

SelectTab:Button({
    Title = "Ketik Kata Terpilih", Desc = "Ketik kata yang dipilih ke game", Icon = "send",
    Callback = function()
        if not getWordsEnabled or not isMyTurn or not selectedWord or serverLetter == "" then return end
        local word = selectedWord; local cur = serverLetter
        for i = #serverLetter + 1, #word do
            if not matchActive or not isMyTurn then return end
            cur = cur .. word:sub(i,i)
            pcall(function() TypeSound:FireServer() end)
            pcall(function() BillboardUpdate:FireServer(cur) end)
            humanDelay()
        end
        humanDelay()
        pcall(function() SubmitWord:FireServer(word) end)
        addUsed(word); humanDelay(); fireBillboardEnd()
    end,
})

-- ══════════════════════════════════════════════════════════
-- TAB PLAYER — save / load config
-- ══════════════════════════════════════════════════════════
local PlayerTab = Window:Tab({ Title = "Player", Icon = "user" })

PlayerTab:Paragraph({
    Title = "Save & Load Config",
    Desc  = "Semua setting otomatis disimpan.\nSaat script di-execute, config terakhir otomatis di-load.",
})

local cfgSummaryPara = PlayerTab:Paragraph({ Title = "Config Tersimpan", Desc = "(belum ada)" })

local function refreshCfgSummary()
    local exists = false
    if CAN_SAVE then pcall(function() readfile(CONFIG_FILE); exists = true end) end
    if not exists then
        pcall(function() cfgSummaryPara:SetDesc("(belum ada config tersimpan)") end); return
    end
    pcall(function()
        cfgSummaryPara:SetDesc(table.concat({
            "Wordlist    : " .. cfg.activeWordlist,
            "Delay       : " .. (cfg.minDelay/1000) .. "s – " .. (cfg.maxDelay/1000) .. "s",
            "Aggression  : " .. cfg.aggression .. "%",
            "Jeda Awal   : " .. cfg.initialDelay .. "s",
            "Jeda Submit : " .. cfg.submitDelay .. "s",
            "Min Length  : " .. cfg.minLength,
            "Max Length  : " .. cfg.maxLength,
            "Auto        : " .. (cfg.autoEnabled  and "ON" or "OFF"),
            "AutoClick   : " .. (cfg.autoClick    and "ON" or "OFF"),
            "AutoJoin    : " .. (cfg.autoJoin     and "ON" or "OFF") .. " [" .. cfg.tableMode .. "]",
            "AFK Hop     : " .. (cfg.afkHop       and "ON" or "OFF"),
            "Hop Timeout : " .. cfg.afkHopTimeout .. "s",
        }, "\n"))
    end)
end

PlayerTab:Button({
    Title = "💾 Save Config Sekarang", Desc = "Simpan semua setting ke file lokal", Icon = "save",
    Callback = function()
        saveConfig(); refreshCfgSummary()
        notify("[OK] SAVE", "Config berhasil disimpan!", 3)
    end,
})

PlayerTab:Button({
    Title = "📂 Load Config", Desc = "Muat ulang config dari file lokal", Icon = "folder-open",
    Callback = function()
        loadConfig(); refreshCfgSummary()
        notify("[OK] LOAD", "Config berhasil di-load!", 3)
    end,
})

PlayerTab:Button({
    Title = "🗑️ Reset Config", Desc = "Hapus file config (kembali ke default)", Icon = "trash-2",
    Callback = function()
        if CAN_SAVE then pcall(delfile, CONFIG_FILE) end
        refreshCfgSummary()
        notify("[OK] RESET", "Config dihapus, pakai default", 3)
    end,
})

PlayerTab:Paragraph({ Title = "Auto Click", Desc = "Klik otomatis di background setelah match selesai" })

PlayerTab:Toggle({
    Title = "Auto Click (Backend)", Desc = "Klik otomatis setelah match selesai", Icon = "mouse-pointer",
    Value = cfg.autoClick,
    Callback = function(v)
        cfg.autoClick = v
        notify(v and "[ON] AUTO CLICK" or "[OFF] AUTO CLICK",
               v and "Auto click aktif" or "Auto click nonaktif", 2)
        saveConfig()
    end,
})

PlayerTab:Slider({
    Title = "Delay Auto Click (detik)", Desc = "Jeda sebelum klik setelah match selesai", Icon = "timer",
    Value = { Min=0, Max=5, Default=cfg.autoClickDelay, Decimals=1, Suffix="s" },
    Callback = function(v) cfg.autoClickDelay = v; saveConfig() end,
})

refreshCfgSummary()

-- ══════════════════════════════════════════════════════════
-- TAB SETTINGS — Auto Join + AFK Hop + dll
-- ══════════════════════════════════════════════════════════
local SettingsTab = Window:Tab({ Title = "Settings", Icon = "settings" })

-- ── Auto Join Table ──
SettingsTab:Paragraph({
    Title = "Auto Join Table",
    Desc  = "Otomatis join meja saat ada slot. Setting ini di-save dan otomatis aktif saat execute ulang."
})

SettingsTab:Dropdown({
    Title = "Pilih Tipe Meja",
    Desc  = "Meja berapa player yang mau di-join. 'Semua' = prioritas 8P > 4P > 2P",
    Icon  = "layout",
    Values = {"Semua","2P","4P","8P"},
    Value  = cfg.tableMode,
    Multi  = false,
    Callback = function(sel)
        if not sel then return end
        cfg.tableMode = sel
        notify("[MEJA]", "Mode: "..sel, 2)
        saveConfig()
        -- Restart loop jika sedang aktif agar langsung pakai mode baru
        if autoJoinEnabled then
            startAutoJoin()
        end
    end,
})

uiAutoJoinToggle = SettingsTab:Toggle({
    Title = "Auto Join Table",
    Desc  = "Otomatis join meja siap main (2P/4P/8P)",
    Icon  = "users",
    Value = cfg.autoJoin,
    Callback = function(v)
        cfg.autoJoin = v
        if v then startAutoJoin(); notify("[AUTO JOIN]","Aktif – mode "..cfg.tableMode,2)
        else stopAutoJoin(); notify("[AUTO JOIN]","Nonaktif",2) end
        saveConfig()
    end,
})

-- ── AFK Hop Mode ──
SettingsTab:Paragraph({
    Title = "AFK Hop Mode",
    Desc  = "Hop ke server lain jika tidak ada player di meja.\nSetting ini di-save – aktif otomatis saat execute ulang."
})

SettingsTab:Slider({
    Title = "Hop Timeout (detik)",
    Desc  = "Berapa detik tunggu tanpa player sebelum hop",
    Icon  = "clock",
    Value = { Min=5, Max=120, Default=cfg.afkHopTimeout, Decimals=0, Suffix="s" },
    Callback = function(v)
        cfg.afkHopTimeout = v
        log("AFKHOP","Timeout:", v)
        saveConfig()
    end,
})

uiAfkHopToggle = SettingsTab:Toggle({
    Title = "AFK Hop Mode",
    Desc  = "Hop server otomatis. Saat ketemu player, auto join & main seperti biasa.",
    Icon  = "shuffle",
    Value = cfg.afkHop,
    Callback = function(v)
        cfg.afkHop = v
        if v then
            startAfkHop()
            notify("[AFKHOP]","Aktif – hop timeout "..cfg.afkHopTimeout.."s",4)
        else
            stopAfkHop()
            notify("[AFKHOP]","Nonaktif",2)
        end
        saveConfig()
    end,
})

-- ── Tema ──
SettingsTab:Dropdown({
    Title = "Tema", Desc = "Pilih warna GUI", Icon = "palette",
    Values = {"Dark","Rose","Midnight"}, Value = "Dark", Multi = false,
    Callback = function(sel)
        if not sel then return end
        local ok, err = pcall(function() WindUI:SetTheme(sel) end)
        if ok then notify("[ART] TEMA", sel .. " aktif", 2)
        else notify("[X] TEMA", tostring(err), 3) end
    end,
})

-- ── Anti Lag ──
SettingsTab:Paragraph({ Title = "Anti Lag", Desc = "Turunkan grafis untuk FPS lebih stabil" })

local origGfx = { gs = Lighting.GlobalShadows, fe = Lighting.FogEnd, br = Lighting.Brightness }
SettingsTab:Toggle({
    Title = "Potato Mode", Desc = "Turunkan semua grafis ke minimum", Icon = "cpu", Value = false,
    Callback = function(v)
        if v then
            pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Level01 end)
            Lighting.GlobalShadows = false; Lighting.FogEnd = 100000; Lighting.Brightness = 1
            for _, c in ipairs(Lighting:GetChildren()) do
                if c:IsA("PostEffect") then c.Enabled = false end
            end
            notify("[CPU] POTATO", "Grafis minimum, FPS naik", 3)
        else
            pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Automatic end)
            Lighting.GlobalShadows = origGfx.gs; Lighting.FogEnd = origGfx.fe; Lighting.Brightness = origGfx.br
            for _, c in ipairs(Lighting:GetChildren()) do
                if c:IsA("PostEffect") then c.Enabled = true end
            end
            notify("[FX] NORMAL", "Grafis normal kembali", 3)
        end
    end,
})

-- ── Server Tools ──
SettingsTab:Paragraph({ Title = "Server", Desc = "Tools server game" })

SettingsTab:Button({
    Title = "Rejoin", Desc = "Masuk ulang ke server sama", Icon = "refresh-cw",
    Callback = function()
        notify("[RLD] REJOIN", "Rejoining...", 2); task.wait(0.8)
        TeleportService:Teleport(game.PlaceId, LocalPlayer)
    end,
})

SettingsTab:Paragraph({ Title = "Job ID", Desc = tostring(game.JobId) })

SettingsTab:Button({
    Title = "Copy Job ID", Desc = "Salin Job ID ke clipboard", Icon = "copy",
    Callback = function()
        if setclipboard then
            setclipboard(tostring(game.JobId))
            notify("[CPY] JOB ID", tostring(game.JobId):sub(1,20) .. "...", 3)
        else notify("[X]","Clipboard tidak support",3) end
    end,
})

local currentKeybind = Enum.KeyCode.X
Window:SetToggleKey(currentKeybind)
SettingsTab:Keybind({
    Title = "Toggle UI Keybind", Desc = "Tombol buka/tutup UI", Value = "X",
    Callback = function(key)
        local ke = (typeof(key) == "EnumItem") and key
                or (typeof(key) == "string" and Enum.KeyCode[key])
        if ke then currentKeybind = ke; Window:SetToggleKey(ke); notify("[KEY]","Toggle: "..ke.Name,2) end
    end,
})

-- ══════════════════════════════════════════════════════════
-- TAB ADMIN
-- ══════════════════════════════════════════════════════════
if isAdmin(LocalPlayer) then
    local AdminTab = Window:Tab({ Title = "Admin", Icon = "shield" })
    local function blCount() local n=0; for _ in pairs(BLACKLIST) do n=n+1 end; return n end

    local admPara = AdminTab:Paragraph({
        Title = "Admin Panel",
        Desc  = "UID: "..LocalPlayer.UserId.." | Maintenance: "..(MAINTENANCE and "ON" or "OFF").." | BL: "..blCount()
    })
    local function refreshAdm()
        pcall(function()
            admPara:SetDesc("UID: "..LocalPlayer.UserId.." | Maintenance: "..(MAINTENANCE and "ON" or "OFF").." | BL: "..blCount())
        end)
    end

    AdminTab:Toggle({
        Title = "Maintenance Mode", Icon = "lock", Value = MAINTENANCE,
        Callback = function(v) MAINTENANCE = v; adminSave(); refreshAdm()
            notify(v and "[OFF] MAINT ON" or "[ON] MAINT OFF","",3) end,
    })

    AdminTab:Input({ Title="Blacklist UID", Icon="user-x", Placeholder="123456789",
        Callback = function(i)
            local uid = tonumber(i); if not uid then notify("[X]","Harus angka",3); return end
            if uid == LocalPlayer.UserId then notify("[X]","Tidak bisa BL diri sendiri",3); return end
            BLACKLIST[uid]=true; adminSave()
            for _,p in ipairs(Players:GetPlayers()) do
                if p.UserId==uid then pcall(function() p:Kick("[AutoKata] Blacklisted.") end) end
            end
            refreshAdm(); notify("[BAN]","UID "..uid.." di-blacklist",3)
        end,
    })

    AdminTab:Input({ Title="Hapus Blacklist", Icon="user-check", Placeholder="123456789",
        Callback = function(i)
            local uid = tonumber(i); if not uid then notify("[X]","Harus angka",3); return end
            if BLACKLIST[uid] then
                BLACKLIST[uid]=nil; adminSave(); refreshAdm()
                notify("[OK]","UID "..uid.." dihapus",3)
            else notify("[!]","UID tidak ada di BL",3) end
        end,
    })

    AdminTab:Button({ Title="Lihat Blacklist", Icon="list",
        Callback = function()
            local l={} for uid in pairs(BLACKLIST) do l[#l+1]=tostring(uid) end
            notify("[BL]",#l==0 and "Kosong" or table.concat(l,", "),5)
        end,
    })

    AdminTab:Button({ Title="Kick Semua Non-Admin", Icon="zap",
        Callback = function()
            local n=0
            for _,p in ipairs(Players:GetPlayers()) do
                if p~=LocalPlayer and not isAdmin(p) then
                    pcall(function() p:Kick("[AutoKata] Kicked by admin.") end); n=n+1
                end
            end
            notify("[ZAP]",n.." player di-kick",3)
        end,
    })
end

-- ══════════════════════════════════════════════════════════
-- TAB ABOUT
-- ══════════════════════════════════════════════════════════
local AboutTab = Window:Tab({ Title = "About", Icon = "info" })
AboutTab:Paragraph({
    Title = "Auto Kata v5.9",
    Desc  = "by dhann x sazaraaax\nAuto play, ranking kata, auto save config\nAuto Join: pilih tipe meja 2P/4P/8P + SeatWeld detection",
})
AboutTab:Paragraph({
    Title = "Cara Pakai",
    Desc  = "1. Pilih wordlist di Main\n2. Aktifkan toggle Auto\n3. Atur delay & aggression\n4. Config otomatis tersimpan tiap perubahan\n\nAuto Join Table (Settings):\n- Scan meja yang ProximityPrompt-nya masih aktif\n- Prioritas meja yang sudah ada player\n- Jika prompt hilang = meja penuh, skip otomatis\n\nAFK Hop Mode (Settings):\n- Hop server jika tidak ada player di meja\n- Atur Hop Timeout (default 15s)\n- Setting tersimpan & aktif otomatis saat re-execute",
})
local function copyBtn(title, url)
    AboutTab:Button({ Title = title, Icon = "link",
        Callback = function()
            if setclipboard then setclipboard(url); notify("[CPY]",title.." disalin!",3)
            else notify("[X]","Clipboard tidak support",3) end
        end,
    })
end
copyBtn("Copy Discord Invite",   "https://discord.gg/bT4GmSFFWt")
copyBtn("Copy WhatsApp Channel", "https://www.whatsapp.com/channel/0029VbCBSBOCRs1pRNYpPN0r")

-- ══════════════════════════════════════════════════════════
-- SECTION : DISCORD LOGIN NOTIF
-- ══════════════════════════════════════════════════════════
sendLoginNotif()

-- ══════════════════════════════════════════════════════════
-- SECTION : REMOTE EVENT HANDLERS
-- ══════════════════════════════════════════════════════════
MatchUI.OnClientEvent:Connect(function(cmd, value)
    log("REMOTE", cmd, tostring(value))

    if cmd == "ShowMatchUI" then
        matchActive = true; isMyTurn = false; serverLetter = ""
        autoRunning = false; blacklistedWords = {}
        resetUsed(); setupSeatMonitoring(); updateStatus(); refreshWordDrop()

    elseif cmd == "HideMatchUI" then
        matchActive = false; isMyTurn = false; serverLetter = ""
        autoRunning = false; blacklistedWords = {}
        resetUsed(); seatStates = {}; updateStatus(); refreshWordDrop()
        safeSpawn(doAutoClick)

    elseif cmd == "StartTurn" then
        isMyTurn = true; lastTurnActivity = tick()
        if type(value) == "string" and value ~= "" then serverLetter = value end
        if cfg.autoEnabled then
            safeSpawn(function()
                task.wait(math.random(200,400)/1000)
                if matchActive and isMyTurn and cfg.autoEnabled then _startUltraAI() end
            end)
        end
        updateStatus(); refreshWordDrop()

    elseif cmd == "EndTurn" then
        isMyTurn = false; updateStatus(); refreshWordDrop()

    elseif cmd == "UpdateServerLetter" then
        serverLetter = value or ""
        updateStatus(); refreshWordDrop()
        if isMyTurn and cfg.autoEnabled and not autoRunning and serverLetter ~= "" then
            safeSpawn(_startUltraAI)
        end

    elseif cmd == "Mistake" then
        if type(value) == "table" and value.userId == LocalPlayer.UserId then
            if cfg.autoEnabled and matchActive and isMyTurn then
                safeSpawn(function()
                    clearToStartWord(); task.wait(0.3)
                    if matchActive and isMyTurn then _startUltraAI() end
                end)
            end
        end
    end
end)

BillboardUpdate.OnClientEvent:Connect(function(word)
    if matchActive and not isMyTurn then opponentStreamWord = word or "" end
end)

UsedWordWarn.OnClientEvent:Connect(function(word)
    if not word then return end
    lastRejectWord = word:lower(); addUsed(word)
    if cfg.autoEnabled and matchActive and isMyTurn and not autoRunning then
        safeSpawn(function()
            clearToStartWord(); task.wait(0.3)
            if matchActive and isMyTurn then _startUltraAI() end
        end)
    end
end)

JoinTable.OnClientEvent:Connect(function(tableName)
    currentTableName = tableName; setupSeatMonitoring(); updateStatus()
end)

LeaveTable.OnClientEvent:Connect(function()
    currentTableName = nil; matchActive = false; isMyTurn = false
    serverLetter = ""; autoRunning = false; blacklistedWords = {}
    resetUsed(); seatStates = {}; updateStatus()
    safeSpawn(doAutoClick)
end)

if PlayerHit then
    PlayerHit.OnClientEvent:Connect(function(player)
        if player ~= LocalPlayer then return end
        if cfg.autoEnabled and matchActive and isMyTurn then
            safeSpawn(function()
                clearToStartWord(); task.wait(0.4)
                if matchActive and isMyTurn then _startUltraAI() end
            end)
        end
    end)
end

if PlayerCorrect then
    PlayerCorrect.OnClientEvent:Connect(function(player)
        if player == LocalPlayer then log("MATCH","PlayerCorrect [OK]") end
    end)
end

-- ══════════════════════════════════════════════════════════
-- SECTION : BACKGROUND LOOPS
-- ══════════════════════════════════════════════════════════
safeSpawn(function()
    while _G.AutoKataActive do
        pcall(function() if matchActive then updateStatus() end end)
        task.wait(0.3)
    end
end)

safeSpawn(function()
    while _G.AutoKataActive do
        pcall(flushLogUI)
        task.wait(1)
    end
end)

safeSpawn(buildIndex)
safeSpawn(downloadWrongWords)
safeSpawn(function()
    loadRanking()
    if cfg.activeWordlist == "Ranking Kata (Kompetitif)" and next(rankingMap) then
        local words = {}
        for w in pairs(rankingMap) do words[#words+1] = w end
        kataModule = words; buildIndex()
        log("WORDLIST","Ranking mode populated:", #kataModule)
    end
end)

-- ══════════════════════════════════════════════════════════
-- AUTO-RESTORE FITUR YANG TERSIMPAN
-- Setelah semua UI siap, restore state dari config
-- ══════════════════════════════════════════════════════════
task.delay(0.5, function()
    -- Auto Join
    if cfg.autoJoin then
        startAutoJoin()
        log("RESTORE","Auto Join aktif dari config")
        -- Set toggle UI jika tersedia
        if uiAutoJoinToggle then pcall(function() uiAutoJoinToggle:Set(true) end) end
    end
    -- AFK Hop
    if cfg.afkHop then
        startAfkHop()
        log("RESTORE","AFK Hop aktif dari config, timeout="..cfg.afkHopTimeout.."s")
        if uiAfkHopToggle then pcall(function() uiAfkHopToggle:Set(true) end) end
    end
    refreshCfgSummary()
end)

log("BOOT","════════════════════════════════════")
log("BOOT","AutoKata v5.9 loaded OK")
log("BOOT","Wordlist:", cfg.activeWordlist, "|", #kataModule, "kata")
log("BOOT","VIM="..tostring(VIM~=nil).." | keypress="..tostring(keypress~=nil))
log("BOOT","autoEnabled="..tostring(cfg.autoEnabled).." | autoJoin="..tostring(cfg.autoJoin).." | afkHop="..tostring(cfg.afkHop))
log("BOOT","════════════════════════════════════")
