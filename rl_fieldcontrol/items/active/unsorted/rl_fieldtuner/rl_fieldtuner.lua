require "/scripts/rl_fieldcontrol.lua"
require "/scripts/vec2.lua"

local statusEnum = {"available", "done"}

function init()
  self.primaryCooldownTimer = 0
  self.altCooldownTimer = 0
  self.fireFailCooldownTimer = 0

  self.blockOffsets = config.getParameter("blockOffsets")
  self.shiftBlockOffsets = config.getParameter("shiftBlockOffsets")
  self.primaryCooldownTime = config.getParameter("primaryCooldownTime")
  self.altCooldownTime = config.getParameter("altCooldownTime")
  self.fireFailCooldownTime = config.getParameter("fireFailCooldownTime")
  self.maxDistance = config.getParameter("maxDistance")

  local scannerConfig = config.getParameter("scannerConfig")
  activeItem.setScriptedAnimationParameter("scannerConfig", scannerConfig)
  activeItem.setScriptedAnimationParameter("targetingData", nil)

  local fieldTunerProperties = player.getProperty(
    rl_fieldcontrol.fieldTunerPropertyName)
  if not fieldTunerProperties then
    resetTuner()
  else
    if playerChangedWorlds(
        fieldTunerProperties.serverUuid, fieldTunerProperties.worldId) then
      resetTuner()
    else
      self.dungeonId = fieldTunerProperties.dungeonId
      animator.setAnimationState("tunerState", "valid")
    end
  end
end

function update(dt, fireMode, shifting)
  updateAim(shifting)

  self.primaryCooldownTimer = math.max(self.primaryCooldownTimer - dt, 0)
  self.altCooldownTimer = math.max(self.altCooldownTimer - dt, 0)
  self.fireFailCooldownTimer = math.max(self.fireFailCooldownTimer - dt, 0)

  if not self.fieldManager then
    if self.findFieldManager then
      local status, result = coroutine.resume(self.findFieldManager)
      if not status then error(result) end
      if result then
        self.fieldManager = result
        self.findFieldManager = nil
      end
    else
      self.findFieldManager = coroutine.create(loadFieldManager)
    end
  elseif self.worldMessageSetDungeonId then
    if self.worldMessageSetDungeonId:finished() then
      if not self.worldMessageSetDungeonId:succeeded() then
        sb.logError("rl_fieldtuner: received setDungeonId message failure")
      end
      animator.playSound("fire")
      self.worldMessageSetDungeonId = nil
    end
  elseif self.getDungeonIdCoroutine then
    self.altCooldownTimer = self.altCooldownTime
    local status, result = coroutine.resume(self.getDungeonIdCoroutine)
    if not status then error(result) end
    if result ~= nil then self.getDungeonIdCoroutine = nil end
  elseif fireMode == "primary" then
    if self.primaryCooldownTimer == 0 then
      self.primaryCooldownTimer = self.primaryCooldownTime
      self.worldMessageSetDungeonId = setDungeonId()
    end
  elseif fireMode == "alt" then
    if self.altCooldownTimer == 0 then
      self.altCooldownTimer = self.altCooldownTime
      self.getDungeonIdCoroutine = coroutine.create(getDungeonId)
    end
  end

  if not self.fieldManager then
    activeItem.setScriptedAnimationParameter("targetingData", nil)
  elseif self.aimDistance > self.maxDistance and not player.isAdmin() then
    activeItem.setScriptedAnimationParameter("targetingData", nil)
  else
    activeItem.setScriptedAnimationParameter(
      "targetingData", self.targetingData)
  end
end

function loadFieldManager()
  while true do
    local findManager = world.findUniqueEntity(rl_fieldcontrol.stagehandUid)
    while not findManager:finished() do coroutine.yield() end
    if findManager:succeeded() then
      return rl_fieldcontrol.stagehandUid
    else
      world.spawnStagehand({5, 5}, "rl_fieldmanager")
    end
    coroutine.yield()
  end
end

function getDungeonId()
  if self.aimDistance > self.maxDistance and not player.isAdmin() then
    return false
  end

  local dungeonId = world.dungeonId(self.aimPosition)
  if world.isTileProtected(self.aimPosition) then
    -- Allow switching to a tile-protected dungeonID only if it is under
    -- the control of a Field Control Console, Ship Shield Switch, or
    -- Station Shield Switch.
    if not rl_fieldcontrol.isFccShielded(dungeonId, coroutine.yield) then
      if not rl_fieldcontrol.isShipShielded(dungeonId) then
        if not rl_fieldcontrol.isStationShielded(dungeonId) then
          --sb.logInfo("rl_fieldtuner: dungeonId %s is reserved; not tuning", dungeonId)
          resetTuner()
          animator.playSound("scanFail")
          return false
        end
      end
    end
  end
  if contains(rl_fieldcontrol.forbiddenDungeonIds, dungeonId) then
    --sb.logInfo("rl_fieldtuner: dungeonId %s is reserved; not tuning", dungeonId)
    resetTuner()
    animator.playSound("scanFail")
    return false
  end

  self.dungeonId = dungeonId
  player.setProperty(rl_fieldcontrol.fieldTunerPropertyName, {
    serverUuid=player.serverUuid(),
    worldId=player.worldId(),
    dungeonId=self.dungeonId
  })
  animator.setAnimationState("tunerState", "valid")
  animator.playSound("scanSuccess")
  --sb.logInfo("rl_fieldtuner: tuned to dungeonId %s", self.dungeonId)
  return true
