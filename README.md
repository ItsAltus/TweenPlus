# TweenPlus
![License: MIT](https://img.shields.io/badge/license-MIT-green)
![Roblox](https://img.shields.io/badge/platform-Roblox-blue)
![Memory Safe](https://img.shields.io/badge/memory-safe-yellow)
![Zero Dependencies](https://img.shields.io/badge/dependencies-none-lightgrey)

**Project:** TweenPlus
**Author:** ItsAltus (GitHub) / DrChicken2424 (ROBLOX)

---

## Overview

**TweenPlus** is a chainable wrapper around Roblox’s native `TweenService`, designed to reduce the boilerplate of common animation flows using a custom API.

- **Chaining** (`:Then`, `:Wait`, `:Loop`)  
- **Presets** (`:CreatePreset` / `:ApplyPreset`)  
- **Batch cancellation** by tag or instance  
- **Optional signals** (`OnStart`, `OnComplete`, `OnCancel`)  
- **Debug helpers** (`:Debug`)  

---

## Installation

To use TweenPlus in your game:

1. Download the latest release `.rbxmx` file from [Releases](https://github.com/ItsAltus/TweenPlus/releases) or the project files above
2. Open your game in Roblox Studio
3. Import the file into `ReplicatedStorage`, or whichever folder you want it in
4. Require it in any script:
   ```lua
   local TweenPlus = require(game.ReplicatedStorage.TweenPlus)
   ```

## Test Place

I have also included a ready-to-open test place so you can see TweenPlus in action right away:

1. Clone or download this repo  
2. Open **`places/TestPlace.rbxl`** in Roblox Studio   

---

## Features & Benefits

- **Boilerplate reduction:** Eliminates repeated `:Completed` wiring  
- **Readability:** Declarative, left-to-right flow vs. nested callbacks  
- **Reusability:** Define a preset once, apply it anywhere  
- **Control:** Pause, loop, cancel by tag or instance in one call  
- **Debugging:** Built-in `:Debug()` with timestamps and tags  
- **Resource management:** Automatic disconnects and memory cleanup 

Compare a “slide up -> slide down -> loop -> cancel” tween flow **without** TweenPlus vs. **with** TweenPlus:

### Without TweenPlus (40 lines pure code)
```lua
local TweenService = game:GetService("TweenService")
local part = script.Parent

local infoIn = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local goalsIn = { Position = part.Position + Vector3.new(0, 5, 0) }

local infoOut = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
local goalsOut = { Position = part.Position }

local tweens = {}
local canceled = false

local function cancelAll()
	if canceled then return end
	canceled = true
	for _, tw in ipairs(tweens) do
		pcall(function() tw:Cancel() end)
	end
	print("[x] cancelled all")    -- OnCancel
end

-- Start the loop after 1s
spawn(function()
	task.wait(1)
	print("[>] Slide started")    -- OnStart

	while not canceled do
		-- slide in
		local tUp = TweenService:Create(part, infoIn, goalsIn)
		table.insert(tweens, tUp)
		tUp:Play()
		tUp.Completed:Wait()
		if canceled then break end

		print("-> at the top")     -- Debug
		task.wait(0.2)

		-- slide out
		local tDown = TweenService:Create(part, infoOut, goalsOut)
		table.insert(tweens, tDown)
		tDown:Play()
		tDown.Completed:Wait()
		if canceled then break end

		print("-> at the bottom")  -- Debug
		task.wait(0.2)
	end

	if not canceled then
		print("[:)] cycle complete")  -- OnComplete
	end
end)

-- Auto-cancel after 6 seconds
task.delay(6, cancelAll)
```

### With TweenPlus (25 lines pure code)
```lua
local TweenPlus = require(game.ReplicatedStorage.TweenPlus)
local part = script.Parent

-- register & reuse presets
TweenPlus:CreatePreset("SlideIn", TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Position = part.Position + Vector3.new(0,5,0)})
TweenPlus:CreatePreset("SlideOut", TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Position = part.Position})

-- build a single handle for infinite slide loop
local h = TweenPlus
	:ApplyPreset("SlideIn", part)
	:Tag("SlideCycle")
	:Debug("-> at the top")
	:Wait(0.2)
	:Then(function(resolve)
		TweenPlus:ApplyPreset("SlideOut", part)
		:Then(resolve)
		:Play()
	end)
	:Debug("-> at the bottom")
	:Wait(0.2)
	:Loop("infinite")

-- optional signals
h.OnStart = function() print("[>] Slide started") end
h.OnComplete = function() print("[:)] cycle complete") end
h.OnCancel = function() print("[x] cancelled all") end

-- fire & auto‐cancel
task.wait(1)
h:Play()
task.delay(6, function()
	TweenPlus:CancelByTag("SlideCycle")
end)
```

### These two scripts in action:
![Comparison Demo](https://i.gyazo.com/f7923d1e0d3eeffaf287b351177dddb6.gif)  

---

## Core API

### Module methods (`TweenPlus`)

| Method                                       | Description                                       |
|----------------------------------------------|---------------------------------------------------|
| `:Create(inst, tweenInfo, goals)`            | Returns a `TweenHandle` for the tween             |
| `:CreatePreset(name, tweenInfo, goals)`      | Registers a reusable preset                       |
| `:ApplyPreset(name, instance)`               | Returns a handle built from a named preset        |
| `:CancelByTag(tag)`                          | Cancels all handles tagged with `tag`             |
| `:CancelByInstance(instance)`                | Cancels all handles running on that instance      |
| `:Debug(message)`                            | Prints immediately (build-time helper)            |

### Handle methods (`TweenHandle`)

| Method                               | Description                                       |
|--------------------------------------|---------------------------------------------------|
| `:Play()`                            | Starts the tween                                  |
| `:Then(funcOrHandle)`                | Runs a function or another handle on completion   |
| `:Wait(seconds)`                     | Inserts a delay in the chain                      |
| `:Loop(count \| "infinite")`         | Repeats the chain `count` times (or forever)      |
| `:Cancel()`                          | Stops the tween and cleans up                     |
| `:Tag(name)`                         | Labels the handle for batch cancellation          |
| `:Debug(message)`                    | Enqueues a timestamped print in the chain         |

#### Optional signals

Assign any of these functions on a handle before calling `:Play()`:

```lua
handle.OnStart    = function(self) print("[>] started:", self._tag) end
handle.OnComplete = function(self) print("[:)] done:",    self._tag) end
handle.OnCancel   = function(self) print("[x] cancelled:", self._tag) end
```

---

## Contributing

1. Fork the repo  
2. Create a branch (`git checkout -b feature/new-preset`)  
3. Make your changes in `src/`  
4. Update documentation in `README.md`  
5. Submit a pull request  
