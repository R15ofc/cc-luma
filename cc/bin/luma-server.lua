local args = { ... }
local unpacker = table.unpack or unpack

if shell then
  shell.run("/luma/server.lua", unpacker(args))
else
  dofile("/luma/server.lua")
end

