require "/scripts/rect.lua"
require "/scripts/util.lua"

rl_fieldcontrol = {}

------------------------------------------------------------------------
-- Definitions
------------------------------------------------------------------------

rl_fieldcontrol.fccUidTemplate = "rl_fieldcontrolconsole_%d"
rl_fieldcontrol.fieldTunerPropertyName = "rl_fieldtuner"
rl_fieldcontrol.playershipconsoleUid = "rl_playershipconsole"
rl_fieldcontrol.playerstationconsoleUid = "playerstationconsole"
rl_fieldcontrol.shieldswitchUid = "rl_shieldswitch"
rl_fieldcontrol.stagehandUid = "rl_fieldmanager"

rl_fieldcontrol.fccDungeonIdRange = {0, 65519}
rl_fieldcontrol.universeDungeonIdRange = {0, 65535}

rl_fieldcontrol.forbiddenDungeonIds = {65524, 65525}
rl_fieldcontrol.hullDungeonIds = {
  playerstation=0
}
rl_fieldcontrol.specialDungeonIds = {
  clientshipworld={65531, 65532, 65535},
  playerstation={65531, 65532}
}

rl_fieldcontrol.fccHazardProtectionStatus = {
  unavailable=1,
  unnecessary=2,
  available=3
}

-- Normal visibility is `nil`.
rl_fieldcontrol.fccVisibility = {
  "bulkhead",
  "hidden"
}
rl_fieldcontrol.fccVisibilityValue = {
  bulkhead=1,
  hidden=2
}

------------------------------------------------------------------------
-- Generic Asynchronous and Transactional Logic
------------------------------------------------------------------------

function rl_fieldcontrol.awaitOnMessage(msg, success, fail)
  if msg:finished() then
    if msg:succeeded() then
      if success then success(msg:result()) end
    else
      if fail then fail(msg:error()) end
    end
    return nil
  end
  return msg
end

function rl_fieldcontrol.beginTransaction(id, msg)
  if msg then
    self.transactions.types[id].msg = msg
    self.transactions.onTransactions()
  end
end

function rl_fieldcontrol.initTransactions(onTransactions, onNoTransactions)
  self.transactions = {
    types={}, onTransactions=onTransactions, onNoTransactions=onNoTransactions
  }
end

function rl_fieldcontrol.processTransactions()
  local preCount = 0
  local postCount = 0
  for _,v in pairs(self.transactions.types) do
    if v.msg then
      preCount = preCount + 1
      v.msg = rl_fieldcontrol.awaitOnMessage(v.msg, v.onSuccess, v.onFailure)
      if v.msg then postCount = postCount + 1 end
    end
  end
  if preCount > 0 and postCount == 0 then
    self.transactions.onNoTransactions()
  end
end

function rl_fieldcontrol.registerTransaction(id, onSuccess, onFailure)
  self.transactions.types[id] = {
    msg=nil, onSuccess=onSuccess, onFailure=onFailure
  }
end

------------------------------------------------------------------------
-- Item (client-side) utils
------------------------------------------------------------------------

function rl_fieldcontrol.dungeonIdValidator(idRange)
  return function(dungeonId)
      return type(dungeonId) == "number" and
        dungeonId >= idRange[1] and dungeonId <= idRange[2] and
        not contains(rl_fieldcontrol.forbiddenDungeonIds, dungeonId)
    end
end

function rl_fieldcontrol.fccUid(dungeonId)
  return string.format(rl_fieldcontrol.fccUidTemplate, dungeonId)
end

function rl_fieldcontrol.isFccShielded(dungeonId, notFinished)
  local obj = world.findUniqueEntity(rl_fieldcontrol.fccUid(dungeonId))
  while not obj:finished() do notFinished() end
  return obj:succeeded() and obj:result() ~= nil
end

function rl_fieldcontrol.isShipShielded(dungeonId)
  return type(world.getProperty("ship.fuel")) == "number" and
    contains(rl_fieldcontrol.specialDungeonIds.clientshipworld, dungeonId)
end

function rl_fieldcontrol.isStationShielded(dungeonId)
  return world.type() == "playerstation" and
    contains(rl_fieldcontrol.specialDungeonIds.playerstation, dungeonId)
end

function rl_fieldcontrol.rectToSpaces(r)
  local ll = rect.ll(r)
  local size = rect.size(r)
  local out = {}
  for i = 0, size[1] - 1 do
    local x = world.xwrap(ll[1] + i)
    for j = 0, size[2] - 1 do
      table.insert(out, {x, ll[2] + j})
    end
  end
  return out
end

--function rl_fieldcontrol.tileDungeonIdsToString(tiles)
--  local out = {}
--  for _,v in ipairs(tiles or {}) do
--    table.insert(out, {pos = v[1], dungeonId = v[2]})
--  end
--  return sb.printJson(out)
--end

function rl_fieldcontrol.updateVisibilityModeButtons(buttons)
  local active = buttons[self.visibilityMode]
  if active == nil then self.visibilityMode = nil end
  for _,v in ipairs(buttons) do widget.setChecked(v, active == v) end
end

------------------------------------------------------------------------
-- Object (server-side) utils
------------------------------------------------------------------------

function rl_fieldcontrol.currentOrRandomDungeonId(pos, dungeonIdValidator)
  local dungeonId = world.dungeonId(pos)
  while not dungeonIdValidator(dungeonId) do
    dungeonId = math.random(
      rl_fieldcontrol.fccDungeonIdRange[1],
      rl_fieldcontrol.fccDungeonIdRange[2])
  end
  return dungeonId
end

function rl_fieldcontrol.getUnderlyingDungeonIds(spaces)
  return util.map(spaces, function(v) return {v, world.dungeonId(v)} end)
end

function rl_fieldcontrol.setUnderlyingDungeonId(tiles, dungeonId)
  for _,v in ipairs(tiles) do
    local pos = v[1]
    local targetId = dungeonId or v[2]
    world.setDungeonId({pos[1], pos[2], pos[1] + 1, pos[2] + 1}, targetId)
  end
end
