# Style Guide for ReaScripts  
**Audio Tool Development**

## General Philosophy
This guide exists to keep our ReaScripts clean, consistent, and collaborative. While it's not enforced by bots, following it will make your code easier to read, maintain, and scale — especially as more people jump in.

## 1. Project Structure

Organize your files by responsibility:

- `main.lua` – Entry point. Handles execution flow, global setup, and ReaImGui defer loop.
- `gui.lua` – All UI code lives here. Uses ReaImGui.
- `engine.lua` – Core logic and features that power the tool.
- `utils.lua` – Helper functions used by `engine.lua` (not GUI-specific).

## 2. Naming Conventions

- **Variables & Functions:** `snake_case`  
  Example: `volume_level`, `update_volume()`, `get_selected_items()`

- **Classes (OOP-style tables):** `CamelCase`  
  Example: `AudioItem`, `RegionList`

- **Module-local constants (optional):** `_UPPER_SNAKE_CASE`  
  Example: `_MAX_REGIONS`, `_DEBUG_MODE`

Stick to meaningful names. Avoid abbreviations unless they’re universally understood (`vol`, `pos`, `fx`, etc.).

## 3. Formatting & Style

- **Indentation:** Tabs, visually aligned to **2 spaces**
- **Line length:** Soft limit at 100 characters
- **Whitespace:** Leave one empty line between function definitions and logic blocks

### Example
```lua
function get_selected_items()

	local items = {}

	for i = 0, reaper.CountSelectedMediaItems(0) - 1 do
		items[#items + 1] = reaper.GetSelectedMediaItem(0, i)
	end

	return items
end

## 4. Comments

- Use **inline comments** where clarity is needed, especially around tricky logic or ReaScript-specific quirks
- Don’t overcomment. Let clean code speak for itself
- Use comments to document **why**, not just **what**

```lua
-- Only update if item has valid take
if take ~= nil then
	process_take(take)
end

## 5. Functions & Modularity

- **Keep functions small**: Prefer composability over one big block
- **Single responsibility**: A function should do one thing well
- Use `utils.lua` for common helper functions
- Prefer `local` scope to avoid global pollution

## 6. Error Handling

Use `pcall()` for safe execution:

```lua
local ok, result = pcall(some_risky_function)
if not ok then
	reaper.ShowMessageBox("Something went wrong: " .. tostring(result), "Error", 0)
end

## 7. Version Control (Git)

- **Hosting:** GitLab
- **Commit messages:**
  - YES! `Fix: Region list UI not refreshing`
  - YES! `Add: auto-trim silence utility function`
  - NO! `misc changes` or `updated stuff`

## 8. External Dependencies

- **Avoid them** whenever possible — scripts should be drop-in and require no external installs
- If unavoidable:
  - Wrap the dependency in a safe loader
  - Clearly document it at the top of `main.lua`

## 9. Collaboration & Code Reviews

- Code reviews are encouraged before merging
- Leave comments on complex logic or tricky REAPER API behavior
- Treat feedback as part of the creative process

## 10. Testing & Validation

- Testing is **manual and local**
- Before submitting code:
  - Run it in REAPER and validate all expected behavior
  - If possible, test on a clean install with factory settings

## Final Notes

This guide is here to help — not to lock you in.  
When in doubt: **favor clarity, reliability, and reusability**.

And remember: write the code you’d want to debug six months from now.
