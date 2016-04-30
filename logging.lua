module(..., package.seeall)

local f = nil

function start(fname)
  f = io.open(fname, "w")
  f:write("Logging started\n")
end

function stop()
  f:close()
end

function log(...)
  if not f then return end
  local t = {...}
  for i, v in ipairs(t) do
    if i > 1 then f:write(", ") end
    f:write(tostring(v))
  end
  f:write("\n")
  f:flush()
end
