-- load Functions
package.path = package.path..';'..debug.getinfo(1, "S").source:match [[^@?(.*[\/])[^\/]-$]] .. "?.lua;" -- GET DIRECTORY FOR REQUIRE
package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua'
local ImGui = require 'imgui' '0.9.3'
local ctx = ImGui.CreateContext('My script')
local FLTMIN = reaper.ImGui_NumericLimits_Float()
local proj = 0

-- global Variables
ScriptVersion = "1.50"
ScriptName = 'JBJ Insert Take Marker'
Settings = {
    takeMarkerPosition_selector = 0,
    checkbox_snapoffset = false,
    colorPicker = 16777215, --white
    takeMarkerName = "",
    peakPosTreshhold = 0.9,
    peakPosMinGap = 4.9,
}
Takes_tbl = {}

local function print(msg)
    reaper.ShowConsoleMsg(tostring(msg) .. "\n")
end

local function find_peak_positions(take, threshold, min_gap)

    local aa = reaper.CreateTakeAudioAccessor(take)
    local src = reaper.GetMediaItemTake_Source(take)
    local item = reaper.GetMediaItemTake_Item(take)
    local item_len = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
  
    local samplerate = reaper.GetMediaSourceSampleRate(src)
    local numchannels = reaper.GetMediaSourceNumChannels(src)
    local block_size = 1024
    local buffer = reaper.new_array(block_size * numchannels)
    
    local positions = {}
    local last_peak_time = -min_gap
    
    local pos = 0.0
    while pos < item_len do
      local samples = math.min(block_size, math.floor((item_len - pos) * samplerate))
   
      if samples <= 0 then break end
   
      buffer.clear()
   
      reaper.GetAudioAccessorSamples(aa, samplerate, numchannels, pos, samples, buffer)
   
      for i = 1, samples * numchannels do
        local sample = math.abs(buffer[i])
        if sample >= threshold then
          local sample_index = math.floor((i - 1) / numchannels)
          local peak_time = pos + sample_index / samplerate
           
          if peak_time - last_peak_time >= min_gap then
            table.insert(positions, peak_time)
            last_peak_time = peak_time
          end
        end
      end
   
      pos = pos + samples / samplerate
    end
   
    reaper.DestroyAudioAccessor(aa)
   
    return positions
end

function InsertTakeMarker(name, color)

    ResetPeaksAndSnapoffset(Takes_tbl)
    
    Takes_tbl = {}

    -- resets tables
    local takes_tbl = {}

    if reaper.CountSelectedMediaItems(proj) > 0 then

        color = reaper.ImGui_ColorConvertNative( color )

        

        for i = 0, reaper.CountSelectedMediaItems(proj) -1 do

            -- GET ITEM AND TAKE
            local item = reaper.GetSelectedMediaItem( proj, i )
            --local dB, maxPeakPos = reaper.NF_GetMediaItemMaxPeakAndMaxPeakPos(item) -- alternative get max peak
            local take = reaper.GetActiveTake(item)
            local take_rate = reaper.GetMediaItemTakeInfo_Value(take, "D_PLAYRATE" )
            local take_offset = reaper.GetMediaItemTakeInfo_Value(take, "D_STARTOFFS")
            table.insert(takes_tbl, take)
            
            if Settings.takeMarkerPosition_selector == 1 then
                local maxPeakPos = find_peak_positions(take, Settings.peakPosTreshhold, Settings.peakPosMinGap)
                for j, pos in ipairs(maxPeakPos) do
                    reaper.DeleteTakeMarker(take, j-1)
                    reaper.SetTakeMarker(take, -1, name, pos * take_rate + take_offset, color|16777216)
                    if Settings.checkbox_snapoffset == true and j == 1 then
                        reaper.SetMediaItemInfo_Value(item, "D_SNAPOFFSET", pos)
                    end
                end
            else
                reaper.DeleteTakeMarker(take, 0)
                reaper.SetMediaItemInfo_Value(item, "D_SNAPOFFSET", 0)
                reaper.SetTakeMarker(take, -1, name, 0 * take_rate + take_offset, color|16777216)
            end
        end
    end

    do return takes_tbl end -- return takes

