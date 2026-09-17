-- Omansory: per-workspace interlocking masonry for Hyprland 0.55+ / Omarchy.
-- Register as lua:omansory. Toggle with `omansory toggle` (Super+Shift+O).
-- Windows stay axis-aligned rectangles (Wayland cannot clip L-shapes); packing
-- uses a skyline bin so tiles lock together instead of a rigid column grid.

local MIN_H = 96
local MIN_W = 160
local MIN_FRAC = 0.12
local LAYOUT_NAME = "omansory"

local workspaces = {}

local PRESETS = {
  { 0.62, 0.48 },
  { 0.38, 0.70 },
  { 0.50, 0.42 },
  { 0.45, 0.58 },
  { 0.33, 0.52 },
  { 0.55, 0.38 },
}

local function box(x, y, w, h)
  return { x = x, y = y, w = w, h = h }
end

local function clamp(value, lo, hi)
  return math.max(lo, math.min(hi, value))
end

local function target_id(target)
  local window = target.window
  if window and window.stable_id then
    return tostring(window.stable_id)
  end
  return tostring(target.index)
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

local function equal_frac(n)
  local frac = {}
  for i = 1, n do
    frac[i] = 1 / n
  end
  return frac
end

local function normalize_frac(frac, n)
  if n <= 1 then
    return { clamp((frac and frac[1]) or 1, MIN_FRAC, 1) }
  end
  local out = {}
  local total = 0
  for i = 1, n do
    out[i] = frac and frac[i] or (1 / n)
    if out[i] < MIN_FRAC then
      out[i] = MIN_FRAC
    end
    total = total + out[i]
  end
  if total <= 0 then
    return equal_frac(n)
  end
  for i = 1, n do
    out[i] = out[i] / total
  end
  return out
end

local function ws_state(ctx)
  local id = workspace_id(ctx)
  local ws = workspaces[id]
  if not ws then
    ws = {
      mode = "fit",
      n_cols = default_columns(ctx.area.w),
      frac = nil,
      columns = {},
      height = {},
      user_h = {},
      size = {},
      user_size = {},
      last_box = {},
      last_order = {},
    }
    workspaces[id] = ws
  end
  if not ws.mode then
    ws.mode = "fit"
  end
  return ws, id
end

local function index_of(list, value)
  for i, item in ipairs(list) do
    if item == value then
      return i
    end
  end
end

local function column_of(ws, id)
  for col, ids in ipairs(ws.columns) do
    local row = index_of(ids, id)
    if row then
      return col, row
    end
  end
end

local function shortest_column(ws, n)
  local best, best_n = 1, math.huge
  for col = 1, n do
    local count = ws.columns[col] and #ws.columns[col] or 0
    if count < best_n then
      best, best_n = col, count
    end
  end
  return best
end

local function apply_swap(ws, order)
  local prev = ws.last_order
  if #prev ~= #order then
    return
  end
  local seen = {}
  for _, id in ipairs(order) do
    seen[id] = true
  end
  for _, id in ipairs(prev) do
    if not seen[id] then
      return
    end
  end
  local diffs = {}
  for i = 1, #order do
    if order[i] ~= prev[i] then
      table.insert(diffs, i)
    end
  end
  if #diffs ~= 2 then
    return
  end
  local a, b = order[diffs[1]], order[diffs[2]]
  local col_a, row_a = column_of(ws, a)
  local col_b, row_b = column_of(ws, b)
  if not col_a or not col_b then
    return
  end
  ws.columns[col_a][row_a], ws.columns[col_b][row_b] = b, a
end

