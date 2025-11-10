--GUI.lua

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
local engine = require_local("engine.lua")
--Debug
local debug = require_local("debug.lua")
---------
--SETUP--
---------

--Contains public parameters and functions
local GUI = {
	Settings = {
		pin_to_top = false,
		no_background = false,
		no_titlebar = false,
		auto_add_regions = false,
		auto_add_markers = false,
		auto_group_items = false,
		normalize_items = false,
		customization = {
			region = {
				color = 1109545621,
				name = "Region"
			},
			marker = {
				color = 1109545621,
				name = "Marker"
			},
			alpha = 1
		}
	},
	Events = {
		preview_playback_volume = -6,
		peak_threshold = 0.9,
		peak_gap = 4.9,
		update_file_include = false
	},
	Histrogram = {
		resolution = 10001, 				--Input determines resolution of histogram
		array = {},
		bias = 1.45
	},
	ModalPopup = {
		dont_ask_me_next_time = false
	},
}

--Manages local script state data
local State = {
	reaper_data = {								--Tool generated reaper objects data
		tracks = nil,
		num_parent_tracks = 0,
		num_child_tracks = 0,
		media_items = nil,
		regions = nil,
		markers = nil,
	},
	file_data = {									--File data parsing and structure
		folder = nil,
		previous_folders = {},
		sound_lib = {},
		sound_type_count = 0,
		sound_layer_count = 0,
	},
	user_data = {									--User input data
		num_layers = 1,									--General Settings
		num_layers_generated = 0,
		num_variations = 1,
		wants_pitch_not_ts = true,
		item_spacing = 10,
		is_sausage_file = false,				--Peak alignment calculation
		randomize = {										--Randomization values
			offset = 0.00,
			pitch = {
				semitones = 0,
				timestretch = 0.00
			},
			volume = 0.0,
		},
		selection = {										--Store user data selections
			sound_types = {}
		}
	},
	preview = {										--DB Audio File Preview
		toggle_play = nil,
		toggle_action = reaper.GetToggleCommandStateEx(0, 41834),
		track = nil,
		item = nil,
		playback_volume_rv = false
	},
	global = {
		has_run = false
	}
}

--Layer Settings
local LayerSettings = {
	layer_name = {},
  selected_sound_layer = {},		--Selected Sound Layer for each Layer
	selected_sound_layer_prev = {},
	media_items = {},
	number_of_files = {},
	toggle_include_all = {},
	
	volume = {},
	pitch = {},
	
	fadein = {
		percentage = {},
		shape = {},
	},
	
	fadeout = {
		percentage = {},
		shape = {},
	},
	
	fadetype = {"Linear", "Logarithmic", "Exponential", "Sine", "Reciprocal Sine", "Inverted S-Curve", "S-Curve"},
	
	eq = {},
	eq_added = {},
	eq_type = {"Lowshelf", "Band", "Highshelf"},

	lowshelf = {
		gain = {},
		freq = {},
		bandwidth = {}
	},
	
	midshelf = {
		gain = {},
		freq = {},
		bandwidth = {}
	},
	
	highshelf = {
		gain = {},
		freq = {},
		bandwidth = {}
	}
}

--Style Setup
local style = {
	header_layer_color = {
		debug = 1117190735,
		default = 1117190735,
		green = 1123706242,
		lightBlue = 1621688218,
		grey = 1667458034,
	},
	button_generate = {
		var = {
			rounding = 20,
			padding_vertical = 25,
			padding_horizontal = 10
		},
		button_colors_enabled = { 					--Green button colors
			color_button = 912932607,
			color_button_hovered = 1487954175,
			color_button_active = 613297407,
			color_text = -1
		},
		button_colors_disabled = { 					--Grey button colors
			color_button = 1667458034,
			color_button_hovered = 2088533247,
			color_button_active = 2088533247,
			color_text = -976894465
		},
		button_is_item_hovered = false
	}
}

--Widgets Setup
local widgets = {
	sliderdbl = {
		flags = {
			layer_count = nil,
			time_offset = reaper.ImGui_SliderFlags_NoRoundToFormat() | reaper.ImGui_SliderFlags_AlwaysClamp(),
			timestretch_offset = reaper.ImGui_SliderFlags_NoRoundToFormat() | reaper.ImGui_SliderFlags_AlwaysClamp(),
			volume_offset = reaper.ImGui_SliderFlags_Logarithmic() | reaper.ImGui_SliderFlags_NoRoundToFormat() | reaper.ImGui_SliderFlags_AlwaysClamp(),
			noInput = reaper.ImGui_SliderFlags_NoInput()
		}
	},
	sliderint = {
		flags = {
			pitch_offset = reaper.ImGui_SliderFlags_NoRoundToFormat() | reaper.ImGui_SliderFlags_AlwaysClamp()
		}
	},
	table = {
		flags = {
			preview = 
			reaper.ImGui_TableFlags_ScrollY()      |
			reaper.ImGui_TableFlags_RowBg()        |
			reaper.ImGui_TableFlags_BordersOuter() |
			reaper.ImGui_TableFlags_BordersV()     |
			reaper.ImGui_TableFlags_Resizable()    |
			reaper.ImGui_TableFlags_Reorderable()  |
			reaper.ImGui_TableFlags_Hideable()
		}
	},
	combo = {
		flags = reaper.ImGui_ComboFlags_NoPreview()
	},
	inputint = {
		variations = {}
	},
	child = {
		combo = {
			flags =  
			reaper.ImGui_ChildFlags_Border() 				
		}
	},
	selected = {
		pitch_combo = 1,
		fadeout_combo_preview = {},
		fadeout_combo = {},
		fadein_combo_preview = {},
		fadein_combo = {},
		category_combo_preview = {},
		eq_bandtype_combo = {},
		eq_bandtype_combo_preview = {}
	},
	layout = {
		width = 0.6,
		small_width = 0.29
	}
}

--Layer Vol, Pitch, Fade and EQ Slider Triggers
local adj_lsh_lvl, adj_msh_lvl, adj_hsh_lvl, adj_lsh_freq, adj_msh_freq, adj_hsh_freq, adj_lsh_bw, adj_msh_bw, adj_hsh_bw = {}, {}, {}, {}, {}, {}, {}, {}, {}
local adj_vol, adj_pt, adj_eq = {}, {}, {}
local adj_fi_prc, adj_fi_shp, adj_fo_prc, adj_fo_shp = {}, {}, {}, {}

-------------
--FUNCTIONS--
-------------

function Table_to_string(tbl, indent)
  indent = indent or 0
  local output = string.rep(" ", indent) .. "{\n"
  indent = indent + 2

  local entries = {}
  local keys = {}

  -- Collect all keys, including those with nil values
  for k, _ in next, tbl do
    table.insert(keys, k)
  end

  for _, k in ipairs(keys) do
    local v = tbl[k]
    local key
    if type(k) == "string" and k:match("^[%a_][%w_]*$") then
      key = k .. " = "
    else
      key = "[" .. string.format("%q", k) .. "] = "
    end

    local value
    if type(v) == "number" then
      value = tostring(v)
    elseif type(v) == "string" then
      value = string.format("%q", v)
    elseif type(v) == "boolean" then
      value = tostring(v)
    elseif type(v) == "table" then
      value = Table_to_string(v, indent)
    elseif type(v) == "nil" then
      value = "nil"
    elseif type(v) == "function" then
      value = '"__function__"' -- Placeholder string
    else
      goto continue -- Skip unsupported types
    end

    table.insert(entries, string.rep(" ", indent) .. key .. value)
    ::continue::
  end

  output = output .. table.concat(entries, ",\n") .. "\n"
  indent = indent - 2
  output = output .. string.rep(" ", indent) .. "}"
  return output
end

--All values that gets saved by the save/load system
function Get_ext_state_key_values()
  return {
    gui = {
      Settings = GUI.Settings,
      Events = GUI.Events,
      Histrogram = GUI.Histrogram,
			ModalPopup = GUI.ModalPopup,
    },

    folder = State.file_data.previous_folders,

    item_spacing_ref = function(new_val)
      if new_val ~= nil then
        State.user_data.item_spacing = new_val
      end
      return State.user_data.item_spacing
    end
  }
