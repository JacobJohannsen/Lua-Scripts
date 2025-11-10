--utils.lua

---------
--SETUP--
---------

local Utils = {}

-- Persistent Settings for Reaper
local EXT_SECTION = "Vegerator"
local EXT_KEY_LASTFOLDER = "LastUsedFolder"

-------------
--FUNCTIONS--
-------------

--- Return dbval in linear value. 0 = -inf, 1 = 0dB, 2 = +6dB, etc...
function Utils.db_to_linear(dbval)
  return 10^(dbval/20) 
end

--- Return value in db. 0 = -inf, 1 = 0dB, 2 = +6dB, etc...
local function linear_to_db(value)
  return 20 * math.log(value,10)    
end

function Utils.get_rgb_color(color)
  local r, g, b = reaper.ColorFromNative(color)-- Extract RGB values from an OS dependent color.
  local color_int = (b + 256 * g + 65536 * r)|16777216 -- CONVERT THE RGB COLOR TO INT
  do return color_int end
end

-- Return percentage to item length
local function get_item_length_percentage(media_item, percentage)
  if media_item == nil or percentage == nil then return end
  local fade_duration = 0

  local item_length = reaper.GetMediaItemInfo_Value(media_item, "D_LENGTH")
  fade_duration = item_length * (percentage / 100)

  do return fade_duration end

end

--Set peak take marker
local function set_peak_marker(take, position, label)
  reaper.SetTakeMarker(take, -1, label or "Peak", position, 0)
end

local function get_peak_positions(take, threshold, min_gap)

  local aa = reaper.CreateTakeAudioAccessor(take)
  local src = reaper.GetMediaItemTake_Source(take)
  local item = reaper.GetMediaItemTake_Item(take)
  local item_len = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")

  local samplerate = reaper.GetMediaSourceSampleRate(src)
  local num_channels = reaper.GetMediaSourceNumChannels(src)
  local block_size = 1024
  local buffer = reaper.new_array(block_size * num_channels)
  
  local positions = {}
  local last_peak_time = -min_gap
  
  local pos = 0.0
  while pos < item_len do
    local samples = math.min(block_size, math.floor((item_len - pos) * samplerate))
 
    if samples <= 0 then break end
 
    buffer.clear()
 
    reaper.GetAudioAccessorSamples(aa, samplerate, num_channels, pos, samples, buffer)
 
    for i = 1, samples * num_channels do
      local sample = math.abs(buffer[i])
      if sample >= threshold then
        local sample_index = math.floor((i - 1) / num_channels)
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

--FIX: Change these to be two functions instead of 4
--Sets fadein based on a percentage
function Utils.set_fade_in_percentage(media_items, fade_in_percentage)
  if media_items == nil or fade_in_percentage == nil then return end
  for _, media_item in ipairs(media_items) do
      local fade_in_duration = get_item_length_percentage(media_item, fade_in_percentage)
      reaper.SetMediaItemInfo_Value(media_item, "D_FADEINLEN_AUTO", -1)
      reaper.SetMediaItemInfo_Value(media_item, "D_FADEINLEN", fade_in_duration)
  end
end

--Sets fadein shape
function Utils.set_fade_in_shape(media_items, fade_in_shape)
  if media_items == nil or fade_in_shape == nil then return end
  for _, media_item in ipairs(media_items) do
      reaper.SetMediaItemInfo_Value(media_item, "C_FADEINSHAPE", fade_in_shape)
  end
end

--Sets fadeout based on a percentage
function Utils.set_fade_out_percentage(media_items, fade_out_percentage)
  if media_items == nil or fade_out_percentage == nil then return end
  for _, media_item in ipairs(media_items) do
    local fade_out_duration = get_item_length_percentage(media_item, fade_out_percentage)
    reaper.SetMediaItemInfo_Value(media_item, "D_FADEOUTLEN_AUTO", -1)
    reaper.SetMediaItemInfo_Value(media_item, "D_FADEOUTLEN", fade_out_duration)
  end
end

-- Sets fadeout shape
function Utils.set_fade_out_shape(media_items, fade_out_shape)
  if media_items == nil or fade_out_shape == nil then return end
  for _, media_item in ipairs(media_items) do
    reaper.SetMediaItemInfo_Value(media_item, "C_FADEOUTSHAPE", fade_out_shape)
  end
end

