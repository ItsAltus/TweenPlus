-- ============================================================
-- Script Name: TweenPlus.lua
-- Project: TweenPlus
-- Author: ItsAltus (GitHub) / DrChicken2424 (Roblox)
-- Description: Chain-friendly wrapper around Roblox TweenService
--              that supports
--                 * clean Then / Wait / Loop syntax
--                 * reusable animation presets
--                 * batch cancellation (by tag or instance)
--                 * optional OnStart / OnComplete / OnCancel
--                 * zero-leak cleanup
-- ============================================================

---------------------------------------------------------------
-- SERVICES
---------------------------------------------------------------
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

---------------------------------------------------------------
-- MODULE TABLES & WEAK REGISTRIES
---------------------------------------------------------------
local TweenPlus = {} ; TweenPlus.__index   = TweenPlus
local TweenHandle = {} ; TweenHandle.__index = TweenHandle

-- tag -> {TweenHandle,…}
local _handlesByTag = {}

-- instance -> {TweenHandle,…} (weak keys so finished handles garbage collect)
local _handlesByInstance = setmetatable({}, {__mode = "k"})

-- presetName -> {tweenInfo = TweenInfo, goals = table}
local _presets = {}

---------------------------------------------------------------
-- HELPER: create a fully-wired TweenHandle
---------------------------------------------------------------
local function newHandle(tween: Tween, startValues: table)
    local self = setmetatable({
        -- tween internals
        _tween = tween,
        _startValues = startValues, -- for rewinds
        _chain = {}, -- queue of funcs / handles
        _canceled = false,
        _connection = nil, -- completed conn
        _rsConn = nil, -- frame counter conn
        _tag = nil,
        _instance = tween.Instance,

        -- user callbacks
        OnStart = nil,
        OnComplete = nil,
        OnCancel = nil,

        -- debug timing
        _startClock = nil,
        _frames = 0,

        -- loop bookkeeping
        _loopOriginal = nil, -- snapshot of first chain
        _loopCount = 0,
    }, TweenHandle)

    -- when tween finishes, pop next link
    self._connection = tween.Completed:Connect(function()
        self:_advance()
    end)

    -- register in weak instance table
    local bucket = _handlesByInstance[self._instance]
    if not bucket then
        bucket = {}
        _handlesByInstance[self._instance] = bucket
    end
    table.insert(bucket, self)

    return self
end

---------------------------------------------------------------
-- INTERNAL: step through the queued chain / handle looping
---------------------------------------------------------------
function TweenHandle:_advance()
    if self._canceled then return end

    local nextItem = table.remove(self._chain, 1)

    -- chain empty -> either loop or finish
    if not nextItem then
        -- ========== LOOP ========== --
        if self._loopCount and self._loopCount > 0 and self._loopOriginal then
            if self._loopCount ~= math.huge then
                self._loopCount -= 1
            end

            -- rewind nested handles (reverse so first tween in)
            for i = #self._loopOriginal, 1, -1 do
                local h = self._loopOriginal[i]
                if getmetatable(h) == TweenHandle then
                    h:_rewind()
                end
            end
            -- rewind the root handle (self)
            self:_rewind()

            -- restart timing + chain and play again
            self._startClock = os.clock()
            self._chain = table.clone(self._loopOriginal)
            self._tween:Play()
            return
        end

        -- ========== FINISHED ========== --
        if type(self.OnComplete) == "function" then
            pcall(self.OnComplete, self)
        end
        if self._rsConn then
            self._rsConn:Disconnect()
        end
        self:_cleanup()
        return
    end

    -- there *is* a nextItem -> run it, then continue
    if typeof(nextItem) == "function" then
        nextItem(function() self:_advance() end)
    else
        -- it's another TweenHandle; splice callback + start it
        nextItem:Then(function() self:_advance() end)
        nextItem:Play()
    end
end

