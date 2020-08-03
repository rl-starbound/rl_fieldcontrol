require "/scripts/rl_fieldcontrol.lua"
require "/scripts/vec2.lua"

function init()
  self.blockOffsets = config.getParameter("blockOffsets")
  self.lightColor = config.getParameter("lightColorOn")

  self.validateDungeonId = rl_fieldcontrol.dungeonIdValidator(
    rl_fieldcontrol.fccDungeonIdRange)

  if storage.bulkheadMode then
    animator.setAnimationState("consoleState", "bulkhead")
    object.setLightColor({0, 0, 0, 0})
  end

  local pos = vec2.floor(entity.position())
  if storage.dungeonId then
    storage.unregisteredDungeonId = storage.dungeonId
    -- Aggressively reset the dungeonId of tiles underlying a registered
    -- field control console.
    local box = rl_fieldcontrol.objectBoundBox(pos, self.blockOffsets)
    local tiles = rl_fieldcontrol.getUnderlyingDungeonIds(box)
    rl_fieldcontrol.setUnderlyingDungeonId(tiles, storage.dungeonId)
  elseif not storage.unregisteredDungeonId then
    storage.unregisteredDungeonId = rl_fieldcontrol.currentOrRandomDungeonId(
      pos, self.validateDungeonId)
  end

  message.setHandler("deregisterDungeonId", deregisterDungeonId)
  message.setHandler("registerDungeonId", registerDungeonId)
  message.setHandler("setBulkheadMode", setBulkheadMode)
  message.setHandler("setDungeonBreathable", setDungeonBreathable)
  message.setHandler("setDungeonGravity", setDungeonGravity)
  message.setHandler("setDungeonTileProtection", setDungeonTileProtection)
  message.setHandler("setUnregisteredDungeonId", setUnregisteredDungeonId)
end

function die(smash)
  deregisterDungeonId()
end

function onInteraction()
  local pos = vec2.floor(entity.position())
  if storage.dungeonId then
    -- Aggressively reset the dungeonId of tiles underlying a registered
    -- field control console.
    local box = rl_fieldcontrol.objectBoundBox(pos, self.blockOffsets)
    local tiles = rl_fieldcontrol.getUnderlyingDungeonIds(box)
    rl_fieldcontrol.setUnderlyingDungeonId(tiles, storage.dungeonId)
  end

  local interactData = root.assetJson(config.getParameter("interactData"))
  interactData.bulkheadMode = storage.bulkheadMode
  interactData.registeredDungeonId = storage.dungeonId
  interactData.unregisteredDungeonId = storage.unregisteredDungeonId
  if storage.dungeonId then
    interactData.breathable = world.breathable(pos)
    interactData.gravity = world.gravity(pos)
    interactData.protection = world.isTileProtected(pos)
  end
  return {config.getParameter("interactAction"), interactData}
end

function update(dt)
  -- Admins can raise or lower shields independent of this console, so
  -- check that animation state is synced with shield state.
  if storage.dungeonId then
    local pos = vec2.floor(entity.position())
    local protection = world.isTileProtected(pos)
    if not protection then
      setConsoleAnimation("shieldsdown")
    else
      setConsoleAnimation("shieldsup")
    end
  end
end

function deregisterDungeonId(_, _, doAnimation)
  if not storage.dungeonId then return end
  world.setTileProtection(storage.dungeonId, false)
  world.setDungeonBreathable(storage.dungeonId, storage.origBreathable)
  world.setDungeonGravity(storage.dungeonId, storage.origGravity)
  object.setUniqueId()
  storage.dungeonId = nil
  storage.origBreathable = nil
  storage.origGravity = nil
  if doAnimation then
    setConsoleAnimation("unregistered")
    animator.playSound("deregister")
  end
end

