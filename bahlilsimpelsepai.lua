-- =========================================================
-- SIMPLE SPY V3 - WindUI Build
-- Original SimpleSpy by 78n
-- WindUI by Footagesus
-- Tema diambil dari script WindUI (Dark theme)
-- =========================================================

if getgenv().SimpleSpyExecuted and type(getgenv().SimpleSpyShutdown) == "function" then
    getgenv().SimpleSpyShutdown()
end

-- ══════════════════════════════════════════════════════════
-- CORE CONFIG
-- ══════════════════════════════════════════════════════════
local realconfigs = {
    logcheckcaller = false,
    autoblock      = false,
    funcEnabled    = true,
    advancedinfo   = false,
    supersecretdevtoggle = false
}

local configs = newproxy(true)
local configsmetatable = getmetatable(configs)
configsmetatable.__index = function(self, index)
    return realconfigs[index]
end

-- ══════════════════════════════════════════════════════════
-- COMPATIBILITY SHIMS
-- ══════════════════════════════════════════════════════════
local oth     = syn and syn.oth
local unhook  = oth and oth.unhook
local hook    = oth and oth.hook

local lower   = string.lower
local byte    = string.byte
local running = coroutine.running
local resume  = coroutine.resume
local status  = coroutine.status
local yield   = coroutine.yield
local create  = coroutine.create
local close   = coroutine.close
local OldDebugId = game.GetDebugId
local info    = debug.info
local IsA     = game.IsA
local tostring = tostring
local tonumber = tonumber
local delay   = task.delay
local spawn   = task.spawn
local clear   = table.clear
local clone   = table.clone

local function blankfunction(...) return ... end

local get_thread_identity = (syn and syn.get_thread_identity) or getidentity or getthreadidentity
local set_thread_identity = (syn and syn.set_thread_identity) or setidentity
local islclosure  = islclosure or is_l_closure
local getinfo_fn  = getinfo or blankfunction
local getupvalues = getupvalues or debug.getupvalues or blankfunction
local getconstants = getconstants or debug.getconstants or blankfunction
local getcustomasset  = getsynasset or getcustomasset
local getcallingscript = getcallingscript or blankfunction
local newcclosure  = newcclosure or blankfunction
local clonefunction = clonefunction or blankfunction
local cloneref     = cloneref or blankfunction
local request      = request or syn and syn.request
local makewritable = makewriteable or function(t) setreadonly(t, false) end
local makereadonly = makereadonly or function(t) setreadonly(t, true) end
local isreadonly   = isreadonly or table.isfrozen

local setclipboard = setclipboard or toclipboard or set_clipboard
    or (Clipboard and Clipboard.set)
    or function(...) warn("Clipboard not supported") end

local hookmetamethod = hookmetamethod
    or (makewriteable and makereadonly and getrawmetatable) and function(obj, metamethod, func)
        local old = getrawmetatable(obj)
        if hookfunction then
            return hookfunction(old[metamethod], func)
        else
            local oldmm = old[metamethod]
            makewriteable(old); old[metamethod] = func; makereadonly(old)
            return oldmm
        end
    end

-- ══════════════════════════════════════════════════════════
-- HELPERS
-- ══════════════════════════════════════════════════════════
local function Create(instance, properties)
    local obj = Instance.new(instance)
    for i, v in next, properties or {} do obj[i] = v end
    return obj
end

local function SafeGetService(s) return cloneref(game:GetService(s)) end

local function IsCyclicTable(tbl)
    local checked = {}
    local function Search(t)
        table.insert(checked, t)
        for _, v in next, t do
            if type(v) == "table" then
                return table.find(checked, v) and true or Search(v)
            end
        end
    end
    return Search(tbl)
end

local function deepclone(args, copies)
    copies = copies or {}
    if type(args) == "table" then
        if copies[args] then return copies[args] end
        local copy = {}; copies[args] = copy
        for i, v in next, args do
            copy[deepclone(i, copies)] = deepclone(v, copies)
        end
        return copy
    elseif typeof(args) == "Instance" then
        return cloneref(args)
    end
    return args
end

local function rawtostring(userdata)
    if type(userdata) == "table" or typeof(userdata) == "userdata" then
        local rm = getrawmetatable(userdata)
        local cs = rm and rawget(rm, "__tostring")
        if cs then
            local wr = isreadonly(rm)
            if wr then makewritable(rm) end
            rawset(rm, "__tostring", nil)
            local s = tostring(userdata)
            rawset(rm, "__tostring", cs)
            if wr then makereadonly(rm) end
            return s
        end
    end
    return tostring(userdata)
end

-- ══════════════════════════════════════════════════════════
-- SERVICES
-- ══════════════════════════════════════════════════════════
local CoreGui          = SafeGetService("CoreGui")
local Players          = SafeGetService("Players")
local RunService       = SafeGetService("RunService")
local UserInputService = SafeGetService("UserInputService")
local TweenService     = SafeGetService("TweenService")
local TextService      = SafeGetService("TextService")
local http             = SafeGetService("HttpService")
local GuiInset         = game:GetService("GuiService"):GetGuiInset()

local function jsone(s) return http:JSONEncode(s) end
local function jsond(s)
    local ok, v = pcall(http.JSONDecode, http, s)
    return ok and v or ok
end

function ErrorPrompt(msg, state)
    if getrenv then
        local EP = getrenv().require(
            CoreGui:WaitForChild("RobloxGui"):WaitForChild("Modules"):WaitForChild("ErrorPrompt")
        )
        local p  = EP.new("Default", {HideErrorCode = true})
        local sg = Create("ScreenGui", {Parent = CoreGui, ResetOnSpawn = false})
        local th = state and running()
        p:setParent(sg); p:setErrorTitle("Simple Spy Error")
        p:updateButtons({{Text="Proceed",Callback=function()
            p:_close(); sg:Destroy()
            if th then resume(th) end
        end, Primary=true}}, "Default")
        p:_open(msg)
        if th then yield(th) end
    else warn(msg) end
end

-- ══════════════════════════════════════════════════════════
-- LOAD HIGHLIGHT
-- ══════════════════════════════════════════════════════════
local Highlight = (isfile and loadfile and isfile("Highlight.lua") and loadfile("Highlight.lua")())
    or loadstring(game:HttpGet("https://raw.githubusercontent.com/78n/SimpleSpy/main/Highlight.lua"))()