function Utils.insert_eq(track)
  if not track then return end
  -- this function relies on ReaEQ from cockos
  local track_eq = reaper.TrackFX_GetEQ(track, true)
  reaper.TrackFX_Show(track, track_eq, 2) -- prevents the EQ from appearing in a floating window
  reaper.TrackFX_SetEQBandEnabled(track, track_eq, 2, 1, false ) --disable unused band
end

function Utils.update_eq_param(track, low_gain, low_freq, low_band, mid_gain, mid_freq, mid_band, high_gain, high_freq, high_band)
  
  if not track then return end

  local eq = reaper.TrackFX_GetEQ( track, false )

  if eq >= 0 then
    --low
    reaper.TrackFX_SetEQParam(track, eq, 1, 0, 0, low_freq, false ) --freq
    local low_gain_new = 10^(low_gain / 20) --normalizes volume input
    reaper.TrackFX_SetEQParam(track, eq, 1, 0, 1, low_gain_new, false ) --dB
    reaper.TrackFX_SetEQParam(track, eq, 1, 0, 2, low_band, false ) --band
    --mid
    reaper.TrackFX_SetEQParam(track, eq, 2, 0, 0, mid_freq, false ) --freq
    local mid_gain_new = 10^(mid_gain / 20) --normalizes volume input
    reaper.TrackFX_SetEQParam(track, eq, 2, 0, 1, mid_gain_new, false ) --dB
    reaper.TrackFX_SetEQParam(track, eq, 2, 0, 2, mid_band, false ) --band
    --high 
    reaper.TrackFX_SetEQParam(track, eq, 4, 0, 0, high_freq, false ) --freq
    local high_gain_new = 10^(high_gain / 20) --normalizes volume input
    reaper.TrackFX_SetEQParam(track, eq, 4, 0, 1, high_gain_new, false ) --dB
    reaper.TrackFX_SetEQParam(track, eq, 4, 0, 2, high_band, false ) --band
  end
end

function Utils.remove_eq(track)
  if not track then return end
  local track_eq = reaper.TrackFX_GetEQ(track, false)
  reaper.TrackFX_Delete(track, track_eq)
end

function Utils.set_volume(volume, media_items)
  for _, item in ipairs(media_items) do
    reaper.SetMediaItemInfo_Value(item, "D_VOL", Utils.db_to_linear(volume))
  end
end

function Utils.set_pitch(pitch, media_items)
  for _, item in ipairs(media_items) do
    local active_take = reaper.GetActiveTake(item)
    reaper.SetMediaItemTakeInfo_Value(active_take, "D_PITCH", pitch)
  end
end

--------------------------------------
---File parsing and databse builder---
--------------------------------------

function Utils.get_wav_files(dir)
  local files = {}

  local function scan(path)
    local i = 0
    while true do
      local file = reaper.EnumerateFiles(path, i)
      if not file then break end
      if file:lower():match("%.wav$") then
        table.insert(files, path .. "/" .. file)
      end
      i = i + 1
    end

    local j = 0
    while true do
      local subdir = reaper.EnumerateSubdirectories(path, j)
      if not subdir then break end
      scan(path .. "/" .. subdir)
      j = j + 1
    end
  end

  scan(dir)
  return files
end

function Utils.select_folder()
  if not reaper.APIExists("JS_Dialog_BrowseForFolder") then
    reaper.MB("JS_ReaScriptAPI is require. Please install via ReaPack.", "Missing API", 0)
    return nil
  end

  local default = reaper. GetExtState(EXT_SECTION, EXT_KEY_LASTFOLDER)
  if default == "" then default = reaper.GetProjectPath("") end

  local retval, path = reaper.JS_Dialog_BrowseForFolder("Choose a directory", reaper.GetProjectPath(""))
  if retval == 1 then
    reaper.SetExtState(EXT_SECTION, EXT_KEY_LASTFOLDER, path, true)
    return path
  end
  return nil
end

function Utils.get_filename(path)
  return path:match("^.+/(.+)$")
end

function Utils.split_filename(name)
  local parts = {}
  for part in string.gmatch(name, "([^_]+)") do
    table.insert(parts, part)
  end
  return parts
end

------------------------------------
---Track Builder helper functions---
------------------------------------