function registerDungeonId(_, _, dungeonId)
  if storage.dungeonId then
    sb.logError("rl_fieldcontrolconsole: Console already registered.")
    return {success=false, dungeonId=dungeonId}
  end
  if not self.validateDungeonId(dungeonId) then
    sb.logError("rl_fieldcontrolconsole: Invalid dungeonId.")
    return {success=false, dungeonId=dungeonId}
  end

  local pos = vec2.floor(entity.position())
  local box = rl_fieldcontrol.objectBoundBox(pos, self.blockOffsets)
  local tiles = rl_fieldcontrol.getUnderlyingDungeonIds(box)

  local origBreathable = world.breathable(pos)
  local origGravity = world.gravity(pos)

  if world.findUniqueEntity(rl_fieldcontrol.fccUid(dungeonId)):result() ~= nil then
    --sb.logInfo("rl_fieldcontrolconsole: dungeonId " .. dungeonId .. " already controlled. No action taken.")
    return {success=false, dungeonId=dungeonId}
  end

  rl_fieldcontrol.setUnderlyingDungeonId(tiles, dungeonId)
  if world.isTileProtected(pos) then
    --sb.logInfo("rl_fieldcontrolconsole: dungeonId " .. dungeonId .. " reserved. Reverting.")
    rl_fieldcontrol.setUnderlyingDungeonId(tiles)
    return {success=false, dungeonId=dungeonId}
  end

  -- You've just changed the dungeonId of the region under this object.
  -- Depending on the world, that new dungeonId might have different
  -- properties than the previous one. Set the properties of the new
  -- dungeonId to match the previous one.
  world.setDungeonBreathable(dungeonId, origBreathable)
  world.setDungeonGravity(dungeonId, origGravity)

  storage.origBreathable = origBreathable
  storage.origGravity = origGravity
  storage.dungeonId = dungeonId
  object.setUniqueId(rl_fieldcontrol.fccUid(dungeonId))
  setConsoleAnimation("shieldsdown")
  animator.playSound("register")
  return {
    success=true,
    dungeonId=dungeonId,
    breathable=origBreathable,
    gravity=origGravity,
    protection=false
  }
end

function setBulkheadMode(_, _, bulkheadMode)
  if bulkheadMode == nil then bulkheadMode = false end
  if not bulkheadMode and storage.bulkheadMode then
    storage.bulkheadMode = bulkheadMode
    -- We are leaving bulkhead mode. Probe to find the current state of
    -- the object.
    local pos = vec2.floor(entity.position())
    local currentProtection = world.isTileProtected(pos)
    if storage.dungeonId then
      if currentProtection then
        setConsoleAnimation("shieldsup")
      else
        setConsoleAnimation("shieldsdown")
      end
    else
      setConsoleAnimation("unregistered")
    end
  elseif bulkheadMode and not storage.bulkheadMode then
    storage.bulkheadMode = bulkheadMode
    setConsoleAnimation("bulkhead")
  end
end

function setDungeonBreathable(_, _, breathable)
  if breathable == nil then breathable = true end
  world.setDungeonBreathable(storage.dungeonId, breathable)
end

function setDungeonGravity(_, _, gravity)
  if not gravity then gravity = 80 end
  if gravity < -10 then gravity = -10 end
  if gravity > 100 then gravity = 100 end
  world.setDungeonGravity(storage.dungeonId, gravity)
end

function setDungeonTileProtection(_, _, protection)
  if protection == nil then protection = false end
  local pos = vec2.floor(entity.position())
  local currentProtection = world.isTileProtected(pos)
  if not currentProtection and protection then
    setConsoleAnimation("shieldsup")
    animator.playSound("shieldsUp")
    world.setTileProtection(storage.dungeonId, protection)
  elseif currentProtection and not protection then
    setConsoleAnimation("shieldsdown")
    animator.playSound("shieldsDown")
    world.setTileProtection(storage.dungeonId, protection)
  end
end

function setUnregisteredDungeonId(_, _, dungeonId)
  if not self.validateDungeonId(dungeonId) then
    sb.logError("rl_fieldcontrolconsole: Invalid dungeonId.")
    return
  end
  storage.unregisteredDungeonId = dungeonId
end

function setConsoleAnimation(state)
  if storage.bulkheadMode then
    animator.setAnimationState("consoleState", "bulkhead")
    object.setLightColor({0, 0, 0, 0})
  else
    animator.setAnimationState("consoleState", state)
    object.setLightColor(self.lightColor)
  end
end
