-- Omansory: per-workspace interlocking masonry for Hyprland 0.55+ / Omarchy.
-- Register as lua:omansory. Toggle with `omansory toggle` (Super+Shift+O).
-- Windows stay axis-aligned rectangles (no L-shapes). Fit mode is a squarified
-- treemap that fills the work area without full-width single-app bars.
-- Super+Shift+K locks a window's fraction so toggle on/off restores it.

local MIN_H = 96
local MIN_W = 160
local MIN_FRAC = 0.12
local LAYOUT_NAME = "omansory"
local LOCK_TAG = "omansory-lock"

local workspaces = {}
local load_locks

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
      locks = load_locks(id),
      arranged = false,
      pack_area = nil,
    }
    workspaces[id] = ws
  end
  if not ws.mode then
    ws.mode = "fit"
  end
  if ws.arranged == nil then
    ws.arranged = false
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

local function state_dir()
  local home = os.getenv("HOME") or ""
  return (os.getenv("XDG_STATE_HOME") or (home .. "/.local/state")) .. "/omansory"
end

local function locks_path(ws_id)
  return state_dir() .. "/locks/" .. tostring(ws_id) .. ".jsonl"
end

load_locks = function(ws_id)
  local locks = {}
  local file = io.open(locks_path(ws_id), "r")
  if not file then
    return locks
  end
  for line in file:lines() do
    local id = line:match('"id":"([^"]+)"')
    local class = line:match('"class":"([^"]*)"') or ""
    local rx = tonumber(line:match('"rx":([%-%d%.eE+]+)'))
    local ry = tonumber(line:match('"ry":([%-%d%.eE+]+)'))
    local rw = tonumber(line:match('"rw":([%-%d%.eE+]+)'))
    local rh = tonumber(line:match('"rh":([%-%d%.eE+]+)'))
    if id and rx and ry and rw and rh then
      locks[id] = { class = class, rx = rx, ry = ry, rw = rw, rh = rh }
    end
  end
  file:close()
  return locks
end

local function save_locks(ws_id, ws)
  os.execute("mkdir -p '" .. state_dir() .. "/locks'")
  local file = io.open(locks_path(ws_id), "w")
  if not file then
    return
  end
  for id, lock in pairs(ws.locks or {}) do
    local class = tostring(lock.class or ""):gsub('"', "")
    file:write(string.format(
      '{"id":"%s","class":"%s","rx":%.6f,"ry":%.6f,"rw":%.6f,"rh":%.6f}\n',
      id,
      class,
      lock.rx,
      lock.ry,
      lock.rw,
      lock.rh
    ))
  end
  file:close()
end

local function tag_lock(target, on)
  local window = target.window
  if not window or not window.address then
    return
  end
  local op = on and "+" or "-"
  pcall(function()
    hl.dispatch(hl.dsp.window.tag({
      window = "address:" .. window.address,
      tag = op .. LOCK_TAG,
    }))
  end)
end

local function record_place(ws, item, rect)
  item.target:place(box(rect.x, rect.y, rect.w, rect.h))
  ws.last_box[item.id] = { x = rect.x, y = rect.y, w = rect.w, h = rect.h }
end

local function remap_box(b, from, to)
  if not b or not to then
    return b
  end
  if not from or from.w < 1 or from.h < 1 then
    return { x = b.x, y = b.y, w = b.w, h = b.h }
  end
  return {
    x = to.x + ((b.x - from.x) / from.w) * to.w,
    y = to.y + ((b.y - from.y) / from.h) * to.h,
    w = (b.w / from.w) * to.w,
    h = (b.h / from.h) * to.h,
  }
end

local function overlap_1d(a1, a2, b1, b2)
  return math.min(a2, b2) - math.max(a1, b1)
end