end

function ResetPeaksAndSnapoffset(takes_tbl)

        for _,take in ipairs(takes_tbl) do
            local nmbTakes = reaper.GetNumTakeMarkers(take)
            local item = reaper.GetMediaItemTakeInfo_Value( take, "P_ITEM")
            reaper.SetMediaItemInfo_Value(item, "D_SNAPOFFSET", 0)
            for i = 0, nmbTakes -1 do
                reaper.DeleteTakeMarker(take, i)
                reaper.DeleteTakeMarker(take, i)
                reaper.DeleteTakeMarker(take, i)
                reaper.DeleteTakeMarker(take, i)
                reaper.DeleteTakeMarker(take, i)
                reaper.DeleteTakeMarker(take, i)
                reaper.DeleteTakeMarker(take, i)
                reaper.DeleteTakeMarker(take, i)
                reaper.DeleteTakeMarker(take, i)
                reaper.DeleteTakeMarker(take, i)
                reaper.DeleteTakeMarker(take, i)
                reaper.DeleteTakeMarker(take, i)
            end
        end

end

----------------------------------------GUI-----------------------------------------------
-- window variables
local window_name = ScriptName..' '..ScriptVersion
local window_flags = ImGui.WindowFlags_None
local gui_size_w = 230
local gui_size_h = 230
Pin = true

-- font settings
Font = reaper.ImGui_CreateFont('Ubisoft Sans', 16)
FontBold = reaper.ImGui_CreateFont('Ubisoft Sans', 16, ImGui.FontFlags_Bold)
reaper.ImGui_Attach(ctx, Font)
reaper.ImGui_Attach(ctx, FontBold)

local currentItem = 1

