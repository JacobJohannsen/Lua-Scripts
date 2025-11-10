--engine.lua

-----------
--MODULES--
-----------

--Require helper function
local function require_local(name)
	local path = debug.getinfo(2, 'S').source:match("@?(.*[\\/])")
	return dofile(path .. name)
end

--Import modules
local utils = require_local("utils.lua")

---------
--SETUP--
---------

local Engine = {}

Engine.naming_presets = {
  default_single = {
    name = "Default",
    separator = "_",
    sound_type_token_count = 2,
    ignore_variation_numbers = true
  },

  default_dual = {
    name = "Default",
    separator = "_",
    sound_layer_tokens = {1, 2, 3, 4, 5},
    sound_type_tokens = {6, 7},
    ignore_variation_numbers = true
  }
}

---------
--START--
---------

local function parse_filename(filename, preset)
  preset = preset or Engine.naming_presets.default_single
  local sep = preset.separator or "_"


  --Strip extension (assumes ".wav")
  filename = filename:match("([^/\\]+)%.wav$") or filename

  --Conditionally ignore variaiton numbers if preference is enabled
  if preset.ignore_variation_numbers then
    filename = filename:gsub("_(%d+)$", "")
  end

  --Split the filename into tokens
  local tokens = {}
  for token in filename:gmatch("[^" .. sep .. "]+") do
    table.insert(tokens, token)
  end

  if preset.sound_type_token_count then
    local n = preset.sound_type_token_count
    local total = #tokens
    local sound_type, sound_layer = "", ""

    if total >= n then
      sound_type = table.concat(tokens, sep, total - n + 1, total)
      if total - n > 0 then
        sound_layer = table.concat(tokens, sep, 1, total - n)
      else
        sound_layer = "Uncategorized"
      end
    else
      -- Fallback if there are fewer tokens than expected
      sound_type = "Default"
      sound_layer = table.concat(tokens, sep)
    end
    return sound_layer, sound_type
  else
    local sound_layer_tokens = preset.sound_layer_tokens
    local sound_type_tokens = preset.sound_type_tokens
    
    local function extract(indices)
      local parts = {}
      for _, i in ipairs(indices) do
        if tokens [i] then table.insert(parts, tokens[i]) end
      end
      return table.concat(parts, sep)
    end

    local sound_layer = extract(sound_layer_tokens)
    local sound_type = extract(sound_type_tokens)

    return sound_layer ~= "" and sound_layer or "Uncategorized",
           sound_type ~= "" and sound_type or "Default"
  end
end

function Engine.scan_folder(folder, preset)
  local files = utils.get_wav_files(folder)
  local data = {}

  for _, file in ipairs(files) do
    local sound_layer, sound_type = parse_filename(file, preset)
    data[sound_type] = data[sound_type] or {}
    data[sound_type][sound_layer] = data[sound_type][sound_layer] or {}
    data[sound_type][sound_layer][file] = false
  end

  return data    
end

function Engine.create_preview_track()
  reaper.InsertTrackAtIndex(0, true)
  local track = reaper.GetTrack(0, 0)
  reaper.SetMediaTrackInfo_Value(track, "B_SHOWINTCP", 0)
  reaper.GetSetMediaTrackInfo_String(track, "P_NAME", "PREVIEW", 1)
  return track
end

function Engine.delete_preview_track(preview_track)
  local ok, err = pcall(function()
    reaper.DeleteTrack(preview_track)
  end)
  if not ok then return end
end

function Engine.delete_preview_item(preview_track, preview_item)
  reaper.DeleteTrackMediaItem(preview_track, preview_item)
end

function Engine.play_audio_file(path, preview_track)
  --Make sure preview track is only selected track
  reaper.SetOnlyTrackSelected(preview_track)

  local c_pos = reaper.GetCursorPosition()
  reaper.MoveEditCursor(-(c_pos), false)

  --Move edit cursot to start of project and Insert file in preview track
  reaper.InsertMedia(path, 0)
  local item = reaper.GetMediaItem(0, 0)
  
  --Make sure item is at position 0 and get item length to set loop range
  reaper.SetMediaItemInfo_Value(item, "D_POSITON", 0)
  local length = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")

  --Setup loop and make sure cursor is back at position 0 in timeline
  reaper.GetSet_LoopTimeRange(true, true, 0, length, true)

  c_pos = reaper.GetCursorPosition()
  reaper.MoveEditCursor(-(c_pos), false)
  reaper.UpdateArrange()

  reaper.SetTrackUISolo(preview_track, 1, 1)
  reaper.Main_OnCommand(1007, 0) --Transport Play

  return item
end