local function sync_columns(ctx, ws)
  local present = {}
  local order = {}
  local targets = {}
  for _, target in ipairs(ctx.targets) do
    local id = target_id(target)
    present[id] = true
    targets[id] = target
    table.insert(order, id)
  end

  apply_swap(ws, order)

  local n_wanted = ws.n_cols or default_columns(ctx.area.w)
  ws.n_cols = n_wanted
  local n = math.max(1, math.min(n_wanted, math.max(1, #ctx.targets)))
  while #ws.columns < n do
    table.insert(ws.columns, {})
  end
  while #ws.columns > n do
    local extra = table.remove(ws.columns)
    for _, id in ipairs(extra) do
      table.insert(ws.columns[n], id)
    end
  end

  for col = 1, n do
    local kept = {}
    for _, id in ipairs(ws.columns[col] or {}) do
      if present[id] then
        table.insert(kept, id)
      end
    end
    ws.columns[col] = kept
  end

  for id in pairs(ws.height) do
    if not present[id] then
      ws.height[id] = nil
      ws.user_h[id] = nil
      ws.size[id] = nil
      ws.user_size[id] = nil
      ws.last_box[id] = nil
    end
  end

  for _, id in ipairs(order) do
    if not column_of(ws, id) then
      table.insert(ws.columns[shortest_column(ws, n)], id)
    end
  end

  local empty, heavy = 0, 0
  for col = 1, n do
    local count = #(ws.columns[col] or {})
    if count == 0 then
      empty = empty + 1
    end
    if count > heavy then
      heavy = count
    end
  end
  if empty > 0 and heavy > 1 then
    local ids = {}
    for col = 1, n do
      for _, id in ipairs(ws.columns[col] or {}) do
        table.insert(ids, id)
      end
      ws.columns[col] = {}
    end
    for i, id in ipairs(ids) do
      table.insert(ws.columns[((i - 1) % n) + 1], id)
    end
  end

  ws.frac = normalize_frac(ws.frac, n)
  ws.last_order = order
  return targets, n
end

local function preferred_height(ws, target, id, area_h, fallback)
  if ws.user_h[id] and ws.height[id] and ws.height[id] > 0 then
    return clamp(ws.height[id], MIN_H, area_h)
  end
  return fallback
end

local function window_class(target)
  local window = target.window
  return string.lower((window and (window.class or window.initial_class)) or "")
end

local function classify(class)
  if class:find("brave", 1, true) or class:find("firefox", 1, true) or class:find("chrom", 1, true) or class:find("webkit", 1, true) then
    return "wide"
  end
  if class:find("ghostty", 1, true) or class:find("kitty", 1, true) or class:find("alacritty", 1, true) or class:find("foot", 1, true) or class:find("agent", 1, true) or class:find("code", 1, true) then
    return "tall"
  end
  return "tile"
end

local function desired_size(ws, target, id, index, area)
  if ws.user_size[id] and ws.size[id] then
    return clamp(ws.size[id].w, MIN_W, area.w), clamp(ws.size[id].h, MIN_H, area.h)
  end
  local kind = classify(window_class(target))
  local preset = PRESETS[((index - 1) % #PRESETS) + 1]
  local fw, fh = preset[1], preset[2]
  if kind == "wide" then
    fw, fh = math.max(fw, 0.58), math.min(fh, 0.55)
  elseif kind == "tall" then
    fw, fh = math.min(fw, 0.42), math.max(fh, 0.58)
  end
  return clamp(area.w * fw, MIN_W, area.w), clamp(area.h * fh, MIN_H, area.h)
end

local function merge_skyline(segs)
  table.sort(segs, function(a, b)
    return a.x < b.x
  end)
  local out = {}
  for _, seg in ipairs(segs) do
    if seg.w > 0.5 then
      local last = out[#out]
      if last and math.abs((last.x + last.w) - seg.x) < 0.5 and math.abs(last.y - seg.y) < 0.5 then
        last.w = last.w + seg.w
      else
        table.insert(out, { x = seg.x, y = seg.y, w = seg.w })
      end
    end
  end
  return out
end

local function height_at(skyline, x, width)
  local maxy = 0
  local x2 = x + width
  for _, seg in ipairs(skyline) do
    local a = math.max(x, seg.x)
    local b = math.min(x2, seg.x + seg.w)
    if b > a + 0.5 then
      maxy = math.max(maxy, seg.y)
    end
  end
  return maxy
end

local function insert_box(skyline, x, y, w, h)
  local x2 = x + w
  local y2 = y + h
  local new = {}
  for _, seg in ipairs(skyline) do
    local s1, s2 = seg.x, seg.x + seg.w
    if s2 <= x + 0.5 or s1 >= x2 - 0.5 then
      table.insert(new, seg)
    else
      if s1 < x - 0.5 then
        table.insert(new, { x = s1, y = seg.y, w = x - s1 })
      end
      if s2 > x2 + 0.5 then
        table.insert(new, { x = x2, y = seg.y, w = s2 - x2 })
      end
    end
  end
  table.insert(new, { x = x, y = y2, w = w })
  return merge_skyline(new)
end

local function find_pos(skyline, area, w, h)
  local candidates = { 0 }
  for _, seg in ipairs(skyline) do
    table.insert(candidates, seg.x)
    table.insert(candidates, math.max(0, seg.x + seg.w))
  end
  local best_x, best_y = 0, math.huge
  local found = false
  for _, x in ipairs(candidates) do
    if x < 0 then
      x = 0
    end
    if x + w <= area.w + 1 then
      local y = height_at(skyline, x, w)
      if y + h <= area.h + 2 and y < best_y then
        best_x, best_y, found = x, y, true
      end
    end
  end
  if found then
    return best_x, best_y, w, h
  end
  -- Does not fit at full size: sit on the lowest skyline and shrink to leftover.
  local x, y = 0, height_at(skyline, 0, math.min(w, area.w))
  for _, cand in ipairs(candidates) do
    if cand >= 0 and cand < area.w then
      local yy = height_at(skyline, cand, math.min(w, area.w - cand))
      if yy < y then
        x, y = cand, yy
      end
    end
  end
  local rw = math.max(MIN_W, area.w - x)
  local rh = math.max(MIN_H, area.h - y)
  return x, y, math.min(w, rw), math.min(h, rh)
end

local function place_fit(ctx)
  local n = #ctx.targets
  if n == 0 then
    return
  end
  local ws = ws_state(ctx)
  local area = ctx.area
  if n == 1 then
    ctx.targets[1]:place(area)
    ws.last_box[target_id(ctx.targets[1])] = { w = area.w, h = area.h }
    return
  end

  local skyline = { { x = 0, y = 0, w = area.w } }
  for i, target in ipairs(ctx.targets) do
    local id = target_id(target)
    local dw, dh = desired_size(ws, target, id, i, area)
    local x, y, w, h = find_pos(skyline, area, dw, dh)
    if h > 0 and w > 0 then
      target:place(box(area.x + x, area.y + y, w, h))
      ws.last_box[id] = { w = w, h = h }
      skyline = insert_box(skyline, x, y, w, h)
    end
  end
end

local function place_columns(ctx)
  local targets_n = #ctx.targets
  if targets_n == 0 then
    return
  end

  local ws = ws_state(ctx)
  local targets, n = sync_columns(ctx, ws)
  local area = ctx.area

  local x = area.x
  for col = 1, n do
    local ids = ws.columns[col] or {}
    local col_w = area.w * (ws.frac[col] or (1 / n))
    local fallback = area.h / math.max(1, #ids)
    local items = {}
    local total = 0
    local any_user = false
    for _, id in ipairs(ids) do
      local target = targets[id]
      if target then
        local height = preferred_height(ws, target, id, area.h, fallback)
        if ws.user_h[id] then
          any_user = true
        end
        table.insert(items, { id = id, target = target, h = height })
        total = total + height
      end
    end

    if not any_user and total > 0 then
      local scale_fill = area.h / total
      for _, item in ipairs(items) do
        item.h = item.h * scale_fill
      end
      total = area.h
    end

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
        item.target:place(box(x, y, col_w, height))
        ws.last_box[item.id] = { w = col_w, h = height }
        y = y + height
      end
    end
    x = x + col_w
  end
end

local function place_masonry(ctx)
  local ws = ws_state(ctx)
  if ws.mode == "columns" then
    place_columns(ctx)
  else
    place_fit(ctx)
  end
end

local function focused_id(ctx)
  for _, target in ipairs(ctx.targets) do
    local window = target.window
    if window and window.active then
      return target_id(target)
    end
  end
  if ctx.targets[1] then
    return target_id(ctx.targets[1])
  end
end

local function resize_fit(ctx, axis, delta)
  local ws = ws_state(ctx)
  local id = focused_id(ctx)
  if not id then
    return
  end
  local last = ws.size[id] or ws.last_box[id] or { w = ctx.area.w * 0.45, h = ctx.area.h * 0.45 }
  local w, h = last.w, last.h
  if axis == "h" then
    w = clamp(w - delta, MIN_W, ctx.area.w)
  else
    h = clamp(h + delta, MIN_H, ctx.area.h)
  end
  ws.size[id] = { w = w, h = h }
  ws.user_size[id] = true
end

local function resize_horizontal(ctx, delta)
  local ws = ws_state(ctx)
  if ws.mode ~= "columns" then
    resize_fit(ctx, "h", delta)
    return
  end
  local id = focused_id(ctx)
  if not id then
    return
  end
  local n = math.max(1, #ws.columns)
  local col = column_of(ws, id) or 1
  ws.frac = normalize_frac(ws.frac, n)
  local step = delta / math.max(1, ctx.area.w)
  local grow = -step
  if n == 1 then
    ws.frac[1] = clamp(ws.frac[1] + grow, MIN_FRAC, 1)
    return
  end
  local neighbor = col < n and col + 1 or col - 1
  local next_frac = clamp(ws.frac[col] + grow, MIN_FRAC, 1 - MIN_FRAC)
  local stolen = next_frac - ws.frac[col]
  ws.frac[col] = next_frac
  ws.frac[neighbor] = clamp(ws.frac[neighbor] - stolen, MIN_FRAC, 1 - MIN_FRAC)
  ws.frac = normalize_frac(ws.frac, n)
end

local function resize_vertical(ctx, delta)
  local ws = ws_state(ctx)
  if ws.mode ~= "columns" then
    resize_fit(ctx, "v", delta)
    return
  end
  local id = focused_id(ctx)
  if not id then
    return
  end
  local current = ws.height[id]
  if not current then
    local last = ws.last_box[id]
    current = last and last.h or (ctx.area.h / 2)
  end
  ws.height[id] = clamp(current + delta, MIN_H, ctx.area.h)
  ws.user_h[id] = true
end

local function handle_msg(ctx, msg)
  local command, rest = msg:match("^(%S+)%s*(.*)$")
  command = command or ""
  rest = rest or ""
  local ws = ws_state(ctx)

  if command == "mode" then
    if rest == "fit" or rest == "columns" then
      ws.mode = rest
      return true
    end
    return "omansory: mode expects fit or columns"
  end

  if command == "cols" or command == "columns" then
    ws.mode = "columns"
    local current = ws.n_cols or default_columns(ctx.area.w)
    if rest == "+" or rest == "inc" then
      ws.n_cols = math.min(6, current + 1)
    elseif rest == "-" or rest == "dec" then
      ws.n_cols = math.max(1, current - 1)
    elseif rest:match("^%d+$") then
      ws.n_cols = clamp(tonumber(rest), 1, 6)
    elseif rest == "" then
      return true
    else
      return "omansory: cols expects +, -, or a number 1-6"
    end
    ws.frac = equal_frac(ws.n_cols)
    return true
  end

  if command == "reset" then
    local id = workspace_id(ctx)
    workspaces[id] = nil
    return true
  end

  if command == "resize" then
    local axis, amount = rest:match("^(%S+)%s*(%S+)")
    amount = tonumber(amount)
    if not axis or not amount then
      return "omansory: resize expects h|v <pixels>"
    end
    if axis == "h" or axis == "x" then
      resize_horizontal(ctx, amount)
    elseif axis == "v" or axis == "y" then
      resize_vertical(ctx, amount)
    else
      return "omansory: resize axis must be h or v"
    end
    return true
  end

  return "omansory: expected mode, cols, reset, or resize h|v <px>"
end

hl.layout.register(LAYOUT_NAME, {
  recalculate = place_masonry,
  layout_msg = handle_msg,
})
