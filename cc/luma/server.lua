local VERSION = "0.1.0"
local START_MARK = "-- Luma server startup: begin"
local END_MARK = "-- Luma server startup: end"

local args = { ... }

local PAGES = {
  ["luma://home"] = {
    title = "Luma Home",
    body = "Welcome to the Luma network.",
  },
  ["luma://packages"] = {
    title = "Packages",
    body = "Package discovery is powered by RIG and Dock Store.",
  },
}

local STARTUP_BLOCK = START_MARK .. "\n" .. [[
if fs.exists("/startup/luma-server.lua") then
  if shell then
    shell.run("/startup/luma-server.lua")
  else
    dofile("/startup/luma-server.lua")
  end
end
]] .. END_MARK .. "\n"

local function read_file(path)
  if not fs.exists(path) then
    return nil
  end
  local handle = fs.open(path, "r")
  if not handle then
    return nil
  end
  local data = handle.readAll()
  handle.close()
  return data
end

local function write_file(path, data)
  local dir = fs.getDir(path)
  if dir and dir ~= "" and not fs.exists(dir) then
    fs.makeDir(dir)
  end
  local handle = fs.open(path, "w")
  if not handle then
    return nil, "cannot open " .. path
  end
  handle.write(data or "")
  handle.close()
  return true
end

local function replace_block(existing)
  existing = existing or ""
  local start_pos = existing:find(START_MARK, 1, true)
  if start_pos then
    local _, end_finish = existing:find(END_MARK, start_pos, true)
    if end_finish then
      return existing:sub(1, start_pos - 1) .. STARTUP_BLOCK .. existing:sub(end_finish + 1)
    end
  end
  if existing ~= "" and existing:sub(-1) ~= "\n" then
    existing = existing .. "\n"
  end
  return existing .. "\n" .. STARTUP_BLOCK
end

local function install_startup()
  if not fs.exists("/startup") then
    fs.makeDir("/startup")
  end
  if fs.exists("/startup.lua") and not fs.exists("/startup.lua.luma-server.bak") then
    fs.copy("/startup.lua", "/startup.lua.luma-server.bak")
  end
  local ok, err = write_file("/startup.lua", replace_block(read_file("/startup.lua") or ""))
  if ok then
    print("OK Luma server startup installed")
  else
    print("ERR " .. tostring(err))
  end
end

local function is_modem(name)
  if peripheral and peripheral.hasType then
    local ok, result = pcall(peripheral.hasType, name, "modem")
    if ok and result then
      return true
    end
  end
  return peripheral and peripheral.getType(name) == "modem"
end

local function open_modems()
  local opened = {}
  if not rednet or not peripheral then
    return opened
  end
  for _, name in ipairs(peripheral.getNames()) do
    if is_modem(name) then
      pcall(rednet.open, name)
      if rednet.isOpen(name) then
        table.insert(opened, name)
      end
    end
  end
  return opened
end

local function serve()
  local opened = open_modems()
  print("Luma Server " .. VERSION)
  if #opened == 0 then
    print("No rednet modem is open.")
  else
    print("Rednet: " .. table.concat(opened, ", "))
  end

  if rednet and rednet.host then
    pcall(rednet.host, "luma.web", "luma-web")
  end

  print("Protocol: luma.web")
  print("Press Ctrl+T to stop.")

  while true do
    if not rednet then
      sleep(2)
    else
      local sender, message, protocol = rednet.receive(nil, 5)
      if sender and protocol == "luma.web" then
        local address = type(message) == "table" and message.address or "luma://home"
        local page = PAGES[address]
        rednet.send(sender, {
          ok = page ~= nil,
          address = address,
          page = page,
        }, "luma.web.reply")
      end
    end
  end
end

if args[1] == "startup" and args[2] == "install" then
  install_startup()
else
  serve()
end