---------------------------------------------------------------
-- PUBLIC (handle): Play / Then / Wait / Loop / Cancel / Tag
---------------------------------------------------------------
function TweenHandle:Play()
    if self._canceled then return self end

    -- first ever play -> start timing & OnStart
    if not self._startClock then
        self._startClock = os.clock()

        if type(self.OnStart) == "function" then
            pcall(self.OnStart, self)
        end

        local evt = RunService:IsClient() and RunService.RenderStepped
                                         or RunService.Heartbeat
        self._rsConn = evt:Connect(function()
            self._frames += 1
        end)
    end

    self._tween:Play()
    return self
end

function TweenHandle:Then(item) table.insert(self._chain, item);   return self end
function TweenHandle:Wait(sec) return self:Then(function(r) task.delay(sec,r) end) end

function TweenHandle:Loop(count)
    if count == "infinite" then count = math.huge end
    assert(type(count) == "number" and count >= 1, "Loop count must be positive or \"infinite\"")
    self._loopCount = count
    self._loopOriginal = table.clone(self._chain)
    return self
end

function TweenHandle:Cancel()
    if self._canceled then return end
    self._canceled = true
    if type(self.OnCancel) == "function" then
        pcall(self.OnCancel, self)
    end
    self._tween:Cancel()
    if self._connection then self._connection:Disconnect() end
    if self._rsConn   then self._rsConn:Disconnect()   end
    self:_cleanup()
end

function TweenHandle:Tag(name)
    if self._tag then -- remove old tag bucket
        local old = _handlesByTag[self._tag]
        if old then table.remove(old, table.find(old, self)) end
    end
    self._tag = name
    _handlesByTag[name] = _handlesByTag[name] or {}
    table.insert(_handlesByTag[name], self)
    return self
end

-- inline debug print
function TweenHandle:Debug(msg)
    local tag = self._tag or "untagged"
    return self:Then(function(resolve)
        local dt = self._startClock and (os.clock() - self._startClock) or 0
        print(("[TweenPlus][%s] [+%.2fs] %s"):format(tag, dt, msg))
        resolve()
    end)
end

---------------------------------------------------------------
-- INTERNAL: rewind & hard cleanup
---------------------------------------------------------------
function TweenHandle:_rewind()
    if not self._startValues then return end
    for prop, val in pairs(self._startValues) do
        self._tween.Instance[prop] = val
    end
end

function TweenHandle:_cleanup()
    self._tween, self._chain, self._loopOriginal, self._startValues = nil,nil,nil,nil
end

---------------------------------------------------------------
-- PUBLIC (module): Create / Debug
---------------------------------------------------------------
function TweenPlus:Create(inst, info: TweenInfo, goals: table)
    local tween = TweenService:Create(inst, info, goals)

    -- capture start values for rewind
    local start = {}
    for prop in pairs(goals) do
        start[prop] = inst[prop]
    end
    return newHandle(tween, start)
end

function TweenPlus:Debug(msg) print("[TweenPlus]", msg); return self end

---------------------------------------------------------------
-- PUBLIC (module): Batch cancel helpers
---------------------------------------------------------------
function TweenPlus:CancelByTag(tag)
    local bucket = _handlesByTag[tag]
    if not bucket then return end
    for i = #bucket, 1, -1 do
        if bucket[i] then
            bucket[i]:Cancel()
        end
        bucket[i] = nil
    end
    _handlesByTag[tag] = nil
end

function TweenPlus:CancelByInstance(inst)
    local bucket = _handlesByInstance[inst]
    if not bucket then return end
    for i = #bucket, 1, -1 do
        if bucket[i] then
            bucket[i]:Cancel()
        end
        bucket[i] = nil
    end
    _handlesByInstance[inst] = nil
end

---------------------------------------------------------------
-- PUBLIC (module): Preset registry
---------------------------------------------------------------
function TweenPlus:CreatePreset(name, info, goals)
    assert(type(name) == "string" and #name > 0, "invalid preset name")
    assert(typeof(info) == "TweenInfo", "second arg must be TweenInfo")
    _presets[name] = {tweenInfo = info, goals = table.clone(goals)}
    return self
end

function TweenPlus:ApplyPreset(name, inst)
    local p = _presets[name]
    assert(p, ("No preset %q registered"):format(name))
    return self:Create(inst, p.tweenInfo, p.goals)
end

return TweenPlus
