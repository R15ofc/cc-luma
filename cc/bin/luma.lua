local args = { ... }
local unpacker = table.unpack or unpack

if shell then
  shell.run("/luma/luma.lua", unpacker(args))
else
  dofile("/luma/luma.lua")
end

