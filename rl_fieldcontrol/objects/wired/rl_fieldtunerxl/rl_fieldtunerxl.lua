require "/scripts/rect.lua"
require "/scripts/rl_fieldcontrol.lua"
require "/scripts/vec2.lua"

function init()
  self.maxTilesPerTick = 1000

  self.blockOffsets = config.getParameter("blockOffsets")
  self.lightColor = config.getParameter("lightColorOn")

  self.validateDungeonId = rl_fieldcontrol.dungeonIdValidator(
    rl_fieldcontrol.universeDungeonIdRange)

  local pos = vec2.floor(entity.position())
  if not storage.inactiveDungeonId then
    storage.inactiveDungeonId = rl_fieldcontrol.currentOrRandomDungeonId(
      pos, self.validateDungeonId)
  end

  message.setHandler("setInactiveDungeonId", setInactiveDungeonId)
  message.setHandler("tuneToDungeonId", tuneToDungeonId)

  object.setInteractive(true)
  object.setLightColor({0, 0, 0, 0})
end

function onInteraction(args)
  local interactData = root.assetJson(config.getParameter("interactData"))
  interactData.dungeonId = storage.inactiveDungeonId
  return {config.getParameter("interactAction"), interactData}
end

function onNodeConnectionChange(args)
  local pos = vec2.floor(entity.position())
  local box = rl_fieldcontrol.objectBoundBox(pos, self.blockOffsets)
  storage.tuningRegion = buildBoundingBox(pos, box)
end

function update(dt)
  if self.tuningCooldown then
    if animator.animationState("tunerState") == "inactive" then
      object.setInteractive(true)
      object.setLightColor({0, 0, 0, 0})
      self.tuningCooldown = nil
    end
  elseif self.tuningWarmup then
    if animator.animationState("tunerState") == "active" then
      local status, result = coroutine.resume(
        self.tuningCoroutine, self.activeDungeonId, storage.tuningRegion)
      self.tuningWarmup = nil
      tuningTaskCheck(status, result)
    end
  elseif self.tuningCoroutine then
    local status, result = coroutine.resume(self.tuningCoroutine)
    tuningTaskCheck(status, result)
  end
end

function setInactiveDungeonId(_, _, dungeonId)
  if not self.validateDungeonId(dungeonId) then
    sb.logError("rl_fieldtunerxlgui: Invalid dungeonId.")
    return
  end
  storage.inactiveDungeonId = dungeonId
end

function tuneToDungeonId(_, _, dungeonId)
  if self.tuningCooldown or self.tuningCoroutine then
    sb.logError("rl_fieldtunerxl: Tuning already in progress.")
    return false
  end
  if not self.validateDungeonId(dungeonId) then
    sb.logError("rl_fieldtunerxl: Invalid dungeonId.")
    return false
  end

  local pos = vec2.floor(entity.position())
  local box = rl_fieldcontrol.objectBoundBox(pos, self.blockOffsets)
  local tiles = rl_fieldcontrol.getUnderlyingDungeonIds(box)

  rl_fieldcontrol.setUnderlyingDungeonId(tiles, dungeonId)
  if world.isTileProtected(pos) then
    -- Allow switching to a tile-protected dungeonID only if it is under
    -- the control of a Field Control Console, Ship Shield Switch, or
    -- Station Shield Switch.
    if not rl_fieldcontrol.isFccShielded(dungeonId, unexpectedAsync) then
      if not rl_fieldcontrol.isShipShielded(dungeonId, unexpectedAsync) then
        if not rl_fieldcontrol.isStationShielded(dungeonId) then
          --sb.logInfo("rl_fieldtunerxl: dungeonId " .. dungeonId .. " reserved. Reverting.")
          rl_fieldcontrol.setUnderlyingDungeonId(tiles)
          return false
        end
      end
    end
  end

  -- If we got here, we are allowed to tune to this dungeonId. Kick off
  -- the asynchronous process.
  storage.inactiveDungeonId = dungeonId
  if not storage.tuningRegion then
    storage.tuningRegion = buildBoundingBox(pos, box)
  end

  object.setInteractive(false)
  self.activeDungeonId = dungeonId
  self.tuningCoroutine = coroutine.create(tuningTask)
  if object.outputNodeCount() > 0 then object.setOutputNodeLevel(0, true) end
  animator.setAnimationState("tunerState", "activate")
  object.setLightColor(self.lightColor)
  self.tuningWarmup = true

  return true