end

--Merges t2 into t1. If either is not a table, t2 overwrites t1.
function DeepMerge(t1, t2)

  if type(t1) ~= "table" or type(t2) ~= "table" then
    return t2
  end

  for k, v in pairs(t2) do

    if type(v) == "table" and type(t1[k]) == "table" then
      t1[k] = DeepMerge(t1[k], v)

    else
      t1[k] = v
    end

  end

  return t1
end

--Function used by the EQ histogram
local function freq_to_bin(freq, num_bins, type)
	if type == "logarithmic" then
		local min_freq, max_freq = 20, 20000
		local oct_min = math.log(min_freq) / math.log(2)
		local oct_max = math.log(max_freq) / math.log(2)
		local oct_freq = math.log(math.max(min_freq, math.min(freq, max_freq))) / math.log(2)
		local norm = ((oct_freq - oct_min) / (oct_max - oct_min)) ^ GUI.Histrogram.bias
		return math.floor(norm * (num_bins - 1) + 0.5)
	end

	if type == "linear" then
		local min_freq, max_freq = 20, 20000
		local clamped_freq = math.max(min_freq, math.min(freq, max_freq))
		local norm = (clamped_freq - min_freq) / (max_freq - min_freq)
		return math.floor(norm * (num_bins - 1) + 0.5)
	end
end

--Convert bandwidth (in octaves) to spread in bins used by the EQ histogram
local function bandwidth_to_spread(bandwidth, num_bins)
	return math.max(1, math.floor((bandwidth / 4.0) * num_bins)) -- the first number indicates minimum spread of bins
end

--Function used by the EQ histogram
local function apply_band(eq_array, gain, freq, bw, band_type)
	if math.abs(gain) < 0.001 then gain = gain + 0.001 end -- adding +0.001 to avoid input being exactly zero

	local num_bins = eq_array.get_alloc()
	local center = freq_to_bin(freq, num_bins, "logarithmic")
	local spread = bandwidth_to_spread(bw, num_bins)
	local height = gain

	for i = 1, num_bins do
			local dist = (i - center) / spread
			local influence

			if band_type == "lowshelf" then
					influence = 1.0 / (1.0 + math.exp(dist * 4))  -- sigmoid curve
			elseif band_type == "highshelf" then
					influence = 1.0 / (1.0 + math.exp(-dist * 4))  -- flipped sigmoid
			else -- midshelf (bell)
					influence = math.exp(-dist * dist * 4)  -- Gaussian
			end

			eq_array[i] = eq_array[i] + height * influence
	end
end

--Sets the active folder that engine will reference
local function set_active_folder(folder)
	if folder then
		--Reset data everytime a user picks a new folder
		State.user_data.num_layers = 1
		State.file_data.sound_lib = {}
		State.file_data.sound_layer_count = 0
		
		--Start folder parsing
		State.file_data.folder = folder
		State.file_data.sound_lib = engine.scan_folder(folder, engine.naming_presets.default_single) --Organizes all files in folder into nested tables per sound_layer and sound_type
		State.file_data.sound_type_count = 0
		
		local set = {}
		--Loop through sound_lib data and set sound_type and sound_layer count
		for sound_type, sound_layers in pairs(State.file_data.sound_lib) do
			State.file_data.sound_type_count = State.file_data.sound_type_count + 1
			for sound_layer, v in pairs(sound_layers) do
				if not set[sound_layer] then
					State.file_data.sound_layer_count = State.file_data.sound_layer_count + 1
					set[sound_layer]=true
				end
			end
		end
	end
end

---------
--START--
---------