end

function setDungeonId()
  if self.aimDistance > self.maxDistance and not player.isAdmin() then
    return
  end
  if not self.dungeonId then
    -- The only way to get here is if the tuner hasn't been set to a
    -- valid dungeonId.
    fireFail()
    return
  end
  if not self.targetingData then
    -- The only way to get here (aside from dungeonId not being set) is
    -- if the targeting cursor is completely out of the world's bounds.
    -- This can happen when the player spawns into a world with the tool
    -- already equipped.
    fireFail()
    return
  end
  if not self.fieldManager then
    -- Should not be possible to get here.
    sb.logError("rl_fieldtuner: field manager not set; no action taken")
    return
  end
  if self.worldMessageSetDungeonId then
    -- Should not be possible to get here.
    sb.logError("rl_fieldtuner: a previous message is in progress; no action taken")
    return
  end

  --sb.logInfo("rl_fieldtuner: sending tiles %s to field manager for assignment to dungeonId %d", targetingDataToString(), self.dungeonId)
  return world.sendEntityMessage(
    self.fieldManager, "setDungeonId", self.dungeonId, self.targetingData
  )
end

function fireFail()
  if self.fireFailCooldownTimer == 0 then
    self.fireFailCooldownTimer = self.fireFailCooldownTime
    animator.playSound("fireFail")
  end
end

function getTargetingData(shifting, pos)
  local offsets = shifting and self.shiftBlockOffsets or self.blockOffsets
  local targetRect = {pos[1] - offsets[1], pos[2] - offsets[1],
                      pos[1] + offsets[2], pos[2] + offsets[2]}

  local maxY = world.size()[2]
  local ll = rect.ll(targetRect)
  local ur = rect.ur(targetRect)
  if ll[2] >= maxY or ur[2] < 1 then
    sb.logInfo("rl_fieldtuner: rectangle %s is out of bounds",
      sb.printJson(targetRect)
    )
    return nil
  end
  if ll[2] < 0 then
    targetRect[2] = 0
    --sb.logInfo("rl_fieldtuner: rectangle %s trimmed", sb.printJson(targetRect))
  end
  if ur[2] > maxY then
    targetRect[4] = maxY
    --sb.logInfo("rl_fieldtuner: rectangle %s trimmed", sb.printJson(targetRect))
  end

  local targetingData = {}
  for _, pos in ipairs(rl_fieldcontrol.rectToSpaces(targetRect)) do
    local posDungeonId = world.dungeonId(pos)
    if world.isTileProtected(pos) and posDungeonId ~= self.dungeonId then
      table.insert(targetingData, {pos, 3})
    elseif contains(rl_fieldcontrol.forbiddenDungeonIds, posDungeonId) then
      table.insert(targetingData, {pos, 3})
    elseif posDungeonId == self.dungeonId then
      table.insert(targetingData, {pos, 2})
    else
      table.insert(targetingData, {pos, 1})
    end
  end
  return targetingData
end

--function targetingDataToString()
--  local out = {}
--  for _,v in ipairs(self.targetingData or {}) do
--    table.insert(out, {pos = v[1], status = statusEnum[v[2]] or "unavailable"})
--  end
--  return sb.printJson(out)
--end

function updateAim(shifting)
  self.aimPosition = activeItem.ownerAimPosition()
  local aimDirection = 0
  _, aimDirection = activeItem.aimAngleAndDirection(0, self.aimPosition)
  activeItem.setFacingDirection(aimDirection)
  local scanOffset = animator.partPoint("tuner", "scanPosition")
  scanOffset[1] = scanOffset[1] * aimDirection
  local scanPosition = vec2.add(mcontroller.position(), scanOffset)
  self.aimDistance = world.magnitude(self.aimPosition, scanPosition)
  if self.dungeonId then
    self.targetingData = getTargetingData(
      shifting, vec2.floor(self.aimPosition))
  else
    self.targetingData = nil
  end
end

function playerChangedWorlds(oldServerUuid, oldWorldId)
  return oldServerUuid ~= player.serverUuid() or oldWorldId ~= player.worldId()
end

function resetTuner()
  self.dungeonId = nil
  player.setProperty(rl_fieldcontrol.fieldTunerPropertyName, nil)
  animator.setAnimationState("tunerState", "invalid")
end