--Manage all item parameter randomization
function Utils.randomize_item(item, offset_range, pitch_range, playrate_range, vol_range, state_pitch)

  if not item then return end
  local active_take = reaper.GetActiveTake(item)
  local pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
  
  --Apply a random time offset
  local new_pos = pos + ((math.random()*math.random(-1, 1)) * offset_range)
  reaper.SetMediaItemInfo_Value(item, "D_POSITION", new_pos)

  --Apply a random playback rate
  
  if active_take then
    if state_pitch then
      local new_pitch = 0 + math.random(-1, 1) * pitch_range
      reaper.SetMediaItemTakeInfo_Value(active_take, "D_PITCH", new_pitch)

    else
      local rnd_playrate = 1 + (math.random()*math.random(-1, 1)) * playrate_range
      local new_playrate = 2 ^ (rnd_playrate / 12)
      reaper.SetMediaItemTakeInfo_Value(active_take, "B_PPITCH", 0)
      reaper.SetMediaItemTakeInfo_Value(active_take, "D_PLAYRATE", new_playrate)
    end
  end
  
  -- Apply random volume adjustment to the media item.
  local new_vol = 0 + (math.random()*math.random(-1, 1)) * vol_range
  reaper.SetMediaItemInfo_Value(item, "D_VOL", Utils.db_to_linear(new_vol))
end

--Add a new take to an item
function Utils.add_take_to_item(item, filepath)
  --Create a PCM source from the file.
  local src = reaper.PCM_Source_CreateFromFile(filepath)
  if src then
    local new_take = reaper.AddTakeToMediaItem(item)
    if new_take then
      reaper.SetMediaItemTake_Source(new_take, src)
      reaper.GetSetMediaItemTakeInfo_String(new_take, "P_NAME", filepath:match("^.+/(.+)$"), true)
    end
  end
end

--Auto group items (needs table to find group items)
function Utils.group_items (media_items, group_id)

  if #media_items == 0 then return end

  for i=1, #media_items[1] do -- This will iterate for the # of media items on the first child track
    group_id = group_id + 1
    reaper.SetMediaItemInfo_Value(media_items[1][i], "I_GROUPID", group_id)
    for j=2, #media_items do -- This iterates through ith item in every child track after the first track and checks item start and end
      reaper.SetMediaItemInfo_Value(media_items[j][i], "I_GROUPID", group_id)
    end
  end
  return group_id
end

--Normalize items
function Utils.normalize_items (media_items)

  if #media_items == 0 then return end

  reaper.SelectAllMediaItems(0, false) -- Unselects all media items

  --Loop through child media item lists
  for i=1, #media_items[1] do -- This will iterate for the # of media items on the first child track

    reaper.SetMediaItemSelected(media_items[1][i], true)

    for j=2, #media_items do -- This iterates through ith item in every child track after the first track and checks item start and end

      reaper.SetMediaItemSelected(media_items[j][i], true)

    end
  end

  reaper.Main_OnCommand( 40108, 0 )-- Item properties: Normalize items to +0dB peak
  reaper.SelectAllMediaItems( 0, false )-- Unselects all media items

end

------------------------------
---Peak Markers and tagging---
------------------------------

---Calculate max peak position and add a marker (Single marker option)
function Utils.set_marker_at_max_peak(take)
  
  local aa = reaper.CreateTakeAudioAccessor(take)
  local src = reaper.GetMediaItemTake_Source(take)
  local item = reaper.GetMediaItemTake_Item(take)
  local item_len = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")

  local samplerate = reaper.GetMediaSourceSampleRate(src)
  local num_channels = reaper.GetMediaSourceNumChannels(src)
  local block_size = 1024
  local buffer = reaper.new_array(block_size * num_channels)

  local max_peak = 0
  local max_peaks_pos = 0

  local  pos = 0.0
  while pos < item_len do
    local samples = math.min(block_size, math.floor((item_len - pos) * samplerate))

    if samples <= 0 then break end
 
    buffer.clear()
 
    reaper.GetAudioAccessorSamples(aa, samplerate, num_channels, pos, samples, buffer)
 
    for i = 1, samples * num_channels do
      local sample = math.abs(buffer[i])
      if sample > max_peak then
        max_peak = sample
        local sample_index = math.floor((i - 1) / num_channels)
        max_peaks_pos = pos + sample_index / samplerate
      end
    end

    pos = pos + samples / samplerate
  end

  reaper.DestroyAudioAccessor(aa)

  if max_peak > 0 then 
    set_peak_marker(take, max_peaks_pos, "Peak")
    return max_peaks_pos
  end

  return nil
end

