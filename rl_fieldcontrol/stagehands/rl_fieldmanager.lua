require "/scripts/rl_fieldcontrol.lua"

function init()
  local tryUniqueId = config.getParameter("tryUniqueId")
  if entity.uniqueId() ~= tryUniqueId then
    if world.findUniqueEntity(tryUniqueId):result() == nil then
      stagehand.setUniqueId(tryUniqueId)
    else
      stagehand.die()
    end
  end

  local worldSize = world.size()
  storage.maxX = worldSize[1]
  storage.maxY = worldSize[2]

  storage.maxSize = 25

  message.setHandler("setDungeonId", setDungeonId)
end

function setDungeonId(_, _, dungeonId, targetingData)
  local changedAny = false
  if #targetingData > storage.maxSize then
    return changedAny
  end
  for _, v in ipairs(targetingData) do
    changedAny = trySetDungeonId(dungeonId, v[1]) or changedAny
  end
  return changedAny
end

function trySetDungeonId(dungeonId, pos)
  if not worldBoundsCheck(pos) then return false end
  local posDungeonId = world.dungeonId(pos)
  if world.isTileProtected(pos) and posDungeonId ~= dungeonId then
    --sb.logInfo("rl_fieldmanager: pos " .. rl_fieldcontrol.vecToString(pos) .. " is tile protected; not altering dungeonId.")
    return false
  end
  if rl_fieldcontrol.isInList(
      posDungeonId, rl_fieldcontrol.forbiddenDungeonIds) then
    --sb.logInfo("rl_fieldmanager: pos " .. rl_fieldcontrol.vecToString(pos) .. " is at forbidden dungeonId " .. posDungeonId .. "; not altering dungeonId.")
    return false
  end
  if posDungeonId ~= dungeonId then
    world.setDungeonId({pos[1], pos[2], pos[1] + 1, pos[2] + 1}, dungeonId)
  end
  return true
end

function worldBoundsCheck(pos)
  return pos[1] >= 0 and pos[2] >= 0 and
    pos[1] < storage.maxX and pos[2] < storage.maxY
end
