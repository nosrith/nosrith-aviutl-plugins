module(..., package.seeall)

-- Utilities

function getsegpt(t, i)
  return t[i * 2 - 1], t[i * 2], t[i * 2 + 1], t[i * 2 + 2]
end

function getd(x1, y1, x2, y2)
  local dx = x2 - x1
  local dy = y2 - y1
  local d = math.sqrt(dx * dx + dy * dy)
  return d, dx, dy
end

function getuxy(x1, y1, x2, y2, f)
  f = f or 1
  local d, dx, dy = getd(x1, y1, x2, y2)
  return -dy / d * f, dx / d * f
end

function getlen(anchors)
  local numanc = #anchors / 2
  local sumslen = 0
  for i = 1, numanc - 1 do
    sumslen = sumslen + getd(getsegpt(anchors, i))
  end
  return sumslen
end  

-- Path

function polypath(anchors)
  local newancs = {}
  for _, v in ipairs(anchors) do
    newancs[#newancs + 1] = v
  end
  return Path:new(newancs)
end

function subpathf(path, beginf, endf)
  return subpath(path, path.len * beginf, path.len * endf)
end

function subpath(path, beginpos, endpos)
  local newancs = {}
  local pos = 0
  local contains = false
  local sx1, sy1, sx2, sy2, slen, sdx, sdy
  for i = 1, path.numanc - 1 do
    sx1, sy1, sx2, sy2 = path:getsegpt(i)
    slen, sdx, sdy = getd(sx1, sy1, sx2, sy2)
    if not contains then
      if pos + slen > beginpos then
        local plen = beginpos - pos
        newancs[#newancs + 1] = sx1 + plen * sdx / slen
        newancs[#newancs + 1] = sy1 + plen * sdy / slen
        contains = true
      end
    end
    if contains then
      if pos + slen >= endpos or i == path.numanc - 1 then
        break
      else
        newancs[#newancs + 1] = sx2
        newancs[#newancs + 1] = sy2
      end
    end
    pos = pos + slen
  end
  if not contains then
    local plen = beginpos - pos
    newancs[#newancs + 1] = sx1 + plen * sdx / slen
    newancs[#newancs + 1] = sy1 + plen * sdy / slen
  end
  local plen = endpos - pos
  newancs[#newancs + 1] = sx1 + plen * sdx / slen
  newancs[#newancs + 1] = sy1 + plen * sdy / slen
  return Path:new(newancs)
end  

function segpath(path, i)
  return Path:new({path:getsegpt(i)})
end

-- Bezier path

function blend(t, n, i)
  local s = 1
  if i > 0 or i < n then
    for j = 1, math.min(i, n - i) do
      s = s * (n - j + 1) / j
    end
  end
  return s * math.pow(t, i) * math.pow(1 - t, n - i)
end

function bezierpt(t, anchors)
  local n = #anchors / 2
  local sx = 0
  local sy = 0
  for i = 1, n do
    local b = blend(t, n - 1, i - 1)
    sx = sx + anchors[i * 2 - 1] * b
    sy = sy + anchors[i * 2] * b
  end
  return sx, sy
end

function bezierpath(anchors)
  local numnewseg = math.floor(getlen(anchors))  
  local newancs = {}
  for i = 0, numnewseg do
    local t = i / numnewseg
    local x, y = bezierpt(t, anchors)
    newancs[#newancs + 1] = x
    newancs[#newancs + 1] = y
  end
  return Path:new(newancs)
end

-- Average path

function mvavpath(anchors, bandwidth)
  if bandwidth == 0 then return polypath(anchors) end
  local numanc = #anchors / 2
  local len = getlen(anchors)
  local newancs = {}
  for i = 0, math.ceil(len) do
    local gpos = math.min(i, len)
    local beginpos = gpos - bandwidth / 2
    local endpos = gpos + bandwidth / 2
    local sumx, sumy = 0, 0
    local pos = 0
    for i = 1, numanc - 1 do
      local sx1, sy1, sx2, sy2 = getsegpt(anchors, i)
      local slen, sdx, sdy = getd(sx1, sy1, sx2, sy2)
      if slen > 0 then
        local bspos = math.min(beginpos - pos, slen)
        local espos = math.max(endpos - pos, 0)
        if i > 1 then bspos = math.max(bspos, 0) end
        if i < numanc - 1 then espos = math.min(espos, slen) end
        local x1 = sx1 + bspos * sdx / slen
        local y1 = sy1 + bspos * sdy / slen
        local x2 = sx1 + espos * sdx / slen
        local y2 = sy1 + espos * sdy / slen
        sumx = sumx + ((x1 + x2) / 2) * (espos - bspos)
        sumy = sumy + ((y1 + y2) / 2) * (espos - bspos)
        pos = pos + slen
      end
    end
    newancs[#newancs + 1] = sumx / bandwidth
    newancs[#newancs + 1] = sumy / bandwidth
  end
  return Path:new(newancs)
end

-- Get point xy by fraction

Path = {}
Path_mt = {__index = Path}

function Path:new(anchors)
  local o = {
    ancs = anchors, 
    numanc = #anchors / 2, 
    len = getlen(anchors),
    dx = anchors[#anchors - 1] - anchors[1],
    dy = anchors[#anchors] - anchors[2]
  }
  return setmetatable(o, Path_mt)
end

function Path:getsegpt(i)
  return getsegpt(self.ancs, i)
end

function Path:getpt(frac)
  local tarpos = self.len * frac
  local pos = 0, sx1, sy1, sx2, sy2, slen, sdx, sdy
  for i = 1, self.numanc - 1 do
    sx1, sy1, sx2, sy2 = self:getsegpt(i)
    slen0, sdx0, sdy0 = slen, sdx, sdy
    slen, sdx, sdy = getd(sx1, sy1, sx2, sy2)
    if slen == 0 then slen, sdx, sdy = slen0, sdx0, sdy0 end
    if pos + slen >= tarpos then break end
    pos = pos + slen
  end
  local plen = tarpos - pos
  local sfx, sfy = sdx / slen, sdy / slen
  return sx1 + plen * sfx, sy1 + plen * sfy, sfx, sfy
end

function Path:draw(obj, conf)
  local width = conf.width or 1
  local patlen = conf.patlen or 0
  local filllen = conf.filllen or ((conf.filllenf or 0) * patlen)
  local ppos = conf.ppos or (conf.pposf or 0) * patlen

  local gpos = 0
  for i = 1, self.numanc - 1 do
    if gpos >= self.len then break end

    local sx1, sy1, sx2, sy2 = self:getsegpt(i)
    local slen, sdx, sdy = getd(sx1, sy1, sx2, sy2)
    local ux, uy = getuxy(sx1, sy1, sx2, sy2, width / 2)
    local sfx, sfy = sdx / slen, sdy / slen

    if i > 1 and (patlen == 0 or ppos < filllen) then
      -- draw corner
      local sx0 = self.ancs[(i - 1) * 2 - 1]
      local sy0 = self.ancs[(i - 1) * 2]
      local ux0, uy0 = getuxy(sx0, sy0, sx1, sy1, width / 2)
      obj.drawpoly(
        sx1, sy1, 0,
        sx1 + ux0, sy1 + uy0, 0,
        sx1 + ux, sy1 + uy, 0,
        sx1, sy1, 0)
      obj.drawpoly(
        sx1, sy1, 0,
        sx1 - ux, sy1 - uy, 0,
        sx1 - ux0, sy1 - uy0, 0,
        sx1, sy1, 0)
    end

    if patlen == 0 then
      -- draw straight line
      local d = slen
      if gpos + d >= self.len then
        d = self.len - gpos
        sx2 = sx1 + d * sfx
        sy2 = sy1 + d * sfy
      end
      local adj = 1
      local x1 = sx1 - adj * sfx
      local y1 = sy1 - adj * sfy
      local x2 = sx2 + adj * sfx
      local y2 = sy2 + adj * sfy
      obj.drawpoly(
        x1 + ux, y1 + uy, 0,
        x2 + ux, y2 + uy, 0,
        x2 - ux, y2 - uy, 0,
        x1 - ux, y1 - uy, 0)
      gpos = gpos + d
    else
      -- draw patterned line iteratively
      local spos = 0
      while spos < slen and gpos < self.len do
        if ppos < filllen then
          local d = filllen - ppos
          if spos + d >= slen then d = slen - spos end
          if gpos + d >= self.len then d = self.len - gpos end
          local adj = 1
          local x1 = sx1 + (spos - adj) * sfx
          local y1 = sy1 + (spos - adj) * sfy
          local x2 = sx1 + (spos + adj + d) * sfx
          local y2 = sy1 + (spos + adj + d) * sfy
          obj.drawpoly(
            x1 + ux, y1 + uy, 0,
            x2 + ux, y2 + uy, 0,
            x2 - ux, y2 - uy, 0,
            x1 - ux, y1 - uy, 0)
        end

        local d = conf.patlen - ppos
        if spos + d >= slen then
          d = slen - spos
          ppos = ppos + d
          spos = slen
          gpos = gpos + d
        elseif gpos + d >= self.len then
          d = self.len - gpos
          ppos = ppos + d
          spos = spos + d
          gpos = self.len
        else
          ppos = 0
          spos = spos + d
          gpos = gpos + d
        end
      end
    end
  end
  return self
end

function Path:dump(obj, label, conf)
  conf = conf or {}
  local color = conf.color or 0xffffff
  local width = conf.width or 2

  obj.load("figure", "ŽlŠpŒ`", color, 2)
  obj.ox, obj.oy = -obj.getvalue("x"), -obj.getvalue("y")
  self:draw(obj, {width = width})

  local x, y, dx, dy = self:getpt(1)
  local angle = math.deg(math.atan2(dx, -dy))
  obj.load("figure", "ŽOŠpŒ`", color, width * 7)
  obj.ox = x - obj.getvalue("x")
  obj.oy = y - obj.getvalue("y")
  obj.rz = angle
  obj.draw()

  obj.setfont("MS UI Gothic", 18, 2)
  obj.load("text", label)
  x, y, dx, dy = self:getpt(0)
  angle = math.deg(math.atan2(dy, dx))
  if angle >= -90 and angle < 90 then
    obj.ox = x - obj.getvalue("x") + dy * 12
    obj.oy = y - obj.getvalue("y") - dx * 12
    obj.rz = angle
  else
    obj.ox = x - obj.getvalue("x") - dy * 12
    obj.oy = y - obj.getvalue("y") + dx * 12
    obj.rz = angle - 180
  end
  obj.draw()
end


-- Register

local regtb = {}

function register(name, path)
  regtb[name] = path
end

function getregpath(name)
  return regtb[name]
end
