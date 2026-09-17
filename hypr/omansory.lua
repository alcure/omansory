-- Omansory: per-workspace masonry layout for Hyprland 0.55+ / Omarchy.
-- Register as lua:omansory. Toggle with `omansory toggle` (Super+Shift+O).

local MIN_H = 96
local LAYOUT_NAME = "omansory"

local state = {
  cols_by_ws = {},
}

local function vec(value)
  if type(value) ~= "table" then
    return nil, nil
  end
  local x = tonumber(value.x or value.w or value[1])
  local y = tonumber(value.y or value.h or value[2])
  return x, y
end

local function box(x, y, w, h)
  return { x = x, y = y, w = w, h = h }
end

local function workspace_id(ctx)
  for _, target in ipairs(ctx.targets) do
    local window = target.window
    if window and window.workspace and window.workspace.id then
      return window.workspace.id
    end
  end
  return 0
end

local function default_columns(area_w)
  if area_w >= 2800 then
    return 3
  end
  if area_w >= 1400 then
    return 2
  end
  return 1
end

local function column_count(ctx)
  local ws = workspace_id(ctx)
  local forced = state.cols_by_ws[ws]
  if forced then
    return math.max(1, math.min(6, forced))
  end
  return default_columns(ctx.area.w)
end

local function preferred_height(target, area_h, fallback)
  local window = target.window
  if window then
    local _, height = vec(window.size)
    if height and height > 0 then
      return math.max(MIN_H, math.min(height, area_h))
    end
  end
  return fallback
end

local function shortest_column(heights)
  local best = 1
  for index = 2, #heights do
    if heights[index] < heights[best] then
      best = index
    end
  end
  return best
end

local function place_masonry(ctx)
  local targets = ctx.targets
  local n = #targets
  if n == 0 then
    return
  end

  local area = ctx.area
  if n == 1 then
    targets[1]:place(area)
    return
  end

  local cols = math.min(column_count(ctx), n)
  local col_w = area.w / cols
  local fallback = area.h / math.max(1, math.ceil(n / cols))

  local columns = {}
  local heights = {}
  for index = 1, cols do
    columns[index] = {}
    heights[index] = 0
  end

  for _, target in ipairs(targets) do
    local col = shortest_column(heights)
    local height = preferred_height(target, area.h, fallback)
    table.insert(columns[col], { target = target, h = height })
    heights[col] = heights[col] + height
  end

  for col = 1, cols do
    local items = columns[col]
    local total = heights[col]
    local scale = 1
    if total > area.h and total > 0 then
      scale = area.h / total
    end

    local y = area.y
    for _, item in ipairs(items) do
      local height = math.max(MIN_H, item.h * scale)
      local remaining = area.y + area.h - y
      if height > remaining then
        height = math.max(0, remaining)
      end
      if height > 0 then
        item.target:place(box(area.x + (col - 1) * col_w, y, col_w, height))
        y = y + height
      end
    end
  end
end

local function handle_msg(ctx, msg)
  local command, arg = msg:match("^(%S+)%s*(.*)$")
  command = command or ""
  arg = arg or ""
  local ws = workspace_id(ctx)
  local current = state.cols_by_ws[ws] or default_columns(ctx.area.w)

  if command == "cols" or command == "columns" then
    if arg == "+" or arg == "inc" then
      state.cols_by_ws[ws] = math.min(6, current + 1)
    elseif arg == "-" or arg == "dec" then
      state.cols_by_ws[ws] = math.max(1, current - 1)
    elseif arg:match("^%d+$") then
      state.cols_by_ws[ws] = math.max(1, math.min(6, tonumber(arg)))
    else
      return "omansory: cols expects +, -, or a number 1-6"
    end
    return true
  end

  if command == "reset" then
    state.cols_by_ws[ws] = nil
    return true
  end

  return "omansory: expected cols +|-|N or reset"
end

hl.layout.register(LAYOUT_NAME, {
  recalculate = place_masonry,
  layout_msg = handle_msg,
})