-- ══════════════════════════════════════════════════════════
-- LOAD WINDUI  (sama persis seperti script kamu)
-- ══════════════════════════════════════════════════════════
local _raw = ""
pcall(function()
    _raw = game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua")
end)
if _raw == "" then
    warn("[SimpleSpy] Gagal load WindUI!"); return
end
local _fn, _fe = loadstring(_raw)
if not _fn then warn("[SimpleSpy] WindUI loadstring gagal: " .. tostring(_fe)); return end
local _ok, WindUI = pcall(_fn)
if not _ok or not WindUI then warn("[SimpleSpy] WindUI init gagal: " .. tostring(WindUI)); return end

-- ══════════════════════════════════════════════════════════
-- SIMPLE SPY STATE
-- ══════════════════════════════════════════════════════════
local layoutOrderNum   = 999999999
local mainClosing      = false
local closed           = false
local logs             = {}
local selected         = nil
local blacklist        = {}
local blocklist        = {}
local connectedRemotes = {}
local toggle           = false
local prevTables       = {}
local remoteLogs       = {}
getgenv().SIMPLESPYCONFIG_MaxRemotes = 300
local indent           = 4
local scheduled        = {}
local schedulerconnect
local SimpleSpy        = {}
local topstr           = ""
local bottomstr        = ""
local codebox_instance -- Frame untuk Highlight
local codebox          -- Highlight object
local getnilrequired   = false
local history          = {}
local excluding        = {}
local connections      = {}
local DecompiledScripts = {}
local generation       = {}
local running_threads  = {}
local originalnamecall

-- ══════════════════════════════════════════════════════════
-- INTERNAL REMOTES
-- ══════════════════════════════════════════════════════════
local Storage          = Create("Folder", {})
local remoteEvent      = Instance.new("RemoteEvent", Storage)
local remoteFunction   = Instance.new("RemoteFunction", Storage)
local GetDebugIdHandler = Instance.new("BindableFunction", Storage)

local originalEvent    = remoteEvent.FireServer
local originalFunction = remoteFunction.InvokeServer
local GetDebugIDInvoke = GetDebugIdHandler.Invoke

function GetDebugIdHandler.OnInvoke(obj) return OldDebugId(obj) end
local function ThreadGetDebugId(obj) return GetDebugIDInvoke(GetDebugIdHandler, obj) end

local synv3 = false
if syn and identifyexecutor then
    local _, ver = identifyexecutor()
    if ver and ver:sub(1, 2) == "v3" then synv3 = true end
end

-- ══════════════════════════════════════════════════════════
-- CONFIG SAVE / LOAD
-- ══════════════════════════════════════════════════════════
xpcall(function()
    if isfile and readfile and isfolder and makefolder then
        local cached = isfile("SimpleSpy//Settings.json") and jsond(readfile("SimpleSpy//Settings.json"))
        if cached then
            for i, v in next, realconfigs do
                if cached[i] == nil then cached[i] = v end
            end
            realconfigs = cached
        end
        if not isfolder("SimpleSpy") then makefolder("SimpleSpy") end
        if not isfolder("SimpleSpy//Assets") then makefolder("SimpleSpy//Assets") end
        if not isfile("SimpleSpy//Settings.json") then
            writefile("SimpleSpy//Settings.json", jsone(realconfigs))
        end
        configsmetatable.__newindex = function(_, i, v)
            realconfigs[i] = v
            writefile("SimpleSpy//Settings.json", jsone(realconfigs))
        end
    else
        configsmetatable.__newindex = function(_, i, v) realconfigs[i] = v end
    end
end, function(err) ErrorPrompt(("Config error: (%s)"):format(err)) end)

-- ══════════════════════════════════════════════════════════
-- UTILITY FUNCTIONS
-- ══════════════════════════════════════════════════════════
local function logthread(t) table.insert(running_threads, t) end

function clean()
    local max = getgenv().SIMPLESPYCONFIG_MaxRemotes
    if not typeof(max) == "number" or math.floor(max) ~= max then max = 500 end
    if #remoteLogs > max then
        for i = 100, #remoteLogs do
            local v = remoteLogs[i]
            if typeof(v[1]) == "RBXScriptConnection" then v[1]:Disconnect() end
            if typeof(v[2]) == "Instance" then v[2]:Destroy() end
        end
        local n = {}
        for i = 1, 100 do n[i] = remoteLogs[i] end
        remoteLogs = n
    end
end

local function ThreadIsNotDead(t) return not status(t) == "dead" end

function schedule(f, ...) table.insert(scheduled, {f, ...}) end
function scheduleWait()
    local t = running(); schedule(function() resume(t) end); yield()
end

