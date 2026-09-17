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

local function config_num(key, fallback)
  local ok, value = pcall(hl.get_config, key)
  if not ok then
    return fallback
  end
  if type(value) == "number" then
    return value
  end
  if type(value) == "table" then
    return tonumber(value.float or value[1] or value.x) or fallback
  end
  return tonumber(value) or fallback
end

local function config_vec2(key)
  local ok, value = pcall(hl.get_config, key)
  if not ok or type(value) ~= "table" then
    return nil, nil
  end
  local x = tonumber(value.x or value[1])
  local y = tonumber(value.y or value[2])
  return x, y
end

-- Same box Hyprland uses for one tiled window: square aspect if that
-- Omarchy toggle is on, otherwise scrolling's column_width at full height.
local function scrolling_single_box(area)
  local rw, rh = config_vec2("layout.single_window_aspect_ratio")
  if rw and rh and rw > 0 and rh > 0 then
    local scale = math.min(area.w / rw, area.h / rh)
    local hub_w = math.max(1, math.floor(rw * scale + 0.5))
    local hub_h = math.max(1, math.floor(rh * scale + 0.5))
    return {
      x = area.x + (area.w - hub_w) / 2,
      y = area.y + (area.h - hub_h) / 2,
      w = hub_w,
      h = hub_h,
    }
  end
  local col = clamp(config_num("scrolling.column_width", 0.49), 0.1, 1.0)
  local hub_w = math.max(1, math.floor(area.w * col + 0.5))
  return {
    x = area.x + (area.w - hub_w) / 2,
    y = area.y,
    w = hub_w,
    h = area.h,
  }
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

