local DEFAULT_SOURCE_URL = "https://raw.githubusercontent.com/R15ofc/cc-luma/main/cc"
local TEMP_DIR = "/luma/.installer"

local FILES = {
  { source = "luma/luma.lua", target = "/luma/luma.lua" },
  { source = "bin/luma.lua", target = "/bin/luma.lua" },
}

local function parse_args(raw)
  local source_url = DEFAULT_SOURCE_URL
  local index = 1
  while index <= #raw do
    if raw[index] == "--source" then
      source_url = raw[index + 1] or source_url
      index = index + 2
    else
      index = index + 1
    end
  end
  return source_url
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

local function download(url)
  if not http then
    return nil, "HTTP API is disabled"
  end
  local handle, err = http.get(url, { ["Accept"] = "text/plain" })
  if not handle then
    return nil, err or "request failed"
  end
  local body = handle.readAll()
  local code = 200
  if handle.getResponseCode then
    code = handle.getResponseCode()
  end
  handle.close()
  if code < 200 or code >= 300 then
    return nil, "HTTP " .. tostring(code)
  end
  return body or ""
end

local function join_url(base_url, path)
  return tostring(base_url):gsub("/+$", "") .. "/" .. tostring(path):gsub("^/+", "")
end

local function temp_path(target)
  return TEMP_DIR .. "/" .. target:gsub("^/+", "")
end

local function append_shell_path(path)
  if not shell or not shell.path or not shell.setPath then
    return
  end
  local current = shell.path()
  for part in string.gmatch(current, "[^:]+") do
    if part == path then
      return
    end
  end
  shell.setPath(current .. ":" .. path)
end

local source_url = parse_args({ ... })

print("Luma Browser Installer")
print("Source: " .. source_url)

if fs.exists(TEMP_DIR) then
  fs.delete(TEMP_DIR)
end
fs.makeDir(TEMP_DIR)

for index, file in ipairs(FILES) do
  print("Luma [" .. tostring(index) .. "/" .. tostring(#FILES) .. "] " .. file.source)
  local body, err = download(join_url(source_url, file.source))
  if not body then
    fs.delete(TEMP_DIR)
    print("ERR Download failed: " .. tostring(err))
    return
  end
  local ok, write_err = write_file(temp_path(file.target), body)
  if not ok then
    fs.delete(TEMP_DIR)
    print("ERR " .. tostring(write_err))
    return
  end
end

for _, file in ipairs(FILES) do
  if fs.exists(file.target) then
    fs.delete(file.target)
  end
  ensure_parent(file.target)
  fs.move(temp_path(file.target), file.target)
end

fs.delete(TEMP_DIR)
append_shell_path("/bin")

if fs.exists("/dock") then
  write_file("/dock/apps/luma.lua", "return { id = \"luma\", name = \"Luma Browser\", command = \"luma\" }\n")
end

print("OK Luma Browser installed")
print("Run: luma")

