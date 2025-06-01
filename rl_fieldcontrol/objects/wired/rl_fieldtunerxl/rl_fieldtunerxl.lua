require "/scripts/poly.lua"
require "/scripts/rect.lua"
require "/scripts/rl_fieldcontrol.lua"
require "/scripts/util.lua"
require "/scripts/vec2.lua"

function init()
  self.position = entity.position()
  self.spaces = util.map(object.spaces(), function(v)
      return vec2.add(self.position, v)
    end)

  self.lightColor = config.getParameter("lightColorOn")
  self.maxTilesPerTick = 1000

  self.validateDungeonId = rl_fieldcontrol.dungeonIdValidator(
    rl_fieldcontrol.universeDungeonIdRange)

  if not storage.inactiveDungeonId then
    storage.inactiveDungeonId = rl_fieldcontrol.currentOrRandomDungeonId(
      self.position, self.validateDungeonId)
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
  storage.tuningRegion = buildBoundingBox()
end

function update(dt)
  if self.tuningCooldown then
    if animator.animationState("tunerState") == "inactive" then
      self.tuningCooldown = nil
      object.setInteractive(true)
      object.setLightColor({0, 0, 0, 0})
    end
  elseif self.tuningWarmup then
    if animator.animationState("tunerState") == "active" then
      self.tuningWarmup = nil
      local status, result = coroutine.resume(
        self.tuningCoroutine, self.activeDungeonId, storage.tuningRegion)
      tuningTaskCheck(status, result)
    end
  elseif self.tuningCoroutine then
    local status, result = coroutine.resume(self.tuningCoroutine)
    tuningTaskCheck(status, result)
  end
end

function setInactiveDungeonId(_, _, dungeonId)
  if not self.validateDungeonId(dungeonId) then
    sb.logError("rl_fieldtunerxl: invalid dungeonId: %s", dungeonId)
    return
  end
  storage.inactiveDungeonId = dungeonId
end

function tuneToDungeonId(_, _, dungeonId)
  if self.tuningCooldown or self.tuningCoroutine then
    sb.logError("rl_fieldtunerxl: tuning already in progress")
    return false
  end
  if not self.validateDungeonId(dungeonId) then
    sb.logError("rl_fieldtunerxl: invalid dungeonId: %s", dungeonId)
    return false
  end

  local tiles = rl_fieldcontrol.getUnderlyingDungeonIds(self.spaces)
  rl_fieldcontrol.setUnderlyingDungeonId(tiles, dungeonId)
  if world.isTileProtected(self.position) then
    -- Allow switching to a tile-protected dungeonID only if it is under
    -- the control of a Field Control Console, Ship Shield Switch, or
    -- Station Shield Switch.
    if not rl_fieldcontrol.isFccShielded(dungeonId, unexpectedAsync) then
      if not rl_fieldcontrol.isShipShielded(dungeonId) then
        if not rl_fieldcontrol.isStationShielded(dungeonId) then
          --sb.logInfo("rl_fieldtunerxl: dungeonId %s is reserved; reverting", dungeonId)
          rl_fieldcontrol.setUnderlyingDungeonId(tiles)
          return false
        end
      end
    end
  end

  -- If we got here, we are allowed to tune to this dungeonId. Kick off
  -- the asynchronous process.
  storage.inactiveDungeonId = dungeonId
  storage.tuningRegion = storage.tuningRegion or buildBoundingBox()

  object.setInteractive(false)
  self.activeDungeonId = dungeonId
  self.tuningCoroutine = coroutine.create(tuningTask)
  if object.outputNodeCount() > 0 then object.setOutputNodeLevel(0, true) end
  animator.setAnimationState("tunerState", "activate")
  object.setLightColor(self.lightColor)
  self.tuningWarmup = true

  return true
end

-- This function tunes the rectangular region one tile at a time, rather
-- than tuning the whole region at once, because some of the individual
-- tiles might belong to shielded dungeons or might be otherwise off
-- limits to tuning.
function tuningTask(dungeonId, targetRect)
  local positions = nil
  local nextOffset = 0
  repeat
    positions, nextOffset = rectToSpaces(
      targetRect, self.maxTilesPerTick, nextOffset
    )
    for _,pos in ipairs(positions) do
      local posDungeonId = world.dungeonId(pos)
      if not world.isTileProtected(pos) and
         not contains(rl_fieldcontrol.forbiddenDungeonIds, posDungeonId) and
         posDungeonId ~= dungeonId
      then
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
    sb.logError("rl_fieldtunerxl: tuning task failed: %s", result)
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

function buildBoundingBox()
  local points = copy(self.spaces)
  if object.outputNodeCount() > 0 then
    for entityId,_ in pairs(object.getOutputNodeIds(0)) do
      local msg = world.sendEntityMessage(entityId, "getFieldMarkerPosition")
      if msg:finished() then
        if msg:succeeded() then table.insert(points, msg:result()) end
      else
        -- We should never get here.
        sb.logError("rl_fieldtunerxl: getFieldMarkerPosition was asynchronous")
      end
    end
  end
  local boundBox = poly.boundBox(points)
  boundBox[3] = boundBox[3] + 1
  boundBox[4] = boundBox[4] + 1
  return boundBox
end

function rectToSpaces(r, maxSize, startOffset)
  if not startOffset then startOffset = 0 end
  local size = rect.size(r)
  if size[1] <= 0 or size[2] <= 0 then
    sb.logError("rl_fieldtunerxl: returning no spaces for invalid rectangle: %s", sb.printJson(r))
    return {}, nil
  end
  local area = size[1] * size[2]
  if startOffset >= area then
    sb.logError("rl_fieldtunerxl: returning no spaces because startOffset %s >= area %s", startOffset, area)
    return {}, nil
  end
  local ll = rect.ll(r)

  local startOffsetX = math.floor(startOffset / size[2])
  local startOffsetY = math.floor(startOffset % size[2])
  local nextOffset = maxSize and startOffset + maxSize or area
  local nextOffsetX = math.floor(nextOffset / size[2])
  local nextOffsetY = math.floor(nextOffset % size[2])
  if nextOffset >= area then nextOffset = nil end

  local out = {}
  for i = startOffsetX, size[1] - 1 do
    local x = world.xwrap(ll[1] + i)
    for j = startOffsetY, size[2] - 1 do
      -- Reset startOffsetY to 0 after the first iteration so that
      -- subsequent iterations return to the bottom of the rectangle.
      startOffsetY = 0

      if i == nextOffsetX and j == nextOffsetY then
        -- The max size has been reached. Return the current results and
        -- the next offset.
        return out, nextOffset
      end
      table.insert(out, {x, ll[2] + j})
    end
  end
  return out, nextOffset
end

function unexpectedAsync()
  sb.logError("rl_fieldtunerxl: unexpected asynchronous messaging occurred")
end