local function item_weight(ws, id)
  local bonus = (ws.bonus and ws.bonus[id]) or 0
  return math.max(0.5, 1 + bonus)
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
      locks[id] = {
        class = class,
        rx = rx,
        ry = ry,
        rw = rw,
        rh = rh,
        hub = line:find('"hub":true', 1, true) ~= nil,
      }
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
    local hub = lock.hub and ',"hub":true' or ""
    file:write(string.format(
      '{"id":"%s","class":"%s","rx":%.6f,"ry":%.6f,"rw":%.6f,"rh":%.6f%s}\n',
      id,
      class,
      lock.rx,
      lock.ry,
      lock.rw,
      lock.rh,
      hub
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

local function snap_rect(rect)
  local x = math.floor(rect.x)
  local y = math.floor(rect.y)
  local x2 = math.floor(rect.x + math.max(0, rect.w))
  local y2 = math.floor(rect.y + math.max(0, rect.h))
  return { x = x, y = y, w = math.max(0, x2 - x), h = math.max(0, y2 - y) }
end

local function record_place(ws, item, rect)
  rect = snap_rect(rect)
  if rect.w < 1 or rect.h < 1 then
    return
  end
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

local function interiors_overlap(a, b)
  if not a or not b then
    return false
  end
  return overlap_1d(a.x, a.x + a.w, b.x, b.x + b.w) > 0 and overlap_1d(a.y, a.y + a.h, b.y, b.y + b.h) > 0
end

local function clip_away(a, b)
  local ox = overlap_1d(a.x, a.x + a.w, b.x, b.x + b.w)
  local oy = overlap_1d(a.y, a.y + a.h, b.y, b.y + b.h)
  if ox <= 0 or oy <= 0 then
    return a
  end
  local function try(axis)
    if axis == "x" then
      if (a.x + a.w / 2) <= (b.x + b.w / 2) then
        local w = b.x - a.x
        if w < 1 then
          return nil
        end
        return { x = a.x, y = a.y, w = w, h = a.h }
      end
      local x = b.x + b.w
      local w = a.x + a.w - x
      if w < 1 then
        return nil
      end
      return { x = x, y = a.y, w = w, h = a.h }
    end
    if (a.y + a.h / 2) <= (b.y + b.h / 2) then
      local h = b.y - a.y
      if h < 1 then
        return nil
      end
      return { x = a.x, y = a.y, w = a.w, h = h }
    end
    local y = b.y + b.h
    local h = a.y + a.h - y
    if h < 1 then
      return nil
    end
    return { x = a.x, y = y, w = a.w, h = h }
  end
  if ox <= oy then
    return try("x") or try("y")
  end
  return try("y") or try("x")
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
  if #items == 0 then
    return
  end
  rect = snap_rect(rect)
  if rect.w < 1 or rect.h < 1 then
    return
  end
  if #items == 1 then
    record_place(ws, items[1], rect)
    return
  end

  local i = 1
  while i <= #items do
    local left = #items - i + 1
    if rect.w < 1 or rect.h < 1 then
      return
    end
    if left > 1 and (rect.w < math.max(8, MIN_W / 2) or rect.h < math.max(8, MIN_H / 2)) then
      if rect.w >= rect.h then
        local tw = rect.w / left
        local x = rect.x
        for j = i, #items do
          local w = (j == #items) and (rect.x + rect.w - x) or tw
          record_place(ws, items[j], { x = x, y = rect.y, w = w, h = rect.h })
          x = x + w
        end
      else
        local th = rect.h / left
        local y = rect.y
        for j = i, #items do
          local h = (j == #items) and (rect.y + rect.h - y) or th
          record_place(ws, items[j], { x = rect.x, y = y, w = rect.w, h = h })
          y = y + h
        end
      end
      return
    end

    local rem_weight = sum_weight(items, i, #items)
    local rem_area = rect.w * rect.h
    local vertical = rect.w >= rect.h
    if (not vertical) and (#items - i) >= 1 and rect.w >= MIN_W * 2 then
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
      local tw = clamp(rect.w * (row_w / rem_weight), 1, math.max(1, rect.w - (last < #items and 1 or 0)))
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
      rect = snap_rect({ x = rect.x + tw, y = rect.y, w = rect.w - tw, h = rect.h })
    else
      local th = clamp(rect.h * (row_w / rem_weight), 1, math.max(1, rect.h - (last < #items and 1 or 0)))
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
      rect = snap_rect({ x = rect.x, y = rect.y + th, w = rect.w, h = rect.h - th })
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
    if rect.w >= 1 and rect.h >= 1 then
      table.insert(cleaned, snap_rect(rect))
    end
  end
  return cleaned
end

local function region_area(rect)
  return math.max(0, rect.w) * math.max(0, rect.h)
end

local function assign_by_area(items, regions)
  local usable = {}
  for _, region in ipairs(regions) do
    local a = region_area(region.rect)
    if a >= 1 then
      region.area = a
      region.items = {}
      table.insert(usable, region)
    end
  end
  if #usable == 0 or #items == 0 then
    return
  end
  table.sort(usable, function(a, b)
    return a.area > b.area
  end)
  local idx = 1
  for _, region in ipairs(usable) do
    if items[idx] then
      table.insert(region.items, items[idx])
      idx = idx + 1
    end
  end
  while items[idx] do
    local best, best_score = usable[1], -1
    for _, region in ipairs(usable) do
      local score = region.area / math.max(1, #region.items)
      if score > best_score then
        best, best_score = region, score
      end
    end
    table.insert(best.items, items[idx])
    idx = idx + 1
  end
end

local pack_into_free

local function tiles_overlap(ws, items)
  for i = 1, #items do
    local a = ws.last_box[items[i].id]
    for j = i + 1, #items do
      local b = ws.last_box[items[j].id]
      if interiors_overlap(a, b) then
        return true
      end
    end
  end
  return false
end

local function resolve_overlaps(ws, items, area, keep)
  keep = keep or {}
  local function reclip()
    local changed = false
    for i = 1, #items do
      local a = ws.last_box[items[i].id]
      if a then
        for j = 1, #items do
          if i ~= j then
            local b = ws.last_box[items[j].id]
            if b and interiors_overlap(a, b) then
              local ida, idb = items[i].id, items[j].id
              local shrink = items[i]
              local stay = b
              if keep[ida] and not keep[idb] then
                shrink = items[j]
                stay = a
              elseif keep[idb] and not keep[ida] then
                shrink = items[i]
                stay = b
              elseif keep[ida] and keep[idb] then
                if (a.w * a.h) > (b.w * b.h) then
                  shrink = items[j]
                  stay = a
                else
                  shrink = items[i]
                  stay = b
                end
              elseif (a.w * a.h) > (b.w * b.h) then
                shrink = items[j]
                stay = a
              end
              local src = ws.last_box[shrink.id]
              local clipped = clip_away(src, stay)
              if clipped then
                record_place(ws, shrink, clipped)
                changed = true
                if shrink.id == items[i].id then
                  a = clipped
                end
              end
            end
          end
        end
      end
    end
    return changed
  end
  for _ = 1, 24 do
    if not reclip() then
      break
    end
  end
  if not tiles_overlap(ws, items) then
    return
  end
  local reserved, movable = {}, {}
  local holes = { { x = area.x, y = area.y, w = area.w, h = area.h } }
  for _, item in ipairs(items) do
    if keep[item.id] and ws.last_box[item.id] then
      table.insert(reserved, item)
      holes = subtract_rect(holes, ws.last_box[item.id])
    else
      table.insert(movable, item)
    end
  end
  if #movable > 0 then
    if #holes == 0 then
      pack_fill(ws, items, { x = area.x, y = area.y, w = area.w, h = area.h })
    else
      pack_into_free(ws, movable, holes)
    end
  end
end

pack_into_free = function(ws, items, rects)
  if #items == 0 or #rects == 0 then
    return
  end
  local regions = {}
  for _, rect in ipairs(rects) do
    table.insert(regions, { rect = snap_rect(rect) })
  end
  assign_by_area(items, regions)
  local placed = {}
  for _, region in ipairs(regions) do
    if region.items and #region.items > 0 then
      pack_fill(ws, region.items, region.rect)
      for _, item in ipairs(region.items) do
        placed[item.id] = true
      end
    end
  end
  local leftover = {}
  for _, item in ipairs(items) do
    if not placed[item.id] then
      table.insert(leftover, item)
    end
  end
  if #leftover > 0 then
    table.sort(rects, function(a, b)
      return (a.w * a.h) > (b.w * b.h)
    end)
    pack_fill(ws, leftover, rects[1])
  end
end

local function overlaps_any(rect, ws, items, skip)
  for _, item in ipairs(items) do
    if item.id ~= skip then
      local other = ws.last_box[item.id]
      if interiors_overlap(rect, other) then
        return true
      end
    end
  end
  return false
end

local function clamp_rect_area(r, area)
  local x = math.max(area.x, r.x)
  local y = math.max(area.y, r.y)
  local x2 = math.min(area.x + area.w, r.x + r.w)
  local y2 = math.min(area.y + area.h, r.y + r.h)
  return { x = x, y = y, w = math.max(0, x2 - x), h = math.max(0, y2 - y) }
end

-- Absorb leftover wallpaper rectangles into the neighbor with the longest shared edge.
local function fill_gaps(ws, items, area)
  if #items == 0 then
    return
  end
  for _ = 1, 16 do
    local holes = { { x = area.x, y = area.y, w = area.w, h = area.h } }
    for _, item in ipairs(items) do
      local boxr = ws.last_box[item.id]
      if boxr and boxr.w >= 1 and boxr.h >= 1 then
        holes = subtract_rect(holes, boxr)
      end
    end
    if #holes == 0 then
      return
    end
    table.sort(holes, function(a, b)
      return (a.w * a.h) > (b.w * b.h)
    end)
    local grew = false
    for _, hole in ipairs(holes) do
      local best, best_score, best_rect = nil, 0, nil
      for _, item in ipairs(items) do
        local t = ws.last_box[item.id]
        if t then
          local cand, score = nil, 0
          if math.abs((t.x + t.w) - hole.x) <= 1 then
            local ov = overlap_1d(t.y, t.y + t.h, hole.y, hole.y + hole.h)
            if ov > 0 then
              cand = { x = t.x, y = t.y, w = (hole.x + hole.w) - t.x, h = t.h }
              score = ov * hole.w
            end
          elseif math.abs(t.x - (hole.x + hole.w)) <= 1 then
            local ov = overlap_1d(t.y, t.y + t.h, hole.y, hole.y + hole.h)
            if ov > 0 then
              cand = { x = hole.x, y = t.y, w = t.x + t.w - hole.x, h = t.h }
              score = ov * hole.w
            end
          elseif math.abs((t.y + t.h) - hole.y) <= 1 then
            local ov = overlap_1d(t.x, t.x + t.w, hole.x, hole.x + hole.w)
            if ov > 0 then
              cand = { x = t.x, y = t.y, w = t.w, h = (hole.y + hole.h) - t.y }
              score = ov * hole.h
            end
          elseif math.abs(t.y - (hole.y + hole.h)) <= 1 then
            local ov = overlap_1d(t.x, t.x + t.w, hole.x, hole.x + hole.w)
            if ov > 0 then
              cand = { x = t.x, y = hole.y, w = t.w, h = t.y + t.h - hole.y }
              score = ov * hole.h
            end
          end
          if cand then
            cand = clamp_rect_area(cand, area)
            if cand.w >= 1 and cand.h >= 1 and score > best_score and not overlaps_any(cand, ws, items, item.id) then
              best, best_score, best_rect = item, score, cand
            end
          end
        end
      end
      if best then
        record_place(ws, best, best_rect)
        grew = true
        break
      end
    end
    if not grew then
      return
    end
  end
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
  local mine = ws.locks[item.id]
  if mine and not mine.hub then
    return mine
  end
  if (class_n[item.class] or 0) ~= 1 or item.class == "" then
    return
  end
  local orphan
  for id, lock in pairs(ws.locks) do
    if not present[id] and not lock.hub and lock.class == item.class then
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

local function area_changed(prev, area)
  if not prev or not area then
    return true
  end
  return math.abs((prev.x or 0) - area.x) > 1
    or math.abs((prev.y or 0) - area.y) > 1
    or math.abs((prev.w or 0) - area.w) > 2
    or math.abs((prev.h or 0) - area.h) > 2
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
    local weight = item_weight(ws, id)
    table.insert(items, {
      id = id,
      target = target,
      weight = weight,
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
    if area_changed(ws.pack_area, area) then
      ready = false
    end
    for _, item in ipairs(items) do
      if not ws.last_box[item.id] then
        ready = false
        break
      end
    end
    if ready and not tiles_overlap(ws, items) then
      for _, item in ipairs(items) do
        record_place(ws, item, remap_box(ws.last_box[item.id], ws.pack_area, area))
      end
      resolve_overlaps(ws, items, area)
      fill_gaps(ws, items, area)
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
    resolve_overlaps(ws, items, area)
    fill_gaps(ws, items, area)
    ws.pack_area = { x = area.x, y = area.y, w = area.w, h = area.h }
    return
  end

  local holes = { { x = area.x, y = area.y, w = area.w, h = area.h } }
  local keep = {}
  for _, pair in ipairs(locked) do
    local desired = lock_box(area, pair.lock)
    local rect = nil
    local best, best_a = nil, -1
    for _, hole in ipairs(holes) do
      local x = math.max(desired.x, hole.x)
      local y = math.max(desired.y, hole.y)
      local x2 = math.min(desired.x + desired.w, hole.x + hole.w)
      local y2 = math.min(desired.y + desired.h, hole.y + hole.h)
      local w, h = x2 - x, y2 - y
      if w >= 1 and h >= 1 and w * h > best_a then
        best_a = w * h
        best = { x = x, y = y, w = w, h = h }
      end
    end
    if best then
      rect = best
    elseif #holes > 0 then
      table.sort(holes, function(a, b)
        return (a.w * a.h) > (b.w * b.h)
      end)
      local host = holes[1]
      rect = {
        x = host.x,
        y = host.y,
        w = math.min(desired.w, host.w),
        h = math.min(desired.h, host.h),
      }
    else
      rect = desired
    end
    record_place(ws, pair.item, rect)
    keep[pair.item.id] = true
    tag_lock(pair.item.target, true)
    if ws.last_box[pair.item.id] then
      holes = subtract_rect(holes, ws.last_box[pair.item.id])
    end
  end
  if #free > 0 then
    if #holes == 0 then
      resolve_overlaps(ws, items, area, keep)
    else
      pack_into_free(ws, free, holes)
    end
  end
  resolve_overlaps(ws, items, area, keep)
  fill_gaps(ws, items, area)
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
  pack_fill(ws, items, rect)
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

  local hub_box = scrolling_single_box(area)
  local hub_w, hub_h = hub_box.w, hub_box.h
  local cx, cy = hub_box.x, hub_box.y

  if n == 1 or #sats == 0 then
    record_place(ws, { id = hub_id, target = hub_target }, hub_box)
    ws.pack_area = { x = area.x, y = area.y, w = area.w, h = area.h }
    return
  end
  record_place(ws, { id = hub_id, target = hub_target }, hub_box)
  local frac = fractions(area, hub_box)
  frac.class = window_class(hub_target)
  frac.hub = true
  ws.locks[hub_id] = frac

  local all = { { id = hub_id, target = hub_target } }
  for _, sat in ipairs(sats) do
    table.insert(all, sat)
  end

  if ws.arranged then
    local ready = true
    if area_changed(ws.pack_area, area) then
      ready = false
    end
    for _, item in ipairs(sats) do
      if not ws.last_box[item.id] then
        ready = false
        break
      end
    end
    if ready and not tiles_overlap(ws, all) then
      for _, item in ipairs(sats) do
        record_place(ws, item, remap_box(ws.last_box[item.id], ws.pack_area, area))
      end
      resolve_overlaps(ws, all, area, { [hub_id] = true })
      ws.pack_area = { x = area.x, y = area.y, w = area.w, h = area.h }
      return
    end
    ws.arranged = false
  end

  local regions = {
    { rect = { x = area.x, y = area.y, w = area.w, h = math.max(0, cy - area.y) } },
    { rect = { x = area.x, y = cy + hub_h, w = area.w, h = math.max(0, area.y + area.h - (cy + hub_h)) } },
    { rect = { x = area.x, y = cy, w = math.max(0, cx - area.x), h = hub_h } },
    { rect = { x = cx + hub_w, y = cy, w = math.max(0, area.x + area.w - (cx + hub_w)), h = hub_h } },
  }
  assign_by_area(sats, regions)
  for _, region in ipairs(regions) do
    if region.items and #region.items > 0 then
      pack_fill(ws, region.items, region.rect)
    end
  end
  resolve_overlaps(ws, all, area, { [hub_id] = true })
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
        ws.arranged = false
        ws.locks = ws.locks or {}
        for _, target in ipairs(ctx.targets) do
          local id = target_id(target)
          if ws.locks[id] and ws.locks[id].hub then
            ws.locks[id] = nil
            tag_lock(target, false)
          end
        end
        save_locks(workspace_id(ctx), ws)
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
    frac.hub = true
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