local function neighbor_id(ws, id, dir, exclude)
  local a = ws.last_box[id]
  if not a or not a.w then
    return
  end
  dir = ({ left = "l", right = "r", up = "u", down = "d", l = "l", r = "r", u = "u", d = "d" })[dir] or dir
  local function consider(strict)
    local best, best_score = nil, math.huge
    local acx, acy = a.x + a.w / 2, a.y + a.h / 2
    for oid, b in pairs(ws.last_box) do
      if oid ~= id and oid ~= exclude and b and b.w then
        local bcx, bcy = b.x + b.w / 2, b.y + b.h / 2
        local ovx = overlap_1d(a.x, a.x + a.w, b.x, b.x + b.w)
        local ovy = overlap_1d(a.y, a.y + a.h, b.y, b.y + b.h)
        local ok, score = false, math.huge
        if dir == "l" and bcx < acx then
          ok = (not strict) or ovy > 0
          score = acx - bcx
        elseif dir == "r" and bcx > acx then
          ok = (not strict) or ovy > 0
          score = bcx - acx
        elseif dir == "u" and bcy < acy then
          ok = (not strict) or ovx > 0
          score = acy - bcy
        elseif dir == "d" and bcy > acy then
          ok = (not strict) or ovx > 0
          score = bcy - acy
        end
        if ok and score < best_score then
          best, best_score = oid, score
        end
      end
    end
    return best
  end
  return consider(true) or consider(false)
end

local function sum_weight(items, first, last)
  local total = 0
  for i = first, last do
    total = total + items[i].weight
  end
  return total
end

local function worst_ratio(items, first, last, side, rem_area, rem_weight)
  local row_w = sum_weight(items, first, last)
  if row_w <= 0 or side <= 1 or rem_weight <= 0 then
    return math.huge
  end
  local thick = (rem_area * (row_w / rem_weight)) / side
  local worst = 0
  for i = first, last do
    local span = side * (items[i].weight / row_w)
    local short = math.min(span, thick)
    local long = math.max(span, thick)
    if short < 1 then
      return math.huge
    end
    worst = math.max(worst, long / short)
  end
  return worst
end

