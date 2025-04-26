local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local TweenPlus   = {} ; TweenPlus.__index = TweenPlus
local TweenHandle = {} ; TweenHandle.__index = TweenHandle

local function newHandle(tween)
    local self = setmetatable({
        _tween = tween,
        _chain = {}, -- queue of functions/handles
        _canceled = false,
        _connection = nil,
        _tag = nil,

        _startClock = nil,
        _frames = 0
    }, TweenHandle)

    self._connection = tween.Completed:Connect(function()
        self:_advance()
    end)

    return self
end

function TweenHandle:_advance()
    if self._canceled then return end

    local nextItem = table.remove(self._chain, 1)
    if not nextItem then
        if self._rsConn then
            self._rsConn:Disconnect()
            self._rsConn = nil
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

function TweenHandle:Cancel()
    if self._canceled then return end
    self._canceled = true
    self._tween:Cancel()
    if self._connection then self._connection:Disconnect() end
end

function TweenHandle:Tag(tagName)
    self._tag = tagName
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

function TweenPlus:Debug(message)
    print("[TweenPlus]", message)
    return self
end

function TweenPlus:Create(instance, tweenInfo, goals)
    local tween = TweenService:Create(instance, tweenInfo, goals)
    return newHandle(tween)
end

return TweenPlus
