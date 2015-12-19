module(..., package.seeall)

function getseg(t, i)
  return t[i * 2 - 1], t[i * 2], t[i * 2 + 1], t[i * 2 + 2]
end

function getd(x1, y1, x2, y2)
  local dx = x2 - x1
  local dy = y2 - y1
  local d = math.sqrt(dx * dx + dy * dy)
  return d, dx, dy
end

function getuxy(x1, y1, x2, y2, width)
  local d, dx, dy = getd(x1, y1, x2, y2)
  local ux = -dy / d * width / 2
  local uy = dx / d * width / 2
  return ux, uy
end

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

function draw(obj, anchors, conf)
  local glenf = conf.glenf or 1
  local width = conf.width or 1
  local patlen = conf.patlen or 0
  local filllen = conf.filllen or ((conf.filllenf or 0) * patlen)
  local ppos = conf.ppos or (conf.pposf or 0) * patlen
  local bezier = conf.bezier and conf.bezier ~= 0

  if bezier then
    local sumslen = 0
    for i = 1, numanc - 1 do
      sumslen = sumslen + getd(getseg(anchors, i))
    end
    sumslen = math.floor(sumslen)
    local joints = {}
    for i = 0, sumslen do
      local t = i / sumslen
      local x, y = bezierpt(t, anchors)
      joints[#joints + 1] = x
      joints[#joints + 1] = y
    end  
    anchors = joints
  end

  local numanc = #anchors / 2
  local sumslen = 0
  for i = 1, numanc - 1 do
    sumslen = sumslen + getd(getseg(anchors, i))
  end
  local glen = sumslen * glenf

  local gpos = 0
  local sfx, sfy, finx, finy
  for i = 1, numanc - 1 do
    if gpos >= glen then break end

    local sx1, sy1, sx2, sy2 = getseg(anchors, i)
    local slen, sdx, sdy = getd(sx1, sy1, sx2, sy2)
    local ux, uy = getuxy(sx1, sy1, sx2, sy2, width)
    sfx, sfy = sdx / slen, sdy / slen

    if i > 1 and (patlen == 0 or ppos < filllen) then
      -- draw corner
      local sx0 = anchors[(i - 1) * 2 - 1]
      local sy0 = anchors[(i - 1) * 2]
      local ux0, uy0 = getuxy(sx0, sy0, sx1, sy1, width)
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
      if gpos + d >= glen then
        d = glen - gpos
        sx2 = sx1 + d * sfx
        sy2 = sy1 + d * sfy
      end
      local adj = bezier and 1 or 0
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
      finx, finy = sx2, sy2
    else
      -- draw patterned line iteratively
      local spos = 0
      while spos < slen and gpos < glen do
        if ppos < filllen then
          local d = filllen - ppos
          if spos + d >= slen then d = slen - spos end
          if gpos + d >= glen then d = glen - gpos end
          local adj = bezier and 1 or 0
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
        elseif gpos + d >= glen then
          d = glen - gpos
          ppos = ppos + d
          spos = spos + d
          gpos = glen
        else
          ppos = 0
          spos = spos + d
          gpos = gpos + d
        end
      end
      finx = sx1 + spos * sfx
      finy = sy1 + spos * sfy
    end
  end
  return {x=finx, y=finy, dx=sfx, dy=sfy}
end