function GUI.draw(ctx)

	--Set width and height of fonts
	local TEXT_BASE_WIDTH  = reaper.ImGui_CalcTextSize(ctx, 'A')
  local TEXT_BASE_HEIGHT = reaper.ImGui_GetTextLineHeightWithSpacing(ctx)

	-----------
	--MenuBar--
	-----------
	
	if reaper.ImGui_BeginMenuBar(ctx) then

		if reaper.ImGui_BeginMenu(ctx, 'Options') then

			_, GUI.Settings.auto_add_regions = reaper.ImGui_MenuItem(ctx, 'Auto Add Regions', nil, GUI.Settings.auto_add_regions)								--Toggle Auto Add Regions On/Off
			reaper.ImGui_SetItemTooltip(ctx, 'Creates a region for each variation ')
			_, GUI.Settings.auto_add_markers = reaper.ImGui_MenuItem(ctx, 'Auto Add Markers', nil, GUI.Settings.auto_add_markers)								--Toggle Auto Add MArkers On/Off
			reaper.ImGui_SetItemTooltip(ctx, 'Adds marker at the beginning of each variation')
			_, GUI.Settings.auto_group_items = reaper.ImGui_MenuItem(ctx, 'Auto Group Items', nil, GUI.Settings.auto_group_items)								--Toggle Auto Group Items On/Off
			reaper.ImGui_SetItemTooltip(ctx, 'Automatically groups all layerede files for each variation')
			_, GUI.Settings.normalize_items = reaper.ImGui_MenuItem(ctx, 'Normalize Items Generated', nil, GUI.Settings.normalize_items)				--Toggle Normalize Items On/Off
			reaper.ImGui_SetItemTooltip(ctx, 'Normalizes all active take items to 0dB')
			reaper.ImGui_Separator(ctx)

			if reaper.ImGui_BeginMenu(ctx, 'Preview Volume') then --User settings for preview track volume
				State.preview.playback_volume_rv, GUI.Events.preview_playback_volume = reaper.ImGui_SliderDouble(ctx, "##Preview playback volume", GUI.Events.preview_playback_volume, -60, 12, "%.f dB", widgets.sliderdbl.flags.volume_offset | reaper.ImGui_SliderFlags_NoInput())
				
				reaper.ImGui_SetItemTooltip(ctx, 'Sets playback volume for previewing files')

				if State.preview.playback_volume_rv and State.preview.track ~= nil then
					if State.preview.track ~= nil then reaper.SetMediaTrackInfo_Value(State.preview.track, "D_VOL", utils.db_to_linear(GUI.Events.preview_playback_volume)) end
				end
				
				reaper.ImGui_SameLine(ctx)
				if reaper.ImGui_Button(ctx, 'Reset') then --Reset to defualt settings
					GUI.Events.preview_playback_volume = -6
				end
				reaper.ImGui_EndMenu(ctx)
			end

			if reaper.ImGui_BeginMenu(ctx, 'Take Marker Generation') then --User Settings for peak detection and marker generation
				--Set Peak Threshold
				_, GUI.Events.peak_threshold = reaper.ImGui_SliderDouble(ctx, "##Treshold", GUI.Events.peak_threshold, 0.01, 5, "Treshold = %.3f", widgets.sliderdbl.flags.volume_offset | reaper.ImGui_SliderFlags_NoInput())

				reaper.ImGui_SetItemTooltip(ctx, 'Minimum gap between two take markers')

				reaper.ImGui_SameLine(ctx)
				if reaper.ImGui_Button(ctx, "Reset"  .. "##treshold") then  --Reset to defualt settings
					GUI.Events.peak_threshold = 0.9
				end

				--Set Peak Gap
				_, GUI.Events.peak_gap = reaper.ImGui_SliderDouble(ctx, "##Gap", GUI.Events.peak_gap, 0.01, 10, "MinGap = %.3f", widgets.sliderdbl.flags.volume_offset | reaper.ImGui_SliderFlags_NoInput())

				reaper.ImGui_SetItemTooltip(ctx, 'If a sample exceeds treshold new take marker is added')

				reaper.ImGui_SameLine(ctx)
				if reaper.ImGui_Button(ctx, "Reset"  .. "##gap") then  --Reset to defualt settings
					GUI.Events.peak_gap = 4.9
				end

				reaper.ImGui_EndMenu(ctx)
			end

			if reaper.ImGui_BeginMenu(ctx, 'Variation Spacing') then --User Settings for spacing between each variation (defaults to 10 sec)
				_, State.user_data.item_spacing = reaper.ImGui_SliderDouble(ctx, "##Spacing", State.user_data.item_spacing, 0, 20, "Spacing = %.1f sec", widgets.sliderdbl.flags.volume_offset | reaper.ImGui_SliderFlags_NoInput())
				reaper.ImGui_SetItemTooltip(ctx, 'Sets the time (in seconds) between each variation generated')

				reaper.ImGui_SameLine(ctx)

				if reaper.ImGui_Button(ctx, 'Reset' .. "##Spacing") then --Reset to defualt settings
					State.user_data.item_spacing = 10
				end

				reaper.ImGui_EndMenu(ctx)
			end

			if reaper.ImGui_BeginMenu(ctx, 'Colors') then --User Color Settings

				_, GUI.Settings.customization.region.color = reaper.ImGui_ColorEdit3(ctx, 'Region color', GUI.Settings.customization.region.color, reaper.ImGui_ColorEditFlags_NoAlpha() | reaper.ImGui_ColorEditFlags_DisplayRGB())
			
				reaper.ImGui_SameLine(ctx)
				if reaper.ImGui_Button(ctx, "Reset" .. "##Region") then
					GUI.Settings.customization.region.color = 1109545621
				end

				_, GUI.Settings.customization.marker.color = reaper.ImGui_ColorEdit3(ctx, 'Marker color', GUI.Settings.customization.marker.color, reaper.ImGui_ColorEditFlags_NoAlpha() | reaper.ImGui_ColorEditFlags_DisplayRGB())

				reaper.ImGui_SameLine(ctx)
				if reaper.ImGui_Button(ctx, "Reset" .. "##Marker") then
					GUI.Settings.customization.marker.color = 1109545621
				end

				_, style.header_layer_color.debug = reaper.ImGui_ColorEdit4(ctx, 'Test w/Alpha', style.header_layer_color.debug, reaper.ImGui_ColorEditFlags_AlphaBar())

				reaper.ImGui_SameLine(ctx)
				if reaper.ImGui_Button(ctx, "Print") then
					reaper.ShowConsoleMsg(style.header_layer_color.debug .. "\n")
				end

				reaper.ImGui_EndMenu(ctx)
			end

			reaper.ImGui_EndMenu(ctx)
		end

		--Window Settings
		if reaper.ImGui_BeginMenu(ctx, 'Window Settings') then
			_, GUI.Settings.pin_to_top = reaper.ImGui_MenuItem(ctx, 'Always On Top', nil, GUI.Settings.pin_to_top)
			_, GUI.Settings.no_titlebar = reaper.ImGui_MenuItem(ctx, 'No Titlebar', nil, GUI.Settings.no_titlebar)
			_, GUI.Settings.no_background = reaper.ImGui_MenuItem(ctx, 'No Background', nil, GUI.Settings.no_background)
			if reaper.ImGui_BeginMenu(ctx, 'Global Alpha') then
				reaper.ImGui_PushItemWidth(ctx, reaper.ImGui_GetFontSize(ctx) * 8)
				_, GUI.Settings.customization.alpha = reaper.ImGui_DragDouble(ctx, '##GlobalAlpha', GUI.Settings.customization.alpha, 0.005, 0.50, 1.0, '%.2f', reaper.ImGui_SliderFlags_NoInput()) -- Not exposing zero here so user doesn't "lose" the UI (zero alpha clips all widgets)
				reaper.ImGui_PopItemWidth(ctx)
				reaper.ImGui_EndMenu(ctx)
			end
			reaper.ImGui_EndMenu(ctx)
		end

		reaper.ImGui_EndMenuBar(ctx)
	end

	---------
	---GUI---
	---------

	--Select a Folder
	if reaper.ImGui_Button(ctx, "Select Folder") then
		local folder = utils.select_folder()
		table.insert(State.file_data.previous_folders, folder)
		set_active_folder(folder)
	end

	--Recent Folders
	if reaper.ImGui_BeginPopupContextItem(ctx) then

    reaper.ImGui_SeparatorText(ctx, 'Recent Folders')

    local folder_count = 0
    local duplicate_folders = {}
		local menu_items = {}

    -- Iterate backwards to show most recent folders first
    for i = #State.file_data.previous_folders, 1, -1 do
        local folder = State.file_data.previous_folders[i]
        if folder and not duplicate_folders[folder] then
            duplicate_folders[folder] = true
            folder_count = folder_count + 1
            if folder_count <= 10 then
							menu_items[folder] = reaper.ImGui_MenuItem(ctx, folder_count .. ": " .. tostring(folder))
            end
        end
    end

		for item, bool in pairs (menu_items) do
			if bool then
				set_active_folder(item)
			end
		end
		
		if folder_count >= 1 then
			if reaper.ImGui_MenuItem(ctx, "...clear folder history") then
				State.file_data.previous_folders = {}
			end
		else
			reaper.ImGui_TextDisabled(ctx, 'no recently selected folders')
		end

    reaper.ImGui_EndPopup(ctx)
