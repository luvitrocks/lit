local Object = require('core').Object
local Sophia = require('sophia.so')
local digest = require('openssl').digest.digest
local log = require('lit-log')
local hexToBin = require('hex-to-bin')
local binToHex = require('bin-to-hex')

local Storage = Object:extend()

function Storage:initialize(dir)
  local env = Sophia.env()
  self.env = env
  env:ctl("dir", dir)
  self.db = assert(env:open())
  self.dir = dir
end

-- Save a binary blob to disk, returns the sha1 hash of the value
-- value is a string.
function Storage:save(value)
  local hash = digest("sha1", value)
  local key = hexToBin(hash)
  if self.db:get(key) then
    return hash
  end
  log("save", hash)
  local success, err = self.db:set(key, value)
  if success then
    return hash
  end
  return nil, err
end

function Storage:load(hash)
  local key = hexToBin(hash)
  local value, err = self.db:get(key)
  if err then return nil, err end
  if not value then return end
  if hash ~= digest("sha1", value) then
    return nil, "value doesn't match hash: " .. hash
  end
  return value
end

function Storage:read(key)
  return binToHex(self.db:get(key))
end

function Storage:write(key, hash)
  local value = hexToBin(hash)
  if self.db:get(key) == value then return end
  log("write", key)
  return self.db:set(key, value)
end

function Storage:begin()
  log("transaction", "begin")
  return self.db:begin()
end

function Storage:commit()
  log("transaction", "commit", "success")
  return self.db:commit()
end

function Storage:rollback()
  log("transaction", "rollback", "failure")
  return self.db:rollback()
end

return function (dir)
  return Storage:new(dir)
end
