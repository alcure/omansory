-- Omansory: per-workspace interlocking masonry for Hyprland 0.55+ / Omarchy.
-- Register as lua:omansory. Toggle with `omansory toggle` (Super+Shift+O).
-- Windows stay axis-aligned rectangles. Fit mode is a weighted BSP split that
-- covers the whole work area (no holes, no overflow) and prefers browsers/editors.

local MIN_H = 96
local MIN_W = 160
local MIN_FRAC = 0.12
local LAYOUT_NAME = "omansory"

local workspaces = {}

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
      bonus = {},
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
      ws.bonus[id] = nil
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
  if class:find("brave", 1, true) or class:find("firefox", 1, true) or class:find("chrom", 1, true) or class:find("webkit", 1, true) or class:find("librewolf", 1, true) then
    return "wide"
  end
  if class:find("obsidian", 1, true) or class:find("omawrite", 1, true) or class:find("zed", 1, true) or class:find("codium", 1, true) or class:find("sublime", 1, true) or class:find("libreoffice", 1, true) or class:find("evince", 1, true) or class:find("writer", 1, true) or class:find("code-oss", 1, true) or class:find("vscodium", 1, true) or class:find("dev.zed", 1, true) then
    return "wide"
  end
  if class:find("ghostty", 1, true) or class:find("kitty", 1, true) or class:find("alacritty", 1, true) or class:find("foot", 1, true) or class:find("org.omarchy.agent", 1, true) or class:find("org.omarchy.terminal", 1, true) or class:find("org.omarchy.btop", 1, true) then
    return "tall"
  end
  if class:find("code", 1, true) then
    return "wide"
  end
  return "tile"
end

local function base_weight(kind)
  if kind == "wide" then
    return 4
  end
  if kind == "tall" then
    return 1
  end
  return 2
end

local function item_weight(ws, target, id)
  local kind = classify(window_class(target))
  local bonus = (ws.bonus and ws.bonus[id]) or 0
  return math.max(0.5, base_weight(kind) + bonus), kind
end

local function pack_fill(ws, items, rect)
  if #items == 0 then
    return
  end
  if #items == 1 then
    local it = items[1]
    it.target:place(rect)
    ws.last_box[it.id] = { w = rect.w, h = rect.h }
    return
  end

  local total = 0
  for _, it in ipairs(items) do
    total = total + it.weight
  end
  local first = items[1]
  local rest = {}
  for i = 2, #items do
    table.insert(rest, items[i])
  end
  local ratio = first.weight / total
  local split_sideways = rect.w >= rect.h
  if first.kind == "tall" and rect.w > MIN_W * 2 then
    split_sideways = true
  elseif first.kind == "wide" and rect.h > MIN_H * 2 then
    split_sideways = false
  end

  if split_sideways then
    local w1 = clamp(rect.w * ratio, MIN_W, math.max(MIN_W, rect.w - MIN_W))
    first.target:place(box(rect.x, rect.y, w1, rect.h))
    ws.last_box[first.id] = { w = w1, h = rect.h }
    pack_fill(ws, rest, box(rect.x + w1, rect.y, rect.w - w1, rect.h))
  else
    local h1 = clamp(rect.h * ratio, MIN_H, math.max(MIN_H, rect.h - MIN_H))
    first.target:place(box(rect.x, rect.y, rect.w, h1))
    ws.last_box[first.id] = { w = rect.w, h = h1 }
    pack_fill(ws, rest, box(rect.x, rect.y + h1, rect.w, rect.h - h1))
  end
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

  local items = {}
  for _, target in ipairs(ctx.targets) do
    local id = target_id(target)
    local weight, kind = item_weight(ws, target, id)
    table.insert(items, { id = id, target = target, weight = weight, kind = kind })
  end
  table.sort(items, function(a, b)
    if a.weight ~= b.weight then
      return a.weight > b.weight
    end
    return a.id < b.id
  end)
  pack_fill(ws, items, { x = area.x, y = area.y, w = area.w, h = area.h })
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
  -- Super+- expand is negative x; treat any grow as +weight for the focused app.
  local step = (axis == "h") and (-delta / 200) or (delta / 200)
  ws.bonus = ws.bonus or {}
  ws.bonus[id] = clamp((ws.bonus[id] or 0) + step, -3, 8)
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