local function pack_fill(ws, items, rect)
  if #items == 0 or rect.w < 1 or rect.h < 1 then
    return
  end
  if #items == 1 then
    record_place(ws, items[1], rect)
    return
  end

  local i = 1
  while i <= #items do
    if rect.w < MIN_W or rect.h < MIN_H then
      for j = i, #items do
        record_place(ws, items[j], rect)
      end
      return
    end

    local rem_weight = sum_weight(items, i, #items)
    local rem_area = rect.w * rect.h
    local vertical = rect.w >= rect.h
    if (not vertical) and (#items - i) >= 1 and rect.w >= MIN_W * 2 then
      -- Never lay a leftover group as one full-width bar when another tile remains.
      vertical = true
    end
    local side = vertical and rect.h or rect.w
    local last = i
    local best = worst_ratio(items, i, last, side, rem_area, rem_weight)
    for j = i + 1, #items do
      local trial = worst_ratio(items, i, j, side, rem_area, rem_weight)
      if trial <= best then
        best = trial
        last = j
      else
        break
      end
    end
    if last == i and i < #items and (not vertical) then
      last = i + 1
      vertical = true
      side = rect.h
    end

    local row_w = sum_weight(items, i, last)
    if vertical then
      local tw = clamp(rect.w * (row_w / rem_weight), MIN_W, math.max(MIN_W, rect.w - (i < #items and last < #items and MIN_W or 0)))
      if last == #items then
        tw = rect.w
      end
      local y = rect.y
      for j = i, last do
        local h = rect.h * (items[j].weight / row_w)
        if j == last then
          h = rect.y + rect.h - y
        end
        record_place(ws, items[j], { x = rect.x, y = y, w = tw, h = h })
        y = y + h
      end
      rect = { x = rect.x + tw, y = rect.y, w = rect.w - tw, h = rect.h }
    else
      local th = clamp(rect.h * (row_w / rem_weight), MIN_H, math.max(MIN_H, rect.h - (last < #items and MIN_H or 0)))
      if last == #items then
        th = rect.h
      end
      local x = rect.x
      for j = i, last do
        local w = rect.w * (items[j].weight / row_w)
        if j == last then
          w = rect.x + rect.w - x
        end
        record_place(ws, items[j], { x = x, y = rect.y, w = w, h = th })
        x = x + w
      end
      rect = { x = rect.x, y = rect.y + th, w = rect.w, h = rect.h - th }
    end
    i = last + 1
  end
end

local function subtract_rect(free, used)
  local out = {}
  for _, rect in ipairs(free) do
    local ix = math.max(rect.x, used.x)
    local iy = math.max(rect.y, used.y)
    local ix2 = math.min(rect.x + rect.w, used.x + used.w)
    local iy2 = math.min(rect.y + rect.h, used.y + used.h)
    if ix2 <= ix or iy2 <= iy then
      table.insert(out, rect)
    else
      if iy > rect.y then
        table.insert(out, { x = rect.x, y = rect.y, w = rect.w, h = iy - rect.y })
      end
      if iy2 < rect.y + rect.h then
        table.insert(out, { x = rect.x, y = iy2, w = rect.w, h = rect.y + rect.h - iy2 })
      end
      if ix > rect.x then
        table.insert(out, { x = rect.x, y = iy, w = ix - rect.x, h = iy2 - iy })
      end
      if ix2 < rect.x + rect.w then
        table.insert(out, { x = ix2, y = iy, w = rect.x + rect.w - ix2, h = iy2 - iy })
      end
    end
  end
  local cleaned = {}
  for _, rect in ipairs(out) do
    if rect.w >= MIN_W and rect.h >= MIN_H then
      table.insert(cleaned, rect)
    end
  end
  return cleaned
end

local function pack_into_free(ws, items, rects)
  if #items == 0 then
    return
  end
  if #rects == 0 then
    return
  end
  table.sort(rects, function(a, b)
    return (a.w * a.h) > (b.w * b.h)
  end)
  if #rects == 1 or #items == 1 then
    pack_fill(ws, items, rects[1])
    return
  end
  local total_a = 0
  for _, rect in ipairs(rects) do
    total_a = total_a + rect.w * rect.h
  end
  local total_w = sum_weight(items, 1, #items)
  local share = (rects[1].w * rects[1].h) / total_a
  local acc, last = 0, 0
  for i, item in ipairs(items) do
    acc = acc + item.weight
    last = i
    local leftover_items = #items - i
    if leftover_items >= 1 and acc >= share * total_w then
      break
    end
  end
  if last >= #items then
    last = math.max(1, #items - 1)
  end
  local first, rest = {}, {}
  for i, item in ipairs(items) do
    if i <= last then
      table.insert(first, item)
    else
      table.insert(rest, item)
    end
  end
  pack_fill(ws, first, rects[1])
  local remain = {}
  for i = 2, #rects do
    table.insert(remain, rects[i])
  end
  pack_into_free(ws, rest, remain)
end

local function lock_box(area, lock)
  local x = area.x + clamp(lock.rx, 0, 1) * area.w
  local y = area.y + clamp(lock.ry, 0, 1) * area.h
  local w = clamp(lock.rw, 0.08, 1) * area.w
  local h = clamp(lock.rh, 0.08, 1) * area.h
  if x + w > area.x + area.w then
    x = area.x + area.w - w
  end
  if y + h > area.y + area.h then
    y = area.y + area.h - h
  end
  x = math.max(area.x, x)
  y = math.max(area.y, y)
  w = math.max(MIN_W, math.min(w, area.x + area.w - x))
  h = math.max(MIN_H, math.min(h, area.y + area.h - y))
  return { x = x, y = y, w = w, h = h }
end

local function match_lock(ws, item, present, class_n)
  ws.locks = ws.locks or {}
  if ws.locks[item.id] then
    return ws.locks[item.id]
  end
  if (class_n[item.class] or 0) ~= 1 or item.class == "" then
    return
  end
  local orphan
  for id, lock in pairs(ws.locks) do
    if not present[id] and lock.class == item.class then
      if orphan then
        return
      end
      orphan = id
    end
  end
  if not orphan then
    return
  end
  ws.locks[item.id] = ws.locks[orphan]
  ws.locks[orphan] = nil
  return ws.locks[item.id]
end

local function fractions(area, rect)
  return {
    rx = (rect.x - area.x) / math.max(1, area.w),
    ry = (rect.y - area.y) / math.max(1, area.h),
    rw = rect.w / math.max(1, area.w),
    rh = rect.h / math.max(1, area.h),
  }
end

local function place_fit(ctx)
  local n = #ctx.targets
  if n == 0 then
    return
  end
  local ws = ws_state(ctx)
  local area = ctx.area
  if n == 1 then
    record_place(ws, { id = target_id(ctx.targets[1]), target = ctx.targets[1] }, area)
    return
  end

  ws.locks = ws.locks or load_locks(workspace_id(ctx))

  local items = {}
  for _, target in ipairs(ctx.targets) do
    local id = target_id(target)
    local weight, kind = item_weight(ws, target, id)
    table.insert(items, {
      id = id,
      target = target,
      weight = weight,
      kind = kind,
      class = window_class(target),
    })
  end
  table.sort(items, function(a, b)
    if a.weight ~= b.weight then
      return a.weight > b.weight
    end
    return a.id < b.id
  end)

  if ws.arranged then
    local ready = true
    for _, item in ipairs(items) do
      if not ws.last_box[item.id] then
        ready = false
        break
      end
    end
    if ready then
      for _, item in ipairs(items) do
        record_place(ws, item, remap_box(ws.last_box[item.id], ws.pack_area, area))
      end
      ws.pack_area = { x = area.x, y = area.y, w = area.w, h = area.h }
      return
    end
    ws.arranged = false
  end

  local present, class_n = {}, {}
  for _, item in ipairs(items) do
    present[item.id] = true
    class_n[item.class] = (class_n[item.class] or 0) + 1
  end

  local locked, free = {}, {}
  for _, item in ipairs(items) do
    local lock = match_lock(ws, item, present, class_n)
    if lock then
      table.insert(locked, { item = item, lock = lock })
    else
      table.insert(free, item)
    end
  end

  if #locked == 0 then
    pack_fill(ws, items, { x = area.x, y = area.y, w = area.w, h = area.h })
    ws.pack_area = { x = area.x, y = area.y, w = area.w, h = area.h }
    return
  end

  local holes = { { x = area.x, y = area.y, w = area.w, h = area.h } }
  for _, pair in ipairs(locked) do
    local rect = lock_box(area, pair.lock)
    record_place(ws, pair.item, rect)
    tag_lock(pair.item.target, true)
    holes = subtract_rect(holes, rect)
  end
  if #free > 0 then
    if #holes == 0 then
      pack_fill(ws, free, { x = area.x, y = area.y, w = area.w, h = area.h })
    else
      pack_into_free(ws, free, holes)
    end
  end
  ws.pack_area = { x = area.x, y = area.y, w = area.w, h = area.h }
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
        ws.last_box[item.id] = { x = x, y = y, w = col_w, h = height }
        y = y + height
      end
    end
    x = x + col_w
  end
end

local function pack_squares(ws, items, rect, horizontal)
  if #items == 0 or rect.w < 8 or rect.h < 8 then
    return
  end
  local n = #items
  local size
  if horizontal then
    size = math.min(rect.h, rect.w / n)
  else
    size = math.min(rect.w, rect.h / n)
  end
  size = math.max(1, size)
  if horizontal then
    local total = size * n
    local x = rect.x + math.max(0, (rect.w - total) / 2)
    local y = rect.y + math.max(0, (rect.h - size) / 2)
    for i, item in ipairs(items) do
      record_place(ws, item, { x = x + (i - 1) * size, y = y, w = size, h = size })
    end
  else
    local total = size * n
    local x = rect.x + math.max(0, (rect.w - size) / 2)
    local y = rect.y + math.max(0, (rect.h - total) / 2)
    for i, item in ipairs(items) do
      record_place(ws, item, { x = x, y = y + (i - 1) * size, w = size, h = size })
    end
  end
end

local function place_center(ctx)
  local n = #ctx.targets
  if n == 0 then
    return
  end
  local ws = ws_state(ctx)
  local area = ctx.area
  ws.locks = ws.locks or {}

  local hub_id = ws.hub_id
  local hub_target = nil
  local sats = {}
  for _, target in ipairs(ctx.targets) do
    local id = target_id(target)
    if hub_id and id == hub_id then
      hub_target = target
    else
      table.insert(sats, { id = id, target = target, class = window_class(target), weight = 1 })
    end
  end
  if not hub_target then
    hub_target = ctx.targets[1]
    for _, target in ipairs(ctx.targets) do
      local window = target.window
      if window and window.active then
        hub_target = target
        break
      end
    end
    hub_id = target_id(hub_target)
    ws.hub_id = hub_id
    sats = {}
    for _, target in ipairs(ctx.targets) do
      local id = target_id(target)
      if id ~= hub_id then
        table.insert(sats, { id = id, target = target, class = window_class(target), weight = 1 })
      end
    end
  end

  if n == 1 or #sats == 0 then
    record_place(ws, { id = hub_id, target = hub_target }, area)
    ws.pack_area = { x = area.x, y = area.y, w = area.w, h = area.h }
    return
  end

  local short = math.min(area.w, area.h)
  local hub_frac = clamp(0.56 - 0.025 * #sats, 0.38, 0.56)
  local cs = short * hub_frac
  local min_ring = math.min(MIN_W, area.w / 4)
  if area.w - cs < min_ring * 2 then
    cs = math.max(MIN_W, area.w - min_ring * 2)
  end
  if area.h - cs < math.min(MIN_H, area.h / 4) * 2 then
    cs = math.max(MIN_H, area.h - math.min(MIN_H, area.h / 4) * 2)
  end
  local cx = area.x + (area.w - cs) / 2
  local cy = area.y + (area.h - cs) / 2
  local hub_box = { x = cx, y = cy, w = cs, h = cs }
  record_place(ws, { id = hub_id, target = hub_target }, hub_box)
  local frac = fractions(area, hub_box)
  frac.class = window_class(hub_target)
  ws.locks[hub_id] = frac

  if ws.arranged then
    local ready = true
    for _, item in ipairs(sats) do
      if not ws.last_box[item.id] then
        ready = false
        break
      end
    end
    if ready then
      for _, item in ipairs(sats) do
        record_place(ws, item, remap_box(ws.last_box[item.id], ws.pack_area, area))
      end
      ws.pack_area = { x = area.x, y = area.y, w = area.w, h = area.h }
      return
    end
    ws.arranged = false
  end

  local top = { x = area.x, y = area.y, w = area.w, h = math.max(0, cy - area.y) }
  local bot = { x = area.x, y = cy + cs, w = area.w, h = math.max(0, area.y + area.h - (cy + cs)) }
  local left = { x = area.x, y = cy, w = math.max(0, cx - area.x), h = cs }
  local right = { x = cx + cs, y = cy, w = math.max(0, area.x + area.w - (cx + cs)), h = cs }
  local buckets = { top = {}, bottom = {}, left = {}, right = {} }
  local cycle = (area.w >= area.h) and { "right", "left", "top", "bottom" } or { "top", "bottom", "left", "right" }
  for i, item in ipairs(sats) do
    table.insert(buckets[cycle[((i - 1) % 4) + 1]], item)
  end
  pack_squares(ws, buckets.top, top, true)
  pack_squares(ws, buckets.bottom, bot, true)
  pack_squares(ws, buckets.left, left, false)
  pack_squares(ws, buckets.right, right, false)
  ws.pack_area = { x = area.x, y = area.y, w = area.w, h = area.h }
end

local function place_masonry(ctx)
  local ws = ws_state(ctx)
  if ws.mode == "columns" then
    place_columns(ctx)
  elseif ws.mode == "center" then
    place_center(ctx)
  else
    place_fit(ctx)
  end
end

local function focused_target(ctx)
  local active = hl.get_active_window()
  local active_id = active and active.stable_id and tostring(active.stable_id)
  if active_id then
    for _, target in ipairs(ctx.targets) do
      if target_id(target) == active_id then
        return target
      end
    end
  end
  for _, target in ipairs(ctx.targets) do
    local window = target.window
    if window and window.active then
      return target
    end
  end
  return ctx.targets[1]
end

local function focused_id(ctx)
  local target = focused_target(ctx)
  if target then
    return target_id(target)
  end
end

local function swap_windows(ctx, dir)
  local ws = ws_state(ctx)
  local id = focused_id(ctx)
  if not id or id == ws.hub_id then
    return true
  end
  local other = neighbor_id(ws, id, dir, ws.hub_id)
  if not other then
    return true
  end
  ws.last_box[id], ws.last_box[other] = ws.last_box[other], ws.last_box[id]
  local col_a, row_a = column_of(ws, id)
  local col_b, row_b = column_of(ws, other)
  if col_a and col_b then
    ws.columns[col_a][row_a], ws.columns[col_b][row_b] = other, id
  end
  local area = ctx.area
  ws.locks = ws.locks or {}
  if ws.locks[id] and ws.last_box[id] then
    local frac = fractions(area, ws.last_box[id])
    frac.class = ws.locks[id].class
    ws.locks[id] = frac
  end
  if ws.locks[other] and ws.last_box[other] then
    local frac = fractions(area, ws.last_box[other])
    frac.class = ws.locks[other].class
    ws.locks[other] = frac
  end
  save_locks(workspace_id(ctx), ws)
  ws.arranged = true
  ws.pack_area = { x = area.x, y = area.y, w = area.w, h = area.h }
  return true
end

local function resize_fit(ctx, axis, delta)
  local ws = ws_state(ctx)
  ws.arranged = false
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
    if rest == "fit" or rest == "columns" or rest == "center" then
      ws.mode = rest
      if rest ~= "center" then
        ws.hub_id = nil
      end
      return true
    end
    return "omansory: mode expects fit, columns, or center"
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

  if command == "hub" then
    local target = focused_target(ctx)
    if not target then
      return "omansory: no focused window for center mode"
    end
    ws.mode = "center"
    ws.arranged = false
    ws.hub_id = target_id(target)
    local last = ws.last_box[ws.hub_id]
    local area = ctx.area
    local rect = last
    if not rect or not rect.w then
      rect = { x = area.x, y = area.y, w = area.w, h = area.h }
    end
    if not rect.x then
      rect.x, rect.y = area.x, area.y
    end
    local frac = fractions(area, rect)
    frac.class = window_class(target)
    ws.locks = ws.locks or {}
    ws.locks[ws.hub_id] = frac
    tag_lock(target, true)
    save_locks(workspace_id(ctx), ws)
    return true
  end

  if command == "lock" then
    local target = focused_target(ctx)
    if not target then
      return "omansory: no focused window to lock"
    end
    local id = target_id(target)
    ws.locks = ws.locks or {}
    if ws.locks[id] then
      ws.locks[id] = nil
      tag_lock(target, false)
    else
      local last = ws.last_box[id]
      local area = ctx.area
      local rect = last
      if not rect or not rect.w then
        rect = { x = area.x, y = area.y, w = area.w, h = area.h }
      end
      if not rect.x then
        rect.x, rect.y = area.x, area.y
      end
      local frac = fractions(area, rect)
      frac.class = window_class(target)
      ws.locks[id] = frac
      tag_lock(target, true)
    end
    save_locks(workspace_id(ctx), ws)
    return true
  end

  if command == "reset" then
    local id = workspace_id(ctx)
    workspaces[id] = nil
    return true
  end

  if command == "swap" then
    local dir = rest:match("^(%S+)") or ""
    if not ({ l = true, r = true, u = true, d = true, left = true, right = true, up = true, down = true })[dir] then
      return "omansory: swap expects left, right, up, or down"
    end
    return swap_windows(ctx, dir)
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

  return "omansory: expected mode, cols, lock, swap, reset, or resize h|v <px>"
end

hl.window_rule({
  name = "omansory-lock",
  match = { tag = LOCK_TAG },
  border_color = "rgb(FF71CE) rgb(A21CAF)",
  border_size = 3,
})

hl.layout.register(LAYOUT_NAME, {
  recalculate = place_masonry,
  layout_msg = handle_msg,
})
