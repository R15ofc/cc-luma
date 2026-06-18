local VERSION = "0.2.0"
local LUMA_WEB_PROTOCOL = "luma.web"
local LUMA_WEB_REPLY_PROTOCOL = "luma.web.reply"
local CONFIG_PATH = "/luma/config.lua"

local args = { ... }

local current_address = "luma://home"
local page_lines = {}
local scroll = 0

local PAGES = {
  ["luma://home"] = {
    title = "Luma Home",
    body = {
      "Welcome to Luma.",
      "",
      "Luma is the browser layer for DockOS.",
      "Open Luma pages, search the local directory,",
      "or open HTTP/HTTPS URLs when the HTTP API allows it.",
      "",
      "Try:",
      "  luma://packages",
      "  https://example.com",
    },
  },
  ["luma://packages"] = {
    title = "Packages",
    body = {
      "RIG package discovery will be connected here.",
      "",
      "DockOS apps can be installed through Dock Store.",
      "Verified packages install normally.",
      "Unreviewed packages should show warnings.",
    },
  },
}

local function read_config()
  if not fs.exists(CONFIG_PATH) then
    return {}
  end
  local ok, result = pcall(dofile, CONFIG_PATH)
  if ok and type(result) == "table" then
    return result
  end
  return {}
end

local function ensure_parent(path)
  local dir = fs.getDir(path)
  if dir and dir ~= "" and not fs.exists(dir) then
    fs.makeDir(dir)
  end
end

local function write_file(path, data)
  ensure_parent(path)
  local handle = fs.open(path, "w")
  if not handle then
    return nil, "cannot open " .. path
  end
  handle.write(data or "")
  handle.close()
  return true
end

local function write_config(config)
  if not textutils or not textutils.serialize then
    return nil, "textutils.serialize is unavailable"
  end
  return write_file(CONFIG_PATH, "return " .. textutils.serialize(config or {}) .. "\n")
end

local function url_encode(value)
  return tostring(value or ""):gsub("[^%w%-_%.~]", function(character)
    return string.format("%%%02X", string.byte(character))
  end)
end

local function decode_json(body)
  if textutils and textutils.unserializeJSON then
    return textutils.unserializeJSON(body)
  end
  return nil
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

local function open_rednet()
  if not rednet or not peripheral then
    return false
  end
  local opened = false
  for _, name in ipairs(peripheral.getNames()) do
    if is_modem(name) then
      pcall(rednet.open, name)
      opened = opened or rednet.isOpen(name)
    end
  end
  return opened
end

local function request_luma_page(address)
  if not open_rednet() then
    return nil
  end
  rednet.broadcast({ address = address }, LUMA_WEB_PROTOCOL)
  local _, message = rednet.receive(LUMA_WEB_REPLY_PROTOCOL, 1.5)
  if type(message) == "table" and message.ok and type(message.page) == "table" then
    return message.page
  end
  return nil
end

local function can_color()
  return term and term.isColor and term.isColor()
end

local function set_fg(color)
  if can_color() then
    term.setTextColor(color)
  end
end

local function set_bg(color)
  if can_color() then
    term.setBackgroundColor(color)
  end
end

local function reset_colors()
  if can_color() then
    term.setTextColor(colors.white)
    term.setBackgroundColor(colors.black)
  end
end

local function size()
  local width, height = term.getSize()
  return width or 51, height or 19
end

local function fit(text, width)
  text = tostring(text or "")
  if #text <= width then
    return text
  end
  if width <= 1 then
    return text:sub(1, width)
  end
  return text:sub(1, width - 1) .. "."
end

local function clear()
  reset_colors()
  term.clear()
  term.setCursorPos(1, 1)
end

local function write_at(x, y, text, fg, bg)
  if fg then
    set_fg(fg)
  end
  if bg then
    set_bg(bg)
  end
  term.setCursorPos(x, y)
  term.write(text)
  reset_colors()
end

local function draw_chrome()
  local width, height = size()
  set_bg(colors.gray)
  set_fg(colors.white)
  term.setCursorPos(1, 1)
  term.clearLine()
  term.write(fit(" Luma  " .. current_address, width))
  term.setCursorPos(1, height)
  term.clearLine()
  term.write(fit("g: address  /: search  arrows: scroll  q: quit", width))
  reset_colors()
end

local function split_lines(text)
  local lines = {}
  text = tostring(text or "")
  for line in (text .. "\n"):gmatch("(.-)\n") do
    table.insert(lines, line)
  end
  return lines
end

local function normalize_body(body)
  if type(body) == "table" then
    return body
  end
  return split_lines(body or "")
end

local function set_page(title, lines)
  page_lines = { "# " .. title, "" }
  for _, line in ipairs(lines or {}) do
    table.insert(page_lines, line)
  end
  scroll = 0
end

local function gateway_url()
  local config = read_config()
  local url = config.gateway_url
  if type(url) == "string" and url ~= "" then
    return url:gsub("/+$", "")
  end
  return nil
end

local function gateway_get(path, query)
  local base_url = gateway_url()
  if not base_url then
    return nil, "gateway is not configured"
  end
  if not http then
    return nil, "HTTP API is disabled"
  end
  local request_url = base_url .. path .. "?" .. query
  local handle, err = http.get(request_url, { ["Accept"] = "application/json" })
  if not handle then
    return nil, err or "request failed"
  end
  local body = handle.readAll()
  handle.close()
  local result = decode_json(body)
  if type(result) ~= "table" then
    return nil, "gateway returned invalid JSON"
  end
  if not result.ok then
    return nil, result.error or "gateway request failed"
  end
  return result