end

function tuningTask(dungeonId, targetRect)
  local tiles = nil
  local nextOffset = 0
  repeat
    tiles, nextOffset = rectToList(
      targetRect, self.maxTilesPerTick, nextOffset)
    for _, pos in ipairs(tiles) do
      local posDungeonId = world.dungeonId(pos)
      if not world.isTileProtected(pos) and not rl_fieldcontrol.isInList(
            posDungeonId, rl_fieldcontrol.forbiddenDungeonIds) and
          posDungeonId ~= dungeonId then
        world.setDungeonId({pos[1], pos[2], pos[1] + 1, pos[2] + 1}, dungeonId)
      end
    end
    if nextOffset ~= nil then coroutine.yield() end
  until nextOffset == nil
  return true
end

function tuningTaskCheck(status, result)
  if not status then
    tuningTaskEnd()
    error(result)
  end
  if result then tuningTaskEnd() end
end

function tuningTaskEnd()
  self.activeDungeonId = nil
  self.tuningCoroutine = nil
  if object.outputNodeCount() > 0 then object.setOutputNodeLevel(0, false) end
  animator.setAnimationState("tunerState", "deactivate")
  self.tuningCooldown = true
end

function boundingBoxFromPoints(pos, points)
  local offsets = {0, 0, 1, 1}
  for _, v in ipairs(points) do
    local distance = world.distance(v, pos)
    if distance[1] < offsets[1] then offsets[1] = distance[1] end
    if distance[2] < offsets[2] then offsets[2] = distance[2] end
    if distance[1] > offsets[3] then offsets[3] = distance[1] end
    if distance[2] > offsets[4] then offsets[4] = distance[2] end
  end
  return rl_fieldcontrol.objectBoundBox(pos, offsets)
end

function buildBoundingBox(pos, initialBox)
  points = {
    rect.ll(initialBox), rect.lr(initialBox),
    rect.ul(initialBox), rect.ur(initialBox)
  }
  if object.outputNodeCount() > 0 then
    for obj, _ in pairs(object.getOutputNodeIds(0)) do
      local objMsg = world.sendEntityMessage(obj, "getFieldMarkerBounds")
      if objMsg:finished() then
        if objMsg:succeeded() then
          local objBounds = objMsg:result()
          table.insert(points, rect.ll(objBounds))
          table.insert(points, rect.lr(objBounds))
          table.insert(points, rect.ul(objBounds))
          table.insert(points, rect.ur(objBounds))
        end
      else
        -- We should never get here.
        sb.logError("rl_fieldtunerxl: getFieldMarkerBounds was asynchronous.")
      end
    end
  end
  return boundingBoxFromPoints(pos, points)
end

function rectToList(r, maxSize, startOffset)
  if not startOffset then startOffset = 0 end
  local size = rect.size(r)
  local area = size[1] * size[2]
  local ll = rect.ll(r)

  local startOffsetY = math.floor(startOffset / size[1])
  local startOffsetX = math.floor(startOffset % size[1])
  local nextOffset = maxSize and startOffset + maxSize or area
  local nextOffsetY = math.floor(nextOffset / size[1])
  local nextOffsetX = math.floor(nextOffset % size[1])
  if nextOffset >= area then nextOffset = nil end

  local out = {}
  for j = startOffsetY, size[2] - 1 do
    for i = startOffsetX, size[1] - 1 do
      startOffsetX = 0
      if j == nextOffsetY and i == nextOffsetX then
        return out, nextOffset
      end
      table.insert(out, {world.xwrap(ll[1] + i), ll[2] + j})
    end
  end
  return out, nextOffset
end

function unexpectedAsync()
  sb.logError("rl_fieldtunerxl: Unexpected async.")
end
