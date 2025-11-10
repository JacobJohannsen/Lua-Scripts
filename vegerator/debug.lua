--debug.lua

local Debug = {}

function Debug.show_category_list(ctx, tbl)
    for subcat, categories in pairs(tbl) do
      if reaper.ImGui_TreeNode(ctx, subcat) then
        for cat, files in pairs(categories) do
          if reaper.ImGui_TreeNode(ctx, cat) then
            for _, file in ipairs(files) do
              reaper.ImGui_Text(ctx, file)
            end
            reaper.ImGui_TreePop(ctx)
          end
        end
        reaper.ImGui_TreePop(ctx)
      end
    end
end

function Debug.show_value(ctx, string, value)
  reaper.ImGui_Text(ctx, string .. value)
end

return Debug