local function taskscheduler()
    if not toggle then scheduled = {}; return end
    if #scheduled > SIMPLESPYCONFIG_MaxRemotes + 100 then
        table.remove(scheduled, #scheduled)
    end
    if #scheduled > 0 then
        local cur = scheduled[1]; table.remove(scheduled, 1)
        if type(cur) == "table" and type(cur[1]) == "function" then
            pcall(unpack(cur))
        end
    end
end

local function tablecheck(tbl, inst, id)
    return tbl[id] or tbl[inst.Name]
end

-- ══════════════════════════════════════════════════════════
-- SCRIPT GENERATION (unchanged from original)
-- ══════════════════════════════════════════════════════════
local CustomGeneration = {
    Vector3 = (function()
        local t = {}
        for i, v in Vector3 do if type(v) == "vector" then t[v] = "Vector3."..i end end
        return t
    end)(),
    Vector2 = (function()
        local t = {}
        for i, v in Vector2 do if type(v) == "userdata" then t[v] = "Vector2."..i end end
        return t
    end)(),
    CFrame = { [CFrame.identity] = "CFrame.identity" }
}

local number_table = { ["inf"] = "math.huge", ["-inf"] = "-math.huge", ["nan"] = "0/0" }

local ufunctions
ufunctions = {
    TweenInfo = function(u)
        return ("TweenInfo.new(%s,%s,%s,%s,%s,%s)"):format(u.Time,u.EasingStyle,u.EasingDirection,u.RepeatCount,u.Reverses,u.DelayTime)
    end,
    Ray = function(u)
        return ("Ray.new(%s,%s)"):format(ufunctions.Vector3(u.Origin), ufunctions.Vector3(u.Direction))
    end,
    BrickColor  = function(u) return ("BrickColor.new(%s)"):format(u.Number) end,
    NumberRange = function(u) return ("NumberRange.new(%s,%s)"):format(u.Min, u.Max) end,
    Region3     = function(u)
        local c, s = u.CFrame.Position, u.Size/2
        return ("Region3.new(%s,%s)"):format(ufunctions.Vector3(c-s), ufunctions.Vector3(c+s))
    end,
    Faces = function(u)
        local f={}
        if u.Top    then f[#f+1]="Top" end
        if u.Bottom then f[#f+1]="Enum.NormalId.Bottom" end
        if u.Left   then f[#f+1]="Enum.NormalId.Left" end
        if u.Right  then f[#f+1]="Enum.NormalId.Right" end
        if u.Back   then f[#f+1]="Enum.NormalId.Back" end
        if u.Front  then f[#f+1]="Enum.NormalId.Front" end
        return ("Faces.new(%s)"):format(table.concat(f,","))
    end,
    EnumItem    = function(u) return tostring(u) end,
    Enums       = function()  return "Enum" end,
    Enum        = function(u) return "Enum."..tostring(u) end,
    Vector3     = function(u) return CustomGeneration.Vector3[u] or ("Vector3.new(%s)"):format(tostring(u)) end,
    Vector2     = function(u) return CustomGeneration.Vector2[u] or ("Vector2.new(%s)"):format(tostring(u)) end,
    CFrame      = function(u) return CustomGeneration.CFrame[u] or ("CFrame.new(%s)"):format(table.concat({u:GetComponents()},",")) end,
    PathWaypoint = function(u) return ('PathWaypoint.new(%s,%s,"%s")'):format(ufunctions.Vector3(u.Position),u.Action,u.Label) end,
    UDim        = function(u) return ("UDim.new(%s)"):format(tostring(u)) end,
    UDim2       = function(u) return ("UDim2.new(%s)"):format(tostring(u)) end,
    Rect        = function(u) return ("Rect.new(%s,%s)"):format(ufunctions.Vector2(u.Min), ufunctions.Vector2(u.Max)) end,
    Color3      = function(u) return ("Color3.new(%s,%s,%s)"):format(u.R, u.G, u.B) end,
    RBXScriptSignal     = function() return "RBXScriptSignal --[[not supported]]" end,
    RBXScriptConnection = function() return "RBXScriptConnection --[[not supported]]" end,
}

local typeofv2sfunctions = {
    number   = function(v) local n = tostring(v); return number_table[n] or n end,
    boolean  = function(v) return tostring(v) end,
    string   = function(v, l) return formatstr(v, l) end,
    ["function"] = function(v) return f2s(v) end,
    table    = function(v, l, p, n, vtv, i, pt, path, tables, tI)
        return t2s(v, l, p, n, vtv, i, pt, path, tables, tI)
    end,
    Instance = function(v)
        return i2p(v, generation[OldDebugId(v)])
    end,
    userdata = function(v)
        if configs.advancedinfo then
            return getrawmetatable(v) and "newproxy(true)" or "newproxy(false)"
        end
        return "newproxy(true)"
    end,
}

local typev2sfunctions = {
    userdata = function(v, vt)
        if ufunctions[vt] then return ufunctions[vt](v) end
        return ("%s(%s) --[[Generation Failure]]"):format(vt, rawtostring(v))
    end,
    vector = ufunctions.Vector3
}

function v2s(v, l, p, n, vtv, i, pt, path, tables, tI)
    local vt = typeof(v)
    local vtf = typeofv2sfunctions[vt]
    local vtpf = typev2sfunctions[type(v)]
    if not tI then tI = {0} else tI[1] += 1 end
    if vtf  then return vtf(v, l, p, n, vtv, i, pt, path, tables, tI) end
    if vtpf then return vtpf(v, vt) end
    return ("%s(%s) --[[Generation Failure]]"):format(vt, rawtostring(v))
end

function v2v(t)
    topstr = ""; bottomstr = ""; getnilrequired = false
    local ret, count = "", 1
    for i, v in next, t do
        local nm
        if type(i) == "string" and i:match("^[%a_]+[%w_]*$") then
            nm = i
        elseif rawtostring(i):match("^[%a_]+[%w+]*$") then
            nm = lower(rawtostring(i)).."_"..count
        else
            nm = type(v).."_"..count
        end
        ret = ret .. "local " .. nm .. " = " .. v2s(v, nil, nil, nm, true) .. "\n"
        count += 1
    end
    if getnilrequired then
        topstr = "function getNil(name,class) for _,v in next,getnilinstances() do if v.ClassName==class and v.Name==name then return v end end end\n" .. topstr
    end
    if #topstr > 0 then ret = topstr .. "\n" .. ret end
    if #bottomstr > 0 then ret = ret .. bottomstr end
    return ret
end

function t2s(t, l, p, n, vtv, i, pt, path, tables, tI)
    local gi = table.find(getgenv(), t)
    if type(gi) == "string" then return gi end
    if not tI then tI = {0} end
    if not path then path = "" end
    if not l then l = 0; tables = {} end
    if not p then p = t end
    for _, v in next, tables do
        if n and rawequal(v, t) then
            bottomstr ..= "\n"..rawtostring(n)..rawtostring(path).." = "..rawtostring(n)..rawtostring(({v2p(v,p)})[2])
            return "{} --[[DUPLICATE]]"
        end
    end
    table.insert(tables, t)
    local s = "{"; local size = 0; l += indent
    for k, v in next, t do
        size += 1
        if size > (getgenv().SimpleSpyMaxTableSize or 1000) then
            s ..= "\n"..string.rep(" ",l).."-- MAX TABLE SIZE REACHED"; break
        end
        if rawequal(k, t) then
            bottomstr ..= ("\n%s%s[%s%s] = %s"):format(n,path,n,path,
                (rawequal(v,k) and n..path or v2s(v,l,p,n,vtv,k,t,path.."["..n..path.."]",tables)))
            size -= 1; continue
        end
        local cp = (type(k)=="string" and k:match("^[%a_]+[%w_]*$")) and "."..k
            or "["..v2s(k,l,p,n,vtv,k,t,path,tables,tI).."]"
        if size % 100 == 0 then scheduleWait() end
        s ..= "\n"..string.rep(" ",l).."["..v2s(k,l,p,n,vtv,k,t,path..cp,tables,tI).."] = "
            ..v2s(v,l,p,n,vtv,k,t,path..cp,tables,tI)..","
    end
    if #s > 1 then s = s:sub(1,-2) end
    if size > 0 then s ..= "\n"..string.rep(" ",l-indent) end
    return s.."}"
end

function f2s(f)
    for k, x in next, getgenv() do
        local ok, gp
        if rawequal(x,f) then ok, gp = true, ""
        elseif type(x)=="table" then ok, gp = v2p(f,x) end
        if ok and type(k)~="function" then
            if type(k)=="string" and k:match("^[%a_]+[%w_]*$") then return k..gp
            else return "getgenv()["..v2s(k).."]"..gp end
        end
    end
    if configs.funcEnabled then
        local nm = info(f,"n")
        if nm and nm:match("^[%a_]+[%w_]*$") then
            return ("function %s() end -- Called: %s"):format(nm, nm)
        end
    end
    return tostring(f)
end

function i2p(i, customgen)
    if customgen then return customgen end
    local player = getplayer(i)
    local parent = i
    local out = ""
    if parent == nil then return "nil"
    elseif player then
        while true do
            if parent == player.Character then
                if player == Players.LocalPlayer then
                    return 'game:GetService("Players").LocalPlayer.Character'..out
                else return i2p(player)..".Character"..out end
            else
                if parent.Name:match("[%a_]+[%w+]*") ~= parent.Name then
                    out = ":FindFirstChild("..formatstr(parent.Name)..")"..out
                else out = "."..parent.Name..out end
            end
            task.wait(); parent = parent.Parent
        end
    elseif parent ~= game then
        while true do
            if parent and parent.Parent == game then
                if game:FindService(parent.ClassName) then
                    if lower(parent.ClassName) == "workspace" then return "workspace"..out
                    else return 'game:GetService("'..parent.ClassName..'")'..out end
                else
                    if parent.Name:match("[%a_]+[%w_]*") then return "game."..parent.Name..out
                    else return "game:FindFirstChild("..formatstr(parent.Name)..")"..out end
                end
            elseif not parent.Parent then
                getnilrequired = true
                return 'getNil('..formatstr(parent.Name)..',"'..parent.ClassName..'")'..out
            else
                out = (parent.Name:match("[%a_]+[%w_]*") ~= parent.Name)
                    and ':WaitForChild('..formatstr(parent.Name)..")"..out
                    or ':WaitForChild("'..parent.Name..'")'..out
            end
            if i:IsDescendantOf(Players.LocalPlayer) then
                return 'game:GetService("Players").LocalPlayer'..out
            end
            parent = parent.Parent; task.wait()
        end
    else return "game" end
end

function getplayer(instance)
    for _, v in next, Players:GetPlayers() do
        if v.Character and (instance:IsDescendantOf(v.Character) or instance == v.Character) then
            return v
        end
    end
end

function v2p(x, t, path, prev)
    path = path or ""; prev = prev or {}
    if rawequal(x, t) then return true, "" end
    for i, v in next, t do
        if rawequal(v, x) then
            return true, path .. ((type(i)=="string" and i:match("^[%a_]+[%w_]*$")) and "."..i or "["..v2s(i).."]")
        end
        if type(v) == "table" then
            local dup = false
            for _, y in next, prev do if rawequal(y,v) then dup=true end end
            if not dup then
                table.insert(prev, t)
                local found, pp = v2p(x, v, path, prev)
                if found then
                    return true, (type(i)=="string" and i:match("^[%a_]+[%w_]*$"))
                        and "."..i..pp or "["..v2s(i).."]"..pp
                end
            end
        end
    end
    return false, ""
end

function formatstr(s, ind)
    ind = ind or 0
    local handled, max = handlespecials(s, ind)
    return '"'..handled..'"' .. (max and " --[[MAX STRING SIZE REACHED]]" or "")
end

local function isFinished(coros)
    for _, v in next, coros do
        if status(v) == "running" then return false end
    end
    return true
end

local specialstrings = {
    ["\n"] = function(t,i) resume(t,i,"\\n") end,
    ["\t"] = function(t,i) resume(t,i,"\\t") end,
    ["\\"] = function(t,i) resume(t,i,"\\\\") end,
    ['"']  = function(t,i) resume(t,i,'\\"') end,
}

function handlespecials(s, ind)
    local i, n, coros, timeout = 0, 1, {}, 0
    local fn = function(idx, r) s = s:sub(0,idx-1)..r..s:sub(idx+1,-1) end
    repeat
        i += 1
        if timeout >= 10 then task.wait(); timeout = 0 end
        local char = s:sub(i,i)
        if byte(char) then
            timeout += 1
            local c = create(fn); table.insert(coros, c)
            local sf = specialstrings[char]
            if sf then sf(c,i); i += 1
            elseif byte(char) > 126 or byte(char) < 32 then
                resume(c,i,"\\"..byte(char)); i += #rawtostring(byte(char))
            end
            if i >= n*100 then
                local ex = ('" ..\n%s"'):format(string.rep(" ", ind+indent))
                s = s:sub(0,i)..ex..s:sub(i+1,-1); i += #ex; n += 1
            end
        end
    until char=="" or i>(getgenv().SimpleSpyMaxStringSize or 10000)
    while not isFinished(coros) do RunService.Heartbeat:Wait() end
    clear(coros)
    if i > (getgenv().SimpleSpyMaxStringSize or 10000) then
        return s:sub(0, getgenv().SimpleSpyMaxStringSize or 10000), true
    end
    return s, false
end

function genScript(remote, args)
    prevTables = {}
    local gen = ""
    if #args > 0 then
        xpcall(function()
            gen = v2v({args = args}) .. "\n"
        end, function(err)
            gen ..= "-- Error:\n--"..err.."\nlocal args = {"
            xpcall(function()
                for _, v in next, args do
                    gen ..= "\n    " .. v2s(v)
                end
                gen ..= "\n}\n\n"
            end, function() gen ..= "}\n-- Legacy failure" end)
        end)
        if not remote:IsDescendantOf(game) and not getnilrequired then
            gen = "function getNil(name,class) for _,v in next,getnilinstances() do if v.ClassName==class and v.Name==name then return v end end end\n\n"..gen
        end
        if remote:IsA("RemoteEvent") then
            gen ..= v2s(remote)..":FireServer(unpack(args))"
        elseif remote:IsA("RemoteFunction") then
            gen ..= v2s(remote)..":InvokeServer(unpack(args))"
        end
    else
        if remote:IsA("RemoteEvent") then
            gen ..= v2s(remote)..":FireServer()"
        elseif remote:IsA("RemoteFunction") then
            gen ..= v2s(remote)..":InvokeServer()"
        end
    end
    prevTables = {}
    return gen
end

-- ══════════════════════════════════════════════════════════
-- REMOTE HANDLER
-- ══════════════════════════════════════════════════════════
function remoteHandler(data)
    if configs.autoblock then
        local id = data.id
        if excluding[id] then return end
        if not history[id] then history[id] = {badOccurances=0,lastCall=tick()} end
        if tick() - history[id].lastCall < 1 then
            history[id].badOccurances += 1; return
        else history[id].badOccurances = 0 end
        if history[id].badOccurances > 3 then excluding[id]=true; return end
        history[id].lastCall = tick()
    end
    if data.remote:IsA("RemoteEvent") and lower(data.method)=="fireserver" then
        addRemoteLog("event", data)
    elseif data.remote:IsA("RemoteFunction") and lower(data.method)=="invokeserver" then
        addRemoteLog("function", data)
    end
end

local newindex = function(method, originalfn, ...)
    if typeof(...) == "Instance" then
        local remote = cloneref(...)
        if remote:IsA("RemoteEvent") or remote:IsA("RemoteFunction") then
            if not configs.logcheckcaller and checkcaller() then return originalfn(...) end
            local id = ThreadGetDebugId(remote)
            local bc = tablecheck(blocklist, remote, id)
            local args = {select(2,...)}
            if not tablecheck(blacklist, remote, id) and not IsCyclicTable(args) then
                local data = {
                    method=method, remote=remote, args=deepclone(args),
                    metamethod="__index", blockcheck=bc, id=id, returnvalue={}
                }
                args = nil
                if configs.funcEnabled then
                    data.infofunc = info(2,"f")
                    local cs = getcallingscript()
                    data.callingscript = cs and cloneref(cs) or nil
                end
                schedule(remoteHandler, data)
            end
            if bc then return end
        end
    end
    return originalfn(...)
end

local newnamecall = newcclosure(function(...)
    local method = getnamecallmethod()
    if method and (method=="FireServer" or method=="fireServer" or method=="InvokeServer" or method=="invokeServer") then
        if typeof(...) == "Instance" then
            local remote = cloneref(...)
            if IsA(remote,"RemoteEvent") or IsA(remote,"RemoteFunction") then
                if not configs.logcheckcaller and checkcaller() then return originalnamecall(...) end
                local id = ThreadGetDebugId(remote)
                local bc = tablecheck(blocklist, remote, id)
                local args = {select(2,...)}
                if not tablecheck(blacklist, remote, id) and not IsCyclicTable(args) then
                    local data = {
                        method=method, remote=remote, args=deepclone(args),
                        metamethod="__namecall", blockcheck=bc, id=id, returnvalue={}
                    }
                    args = nil
                    if configs.funcEnabled then
                        data.infofunc = info(2,"f")
                        local cs = getcallingscript()
                        data.callingscript = cs and cloneref(cs) or nil
                    end
                    schedule(remoteHandler, data)
                end
                if bc then return end
            end
        end
    end
    return originalnamecall(...)
end)

local newFireServer   = newcclosure(function(...) return newindex("FireServer",originalEvent,...) end)
local newInvokeServer = newcclosure(function(...) return newindex("InvokeServer",originalFunction,...) end)

local function disablehooks()
    if synv3 then
        unhook(getrawmetatable(game).__namecall, originalnamecall)
        unhook(Instance.new("RemoteEvent").FireServer, originalEvent)
        unhook(Instance.new("RemoteFunction").InvokeServer, originalFunction)
        restorefunction(originalnamecall)
        restorefunction(originalEvent)
        restorefunction(originalFunction)
    else
        if hookmetamethod then hookmetamethod(game,"__namecall",originalnamecall)
        else hookfunction(getrawmetatable(game).__namecall, originalnamecall) end
        hookfunction(Instance.new("RemoteEvent").FireServer, originalEvent)
        hookfunction(Instance.new("RemoteFunction").InvokeServer, originalFunction)
    end
end

function toggleSpy()
    if not toggle then
        local old
        if synv3 then
            old = hook(getrawmetatable(game).__namecall, clonefunction(newnamecall))
            originalEvent = hook(Instance.new("RemoteEvent").FireServer, clonefunction(newFireServer))
            originalFunction = hook(Instance.new("RemoteFunction").InvokeServer, clonefunction(newInvokeServer))
        else
            if hookmetamethod then old = hookmetamethod(game,"__namecall",clonefunction(newnamecall))
            else old = hookfunction(getrawmetatable(game).__namecall, clonefunction(newnamecall)) end
            originalEvent = hookfunction(Instance.new("RemoteEvent").FireServer, clonefunction(newFireServer))
            originalFunction = hookfunction(Instance.new("RemoteFunction").InvokeServer, clonefunction(newInvokeServer))
        end
        originalnamecall = originalnamecall or function(...) return old(...) end
    else
        disablehooks()
    end
end

function toggleSpyMethod() toggleSpy(); toggle = not toggle end

local function shutdown()
    if schedulerconnect then schedulerconnect:Disconnect() end
    for _, c in next, connections do pcall(c.Disconnect, c) end
    for _, t in next, running_threads do
        if ThreadIsNotDead(t) then close(t) end
    end
    clear(running_threads); clear(connections); clear(logs); clear(remoteLogs)
    disablehooks()
    pcall(function() mainGui:Destroy() end)
    Storage:Destroy()
    UserInputService.MouseIconEnabled = true
    getgenv().SimpleSpyExecuted = false
end

-- ══════════════════════════════════════════════════════════
-- WIND UI WINDOW
-- ══════════════════════════════════════════════════════════
local mainGui   -- akan di-set oleh WindUI
local statusPara
local logPara
local remoteDrop
local remoteDropOptions = {}

local Window = WindUI:CreateWindow({
    Title       = "SimpleSpy",
    SubTitle    = "Remote Spy v3",
    TabWidth    = 140,
    Size        = UDim2.fromOffset(580, 360),
    Transparent = true,
    Theme       = "Dark",
    Background  = "rbxassetid://",
    Icon        = "shield",
    MinimizeKey = Enum.KeyCode.RightControl,
})

-- ══════════════════════════════════════════════════════════
-- TAB 1 : REMOTES
-- ══════════════════════════════════════════════════════════
local RemoteTab = Window:Tab({ Title = "Remotes", Icon = "activity" })

-- Paragraph status spy
statusPara = RemoteTab:Paragraph({
    Title = "Remote Spy",
    Desc  = "Status: ❌ OFF  |  Metode: Namecall",
})

-- Toggle SPY ON/OFF
local spyToggle = RemoteTab:Toggle({
    Title = "Aktifkan Spy",
    Desc  = "Hook remote event & function",
    Icon  = "radio",
    Value = false,
    Callback = function(val)
        toggleSpyMethod()
        statusPara:SetDesc(
            "Status: "..(toggle and "✅ ON" or "❌ OFF")
            .."  |  Remote logged: "..#logs
        )
        WindUI:Notify({
            Title    = "SimpleSpy",
            Content  = toggle and "Spy aktif!" or "Spy dimatikan",
            Duration = 2,
            Icon     = toggle and "check-circle" or "x-circle",
        })
    end,
})

-- Dropdown daftar remote yang sudah di-log
remoteDrop = RemoteTab:Dropdown({
    Title    = "Log Remote",
    Desc     = "Pilih remote untuk lihat script",
    Icon     = "list",
    Options  = {"(kosong)"},
    CurrentOption = "(kosong)",
    Callback = function(sel)
        for _, v in next, logs do
            if v.DisplayName == sel then
                selected = v
                if codebox then
                    local gs = genScript(v.Remote, v.args)
                    v.GenScript = gs
                    codebox:setRaw(gs)
                end
                break
            end
        end
    end,
})

-- Button: Copy Script
RemoteTab:Button({
    Title    = "Copy Script",
    Desc     = "Copy script remote yang dipilih",
    Icon     = "copy",
    Callback = function()
        if selected then
            local gs = selected.GenScript or genScript(selected.Remote, selected.args)
            setclipboard(gs)
            WindUI:Notify({ Title="Copied!", Content=v2s(selected.Remote), Duration=2, Icon="check" })
        else
            WindUI:Notify({ Title="SimpleSpy", Content="Belum ada remote dipilih", Duration=2, Icon="alert-circle" })
        end
    end,
})

-- Button: Run Script
RemoteTab:Button({
    Title    = "Run Script",
    Desc     = "Eksekusi remote yang dipilih",
    Icon     = "play",
    Callback = function()
        if selected and selected.Remote then
            xpcall(function()
                if selected.Remote:IsA("RemoteEvent") then
                    selected.Remote:FireServer(unpack(selected.args))
                else
                    selected.Remote:InvokeServer(unpack(selected.args))
                end
                WindUI:Notify({ Title="Executed", Content="Berhasil dijalankan", Duration=2, Icon="check-circle" })
            end, function(err)
                WindUI:Notify({ Title="Error", Content=tostring(err):sub(1,80), Duration=3, Icon="alert-triangle" })
            end)
        else
            WindUI:Notify({ Title="SimpleSpy", Content="Belum ada remote dipilih", Duration=2, Icon="alert-circle" })
        end
    end,
})

-- Button: Copy Remote Path
RemoteTab:Button({
    Title    = "Copy Remote Path",
    Desc     = "Copy path lengkap remote",
    Icon     = "link",
    Callback = function()
        if selected and selected.Remote then
            setclipboard(v2s(selected.Remote))
            WindUI:Notify({ Title="Copied!", Content="Path remote berhasil di-copy", Duration=2, Icon="check" })
        end
    end,
})

-- Button: Clear Logs
RemoteTab:Button({
    Title    = "Clear Logs",
    Desc     = "Hapus semua log remote",
    Icon     = "trash-2",
    Callback = function()
        clear(logs)
        remoteDropOptions = {"(kosong)"}
        pcall(function() remoteDrop:Refresh(remoteDropOptions) end)
        selected = nil
        if codebox then codebox:setRaw("") end
        statusPara:SetDesc("Status: "..(toggle and "✅ ON" or "❌ OFF").."  |  Remote logged: 0")
        WindUI:Notify({ Title="Cleared", Content="Semua log dihapus", Duration=2, Icon="trash-2" })
    end,
})

-- ══════════════════════════════════════════════════════════
-- TAB 2 : BLACKLIST / BLOCK
-- ══════════════════════════════════════════════════════════
local FilterTab = Window:Tab({ Title = "Filter", Icon = "filter" })

FilterTab:Paragraph({
    Title = "Blacklist",
    Desc  = "Remote yang di-blacklist tidak akan dicatat sama sekali",
})

FilterTab:Button({
    Title    = "Blacklist (ID) - Remote Dipilih",
    Desc     = "Ignore remote ini berdasarkan Debug ID",
    Icon     = "shield-off",
    Callback = function()
        if selected then
            blacklist[OldDebugId(selected.Remote)] = true
            WindUI:Notify({ Title="Blacklisted", Content=selected.Remote.Name, Duration=2, Icon="shield-off" })
        end
    end,
})

FilterTab:Button({
    Title    = "Blacklist (Name) - Remote Dipilih",
    Desc     = "Ignore semua remote dengan nama ini",
    Icon     = "shield-off",
    Callback = function()
        if selected then
            blacklist[selected.Remote.Name] = true
            WindUI:Notify({ Title="Blacklisted by name", Content=selected.Remote.Name, Duration=2, Icon="shield-off" })
        end
    end,
})

FilterTab:Button({
    Title    = "Clear Blacklist",
    Desc     = "Hapus semua blacklist",
    Icon     = "refresh-ccw",
    Callback = function()
        blacklist = {}
        WindUI:Notify({ Title="Cleared", Content="Blacklist dikosongkan", Duration=2, Icon="check" })
    end,
})

FilterTab:Paragraph({
    Title = "Blocklist",
    Desc  = "Remote yang di-block tetap dicatat tapi tidak dikirim ke server",
})

FilterTab:Button({
    Title    = "Block (ID) - Remote Dipilih",
    Desc     = "Block remote ini berdasarkan Debug ID",
    Icon     = "ban",
    Callback = function()
        if selected then
            blocklist[OldDebugId(selected.Remote)] = true
            WindUI:Notify({ Title="Blocked", Content=selected.Remote.Name, Duration=2, Icon="ban" })
        end
    end,
})

FilterTab:Button({
    Title    = "Block (Name) - Remote Dipilih",
    Desc     = "Block semua remote dengan nama ini",
    Icon     = "ban",
    Callback = function()
        if selected then
            blocklist[selected.Remote.Name] = true
            WindUI:Notify({ Title="Blocked by name", Content=selected.Remote.Name, Duration=2, Icon="ban" })
        end
    end,
})

FilterTab:Button({
    Title    = "Clear Blocklist",
    Desc     = "Hapus semua blocklist",
    Icon     = "refresh-ccw",
    Callback = function()
        blocklist = {}
        WindUI:Notify({ Title="Cleared", Content="Blocklist dikosongkan", Duration=2, Icon="check" })
    end,
})

-- ══════════════════════════════════════════════════════════
-- TAB 3 : TOOLS
-- ══════════════════════════════════════════════════════════
local ToolsTab = Window:Tab({ Title = "Tools", Icon = "tool" })

ToolsTab:Button({
    Title    = "Get Script (Source)",
    Desc     = "Copy script pemanggil remote ke clipboard",
    Icon     = "file-code",
    Callback = function()
        if selected then
            if not selected.Source then
                selected.Source = rawget(getfenv(selected.Function or function() end), "script")
            end
            setclipboard(v2s(selected.Source))
            WindUI:Notify({ Title="Copied!", Content="Calling script di-copy", Duration=2, Icon="check" })
        end
    end,
})

ToolsTab:Button({
    Title    = "Function Info",
    Desc     = "Tampilkan informasi fungsi pemanggil",
    Icon     = "info",
    Callback = function()
        if selected then
            local func = selected.Function
            if func and typeof(func) ~= "string" then
                if codebox then codebox:setRaw("--[[Generating...]]") end
                local lclosure = islclosure(func)
                local inf = {
                    info      = getinfo_fn(func),
                    constants = lclosure and deepclone(getconstants(func)) or "N/A",
                    upvalues  = deepclone(getupvalues(func)),
                    script    = {
                        SourceScript  = rawget(getfenv(func),"script") or "nil",
                        CallingScript = selected.Source or "nil",
                    }
                }
                if configs.advancedinfo then
                    inf.advancedinfo = {
                        Metamethod = selected.metamethod,
                        DebugId    = OldDebugId(selected.Remote),
                        Protos     = lclosure and getprotos and getprotos(func) or "N/A",
                    }
                end
                selected.Function = v2v({functionInfo = inf})
            end
            if codebox then
                codebox:setRaw("-- Function Info\n-- by SimpleSpy V3\n\n"..tostring(selected.Function))
            end
            WindUI:Notify({ Title="Done", Content="Function info ditampilkan", Duration=2, Icon="check" })
        end
    end,
})

ToolsTab:Button({
    Title    = "Decompile Source",
    Desc     = "Decompile script pemanggil (butuh decompile func)",
    Icon     = "code",
    Callback = function()
        if decompile then
            if selected and selected.Source then
                if not DecompiledScripts[selected.Source] then
                    if codebox then codebox:setRaw("--[[Decompiling...]]") end
                    xpcall(function()
                        local dec = decompile(selected.Source):gsub("-- Decompiled with the Synapse X Luau decompiler.","")
                        local sv2s = v2s(selected.Source)
                        if dec:find("script") and sv2s then
                            DecompiledScripts[selected.Source] = ("local script = %s\n%s"):format(sv2s, dec)
                        end
                    end, function(err)
                        if codebox then codebox:setRaw(("--[[Error: %s]]"):format(err)) end
                    end)
                end
                if codebox then codebox:setRaw(DecompiledScripts[selected.Source] or "--No Source") end
                WindUI:Notify({ Title="Done", Content="Decompile selesai", Duration=2, Icon="check" })
            else
                WindUI:Notify({ Title="Error", Content="Source tidak ditemukan", Duration=2, Icon="alert-circle" })
            end
        else
            WindUI:Notify({ Title="Error", Content="Fungsi decompile tidak tersedia", Duration=2, Icon="alert-triangle" })
        end
    end,
})

-- ══════════════════════════════════════════════════════════
-- TAB 4 : SETTINGS
-- ══════════════════════════════════════════════════════════
local SettingsTab = Window:Tab({ Title = "Settings", Icon = "settings" })

SettingsTab:Toggle({
    Title    = "Function Info",
    Desc     = "Aktifkan log fungsi pemanggil (bisa sebabkan lag)",
    Icon     = "cpu",
    Value    = configs.funcEnabled,
    Callback = function(val) configs.funcEnabled = val end,
})

SettingsTab:Toggle({
    Title    = "Log Check Caller",
    Desc     = "Log remote yang dikirim dari exploit sendiri",
    Icon     = "eye",
    Value    = configs.logcheckcaller,
    Callback = function(val) configs.logcheckcaller = val end,
})

SettingsTab:Toggle({
    Title    = "Autoblock Spam",
    Desc     = "[BETA] Otomatis abaikan remote yang terlalu sering muncul",
    Icon     = "zap-off",
    Value    = configs.autoblock,
    Callback = function(val)
        configs.autoblock = val
        if val then history = {}; excluding = {} end
    end,
})

SettingsTab:Toggle({
    Title    = "Advanced Info",
    Desc     = "Tampilkan info tambahan di Function Info",
    Icon     = "layers",
    Value    = configs.advancedinfo,
    Callback = function(val) configs.advancedinfo = val end,
})

-- Tema
local themeOptions = {"Dark","Light","Mocha","Aqua"}
SettingsTab:Dropdown({
    Title    = "Tema WindUI",
    Desc     = "Pilih tema warna GUI",
    Icon     = "palette",
    Options  = themeOptions,
    CurrentOption = "Dark",
    Callback = function(sel)
        pcall(function() WindUI:SetTheme(sel) end)
        WindUI:Notify({ Title="Tema", Content="Tema diubah ke "..sel, Duration=2, Icon="palette" })
    end,
})

-- ══════════════════════════════════════════════════════════
-- TAB 5 : ABOUT
-- ══════════════════════════════════════════════════════════
local AboutTab = Window:Tab({ Title = "About", Icon = "info" })

AboutTab:Paragraph({
    Title = "SimpleSpy V3",
    Desc  = "Remote spy untuk Roblox\nDibuat oleh 78n\nWindUI build by Footagesus\n\nPasang tema WindUI dari script kamu!",
})

AboutTab:Paragraph({
    Title = "Cara Pakai",
    Desc  = "1. Klik toggle 'Aktifkan Spy'\n2. Mainkan game & lakukan aksi\n3. Pilih remote dari dropdown\n4. Copy / Run script",
})

AboutTab:Button({
    Title    = "Join Discord SimpleSpy",
    Desc     = "discord.gg/AWS6ez9",
    Icon     = "message-circle",
    Callback = function()
        setclipboard("https://discord.com/invite/AWS6ez9")
        if request then
            pcall(request, {
                Url = "http://127.0.0.1:6463/rpc?v=1",
                Method = "POST",
                Headers = {["Content-Type"]="application/json", Origin="https://discord.com"},
                Body = http:JSONEncode({cmd="INVITE_BROWSER",nonce=http:GenerateGUID(false),args={code="AWS6ez9"}})
            })
        end
        WindUI:Notify({ Title="Discord", Content="Invite link di-copy!", Duration=2, Icon="check" })
    end,
})

-- ══════════════════════════════════════════════════════════
-- addRemoteLog  (dipanggil dari remoteHandler)
-- ══════════════════════════════════════════════════════════
function addRemoteLog(rtype, data)
    if layoutOrderNum < 1 then layoutOrderNum = 999999999 end
    local remote = data.remote

    local displayName = ("["..(rtype=="event" and "E" or "F").."] "..remote.Name)
        :sub(1, 40)

    -- cegah duplikat nama di dropdown
    local suffix = 1
    local originalName = displayName
    while table.find(remoteDropOptions, displayName) do
        suffix += 1
        displayName = originalName .. " (" .. suffix .. ")"
    end

    local log = {
        DisplayName = displayName,
        Name        = remote.Name,
        Function    = data.infofunc or "--Function Info is disabled",
        Remote      = remote,
        DebugId     = data.id,
        metamethod  = data.metamethod,
        args        = data.args,
        Blocked     = data.blocked,
        Source      = data.callingscript,
        returnvalue = data.returnvalue,
        GenScript   = "-- Generating...",
    }

    logs[#logs + 1] = log

    -- Update dropdown
    if remoteDropOptions[1] == "(kosong)" then
        remoteDropOptions = {}
    end
    table.insert(remoteDropOptions, 1, displayName)
    if #remoteDropOptions > 200 then
        table.remove(remoteDropOptions, #remoteDropOptions)
    end
    pcall(function() remoteDrop:Refresh(remoteDropOptions) end)

    -- Update status paragraph
    pcall(function()
        statusPara:SetDesc("Status: "..(toggle and "✅ ON" or "❌ OFF").."  |  Remote logged: "..#logs)
    end)

    layoutOrderNum -= 1

    -- Limit total logs
    local connect
    table.insert(remoteLogs, 1, {connect, nil})
    clean()
end

-- ══════════════════════════════════════════════════════════
-- CODEBOX  (hidden Frame untuk Highlight renderer)
-- ══════════════════════════════════════════════════════════
-- Buat ScreenGui tersembunyi untuk menampung codebox Highlight
local codeGui = Create("ScreenGui", {
    ResetOnSpawn = false,
    Enabled      = true,
    Name         = "SimpleSpy_CodeBox",
})
codebox_instance = Create("Frame", {
    Parent              = codeGui,
    BackgroundColor3    = Color3.fromRGB(10, 10, 14),
    BorderSizePixel     = 0,
    -- Letakkan di luar layar, user bisa Copy Script via button
    Position            = UDim2.new(2, 0, 2, 0),
    Size                = UDim2.new(0, 400, 0, 200),
})

codeGui.Parent = (gethui and gethui()) or CoreGui

-- ══════════════════════════════════════════════════════════
-- MAIN BOOT
-- ══════════════════════════════════════════════════════════
if not getgenv().SimpleSpyExecuted then
    local ok, err = pcall(function()
        if not RunService:IsClient() then error("SimpleSpy: tidak bisa jalan di server!") end
        if not hookmetamethod then
            WindUI:Notify({
                Title   = "Peringatan",
                Content = "Executor tidak support hookmetamethod, spy mungkin tidak optimal",
                Duration = 5,
                Icon    = "alert-triangle",
            })
        end

        codebox = Highlight.new(codebox_instance)
        logthread(spawn(function()
            local s, updatelog = pcall(game.HttpGet, game, "https://raw.githubusercontent.com/78n/SimpleSpy/main/UpdateLog.lua")
            if s and codebox then codebox:setRaw(updatelog) end
        end))

        getgenv().SimpleSpy = SimpleSpy
        getgenv().getNil = function(name, class)
            for _, v in next, getnilinstances() do
                if v.ClassName==class and v.Name==name then return v end
            end
        end

        schedulerconnect = RunService.Heartbeat:Connect(taskscheduler)

        logthread(spawn(function()
            local lp = Players.LocalPlayer or Players:GetPropertyChangedSignal("LocalPlayer"):Wait() or Players.LocalPlayer
            generation = {
                [OldDebugId(lp)]           = 'game:GetService("Players").LocalPlayer',
                [OldDebugId(lp:GetMouse())] = 'game:GetService("Players").LocalPlayer:GetMouse',
                [OldDebugId(game)]          = "game",
                [OldDebugId(workspace)]     = "workspace",
            }
        end))

        getgenv().SimpleSpyShutdown = shutdown

        WindUI:Notify({
            Title   = "SimpleSpy",
            Content = "Berhasil dimuat! Klik toggle 'Aktifkan Spy' untuk mulai.",
            Duration = 4,
            Icon    = "shield",
        })
    end)

    if ok then
        getgenv().SimpleSpyExecuted = true
    else
        pcall(shutdown)
        ErrorPrompt("SimpleSpy error:\n"..rawtostring(err))
        return
    end
else
    return
end

function SimpleSpy:newButton(name, description, onClick)
    -- Compat shim — tambahkan sebagai button di ToolsTab
    ToolsTab:Button({
        Title    = name,
        Desc     = (type(description)=="function") and description() or tostring(description),
        Icon     = "plus-square",
        Callback = function() onClick() end,
    })
end