end

	reaper.ImGui_SameLine(ctx)
	reaper.ImGui_TextDisabled(ctx, '(?)')
	
	if reaper.ImGui_BeginItemTooltip(ctx) then
		reaper.ImGui_PushTextWrapPos(ctx, reaper.ImGui_GetFontSize(ctx) * 35.0)
		reaper.ImGui_Text(ctx, 'Right click "Select Folder" to display [Recent Folders]')
		reaper.ImGui_PopTextWrapPos(ctx)
		reaper.ImGui_EndTooltip(ctx)
	end

	--Show text with directory if a folder has been selected
	local folder_prompt = "No folder selected..."

	if State.file_data.folder then
		folder_prompt = "Folder: " .. State.file_data.folder
	else
		folder_prompt = "No folder selected..."
	end

	--reaper.ImGui_SetItemTooltip(ctx, 'Choose a folder with .wav sound content you would like to use')

	reaper.ImGui_Text(ctx, folder_prompt)
	
	-------------------
	--GLOBAL SETTINGS--
	-------------------
	reaper.ImGui_SeparatorText(ctx, 'Global Settings')

	reaper.ImGui_PushItemWidth(ctx, reaper.ImGui_GetContentRegionAvail(ctx) * widgets.layout.small_width)

	--Total Variations Selection
	_, State.user_data.num_variations = reaper.ImGui_InputInt(ctx, '# Variations', State.user_data.num_variations, 1, 5)
	reaper.ImGui_SetItemTooltip(ctx, 'Amount of variations that will be generated')

	--FIX: We should probably add proper exception handeling here. Look into pcall
	if State.user_data.num_variations <1 then State.user_data.num_variations = 1 end; if State.user_data.num_variations > 100 then
		reaper.ClearConsole()
		reaper.ShowConsoleMsg("\n" .. "Over 100 variations?! Stop right there!" .. "\n" .. "We don't want to see your PC crash and burn ^_^")
		State.user_data.num_variations = 100
	end


	--Randomizers
	reaper.ImGui_SameLine(ctx)

	--Volume randomizer
	_, State.user_data.randomize.volume = reaper.ImGui_SliderDouble(ctx, "Volume", State.user_data.randomize.volume, 0.0, 24.0, "%.1f dB", widgets.sliderdbl.flags.volume_offset)
	reaper.ImGui_SetItemTooltip(ctx, 'Sets the volume for each media item to a random amount')

	--Time Offset randomizer
	_, State.user_data.randomize.offset = reaper.ImGui_SliderDouble(ctx, "Offset      ", State.user_data.randomize.offset, 0.00, 10.00, "%.1f secs", widgets.sliderdbl.flags.time_offset); reaper.ImGui_SameLine(ctx)
	reaper.ImGui_SetItemTooltip(ctx, 'Sets the offset of each media item to a random amount')

	--Pitch or Ts randomizer. combo selects between both modes
	if State.user_data.wants_pitch_not_ts then
		_, State.user_data.randomize.pitch.semitones = reaper.ImGui_SliderInt(ctx, "Pitch Offset", State.user_data.randomize.pitch.semitones, 0, 12, "%d semitones", widgets.sliderint.flags.pitch_offset)
		reaper.ImGui_SetItemTooltip(ctx, 'Sets the pitch for each media item to a random amount')
	else
		_, State.user_data.randomize.pitch.timestretch = reaper.ImGui_SliderInt(ctx, "Playback Rate", State.user_data.randomize.pitch.timestretch, 0, 12, "%d semitones", widgets.sliderint.flags.pitch_offset)
		reaper.ImGui_SetItemTooltip(ctx, 'Sets the pitch for each media item to a random amount')
	end

	reaper.ImGui_SameLine(ctx)

	--Combo Box to select if user want Pitch Offset or Playback rate offset
	local pitch_items = {"Pitch Offset", "Playback Rate"}
	local preview_value = pitch_items[widgets.selected.pitch_combo]
	if reaper.ImGui_BeginCombo(ctx, '##', preview_value, widgets.combo.flags) then
		for i,v in ipairs(pitch_items) do
			local is_selected = widgets.selected.pitch_combo == i
			if reaper.ImGui_Selectable(ctx, pitch_items[i], is_selected) then
				widgets.selected.pitch_combo = i
			end
			if widgets.selected.pitch_combo <= 1 then
				State.user_data.wants_pitch_not_ts = true
			else State.user_data.wants_pitch_not_ts = false end
			-- Set the initial focus when opening the combo (scrolling + keyboard navigation focus)
			if is_selected then
				reaper.ImGui_SetItemDefaultFocus(ctx)
			end
		end
		reaper.ImGui_EndCombo(ctx)
	end
	reaper.ImGui_SetItemTooltip(ctx, 'Select pitch mode')

	reaper.ImGui_PopItemWidth(ctx)
	
	---------------------
	---Manage Includes---
	---------------------
	
	--Refresh includes
	if GUI.Events.update_file_include then
		GUI.Events.update_file_include = false
		--reset all includes on click
		for sound_type, sound_layers in pairs(State.file_data.sound_lib) do
			for sound_layer, files in pairs(State.file_data.sound_lib[sound_type]) do
				for file, include in pairs(State.file_data.sound_lib[sound_type][sound_layer]) do
					State.file_data.sound_lib[sound_type][sound_layer][file] = false
				end
			end
		end
		--Include only files for sound type layer combos that are selected
		for i=1, State.user_data.num_layers do
			for sound_type, checked in pairs(State.user_data.selection.sound_types) do
				if checked == true and State.file_data.sound_lib[sound_type][LayerSettings.selected_sound_layer[i]] then
					--If Sound_Type is included and sound_layer is part of sound_type
					for file, include in pairs(State.file_data.sound_lib[sound_type][LayerSettings.selected_sound_layer[i]]) do
						--Set every file on valid type/layer combo to included
						State.file_data.sound_lib[sound_type][LayerSettings.selected_sound_layer[i]][file] = true
					end
				end
			end
		end
	end

	-----------------------
	---Parent Management---
	-----------------------
	
	--Create table of checkboxes to allow user to pick which sound types to include
	if State.file_data.folder then
		reaper.ImGui_SeparatorText(ctx, 'Parents')
		--List sound_types checkbox selection
		if reaper.ImGui_BeginTable(ctx, 'split', 3) then
			for sound_type, sound_layers in pairs(State.file_data.sound_lib) do
				local clicked = nil or false
				local checked = State.user_data.selection.sound_types[sound_type] or false
				reaper.ImGui_TableNextColumn(ctx); clicked ,checked           	= reaper.ImGui_Checkbox(ctx, sound_type, checked)
				State.user_data.selection.sound_types[sound_type] = checked
				if clicked then
					GUI.Events.update_file_include = true
				end
			end
      reaper.ImGui_EndTable(ctx)
    end
				
		--------------------
    --Layer Management--
    --------------------
		reaper.ImGui_SeparatorText(ctx, 'Layers')

		--Total Layers Selection
		if State.file_data.folder then --Show only if user has selected a directory
			_, State.user_data.num_layers = reaper.ImGui_SliderInt(ctx, "Number of Layers", State.user_data.num_layers or 1, 1, State.file_data.sound_layer_count, "%d", widgets.sliderdbl.flags.noInput)
		end

		--Create the preview track for file preview within the ImGui
		if State.preview.track == nil then
			State.preview.track = engine.create_preview_track()
		end

		--Begin Child for Layer setups
		if reaper.ImGui_BeginChild(ctx, 'Layer Settings', reaper.ImGui_GetContentRegionAvail(ctx) * 0.9, reaper.ImGui_GetContentRegionAvail(ctx) * 0.65) then
			
			--Layer settings
			--Loop through num of layers selected and create a Layer setting header for each
			for i=1, State.user_data.num_layers do

				if LayerSettings.layer_name[i] == nil then LayerSettings.layer_name[i] = 'Layer ' .. i end
				
				--Style Start
				reaper.ImGui_PushID(ctx, i)
				if widgets.selected.category_combo_preview[i] then
					reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Header(), style.header_layer_color.lightBlue)
				else 
					reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Header(), style.header_layer_color.default)
				end

				--Layer Setup Collapsible Header: All Layer Settings are stup in this block
				if reaper.ImGui_CollapsingHeader(ctx, LayerSettings.layer_name[i]) then
					
					--Setup Combo for category selection
					local set = {}
					local combo_items = {}
					--Loop through sound layers to later add as selectable categories in combo box
					for sound_type, sound_layers in pairs(State.file_data.sound_lib) do
						for sound_layer, _ in pairs(sound_layers) do
							if not set[sound_layer] then
								table.insert(combo_items, sound_layer)
								set[sound_layer] = true
							end
						end
					end

					local preview_value = combo_items[widgets.selected.category_combo_preview[i]]
					-- Create combo box with selectable sound layers
					if reaper.ImGui_BeginCombo(ctx, '##' .. i, preview_value, widgets.combo.flags) then	

						for k, v in ipairs(combo_items) do
							local is_selected = widgets.selected.category_combo_preview[i] == k

							if reaper.ImGui_Selectable(ctx, combo_items[k], is_selected) then
								LayerSettings.selected_sound_layer_prev[i] = LayerSettings.selected_sound_layer[i]
								widgets.selected.category_combo_preview[i] = k
								LayerSettings.selected_sound_layer[i] = combo_items[k]
								GUI.Events.update_file_include = true
							end

							-- Set the initial focus when opening the combo (scrolling + keyboard navigation focus)
							if is_selected then
								reaper.ImGui_SetItemDefaultFocus(ctx)
							end

						end

						reaper.ImGui_EndCombo(ctx)
					end

					-- Display the name of the selected sound for that layer
					reaper.ImGui_SetItemTooltip(ctx, 'Category of sounds that the tool will use when generating variations for layer ' .. i)
					reaper.ImGui_SameLine(ctx, 0.0, -1.0)
					reaper.ImGui_Text(ctx, (LayerSettings.selected_sound_layer[i] or "Choose a Layer"))

					reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Header(), style.header_layer_color.default)

					local sound_types_selected_count = 0
					for _,include in pairs(State.user_data.selection.sound_types ) do
						if include == true then
							sound_types_selected_count = sound_types_selected_count + 1
						end
					end
					if sound_types_selected_count >= 1 then
						reaper.ImGui_Separator(ctx)
					end

					--DB PREVIEW--
					--------------

					local outer_size_w, outer_size_h = 0.0, TEXT_BASE_HEIGHT * 8

					--loop through each selectable variation
					for sound_type, sound_layers in pairs(State.file_data.sound_lib) do

						--Sets the color and text of the header to grey if #files is 0
						local file_count = 0
						local sound_type_text = "##"
						for sound_layer, files in pairs(sound_layers) do
							if sound_layer == LayerSettings.selected_sound_layer[i] then
								for _ in pairs(files) do
									file_count = file_count + 1
								end
							end
						end
						LayerSettings.number_of_files[i] = file_count
						if file_count == 0 then
							reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Header(), style.header_layer_color.grey)
							sound_type_text = " (no files)"
						else
							reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Header(), style.header_layer_color.default)
						end

						--If a variation is selected, create a collapsible header that contains the table of files for that variation.
						if State.user_data.selection.sound_types[sound_type] and State.file_data.sound_lib[sound_type][LayerSettings.selected_sound_layer[i]] then 
							
							if reaper.ImGui_CollapsingHeader(ctx, string.format("%s ## %d", sound_type .. sound_type_text, i)) then
								if reaper.ImGui_BeginTable(ctx, 'File Browser##' .. i, 2, widgets.table.flags.preview, outer_size_w, outer_size_h) then
									--Create header row for each variation database	
									reaper.ImGui_TableSetupScrollFreeze(ctx, 0, 1); -- Make top row always visible
									reaper.ImGui_TableSetupColumn(ctx, 'Include?', reaper.ImGui_TableColumnFlags_None())
									--reaper.ImGui_TableSetupColumn(ctx, 'Preview', reaper.ImGui_TableColumnFlags_None())
									reaper.ImGui_TableSetupColumn(ctx, 'Filename', reaper.ImGui_TableColumnFlags_None())
									reaper.ImGui_TableHeadersRow(ctx)

									--Double click to disable/enable all checkboxes
									local selected_layer = LayerSettings.selected_sound_layer[i]
									if selected_layer then
										local toggle_key = sound_type .. "::" .. selected_layer
										LayerSettings.toggle_include_all = LayerSettings.toggle_include_all or {}
										if LayerSettings.toggle_include_all[toggle_key] == nil then
											LayerSettings.toggle_include_all[toggle_key] = true
										end
										if (reaper.ImGui_TableGetColumnFlags(ctx, 0) & reaper.ImGui_TableColumnFlags_IsHovered()) ~= 0 then
											if reaper.ImGui_IsMouseDoubleClicked(ctx, 0) then
												LayerSettings.toggle_include_all[toggle_key] = not LayerSettings.toggle_include_all[toggle_key]
												for sound_layer, files in pairs(sound_layers) do
													if sound_layer == selected_layer then
														for file, _ in pairs(files) do
															State.file_data.sound_lib[sound_type][sound_layer][file] = LayerSettings.toggle_include_all[toggle_key]
														end
													end
												end
											end
										end
									end
									
									for sound_layer, files in pairs(sound_layers) do									
										if sound_layer == LayerSettings.selected_sound_layer[i] then										
											--Loop through each file if the category is selected in the combo and create row in table.
											for file, include in pairs(files) do
												State.file_data.sound_lib[sound_type][sound_layer][file] = true
												--Creates checkbox on 1st column for user to include/exclude files when generating
												reaper.ImGui_TableNextColumn(ctx);_, include = reaper.ImGui_Checkbox(ctx, "##" .. file, include)
												State.file_data.sound_lib[sound_type][sound_layer][file] = include								
												if reaper.ImGui_IsItemHovered(ctx, reaper.ImGui_HoveredFlags_DelayNormal()) then
													if reaper.ImGui_BeginItemTooltip(ctx) then
														reaper.ImGui_PushTextWrapPos(ctx, reaper.ImGui_GetFontSize(ctx) * 35.0)
														reaper.ImGui_Text(ctx, '[Double Click] select or de-select all sound types')
														reaper.ImGui_PopTextWrapPos(ctx)
														reaper.ImGui_EndTooltip(ctx)
													end
												end

												--Creates Button to preview file on second column.
												--reaper.ImGui_TableNextColumn(ctx); 
												--[[if reaper.ImGui_SmallButton(ctx, "Preview##" .. file) then 
													if State.preview.toggle_action == 0 then
														reaper.Main_OnCommandEx(41834, 0, 0)
													end

													--Set toggle preview variable
													State.preview.toggle_play = true

													--If preview item exists in preview track, clear before adding the new one
													if State.preview.item ~= nil then 
														engine.delete_preview_item(State.preview.track, State.preview.item) 
													end 

													State.preview.item = engine.play_audio_file(file, State.preview.track) 
											
												end--]]

												-- Filename displayed on 2nd column
												reaper.ImGui_TableNextColumn(ctx)
												if reaper.ImGui_Selectable(ctx, file:match("([^/\\]+)%.wav$")) then
													if State.preview.toggle_action == 0 then
														reaper.Main_OnCommandEx(41834, 0, 0)
													end

													State.preview.toggle_play = true

													if State.preview.item ~= nil then
														engine.delete_preview_item(State.preview.track, State.preview.item)
													end

													State.preview.item = engine.play_audio_file(file, State.preview.track)
												end
											end
										else
											--State.file_data.sound_lib[sound_type][sound_layer][file] = false
										end
									end

									reaper.ImGui_EndTable(ctx)
								end
							end
						end
						reaper.ImGui_PopStyleColor(ctx)
					end	

					--Handle preview track soloing when preview enabled. Driven by Play State once preview starts.
					if State.preview.toggle_play then
						if reaper.GetPlayState() == 0 then
							reaper.SetTrackUISolo(State.preview.track, 0, 1)
							if State.preview.toggle_action == 0 then
								reaper.Main_OnCommandEx(41834, 0, 0)
							end
							State.preview.toggle_play = false
						end
					end

					reaper.ImGui_Separator(ctx)

					reaper.ImGui_Text(ctx, 'Layer ' .. i .. ' Settings')
					
					reaper.ImGui_PushItemWidth(ctx, reaper.ImGui_GetContentRegionAvail(ctx) * widgets.layout.width)
					
					--Volume Slider
					adj_vol[i], LayerSettings.volume[i] = reaper.ImGui_SliderDouble(ctx, 'Volume##' .. i, LayerSettings.volume[i], -64, 24, "%.1f dB", widgets.sliderdbl.flags.time_offset)
					reaper.ImGui_SetItemTooltip(ctx, 'Set the volume of each layer ' .. i .. ' item to a specific amount')
					if adj_vol[i] and State.reaper_data.tracks ~= nil then
						utils.set_volume(LayerSettings.volume[i], LayerSettings.media_items[i])
					end

					--Pitch Slider
					adj_pt[i], LayerSettings.pitch[i] = reaper.ImGui_SliderDouble(ctx, 'Pitch##' .. i, LayerSettings.pitch[i], -12, 12, "%.1f semitones", widgets.sliderdbl.flags.time_offset)
					reaper.ImGui_SetItemTooltip(ctx, 'Set the pitch of each layer ' .. i .. ' item to a specific amount')
					if adj_pt[i] and State.reaper_data.tracks ~= nil then
						utils.set_pitch(LayerSettings.pitch[i], LayerSettings.media_items[i])
					end

					--Set initial values for Fadein and Fadeout
					if LayerSettings.fadein.percentage[i] == nil then LayerSettings.fadein.percentage[i] = 0 end
					if LayerSettings.fadein.shape[i] == nil then LayerSettings.fadein.shape[i] = 0 end
					if LayerSettings.fadeout.percentage[i] == nil then LayerSettings.fadeout.percentage[i] = 0 end
					if LayerSettings.fadeout.shape[i] == nil then LayerSettings.fadeout.shape[i] = 0 end

					--Fadein combo and slider
					if widgets.selected.fadein_combo[i] == nil then widgets.selected.fadein_combo[i] = 1 end

					widgets.selected.fadein_combo_preview[i] = LayerSettings.fadetype[widgets.selected.fadein_combo[i]]
					
					adj_fi_prc[i], LayerSettings.fadein.percentage[i] = reaper.ImGui_SliderDouble(ctx, "FadeIn - " .. widgets.selected.fadein_combo_preview[i] .. "##".. i, LayerSettings.fadein.percentage[i], 0, 100, "%1.f percent", widgets.sliderdbl.flags.time_offset)
					
					reaper.ImGui_SetItemTooltip(ctx, 'Set the fade-in of each layer ' .. i .. ' item by a percentage')
					reaper.ImGui_SameLine(ctx)

					--Fade In Shape Selection Combo
					if reaper.ImGui_BeginCombo(ctx, '##fadein' .. tostring(i), widgets.selected.fadein_combo_preview[i], widgets.combo.flags) then
						for fade_in, _ in ipairs(LayerSettings.fadetype) do

							local is_selected = widgets.selected.fadein_combo[i] == fade_in

							if reaper.ImGui_Selectable(ctx, LayerSettings.fadetype[fade_in], is_selected) then

								widgets.selected.fadein_combo[i] = fade_in
								LayerSettings.fadein.shape[i] = fade_in
								-- updates media items
								if State.reaper_data.tracks ~= nil then utils.set_fade_in_shape(utils.get_mediaitems_from_i_childtrack(i, State.reaper_data.tracks), LayerSettings.fadein.shape[i]); reaper.UpdateArrange() end
							end

							-- Set the initial focus when opening the combo (scrolling + keyboard navigation focus)
							if is_selected then
								reaper.ImGui_SetItemDefaultFocus(ctx)
							end

						end

						reaper.ImGui_EndCombo(ctx)
					end
					reaper.ImGui_SetItemTooltip(ctx, 'Fade-in type')

					--Fadeout combo and slider
					if widgets.selected.fadeout_combo[i] == nil then widgets.selected.fadeout_combo[i] = 1 end

					widgets.selected.fadeout_combo_preview[i] = LayerSettings.fadetype[widgets.selected.fadeout_combo[i]]

					adj_fo_prc[i], LayerSettings.fadeout.percentage[i] = reaper.ImGui_SliderDouble(ctx, "FadeOut - " .. widgets.selected.fadeout_combo_preview[i] .. "##" .. i, LayerSettings.fadeout.percentage[i], 0, 100, "%1.f percent", widgets.sliderdbl.flags.time_offset)
					
					reaper.ImGui_SetItemTooltip(ctx, 'Set the fade-out of each layer ' .. i .. ' item by a percentage')
					reaper.ImGui_SameLine(ctx)

					--Fade Out Shape Selection Combo
					if reaper.ImGui_BeginCombo(ctx, '##fadeout' .. tostring(i), widgets.selected.fadeout_combo_preview[i], widgets.combo.flags) then

						for fade_out, _ in ipairs(LayerSettings.fadetype) do
							local is_selected = widgets.selected.fadeout_combo[i] == fade_out
							if reaper.ImGui_Selectable(ctx, LayerSettings.fadetype[fade_out], is_selected) then
								widgets.selected.fadeout_combo[i] = fade_out
								LayerSettings.fadeout.shape[i] = fade_out
								if State.reaper_data.tracks ~= nil then utils.set_fade_out_shape(utils.get_mediaitems_from_i_childtrack(i, State.reaper_data.tracks), LayerSettings.fadeout.shape[i]); reaper.UpdateArrange() end
							end

							-- Set the initial focus when opening the combo (scrolling + keyboard navigation focus)
							if is_selected then
								reaper.ImGui_SetItemDefaultFocus(ctx)
							end
						end

						reaper.ImGui_EndCombo(ctx)
					end

					reaper.ImGui_SetItemTooltip(ctx, 'Fade-out type')
					
					-- Clamp total to 100% only if exceeded
					local total = LayerSettings.fadein.percentage[i] + LayerSettings.fadeout.percentage[i]

					if adj_fi_prc[i] and total > 100 then
							LayerSettings.fadeout.percentage[i] = 100 - LayerSettings.fadein.percentage[i]
					elseif adj_fo_prc[i] and total > 100 then
							LayerSettings.fadein.percentage[i] = 100 - LayerSettings.fadeout.percentage[i]
					end

					--Set fades percentage
					if State.reaper_data.tracks ~= nil then
						if adj_fi_prc[i] then utils.set_fade_in_percentage(utils.get_mediaitems_from_i_childtrack(i, State.reaper_data.tracks), LayerSettings.fadein.percentage[i]); reaper.UpdateArrange() end
						if adj_fo_prc[i] then utils.set_fade_out_percentage(utils.get_mediaitems_from_i_childtrack(i, State.reaper_data.tracks), LayerSettings.fadeout.percentage[i]); reaper.UpdateArrange() end
					end

					--Set initial values for EQ
					if LayerSettings.lowshelf.gain[i] == nil then LayerSettings.lowshelf.gain[i] = 0 end
					if LayerSettings.lowshelf.freq[i] == nil then LayerSettings.lowshelf.freq[i] = 500 end
					if LayerSettings.lowshelf.bandwidth[i] == nil then LayerSettings.lowshelf.bandwidth[i] = 2 end
					if LayerSettings.midshelf.gain[i] == nil then LayerSettings.midshelf.gain[i] = 0 end
					if LayerSettings.midshelf.freq[i] == nil then LayerSettings.midshelf.freq[i] = 2500 end
					if LayerSettings.midshelf.bandwidth[i] == nil then LayerSettings.midshelf.bandwidth[i] = 2 end
					if LayerSettings.highshelf.gain[i] == nil then LayerSettings.highshelf.gain[i] = 0 end
					if LayerSettings.highshelf.freq[i] == nil then LayerSettings.highshelf.freq[i] = 5000 end
					if LayerSettings.highshelf.bandwidth[i] == nil then LayerSettings.highshelf.bandwidth[i] = 2 end
					if LayerSettings.eq_added[i] == nil then LayerSettings.eq_added[i] = false end

					--Insert ReaEQ at 1st position in child track fx chain
					if State.reaper_data.tracks ~= nil and LayerSettings.eq_added[i] == false and LayerSettings.eq[i] == true then

						reaper.PreventUIRefresh(-1)

						--FIX: next method is deprecated. Need refactor
						for _, value in next, State.reaper_data.tracks, nil do
							
							local success, err = pcall(function()
								utils.insert_eq(value[i])
							end)
							
							if not success then
								reaper.ShowMessageBox("Unexpected error: " .. tostring(err), "EQ Insert Error", 0)
							end
							
						end

						reaper.PreventUIRefresh(-1)
						reaper.UpdateArrange()
						LayerSettings.eq_added[i] = true
					end

					--EQ Checkbox
					adj_eq[i], LayerSettings.eq[i] = reaper.ImGui_Checkbox(ctx, 'EQ##' .. i, LayerSettings.eq[i])
					reaper.ImGui_SetItemTooltip(ctx, 'Enable ReaEQ on each of the layer ' .. i ..' tracks')

					if LayerSettings.eq[i] == true then

						reaper.ImGui_SameLine(ctx)

						State.eq_enabled = true

						--EQ Combo
						if widgets.selected.eq_bandtype_combo[i] == nil then widgets.selected.eq_bandtype_combo[i] = 1 end
						widgets.selected.eq_bandtype_combo_preview[i] = LayerSettings.eq_type[widgets.selected.eq_bandtype_combo[i]]
						if reaper.ImGui_BeginCombo(ctx, '##EQcombo' .. tostring(i), widgets.selected.eq_bandtype_combo_preview[i], reaper.ImGui_ComboFlags_WidthFitPreview()) then
							for eq_type, _ in ipairs(LayerSettings.eq_type) do
								local is_selected = widgets.selected.eq_bandtype_combo[i] == eq_type
								if reaper.ImGui_Selectable(ctx, LayerSettings.eq_type[eq_type], is_selected) then
									widgets.selected.eq_bandtype_combo[i] = eq_type
								end
								-- Set the initial focus when opening the combo (scrolling + keyboard navigation focus)
								if is_selected then
									reaper.ImGui_SetItemDefaultFocus(ctx)
								end
							end
							reaper.ImGui_EndCombo(ctx)
						end

						--Plot histogram to visualize EQ
						reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_PlotHistogram(), style.header_layer_color.green)
						if GUI.Histrogram.array[i] == nil then GUI.Histrogram.array[i] = reaper.new_array(GUI.Histrogram.resolution); GUI.Histrogram.array[i].clear() end
						reaper.ImGui_PlotHistogram(ctx, '##Histogram' .. i, GUI.Histrogram.array[i], 0, nil, -24.0, 12.0, 0, 80.0)

						reaper.ImGui_SameLine(ctx)
						reaper.ImGui_TextDisabled(ctx, '(?)')
						
						if reaper.ImGui_BeginItemTooltip(ctx) then
							reaper.ImGui_PushTextWrapPos(ctx, reaper.ImGui_GetFontSize(ctx) * 35.0)
							reaper.ImGui_Text(ctx, 'Graph tooltip shows frequency and volume')
							reaper.ImGui_PopTextWrapPos(ctx)
							reaper.ImGui_EndTooltip(ctx)
						end

						reaper.ImGui_PopStyleColor(ctx)

						--HighShelf Setup
						if widgets.selected.eq_bandtype_combo_preview[i] == "Highshelf" then
							adj_hsh_lvl[i], LayerSettings.highshelf.gain[i] = reaper.ImGui_SliderDouble(ctx, 'HighShelf - Volume' .. "##" .. i, LayerSettings.highshelf.gain[i], -24.0, 12.0, "%.1f dB", widgets.sliderdbl.flags.volume_offset)
							adj_hsh_freq[i], LayerSettings.highshelf.freq[i] = reaper.ImGui_SliderInt(ctx, 'HighShelf - Frequency' .. "##" .. i, LayerSettings.highshelf.freq[i], 20, 20000, "%d Hz", widgets.sliderdbl.flags.time_offset)
							adj_hsh_bw[i], LayerSettings.highshelf.bandwidth[i] = reaper.ImGui_SliderDouble(ctx, 'HighShelf - Bandwidth'.. "##" .. i, LayerSettings.highshelf.bandwidth[i], 0.1, 4.00, "%.1f Oct", widgets.sliderdbl.flags.volume_offset)
						elseif widgets.selected.eq_bandtype_combo_preview[i] == "Band" then
							adj_msh_lvl[i], LayerSettings.midshelf.gain[i] = reaper.ImGui_SliderDouble(ctx, 'Band - Volume' .. "##"  .. i, LayerSettings.midshelf.gain[i], -24.0, 12.0, "%.1f dB", widgets.sliderdbl.flags.volume_offset)
							adj_msh_freq[i], LayerSettings.midshelf.freq[i] = reaper.ImGui_SliderInt(ctx, 'Band - Frequency' .. "##" .. i, LayerSettings.midshelf.freq[i], 20, 20000, "%d Hz", widgets.sliderdbl.flags.time_offset)
							adj_msh_bw[i], LayerSettings.midshelf.bandwidth[i] = reaper.ImGui_SliderDouble(ctx, 'Band - Bandwidth' .. "##" .. i, LayerSettings.midshelf.bandwidth[i], 0.1, 4.00, "%.1f Oct", widgets.sliderdbl.flags.volume_offset)
						elseif widgets.selected.eq_bandtype_combo_preview[i] == "Lowshelf" then
							adj_lsh_lvl[i], LayerSettings.lowshelf.gain[i] = reaper.ImGui_SliderDouble(ctx, 'LowShelf - Volume' .. "##" .. i, LayerSettings.lowshelf.gain[i], -24.0, 12.0, "%.1f dB", widgets.sliderdbl.flags.volume_offset)
							adj_lsh_freq[i], LayerSettings.lowshelf.freq[i] = reaper.ImGui_SliderInt(ctx, 'LowShelf - Frequency' .. "##" .. i, LayerSettings.lowshelf.freq[i], 20, 20000, "%d Hz", widgets.sliderdbl.flags.time_offset)
							adj_lsh_bw[i], LayerSettings.lowshelf.bandwidth[i] = reaper.ImGui_SliderDouble(ctx, 'LowShelf - Bandwidth' .. "##" .. i, LayerSettings.lowshelf.bandwidth[i], 0.1, 4.00, "%.1f Oct", widgets.sliderdbl.flags.volume_offset)
						end
						
						--Adjust EQ Parameters
						if adj_lsh_lvl[i] or adj_msh_lvl[i] or adj_hsh_lvl[i] or adj_lsh_freq[i] or adj_msh_freq[i] or adj_hsh_freq[i] or adj_lsh_bw[i] or adj_msh_bw[i] or adj_hsh_bw[i] then

							--Claer Histogram data
							GUI.Histrogram.array[i].clear()
							for a = 1, GUI.Histrogram.array[i].get_alloc() do
								GUI.Histrogram.array[i][a] = 0
							end

							--Update Histogram Data
							apply_band(GUI.Histrogram.array[i], LayerSettings.lowshelf.gain[i], LayerSettings.lowshelf.freq[i], LayerSettings.lowshelf.bandwidth[i], "lowshelf") 
							apply_band(GUI.Histrogram.array[i], LayerSettings.midshelf.gain[i], LayerSettings.midshelf.freq[i], LayerSettings.midshelf.bandwidth[i], "midshelf")
							apply_band(GUI.Histrogram.array[i], LayerSettings.highshelf.gain[i], LayerSettings.highshelf.freq[i], LayerSettings.highshelf.bandwidth[i], "highshelf")

							if State.reaper_data.tracks ~= nil then
								for _, value in next, State.reaper_data.tracks, nil do
									local success, err = pcall(function()
										utils.update_eq_param(value[i], LayerSettings.lowshelf.gain[i], LayerSettings.lowshelf.freq[i], LayerSettings.lowshelf.bandwidth[i], LayerSettings.midshelf.gain[i], LayerSettings.midshelf.freq[i], LayerSettings.midshelf.bandwidth[i], LayerSettings.highshelf.gain[i], LayerSettings.highshelf.freq[i], LayerSettings.highshelf.bandwidth[i])
									end)
									
									if not success then
										reaper.ShowMessageBox("Unexpected error: " .. tostring(err), "EQ Update Error", 0)
									end
								end
							end
						end
					else -- delete the EQ
					
						State.eq_enabled = false

						if State.reaper_data.tracks ~= nil and LayerSettings.eq_added[i] == true and adj_eq[i] == true then

							reaper.PreventUIRefresh(1)
							local track = 0

							for _, value in next, State.reaper_data.tracks, nil do
								track = value[i]
								utils.remove_eq(track)
							end

							reaper.PreventUIRefresh(-1)
							reaper.UpdateArrange()

							LayerSettings.eq_added[i] = false

							reaper.ImGui_PopItemWidth(ctx)
						end
					end
					
					-- Run layer parameters when engine scipt has run to ensure that they are set immediately and automatically
					if State.global.has_run == true and State.reaper_data.tracks ~= nil then
						reaper.PreventUIRefresh(1)
							--Insert ReaEQ at 1st position in child track fx chain
						if LayerSettings.eq[i] == true then

							--FIX: next method is deprecated.
							for _, value in next, State.reaper_data.tracks, nil do
								local success, err = pcall(function()
									utils.insert_eq(value[i])
								end)
								
								if not success then
									reaper.ShowMessageBox("Unexpected error: " .. tostring(err), "EQ Insert Error", 0)
								end
							end

							LayerSettings.eq_added[i] = true
						end

						--ReaEQ parameters
						for _, value in next, State.reaper_data.tracks, nil do
							local success, err = pcall(function()
								utils.update_eq_param(value[i], LayerSettings.lowshelf.gain[i], LayerSettings.lowshelf.freq[i], LayerSettings.lowshelf.bandwidth[i], LayerSettings.midshelf.gain[i], LayerSettings.midshelf.freq[i], LayerSettings.midshelf.bandwidth[i], LayerSettings.highshelf.gain[i], LayerSettings.highshelf.freq[i], LayerSettings.highshelf.bandwidth[i])
							end)
							
							if not success then
								reaper.ShowMessageBox("Unexpected error: " .. tostring(err), "EQ Update Error", 0)
							end
						end

						reaper.PreventUIRefresh(-1)
						reaper.UpdateArrange()
					end

					reaper.ImGui_PopStyleColor(ctx)

				else
					if LayerSettings.selected_sound_layer[i] ~= nil then
						LayerSettings.layer_name[i] = tostring(LayerSettings.selected_sound_layer[i])
					end
				end

				--Style end
				reaper.ImGui_PopStyleColor(ctx)
				reaper.ImGui_PopID(ctx)
			end

			reaper.ImGui_EndChild(ctx)
		end

		------------
		--GENERATE--
		------------
		
		--Generate button style
		local layer_types_selected_count = 0
		local sound_types_selected_count = 0

		for layertype,_ in pairs(LayerSettings.selected_sound_layer) do
				layer_types_selected_count = layertype
		end

		for _,include in pairs(State.user_data.selection.sound_types ) do
			if include == true then
				sound_types_selected_count = sound_types_selected_count + 1
			end
		end

		if layer_types_selected_count >= 1 and sound_types_selected_count >= 1 then

			if style.button_generate.button_is_item_hovered then
				reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FrameBorderSize(), 5, nil)
			else
				reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FrameBorderSize(), 0, nil)
			end

			--reaper.ImGui_PushFont(ctx, Fonts.ubisoft_sans_bold)
			reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FrameRounding(), style.button_generate.var.rounding, nil)
			reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FramePadding(), style.button_generate.var.padding_vertical, style.button_generate.var.padding_horizontal)
			reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), style.button_generate.button_colors_enabled.color_button)
			reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), style.button_generate.button_colors_enabled.color_button_hovered)
			reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonActive(), style.button_generate.button_colors_enabled.color_button_active)
			reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), style.button_generate.button_colors_enabled.color_text)
		else
			--reaper.ImGui_PushFont(ctx, Fonts.ubisoft_sans_bold)
			reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FrameBorderSize(), 0, nil)
			reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FrameRounding(), style.button_generate.var.rounding, nil)
			reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FramePadding(), style.button_generate.var.padding_vertical, style.button_generate.var.padding_horizontal)
			reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), style.button_generate.button_colors_disabled.color_button)
			reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), style.button_generate.button_colors_disabled.color_button_hovered)
			reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonActive(), style.button_generate.button_colors_disabled.color_button_active)
			reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), style.button_generate.button_colors_disabled.color_text)
		end

		--Generate Button
		if reaper.ImGui_Button(ctx, "Generate") and layer_types_selected_count >= 1 and sound_types_selected_count >= 1 then
			
			if not GUI.ModalPopup.dont_ask_me_next_time then reaper.ImGui_OpenPopup(ctx, 'Continue?') end

			reaper.PreventUIRefresh(1)
			if State.reaper_data.tracks ~= nil then
				engine.delete_tracks(State.reaper_data.tracks)
				if State.regions ~= nil or State.markers ~= nil then
					engine.delete_markers_regions(State.regions, State.markers)
				end
			end
			
			engine.delete_markers_regions(State.reaper_data.regions, State.reaper_data.markers)

			State.reaper_data.tracks, State.reaper_data.media_items, State.reaper_data.regions, State.reaper_data.markers = engine.build_tracks(
				State.file_data.sound_lib,
				State.user_data.selection.sound_types,
				State.user_data.num_layers,
				State.user_data.num_variations,
				State.user_data.is_sausage_file,
				GUI.Events.peak_threshold,
				GUI.Events.peak_gap,
				State.user_data.item_spacing,
				State.user_data.randomize.offset,
				State.user_data.randomize.pitch.semitones,
				State.user_data.randomize.pitch.timestretch,
				State.user_data.randomize.volume,
				State.user_data.wants_pitch_not_ts,
				GUI.Settings.auto_group_items,
				GUI.Settings.normalize_items,
				GUI.Settings.auto_add_regions,
				GUI.Settings.auto_add_markers,
				GUI.Settings.customization.region.color,
				GUI.Settings.customization.marker.color
			)
			State.user_data.num_layers_generated = State.user_data.num_layers

			State.reaper_data.num_parent_tracks = 0
			State.reaper_data.num_child_tracks = 0
			for parent, children in pairs(State.reaper_data.tracks) do
				State.reaper_data.num_parent_tracks = State.reaper_data.num_parent_tracks + 1
				for _, child in pairs(children) do
					State.reaper_data.num_child_tracks = State.reaper_data.num_child_tracks + 1
				end
			end
			for i=1, State.user_data.num_layers do
				LayerSettings.media_items[i] = utils.get_mediaitems_from_i_childtrack(i, State.reaper_data.tracks)
			end
			reaper.PreventUIRefresh(-1)
			reaper.UpdateArrange()

		--reaper.ImGui_PopFont(ctx)
		
		if layer_types_selected_count < 1 and sound_types_selected_count < 1 then
			reaper.ImGui_SetItemTooltip(ctx, 'Please select at least one "Parent" and one "Layer" before generating')
		end

		style.button_generate.button_is_item_hovered = reaper.ImGui_IsItemHovered(ctx, reaper.ImGui_HoveredFlags_AllowWhenBlockedByPopup())

			State.global.has_run = true
		end
		reaper.ImGui_PopStyleVar(ctx,3)
		reaper.ImGui_PopStyleColor(ctx, 4)
		reaper.ImGui_SameLine(ctx)

		if reaper.ImGui_SmallButton(ctx, "Clear" .. "##ClaerAllChanges") then
			--TODO: clear all changes including tracks, regions, markers etc.
		end
		reaper.ImGui_SetItemTooltip(ctx, 'TODO: reset all changes including tracks, regions, markers etc.')

		local center_x, center_y = reaper.ImGui_Viewport_GetCenter(reaper.ImGui_GetWindowViewport(ctx))
		reaper.ImGui_SetNextWindowPos(ctx, center_x, center_y, reaper.ImGui_Cond_Appearing(), 0.5, 0.5)
		if reaper.ImGui_BeginPopupModal(ctx, "Continue?", nil, reaper.ImGui_WindowFlags_AlwaysAutoResize()) then

			reaper.ImGui_Text(ctx, 'Vegerator does not currently support generation of both one-shots and loops simultaneously.\nProceed with caution!')
			
			reaper.ImGui_Separator(ctx)

			reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FramePadding(), 0, 0)

			_, GUI.ModalPopup.dont_ask_me_next_time = reaper.ImGui_Checkbox(ctx, "Don't ask me next time", GUI.ModalPopup.dont_ask_me_next_time)

			reaper.ImGui_PopStyleVar(ctx)

			if reaper.ImGui_Button(ctx, 'OK', 120, 0) then reaper.ImGui_CloseCurrentPopup(ctx) end

			reaper.ImGui_SetItemDefaultFocus(ctx)

			reaper.ImGui_SameLine(ctx)

			if reaper.ImGui_Button(ctx, 'Cancel', 120, 0) then reaper.ImGui_CloseCurrentPopup(ctx) end

			reaper.ImGui_EndPopup(ctx)

		end

		-------------------
		---UPDATE PARAMS---
		-------------------
		if State.global.has_run == true and State.reaper_data.tracks ~= nil then
			for i= 1, State.user_data.num_layers do
				utils.set_fade_in_percentage(utils.get_mediaitems_from_i_childtrack(i, State.reaper_data.tracks), LayerSettings.fadein.percentage[i])
				utils.set_fade_out_percentage(utils.get_mediaitems_from_i_childtrack(i, State.reaper_data.tracks), LayerSettings.fadeout.percentage[i])
				utils.set_fade_in_shape(utils.get_mediaitems_from_i_childtrack(i, State.reaper_data.tracks), LayerSettings.fadein.shape[i])
				utils.set_fade_out_shape(utils.get_mediaitems_from_i_childtrack(i, State.reaper_data.tracks), LayerSettings.fadeout.shape[i])
				--Volume
				utils.set_volume(LayerSettings.volume[i], utils.get_mediaitems_from_i_childtrack(i, State.reaper_data.tracks))
				--Pitch
				utils.set_pitch(LayerSettings.pitch[i], utils.get_mediaitems_from_i_childtrack(i, State.reaper_data.tracks))

				--Insert ReaEQ at 1st position in child track fx chain
				if LayerSettings.eq[i] == true then

					--FIX: next method is deprecated.
					for _, value in next, State.reaper_data.tracks, nil do
						local success, err = pcall(function()
							utils.insert_eq(value[i])
						end)
						
						if not success then
							reaper.ShowMessageBox("Unexpected error: " .. tostring(err), "EQ Insert Error", 0)
						end
					end

					LayerSettings.eq_added[i] = true
				end

				--ReaEQ parameters
				for _, value in next, State.reaper_data.tracks, nil do
					local success, err = pcall(function()
						utils.update_eq_param(value[i], LayerSettings.lowshelf.gain[i], LayerSettings.lowshelf.freq[i], LayerSettings.lowshelf.bandwidth[i], LayerSettings.midshelf.gain[i], LayerSettings.midshelf.freq[i], LayerSettings.midshelf.bandwidth[i], LayerSettings.highshelf.gain[i], LayerSettings.highshelf.freq[i], LayerSettings.highshelf.bandwidth[i])
					end)
					
					if not success then
						reaper.ShowMessageBox("Unexpected error: " .. tostring(err), "EQ Update Error", 0)
					end
				end

				reaper.PreventUIRefresh(-1)
				reaper.UpdateArrange()
			end
		end
	end
end

return GUI