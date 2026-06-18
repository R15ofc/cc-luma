if fs.exists("/luma/server.lua") then
  if shell then
    shell.run("/luma/server.lua")
  else
    dofile("/luma/server.lua")
  end
end

