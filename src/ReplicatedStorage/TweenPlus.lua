local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local TweenPlus   = {} ; TweenPlus.__index = TweenPlus
local TweenHandle = {} ; TweenHandle.__index = TweenHandle

local _handlesByTag = {}
local _handlesByInstance = setmetatable({}, {__mode="k"})

local _presets = {}

local function newHandle(tween, startValues)
    local self = setmetatable({
        _tween = tween,
        _startValues = startValues,
        _chain = {}, -- queue of functions/handles
        _canceled = false,
        _connection = nil,
        _tag = nil,
        _instance = nil,

        OnStart       = nil,
        OnComplete    = nil,
        OnCancel      = nil,

        _startClock = nil,
        _frames = 0,

        _loopOriginal = nil,
        _loopCount = 0
    }, TweenHandle)

    self._connection = tween.Completed:Connect(function()
        self:_advance()
    end)

    self._instance = tween.Instance

    local list = _handlesByInstance[self._instance]
    if not list then
        list = {}
        _handlesByInstance[self._instance] = list
    end
    table.insert(list, self)

    return self
end

function TweenHandle:_advance()
    if self._canceled then return end

    local nextItem = table.remove(self._chain, 1)

    if not nextItem then
        if self._loopCount and self._loopCount > 0 and self._loopOriginal then
            if self._loopCount ~= math.huge then
                self._loopCount -= 1
            end

            for i = #self._loopOriginal, 1, -1 do
                local link = self._loopOriginal[i]
                if getmetatable(link) == TweenHandle then
                    link:_rewind()
                end
            end

            self:_rewind()
            self._startClock = os.clock()
            self._chain = table.clone(self._loopOriginal)
            self._tween:Play()
        else
            if type(self.OnComplete) == "function" then
                pcall(self.OnComplete, self)
            end
            if self._rsConn then
                self._rsConn:Disconnect()
                self._rsConn = nil
            end
            self:_cleanup()
        end

        return
    end

    if typeof(nextItem) == "function" then
        nextItem(function() self:_advance() end)
    else
        nextItem:Then(function() self:_advance() end)
        nextItem:Play()
    end
end

function TweenHandle:Play()
    if self._canceled then return self end

    if not self._startClock then
        self._startClock = os.clock()

        if type(self.OnStart) == "function" then
            pcall(self.OnStart, self)
        end

        self._rsConn = RunService.RenderStepped:Connect(function()
            self._frames += 1
        end)
    end

    self._tween:Play()
    return self
end

function TweenHandle:Then(nextItem)
    table.insert(self._chain, nextItem)
    return self
end

function TweenHandle:Wait(seconds)
    return self:Then(function(resolve)
        task.delay(seconds, resolve)
    end)
end

function TweenHandle:Loop(count)
    if count == "infinite" then
        count = math.huge
    elseif type(count) ~= "number" or (count < 1) then
        error("Loop count must be a positive integer or \"infinite\"")
    end
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
    if self._rsConn then self._rsConn:Disconnect() end
    self:_cleanup()
end

function TweenHandle:Tag(tagName)
    if self._tag and _handlesByTag[self._tag] then
        table.remove(_handlesByTag[self._tag], table.find(_handlesByTag[self._tag], self))
    end

    self._tag = tagName
    _handlesByTag[tagName] = _handlesByTag[tagName] or {}
    table.insert(_handlesByTag[tagName], self)

    return self
end

function TweenHandle:Debug(message)
    local tag = self._tag or "untagged"
    return self:Then(function(resolve)
        local timeStamp
        if self._startClock then
            timeStamp = string.format("+%.2fs", os.clock() - self._startClock)
        else
            timeStamp = "+0.00s"
        end

        print(string.format("[TweenPlus][%s] [%s] %s", tag, timeStamp, tostring(message)))
        resolve()
    end)
end

function TweenHandle:_rewind()
    if not self._startValues then return end
    for prop, value in pairs(self._startValues) do
        self._tween.Instance[prop] = value
    end
end

function TweenHandle:_cleanup()
    self._tween = nil
    self._chain = nil
    self._loopOriginal = nil
    self._startValues = nil
end

function TweenPlus:Create(instance, tweenInfo, goals)
    local tween = TweenService:Create(instance, tweenInfo, goals)
    local startValues = {}
    for prop in pairs(goals) do
        startValues[prop] = instance[prop]
    end
    return newHandle(tween, startValues)
end

function TweenPlus:Debug(message)
    print("[TweenPlus]", message)
    return self
end

function TweenPlus:CancelByTag(tag)
    local list = _handlesByTag[tag]
    if not list then return end
    for i = #list, 1, -1 do
        local h = list[i]
        if h and not h._canceled then h:Cancel() end
        list[i] = nil
    end
    _handlesByTag[tag] = nil
end

function TweenPlus:CancelByInstance(instance)
    local list = _handlesByInstance[instance]
    if not list then return end
    for i = #list, 1, -1 do
        local h = list[i]
        if h and not h._canceled then h:Cancel() end
        list[i] = nil
    end
    _handlesByInstance[instance] = nil
end

function TweenPlus:CreatePreset(name, tweenInfo, goals)
    assert(type(name) == "string" and #name > 0, "Preset name must be a non-empty string")
    assert(typeof(tweenInfo) == "TweenInfo", "tweenInfo must be a TweenInfo")
    assert(type(goals) == "table", "goals must be a table of property -> value")

    local goalsCopy = {}
    for prop, val in pairs(goals) do
        goalsCopy[prop] = val
    end

    _presets[name] = {
        tweenInfo = tweenInfo,
        goals = goalsCopy
    }

    return self
end

function TweenPlus:ApplyPreset(name, instance)
    local preset = _presets[name]
    assert(preset, ("No preset created under name %q"):format(name))

    return self:Create(instance, preset.tweenInfo, preset.goals)
end

return TweenPlus
