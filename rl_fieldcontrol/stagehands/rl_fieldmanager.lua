require "/scripts/rl_fieldcontrol.lua"
require "/scripts/util.lua"

function init()
  local tryUniqueId = rl_fieldcontrol.stagehandUid
  if entity.uniqueId() ~= tryUniqueId then
    if world.findUniqueEntity(tryUniqueId):result() == nil then
      stagehand.setUniqueId(tryUniqueId)
    else
      script.setUpdateDelta(0)
      stagehand.die()
    end
  end

  local worldSize = world.size()
  self.maxX = worldSize[1]
  self.maxY = worldSize[2]

  self.maxSize = 25

  message.setHandler("setDungeonId", setDungeonId)
end

function setDungeonId(_, _, dungeonId, targetingData)
  local changedAny = false
  if #targetingData > self.maxSize then
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
    --sb.logInfo("rl_fieldmanager: position %s is tile protected; not altering dungeonId", sb.printJson(pos))
    return false
  end
  if contains(rl_fieldcontrol.forbiddenDungeonIds, posDungeonId) then
    --sb.logInfo("rl_fieldmanager: position %s has forbidden dungeonId %d; not altering dungeonId", sb.printJson(pos), posDungeonId)
    return false
  end
  if posDungeonId ~= dungeonId then
    world.setDungeonId({pos[1], pos[2], pos[1] + 1, pos[2] + 1}, dungeonId)
  end
  return true
end

function worldBoundsCheck(pos)
  return pos[1] >= 0 and pos[2] >= 0 and
    pos[1] < self.maxX and pos[2] < self.maxY
end
