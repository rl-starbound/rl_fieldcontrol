require "/scripts/rect.lua"

rl_fieldcontrol = {}

rl_fieldcontrol.fccPrefix = "rl_fieldcontrolconsole_"
rl_fieldcontrol.fieldTunerPropertyName = "rl_fieldtuner"
rl_fieldcontrol.stagehandUid = "rl_fieldmanager"

rl_fieldcontrol.fccDungeonIdRange = {0, 65519}
rl_fieldcontrol.universeDungeonIdRange = {0, 65535}

rl_fieldcontrol.forbiddenDungeonIds = {65524, 65525}
rl_fieldcontrol.shipDungeonIds = {65531, 65532, 65535}
rl_fieldcontrol.shipTechStationUid = "techstation"
rl_fieldcontrol.stationDungeonIds = {65531, 65532}
rl_fieldcontrol.stationWorldType = "playerstation"

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

function rl_fieldcontrol.isInList(item, list)
  for _, i in ipairs(list) do if item == i then return true end end
  return false
end

function rl_fieldcontrol.objectBoundBox(pos, offsets)
  return {
    pos[1] + offsets[1], pos[2] + offsets[2],
    pos[1] + offsets[3], pos[2] + offsets[4]
  }
end

function rl_fieldcontrol.rectToList(r)
  local ll = rect.ll(r)
  local size = rect.size(r)
  local out = {}
  for j = 0, size[2] - 1 do for i = 0, size[1] - 1 do
    table.insert(out, {world.xwrap(ll[1] + i), ll[2] + j})
  end end
  return out
end

function rl_fieldcontrol.rectToString(r)
  return "[[" .. r[1] .. ", " .. r[2] .. "], [" .. r[3] .. ", " .. r[4] .. "]]"
end

function rl_fieldcontrol.vecToString(vec, dimensions)
  if not dimensions then dimensions = 1 end
  local out = "["
  for i, v in ipairs(vec) do
    local notLast = i ~= #vec and ", " or ""
    if dimensions > 1 then
      v = vecToString(v, dimensions - 1)
    end
    out = string.format("%s%s%s", out, v, notLast)
  end
  return string.format("%s]", out)
end

--
-- Object (server-side) utils
--

function rl_fieldcontrol.currentOrRandomDungeonId(pos, dungeonIdValidator)
  local dungeonId = world.dungeonId(pos)
  while not dungeonIdValidator(dungeonId) do
    dungeonId = math.random(
      rl_fieldcontrol.fccDungeonIdRange[1],
      rl_fieldcontrol.fccDungeonIdRange[2])
  end
  return dungeonId
end

function rl_fieldcontrol.dungeonIdValidator(idRange)
  return function(dungeonId)
      return dungeonId and
        dungeonId >= idRange[1] and dungeonId <= idRange[2] and
        not rl_fieldcontrol.isInList(
          dungeonId, rl_fieldcontrol.forbiddenDungeonIds)
    end
end

function rl_fieldcontrol.fccUid(dungeonId)
  return string.format("%s%d", rl_fieldcontrol.fccPrefix, dungeonId)
end

function rl_fieldcontrol.getUnderlyingDungeonIds(box)
  local tiles = rl_fieldcontrol.rectToList(box)
  local out = {}
  for _, v in ipairs(tiles) do
    local dungeonId = world.dungeonId(v)
    table.insert(out, {v, dungeonId})
  end
  return out
end

function rl_fieldcontrol.setUnderlyingDungeonId(tiles, dungeonId)
  for _, v in ipairs(tiles) do
    local pos = v[1]
    local targetId = dungeonId or v[2]
    world.setDungeonId({pos[1], pos[2], pos[1] + 1, pos[2] + 1}, targetId)
  end
end

function rl_fieldcontrol.tileDungeonIdsToString(tiles)
  if not tiles then return "[]" end
  local out = "["
  for i, v in ipairs(tiles) do
    local pos = rl_fieldcontrol.vecToString(v[1])
    local notLast = i ~= #tiles and ", " or ""
    out = string.format(
      "%s{\"pos\": %s, \"dungeonId\": %d}%s", out, pos, v[2], notLast)
  end
  return string.format("%s]", out)
end

--
-- Item (client-side) or Object (server-side) utils
--

function rl_fieldcontrol.isFccShielded(dungeonId, notFinished)
  local obj = world.findUniqueEntity(rl_fieldcontrol.fccUid(dungeonId))
  while not obj:finished() do notFinished() end
  return obj:succeeded() and obj:result() ~= nil
end

function rl_fieldcontrol.isShipShielded(dungeonId, notFinished)
  if rl_fieldcontrol.isInList(dungeonId, rl_fieldcontrol.shipDungeonIds) then
    local obj = world.findUniqueEntity(rl_fieldcontrol.shipTechStationUid)
    while not obj:finished() do notFinished() end
    return obj:succeeded() and obj:result() ~= nil
  end
  return false
end

function rl_fieldcontrol.isStationShielded(dungeonId)
  return world.type() == rl_fieldcontrol.stationWorldType and
    rl_fieldcontrol.isInList(dungeonId, rl_fieldcontrol.stationDungeonIds)
end