function Loop()
    -- sets window size
    ImGui.SetNextWindowSize(ctx, gui_size_w, gui_size_h, reaper.ImGui_Cond_Once())

    -- creates window
    reaper.ImGui_PushFont(ctx, FontBold)
    local visible, open = ImGui.Begin(ctx, window_name, true, window_flags)
    reaper.ImGui_PopFont(ctx)

    -- send keys to Reaper
    if reaper.ImGui_IsWindowFocused(ctx) and (not reaper.ImGui_IsAnyItemActive(ctx)) then
        --PassKeys(ctx, false, held_keys) -- Requires at least v2.14.0.1 and JS_extension! All OS
        PassKeys2(false)  -- Requires JS_extension. OS: Windows Only 
    end

    -- pins the window as the top window at all times
    if Pin then
        window_flags = window_flags | reaper.ImGui_WindowFlags_TopMost()
    end
    
    if visible then
        
        -- marker name
        _, Settings.takeMarkerName = ImGui.InputTextWithHint(ctx, "##  ", "input marker name", Settings.takeMarkerName, ImGui.InputTextFlags_None)

        -- marker color
        _,Settings.colorPicker = ImGui.ColorEdit3(ctx, 'Choose Color', Settings.colorPicker, ImGui.ColorEditFlags_NoInputs)

        -- set snapoffset
        _, Settings.checkbox_snapoffset = ImGui.Checkbox(ctx, 'Add Snapoffset', Settings.checkbox_snapoffset)
        
        -- choose which marker placement the user wants
        local combo_items = {"Take Marker: Start Of Item", "Take Marker: Peak"}
        local previewValue = combo_items[currentItem]
        if ImGui.BeginCombo(ctx, ' ', previewValue, ImGui.ComboFlags_WidthFitPreview) then
            for i,v in ipairs(combo_items) do
              local is_selected = currentItem == i
              if ImGui.Selectable(ctx, combo_items[i], is_selected) then
                currentItem = i
                Settings.takeMarkerPosition_selector = i-1
              end
              -- Set the initial focus when opening the combo (scrolling + keyboard navigation focus)
              if is_selected then
                ImGui.SetItemDefaultFocus(ctx)
              end
            end
            ImGui.EndCombo(ctx)
          end

        if Settings.takeMarkerPosition_selector == 1 then
            _, Settings.peakPosMinGap = ImGui.SliderDouble(ctx, "##", Settings.peakPosMinGap, 0.01, 10, "MinGap = %.3f", ImGui.SliderFlags_NoRoundToFormat)
            ImGui.SetItemTooltip(ctx, 'Minimum gap between two take markers')
            _, Settings.peakPosTreshhold = ImGui.SliderDouble(ctx, "## ", Settings.peakPosTreshhold, 0.01, 5, "Treshhold = %.3f", ImGui.SliderFlags_NoRoundToFormat)
            ImGui.SetItemTooltip(ctx, 'If a sample exceeds treshhold new take marker is added')   
        end
        
        -- create markers
        if reaper.ImGui_Button(ctx, 'Create Take Markers', -FLTMIN, 30) then

            reaper.PreventUIRefresh(1)
            reaper.Undo_BeginBlock2(proj)
            reaper.ClearConsole()

            Takes_tbl = InsertTakeMarker(Settings.takeMarkerName, Settings.colorPicker)

            reaper.Undo_EndBlock2(proj,'Create Tracks', -1)
            reaper.PreventUIRefresh(-1)
            reaper.UpdateArrange()

        end

        ImGui.Separator(ctx)

        -- RESET MARKERS
        if reaper.ImGui_RadioButton(ctx, 'Reset ', true) then

            reaper.PreventUIRefresh(1)
            reaper.Undo_BeginBlock2(proj)

            ResetPeaksAndSnapoffset(Takes_tbl)

            reaper.Undo_EndBlock2(proj,'Undo Reset', -1)
            reaper.PreventUIRefresh(-1)
            reaper.UpdateArrange()

        end

        ImGui.End(ctx)
        
    end

    if open then
        reaper.defer(Loop)
    end

end

-- PASS KEY
function PassKeys(ctx, is_midieditor, held_keys)
    if not reaper.ImGui_IsWindowFocused(ctx) or reaper.ImGui_IsAnyItemActive(ctx) then return end -- Only when Script haves the focus

    local sel_window, section
    if is_midieditor then
        local midi = reaper.MIDIEditor_GetActive()
        if midi then 
            sel_window = midi
            section = 32060
        end
    end

    if not sel_window then -- Send to Main Window or Midi Editor closed
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

-- PassKeys to main or midieditor(if is_midieditor and there is any midi editor active). 
---@param is_midieditor boolean if true then it will always pass the key presses to the midi editor. If there isnt a midi editor it will pass to the main window. If false pass to the main window
function PassKeys2(is_midieditor)
    local function get_keys()
        local char = reaper.JS_VKeys_GetState(-1)
        local key_table = {}
        for i = 1, 255 do
            if char:byte(i) ~= 0 then
                table.insert(key_table,i)
            end
        end
    
        return key_table
    end

    --Get keys pressed
    local active_keys = get_keys()
    
    -- Get Window
    local sel_window
    if is_midieditor then
        local midi = reaper.MIDIEditor_GetActive()
        if midi then
            sel_window = midi
        end
    end

    if not sel_window then
        sel_window = reaper.GetMainHwnd()
    end

    --Send Message
    if sel_window then
        if #active_keys > 0  then
            for k, key_val in pairs(active_keys) do
                PostKey(sel_window, key_val)
            end
        end
    end
end

function PostKey(hwnd, vk_code)
    reaper.JS_WindowMessage_Post(hwnd, "WM_KEYDOWN", vk_code, 0,0,0)
    reaper.JS_WindowMessage_Post(hwnd, "WM_KEYUP", vk_code, 0,0,0)
end

reaper.defer(Loop)