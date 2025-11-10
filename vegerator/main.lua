-- main.lua

-----------
--MODULES--
-----------

--Require helper function
local function require_local(name)
	local path = debug.getinfo(2, 'S').source:match("@?(.*[\\/])")
	return dofile(path .. name)
end

--Load modules
local GUI = require_local("GUI.lua")
local engine = require_local("engine.lua")
dofile(reaper.GetResourcePath() .. "\\Scripts\\ReaTeam Extensions\\API\\imgui.lua") -- ReaImGui

---------
--SETUP--
---------

local reaper = reaper

--Global Variables
ScriptName = "Vegerator"
ScriptVersion = "0.0.2"

local ext_state_section = ScriptName .. "_" .. ScriptVersion .. "_Authors_JacobJohannsen_FranzBierschwale"
local held_keys = {}


--GUI Config
local ctx = reaper.ImGui_CreateContext(ScriptName)
local mwin = {
  dimension = {
    w = 850,
    h = 600
  },
  conditions = reaper.ImGui_Cond_Once(),
  flags = {
    menubar = reaper.ImGui_WindowFlags_MenuBar(),
		none = reaper.ImGui_WindowFlags_None(),
		no_background = reaper.ImGui_WindowFlags_NoBackground(),
		no_titlebar = reaper.ImGui_WindowFlags_NoTitleBar(),
		pin_to_top = reaper.ImGui_WindowFlags_TopMost()
  }
}

--Font settings
Fonts = {
  ubisoft_sans = reaper.ImGui_CreateFont('Ubisoft Sans', 14, nil),
  ubisoft_sans_bold = reaper.ImGui_CreateFont('Ubisoft Sans', 14, reaper.ImGui_FontFlags_Bold())
}
reaper.ImGui_Attach(ctx, Fonts.ubisoft_sans)
reaper.ImGui_Attach(ctx, Fonts.ubisoft_sans_bold)

-- PASS KEY
function PassKeys(ctx, is_midieditor, held_keys)
  if not reaper.ImGui_IsWindowFocused(ctx) or reaper.ImGui_IsAnyItemActive(ctx) then return end

  local sel_window, section 
  if is_midieditor then
      local midi = reaper.MIDIEditor_GetActive()
      if midi then 
          sel_window = midi 
          section = 32060
      end
  end

  if not sel_window then
      sel_window = reaper.GetMainHwnd()
      section = 0
  end

  local keys = reaper.JS_VKeys_GetState(0)
  for k = 1, #keys do
      local is_key = keys:byte(k) ~= 0
      if k ~= 0xD and is_key and not held_keys[k] then
          reaper.CF_SendActionShortcut(sel_window, section, k)
          held_keys[k] = true
      elseif not is_key and held_keys[k] then
          held_keys[k] = nil
      end
  end

  if reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_Enter()) then
      reaper.CF_SendActionShortcut(sel_window, section, 0xD)
  end
  if reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_KeypadEnter()) then
      reaper.CF_SendActionShortcut(sel_window, section, 0x800D)
  end  
end

---------
--START--
---------

--Load saved data from REAPER's ext state and merge into current state
local keys_tbl = {
  ext_state_key_GUI = "GUI",
  ext_state_key_folder = "Folder",
  ext_state_key_item_spacing = "ItemSpacing"
}

local state_load = Get_ext_state_key_values()

for key, value in pairs(keys_tbl) do
  if reaper.HasExtState(ext_state_section, value) then
    local get_ext_state = reaper.GetExtState(ext_state_section, value)
    local str = "return " .. get_ext_state
    local func, err = load(str)

    if not func then
      reaper.ShowConsoleMsg("Error loading GetExtState " .. value .. " data: " .. tostring(err) .. "\n")
    else
      local new_value = func()

      if value == keys_tbl.ext_state_key_GUI then
        DeepMerge(state_load.gui, new_value)
      end

      if value == keys_tbl.ext_state_key_folder then
        DeepMerge(state_load.folder, new_value)
      end

      if value == keys_tbl.ext_state_key_item_spacing then
        state_load.item_spacing_ref(new_value)
      end
      
    end
  end
end


local function loop()

  local windowflags = mwin.flags.none
  if GUI.Settings.pin_to_top     then windowflags = windowflags  |  mwin.flags.pin_to_top     end
	if GUI.Settings.no_background  then windowflags = windowflags  |  mwin.flags.no_background  end
	if GUI.Settings.no_titlebar    then windowflags = windowflags  |  mwin.flags.no_titlebar    end

  reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_Alpha(), GUI.Settings.customization.alpha)

  local visible, open = reaper.ImGui_Begin(ctx, ScriptName, true, mwin.flags.menubar | windowflags)

  if visible then
    reaper.ImGui_SetNextWindowSize(ctx, mwin.dimension.w, mwin.dimension.h, mwin.conditions)
    
    if open then

      GUI.draw(ctx)

      -- send keys to Reaper
      if reaper.ImGui_IsWindowFocused(ctx) and (not reaper.ImGui_IsAnyItemActive(ctx)) then
        PassKeys(ctx, false, held_keys) -- Requires at least v2.14.0.1 and JS_extension! All OS
      end
    end
    
    reaper.ImGui_End(ctx)
  end

  
  if open then                                            --Code that runs when window is open
    reaper.defer(loop)
  else                                                    --Code that runs when window closes
    
    engine.delete_preview_track(GUI.Events.preview_track)

    --Deletes previously stored 'key' data
    for key, value in pairs(keys_tbl) do
      if reaper.HasExtState(ext_state_section, value) then
        reaper.DeleteExtState(ext_state_section, value, true)
      end
    end

    --Saves data
    local state_save = Get_ext_state_key_values() --calls an update state when saving

    local function SaveExtState(key, value)
      reaper.SetExtState(ext_state_section, key, value, true)
    end
    
    SaveExtState(keys_tbl.ext_state_key_GUI, Table_to_string(state_save.gui))
    SaveExtState(keys_tbl.ext_state_key_folder, Table_to_string(state_save.folder))
    SaveExtState(keys_tbl.ext_state_key_item_spacing, tostring(state_save.item_spacing_ref()))-- item_spacing_ref is a getter/setter function:

    reaper.UpdateArrange()

  end

  reaper.ImGui_PopStyleVar(ctx)

end

reaper.defer(loop)