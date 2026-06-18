local VERSION = "0.1.0"
local args = { ... }

local PAGES = {
  ["luma://home"] = {
    title = "Luma Home",
    body = {
      "Welcome to Luma Browser.",
      "",
      "Commands:",
      "  luma open luma://home",
      "  luma open luma://packages",
      "  luma search <query>",
      "  luma open <http-url>",
    },
  },
  ["luma://packages"] = {
    title = "Packages",
    body = {
      "RIG package discovery will live here.",
      "DockOS app store packages are available through:",
      "  dock store",
    },
  },
}

local function print_page(page)
  print("Luma " .. VERSION)
  print("== " .. page.title .. " ==")
  for _, line in ipairs(page.body) do
    print(line)
  end
end

local function open_http(url)
  if not http then
    print("ERR HTTP API is disabled")
    return
  end
  local handle, err = http.get(url)
  if not handle then
    print("ERR " .. tostring(err or "request failed"))
    return
  end
  local body = handle.readAll()
  local code = 200
  if handle.getResponseCode then
    code = handle.getResponseCode()
  end
  handle.close()
  print("Luma HTTP " .. tostring(code))
  print((body or ""):sub(1, 1600))
end

local function open(address)
  address = address or "luma://home"
  if PAGES[address] then
    print_page(PAGES[address])
    return
  end
  if address:sub(1, 7) == "http://" or address:sub(1, 8) == "https://" then
    open_http(address)
    return
  end
  print("ERR Unknown Luma address: " .. tostring(address))
end

local function search(query)
  query = table.concat(args, " ", 2)
  if query == "" then
    print("ERR Search query is required")
    return
  end
  print("Luma Search")
  print("Query: " .. query)
  print("")
  print("luma://home")
  print("luma://packages")
end

local command = args[1] or "open"

if command == "open" then
  open(args[2] or "luma://home")
elseif command == "search" then
  search()
elseif command == "version" then
  print(VERSION)
else
  open(command)
end