function Engine.build_tracks(sound_lib, selected_sound_types, num_layers, num_variations, is_sausage_file, peak_threshold, peak_gap, item_spacing, offset_range, pitch_range, playrate_range, vol_range, state_pitch, auto_group_items, normalize_items, auto_add_regions, auto_add_markers, region_color, marker_color)
  
  --Prevent Ui Refresh
  reaper.PreventUIRefresh(1)

  --Get Project Cursor Time
  --Reset cursor position to session start
  reaper.MoveEditCursor(-1*reaper.GetCursorPosition(), false)
  local cursor_pos = reaper.GetCursorPosition()

  --New track generated list
  local tracks = {}
  local media_items = {}
  
  -- Region and Marker tracker
  local regions = {}
  local markers = {}

  -- Item grouping
  GROUP_ID = 0
  
  --Start Track Build Error Handling
  local ok, err = pcall(function()
  --Loop through selected sound types
  local current_index = reaper.CountTracks(0) -- Start inserting tracks here
  
  --Reset cursor position to session start
    --Iterate over each sound_type (keys of category_data)
    ---------------------
    --Parent Track Loop--
    ---------------------
    for sound_type, include in pairs(selected_sound_types) do

      if include and sound_lib[sound_type] then
        --Create a parent track for the sound_type
        reaper.InsertTrackAtIndex(current_index, true) 
        local parent_track = reaper.GetTrack(0, current_index)

        reaper.GetSetMediaTrackInfo_String(parent_track, "P_NAME", sound_type, true)
        -- Set the parent track's folder depth so that the following tracks become children.
        reaper.SetMediaTrackInfo_Value(parent_track, "I_FOLDERDEPTH", 1)
        current_index = current_index + 1

        local sound_layer_table = sound_lib[sound_type]
        local child_tracks_count = 0
        local last_child_track = nil
        local child_tracks = {}
        local parent_items = {}

        --Loop through each category within this sound_type
        --------------------
        --Child Track Loop--
        --------------------

        for sound_layer, files in pairs(sound_layer_table) do
          
          local included_files = {}
          
          for file, include in pairs(files) do
            if include == true then
              table.insert(included_files, file)
            end
          end
          
          if #included_files == nil or #included_files == 0 then 
            goto continue 
          end

          if child_tracks_count >= num_layers then break end
          
          child_tracks_count = child_tracks_count + 1

          --Create child track
          reaper.InsertTrackAtIndex(current_index, false) 
          local child_track = reaper.GetTrack(0, current_index)
          table.insert(child_tracks, child_track)

          reaper.GetSetMediaTrackInfo_String(child_track, "P_NAME", sound_layer .. "_" .. sound_type, true) 
          -- Make this track a child of the parent by setting its folder depth to 0
          reaper.SetMediaTrackInfo_Value(child_track, "I_FOLDERDEPTH", 0)
          last_child_track = child_track
          current_index = current_index + 1

          if #included_files > 0 then
            --Force child track to be the only one selected
            reaper.SetOnlyTrackSelected(child_track)

            --Clear Item selection to start from scratch
            reaper.Main_OnCommandEx(40289, 0, 0)

            --Create a media item on this track that groups all file variations as takes
            local insertion_success = reaper.InsertMedia(included_files[1], 0)
            if insertion_success then
              local item_count = reaper.CountMediaItems(0)
              local item = reaper.GetMediaItem(0, item_count - 1)

              local marker_pos = 0.0
              local positions = {}

              --Move the item to the correct child track
              reaper.MoveMediaItemToTrack(item, child_track)

              --Move Media Item start to Cursor position
              reaper.SetMediaItemPosition(item, cursor_pos, false)
              
              --For every additional variation file, add it as an extra take
              for i = 2, #included_files do
                utils.add_take_to_item(item, included_files[i])
              end
                         
              --Randomly choose a take to be active
              local num_takes = reaper.CountTakes(item)
              local chosen_index = math.random(0, num_takes - 1)
              reaper.SetMediaItemInfo_Value(item, "I_CURTAKE", chosen_index)

              --Correct media item bounds to current active take
              utils.correct_media_item_length(item)
              
              --SetPeakMarkers
              for i = 0, num_takes - 1 do
                local take = reaper.GetMediaItemTake(item, i)
                if not is_sausage_file then
                  marker_pos = utils.set_marker_at_max_peak(take)
                  table.insert(positions, marker_pos)
                else
                  utils.set_multiple_peak_markers(take, peak_threshold, peak_gap, true)
                  end
              end

              --Align Peak Markers
              local ref_pos = positions[chosen_index + 1]
              for i = 0, num_takes - 1 do
                if i ~= chosen_index then
                  local take = reaper.GetMediaItemTake(item, i)
                  reaper.SetMediaItemTakeInfo_Value(take, "D_STARTOFFS", -1 * (ref_pos - positions[i+1]))
                end
              end

              local prev_item_pos = cursor_pos
              local prev_item_len = 0

              --Loop for variation count
              for i=1, num_variations - 1 do
                -- Get previous item start position and duplicate
                prev_item_pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
                prev_item_len = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")

                local prev_item_end = prev_item_pos + prev_item_len

                reaper.SetOnlyTrackSelected(child_track)
                reaper.Main_OnCommandEx(41295, 0, 0)
                reaper.SetOnlyTrackSelected(child_track)

                --Get new item
                item_count = reaper.CountMediaItems(0)
                item = reaper.GetMediaItem(0, item_count - 1)

                --Push new item position ahead by Time split (FIXED TO 10 sec)
                reaper.SetMediaItemInfo_Value(item, "D_POSITION", prev_item_end + item_spacing)

                --Randomly choose a take to be active
                local num_takes = reaper.CountTakes(item)
                local chosen_index = math.random(0, num_takes - 1)
                reaper.SetMediaItemInfo_Value(item, "I_CURTAKE", chosen_index)
                
                --Correct media item bounds to current active take
                utils.correct_media_item_length(item)

                --Randomize parameters
                debug = utils.randomize_item(item, offset_range, pitch_range, playrate_range, vol_range, state_pitch)

                -- Align all takes in the item using peak markers
                utils.align_item_takes(item, default_spacing)
              end
              
              table.insert(parent_items, utils.get_all_media_items_on_track(child_track))
            end
          end
          ::continue::
        end

        -- Get last item position
        local item_count = reaper.CountMediaItems(0)
        local item = reaper.GetMediaItem(0, item_count - 1)

        -- increment parent start time to cursor position + buffer
        cursor_pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION") + reaper.GetMediaItemInfo_Value(item, "D_LENGTH") + 5

        --If at least one child track created, close the folder by setting the last child folder depth to -1
        if last_child_track then
          reaper.SetMediaTrackInfo_Value(last_child_track, "I_FOLDERDEPTH", -1)
        else
          --If no child was created remove folder status from the parent
          reaper.SetMediaTrackInfo_Value(parent_track, "I_FOLDERDEPTH", 0)
        end

        --Append Child Tracks Table to It's Parent Track Key in Tracks Table
        tracks[parent_track] = child_tracks
        
        table.insert(media_items, parent_items)
        --Create/Reset region and marker idx tables
        local rgn_idx = {}
        local mrk_idx = {}

        --Generate regions
        if auto_add_regions == true then
          rgn_idx = utils.create_markers_regions(parent_items, true, sound_type, region_color)
        end
        
        if #rgn_idx > 0 then
          for i=1, #rgn_idx do
            table.insert(regions, rgn_idx[i])
          end
        end 

        --Generate Markers
        if auto_add_markers == true then
          mrk_idx = utils.create_markers_regions(parent_items, false, sound_type, marker_color)
        end 

        if #mrk_idx > 0 then
          for i=1, #mrk_idx do
            table.insert(markers, mrk_idx[i])
          end
        end

        --Normalize Media Items
        if normalize_items == true then
          utils.normalize_items(parent_items)
        end

        -- Group all layers in variation
        if auto_group_items then
          GROUP_ID = utils.group_items(parent_items, GROUP_ID)
        end
      end
    end
  end)

  --Resume UI updates
  reaper.PreventUIRefresh(-1)

  if not ok then
    reaper.ShowConsoleMsg("Error in build tracks: " .. err .. "\n")
  end

  -- Refresh Arrange view
  if reaper.UpdateArrange then
    reaper.UpdateArrange()
  end

  return tracks, media_items, regions, markers
end

function Engine.delete_tracks(tracks)
  --Stop UI updates
  reaper.PreventUIRefresh(0)
  --Wrapping in pcall to handle error if user manually deleted tracks before closing
  local ok, err = pcall(function()
    for parent_track, child_tracks in pairs(tracks) do
      for _, child_track in pairs(child_tracks) do
        reaper.DeleteTrack(child_track)
      end
    reaper.DeleteTrack(parent_track)
    end
  end)

  if not ok then reaper.UpdateArrange() return end
  --Resume UI updates
  reaper.PreventUIRefresh(-1)
  reaper.UpdateArrange()
end

function Engine.delete_markers_regions(regions, markers)
  if regions ~= nil then  
    if #regions > 0 then
      utils.delete_marker_region(regions, true)
    end
  end
  if markers ~= nil then
    if #markers > 0 then
      utils.delete_marker_region(markers, false)
    end
  end
end

return Engine