end

local function gateway_fetch(address)
  return gateway_get("/fetch", "url=" .. url_encode(address))
end

local function gateway_search(query)
  return gateway_get("/search", "q=" .. url_encode(query))
end

local function render()
  clear()
  draw_chrome()
  local width, height = size()
  local viewport = height - 2
  for row = 1, viewport do
    local line = page_lines[row + scroll] or ""
    local y = row + 1
    if line:sub(1, 2) == "# " then
      write_at(1, y, fit(line:sub(3), width), colors.cyan)
    else
      write_at(1, y, fit(line, width), colors.lightGray)
    end
  end
end

local function open_http(address)
  if not http then
    set_page("HTTP disabled", { "The HTTP API is not enabled for this computer." })
    return
  end
  set_page("Loading", { address })
  render()
  local handle, err = http.get(address, { ["Accept"] = "text/plain" })
  if not handle then
    local result, gateway_err = gateway_fetch(address)
    if result then
      set_page(result.title or address, {
        "URL: " .. tostring(result.url or address),
        "Status: " .. tostring(result.status or "gateway"),
        "",
      })
      for _, line in ipairs(split_lines(result.text or "")) do
        table.insert(page_lines, line)
      end
    else
      set_page("Request failed", {
        tostring(err or "request failed"),
        "",
        "Gateway: " .. tostring(gateway_err),
        "Set gateway: luma gateway set http://192.168.31.21:9000",
      })
    end
    return
  end
  local body = handle.readAll()
  local code = 200
  if handle.getResponseCode then
    code = handle.getResponseCode()
  end
  handle.close()
  set_page("HTTP " .. tostring(code), split_lines((body or ""):sub(1, 4000)))
end

local function open_luma(address)
  local page = PAGES[address]
  if page then
    set_page(page.title, page.body)
    return
  end
  page = request_luma_page(address)
  if page then
    set_page(page.title or address, normalize_body(page.body))
    return
  end
  set_page("Not found", {
    "No local page exists for:",
    address,
    "",
    "If this page should come from your server,",
    "start dock-server or luma-server on a CC PC with a modem.",
  })
end

local function open(address)
  current_address = address or "luma://home"
  if current_address:sub(1, 7) == "http://" or current_address:sub(1, 8) == "https://" then
    open_http(current_address)
  elseif current_address:sub(1, 7) == "luma://" then
    open_luma(current_address)
  else
    open_luma("luma://home")
  end
end

local function search(query)
  current_address = "luma://search?q=" .. tostring(query or "")
  local result = gateway_search(query)
  if result and type(result.results) == "table" then
    local lines = { "Query: " .. tostring(query or ""), "" }
    for _, item in ipairs(result.results) do
      table.insert(lines, tostring(item.title or item.url or "result"))
      table.insert(lines, "  " .. tostring(item.url or ""))
      if item.snippet then
        table.insert(lines, "  " .. tostring(item.snippet))
      end
      table.insert(lines, "")
    end
    set_page("Search", lines)
    return
  end
  set_page("Search", {
    "Query: " .. tostring(query or ""),
    "",
    "luma://home",
    "luma://packages",
    "https://example.com",
  })
end

local function configure_gateway(action, value)
  if action == "set" then
    if not value or value == "" then
      print("Usage: luma gateway set <url>")
      return
    end
    local config = read_config()
    config.gateway_url = value:gsub("/+$", "")
    local ok, err = write_config(config)
    if ok then
      print("OK Gateway set to " .. config.gateway_url)
    else
      print("ERR " .. tostring(err))
    end
  elseif action == "clear" then
    local config = read_config()
    config.gateway_url = nil
    local ok, err = write_config(config)
    if ok then
      print("OK Gateway cleared")
    else
      print("ERR " .. tostring(err))
    end
  else
    print("Gateway: " .. tostring(gateway_url() or "not set"))
    print("Set: luma gateway set http://192.168.31.21:9000")
  end
end

local function prompt(label, default)
  local width, height = size()
  set_bg(colors.black)
  set_fg(colors.white)
  term.setCursorPos(1, height)
  term.clearLine()
  term.write(fit(label .. " ", width))
  reset_colors()
  local input = read(nil, nil, nil, default or "")
  return input
end

local function loop()
  open(current_address)
  while true do
    render()
    local _, key = os.pullEvent("key")
    if key == keys.q then
      clear()
      return
    elseif key == keys.up and scroll > 0 then
      scroll = scroll - 1
    elseif key == keys.down and scroll < math.max(0, #page_lines - (select(2, size()) - 2)) then
      scroll = scroll + 1
    elseif key == keys.g then
      local address = prompt("Address:", current_address)
      if address and address ~= "" then
        open(address)
      end
    elseif key == keys.slash then
      local query = prompt("Search:", "")
      if query and query ~= "" then
        search(query)
      end
    elseif key == keys.r then
      open(current_address)
    end
  end
end

local command = args[1] or "ui"

if command == "open" then
  current_address = args[2] or "luma://home"
  loop()
elseif command == "search" then
  search(table.concat(args, " ", 2))
  render()
elseif command == "gateway" then
  configure_gateway(args[2], args[3])
elseif command == "version" then
  print(VERSION)
else
  current_address = command:find("://", 1, true) and command or "luma://home"
  loop()
end