--Set multiple peak markers and split (For sausage files)
function Utils.set_multiple_peak_markers(take, threshold, min_gap, do_split)
  
  local item = reaper.GetMediaItemTake_Item(take)
  if not take or reaper.TakeIsMIDI(take) then return end
  
  local peak_positions = get_peak_positions(take, threshold, min_gap)
  
  local item_pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
  
  for i, pos in ipairs(peak_positions) do
    set_peak_marker(take, pos, "Peak")
  end

  if do_split then
    for i = #peak_positions, 1, -1 do
      local split_pos = item_pos + peak_positions[i]
      reaper.SplitMediaItem(item, split_pos)
    end
  end
end

function Utils.align_item_takes(item, spacing)
  --TO DO implement item alignment using peak markers
end

----------------------------
---Other helper functions---
----------------------------

--Correct item length to current item take
function Utils.correct_media_item_length(item)
  -- Get the take from the selected media item
  local take = reaper.GetActiveTake(item)
  -- Get the source of the take
  local src = reaper.GetMediaItemTake_Source(take)
  -- Get the length of the source
  local length = reaper.GetMediaSourceLength(src)
  
  reaper.SetMediaItemTakeInfo_Value(take, "D_STARTOFFS", 0)

  reaper.SetMediaItemInfo_Value(item, "D_LENGTH", length)
end

function Utils.get_all_media_items_on_track(track)
  local items = {}
  local itemCount = reaper.CountTrackMediaItems(track)
  for i = 0, itemCount - 1 do
    local item = reaper.GetTrackMediaItem(track, i)
    table.insert(items, item)
  end
  return items
end

function Utils.create_markers_regions(media_items, isrgn, name, color)
  local rgn_idx_tbl = {}
  local rgb_color = Utils.get_rgb_color(color)

  if #media_items == 0 then return end
  --Loop through child media item lists
  for i=1, #media_items[1] do -- This will iterate for the # of media items on the first child track
    local rgn_start = reaper.GetMediaItemInfo_Value(media_items[1][i], "D_POSITION")
    local rgn_end = rgn_start + reaper.GetMediaItemInfo_Value(media_items[1][i], "D_LENGTH")

    for j=2, #media_items do -- This iterates through ith item in every child track after the first track and checks item start and end
      
      local item_start = reaper.GetMediaItemInfo_Value(media_items[j][i], "D_POSITION") 
      local item_end = item_start + reaper.GetMediaItemInfo_Value(media_items[j][i], "D_LENGTH")

      if item_start < rgn_start then --if items start is less then regn start, set rgn start to item start
        rgn_start = item_start
      end

      if item_end > rgn_end then --if items end is more then regn end, set rgn end to item end
        rgn_end = item_end
      end
    end
    local idx = reaper.AddProjectMarker2(0, isrgn, rgn_start, rgn_end, tostring(name), -1, rgb_color) --Creates regions or markers depending on user settings
    table.insert(rgn_idx_tbl, idx)
  end
  return rgn_idx_tbl
end

function Utils.delete_marker_region(markers, isrgn)
  for k, v in ipairs(markers) do
    reaper.DeleteProjectMarker(0, v, isrgn)
  end
end

function Utils.get_mediaitems_from_i_childtrack(i, tracks)

  if not tracks then return end
  reaper.PreventUIRefresh(1)

  local childtrack_mediaItem = {}

  reaper.SelectAllMediaItems( 0, false )
  reaper.Main_OnCommand( 40297, 0 ) --Track: Unselect (clear selection of) all tracks

  --get i-th child track for each parent and select it
  for _, childtbl in next, tracks, nil do
    if not childtbl[i] then break end
    reaper.SetTrackSelected(childtbl[i], true )
  end

  reaper.Main_OnCommand( 40421, 0 ) -- Item: Select all items in track
  
  -- cycle through all tracks and get the ones that's selected
  local cnt = reaper.CountMediaItems(0)
  for c = 0, cnt -1 do
    local mediaItem = reaper.GetMediaItem(0, c)
    if reaper.IsMediaItemSelected(mediaItem) then
      table.insert(childtrack_mediaItem, mediaItem)
    end
  end

  reaper.SelectAllMediaItems( 0, false )
  reaper.Main_OnCommand( 40297, 0 ) --Track: Unselect (clear selection of) all tracks

  reaper.PreventUIRefresh(-1)
  return childtrack_mediaItem

end

return Utils

