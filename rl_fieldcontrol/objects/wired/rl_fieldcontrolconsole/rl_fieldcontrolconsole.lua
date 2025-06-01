require "/scripts/rl_fieldcontrol.lua"
require "/scripts/util.lua"
require "/scripts/vec2.lua"

function init()
  self.position = entity.position()
  self.spaces = util.map(object.spaces(), function(v)
      return vec2.add(self.position, v)
    end)

  self.enableHazardProtection = root.assetJson("/versioning.config").rl_dynamicstatuseffects
  self.hazardProtectionConfig = config.getParameter("hazardProtection", {})

  self.initialConfig = config.getParameter("initialConfiguration")

  self.lightColor = config.getParameter("lightColorOn")

  self.validateDungeonId = rl_fieldcontrol.dungeonIdValidator(
    rl_fieldcontrol.fccDungeonIdRange
  )

  if storage.bulkheadMode then
    animator.setAnimationState("consoleState", "bulkhead")
    object.setLightColor({0, 0, 0, 0})
  end

  if storage.dungeonId then
    -- Aggressively reset the dungeonId of tiles underlying an activated
    -- field control console.
    rl_fieldcontrol.setUnderlyingDungeonId(
      rl_fieldcontrol.getUnderlyingDungeonIds(self.spaces), storage.dungeonId
    )
  end

  self.breathableOutputNode = 0
  self.protectionOutputNode = 1

  object.setOutputNodeLevel(self.breathableOutputNode,
    storage.dungeonId and world.breathable(self.position)
  )
  object.setOutputNodeLevel(self.protectionOutputNode,
    storage.dungeonId and world.isTileProtected(self.position)
  )

  -- Wait 1 second before attempting to apply initial configuration.
  self.initialConfigDelayTime = 1

  -- Wait 1 second between sync checks.
  self.fieldSyncTime = 1
  self.fieldSyncTimer = self.fieldSyncTime

  message.setHandler("deregisterDungeonId", deregisterDungeonId)
  message.setHandler("registerDungeonId", registerDungeonId)
  message.setHandler("setBulkheadMode", setBulkheadMode)
  message.setHandler("setDungeonBreathable", setDungeonBreathable)
  message.setHandler("setDungeonGravity", setDungeonGravity)
  message.setHandler("setDungeonHazardProtection", setDungeonHazardProtection)
  message.setHandler("setDungeonTileProtection", setDungeonTileProtection)
  message.setHandler("setUnregisteredDungeonId", setUnregisteredDungeonId)
end

function die(smash)
  deregisterDungeonId()
end

function onInteraction()
  if storage.dungeonId then
    -- Aggressively reset the dungeonId of tiles underlying an activated
    -- field control console.
    rl_fieldcontrol.setUnderlyingDungeonId(
      rl_fieldcontrol.getUnderlyingDungeonIds(self.spaces), storage.dungeonId
    )
  end
  if not storage.unregisteredDungeonId then
    storage.unregisteredDungeonId = rl_fieldcontrol.currentOrRandomDungeonId(
      self.position, self.validateDungeonId
    )
  end

  local interactData = root.assetJson(config.getParameter("interactData"))
  interactData.bulkheadMode = storage.bulkheadMode
  interactData.registeredDungeonId = storage.dungeonId
  interactData.unregisteredDungeonId = storage.unregisteredDungeonId
  if storage.dungeonId then
    interactData.breathable = world.breathable(self.position)
    interactData.gravity = world.gravity(self.position)
    interactData.hazardProtection = getHazardProtectionStatus()
    interactData.protection = world.isTileProtected(self.position)
  end
  return {config.getParameter("interactAction"), interactData}
end

function update(dt)
  if not storage.intialConfigApplied then
    self.initialConfigDelayTime = self.initialConfigDelayTime - dt
    if self.initialConfigDelayTime <= 0 then
      applyInitialConfiguration()
      storage.intialConfigApplied = true
    end
  end

  -- Admins can raise or lower shields independent of this console, so
  -- ensure that object state is synced with world state.
  if storage.dungeonId then
    self.fieldSyncTimer = self.fieldSyncTimer - dt
    if self.fieldSyncTimer <= 0 then
      local breathable = world.breathable(self.position)
      local breathableOutputLevel = object.getOutputNodeLevel(
        self.breathableOutputNode
      )
      if breathable ~= breathableOutputLevel then
        object.setOutputNodeLevel(self.breathableOutputNode, breathable)
      end

      local protection = world.isTileProtected(self.position)
      local protectionOutputLevel = object.getOutputNodeLevel(
        self.protectionOutputNode
      )
      setConsoleAnimation(protection and "shieldsup" or "shieldsdown")
      if protection ~= protectionOutputLevel then
        object.setOutputNodeLevel(self.protectionOutputNode, protection)
      end

      self.fieldSyncTimer = self.fieldSyncTime
    end
  end
end

function deregisterDungeonId(_, _, doAnimation)
  if not storage.dungeonId then return end

  if self.enableHazardProtection then
    local manager = getDynamicStatusEffectsManager()
    if manager then
      world.sendEntityMessage(manager, "clearEffects",
        storage.dungeonId, "rl_fieldcontrolconsole"
      )
      world.sendEntityMessage(manager, "clearEffects",
        storage.dungeonId, "rl_fieldcontrolconsole_airless"
      )
    else
      sb.logError("rl_fieldcontrolconsole: possibly failed to clear dungeon %s status effects", storage.dungeonId)
    end
  end

  world.setTileProtection(storage.dungeonId, false)
  world.setDungeonBreathable(storage.dungeonId, storage.origBreathable)
  world.setDungeonGravity(storage.dungeonId, storage.origGravity)
  object.setAllOutputNodes(false)
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
    sb.logError("rl_fieldcontrolconsole: console already activated")
    return {success=false, dungeonId=dungeonId}
  end
  if not self.validateDungeonId(dungeonId) then
    sb.logError("rl_fieldcontrolconsole: invalid dungeonId: %s", dungeonId)
    return {success=false, dungeonId=dungeonId}
  end
  if world.loadUniqueEntity(rl_fieldcontrol.fccUid(dungeonId)) ~= 0 then
    --sb.logInfo("rl_fieldcontrolconsole: dungeonId %s is already controlled; no action taken", dungeonId)
    return {success=false, dungeonId=dungeonId}
  end

  local origBreathable = world.breathable(self.position)
  local origGravity = world.gravity(self.position)

  local tiles = rl_fieldcontrol.getUnderlyingDungeonIds(self.spaces)
  rl_fieldcontrol.setUnderlyingDungeonId(tiles, dungeonId)
  if world.isTileProtected(self.position) then
    --sb.logInfo("rl_fieldcontrolconsole: dungeonId %s is reserved; reverting", dungeonId)
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
  object.setOutputNodeLevel(self.breathableOutputNode, origBreathable)
  setConsoleAnimation("shieldsdown")
  animator.playSound("register")
  return {
    success=true,
    dungeonId=dungeonId,
    breathable=origBreathable,
    gravity=origGravity,
    hazardProtection=getHazardProtectionStatus(),
    protection=false
  }
end

function setBulkheadMode(_, _, bulkheadMode)
  if bulkheadMode == nil then bulkheadMode = false end
  if not bulkheadMode and storage.bulkheadMode then
    storage.bulkheadMode = bulkheadMode
    -- We are leaving bulkhead mode. Probe to find the current state of
    -- the object.
    local currentProtection = world.isTileProtected(self.position)
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
  object.setOutputNodeLevel(self.breathableOutputNode, breathable)

  -- When using Dynamic Status Effects and we set the dungeon to be
  -- airless, then add the `biomeairless` status effect to the dungeon
  -- so that players get warned if they don't have breath protection.
  local manager = getDynamicStatusEffectsManager()
  if manager then
    if breathable then
      world.sendEntityMessage(manager, "clearEffects",
        storage.dungeonId, "rl_fieldcontrolconsole_airless"
      )
    else
      world.sendEntityMessage(manager, "setEffects",
        storage.dungeonId, "rl_fieldcontrolconsole_airless", {"biomeairless"}
      )
    end
  end
end

function setDungeonGravity(_, _, gravity)
  if not gravity then gravity = 80 end
  gravity = util.clamp(gravity, -10, 100)
  world.setDungeonGravity(storage.dungeonId, gravity)
end

function setDungeonHazardProtection(_, _, protection)
  if protection == nil then protection = false end
  local manager = getDynamicStatusEffectsManager()
  if not manager then
    sb.logError("rl_fieldcontrolconsole: failed to set or clear dungeon %s status effects", storage.dungeonId)
    return
  end
  if protection then
    world.sendEntityMessage(manager, "setEffects",
      storage.dungeonId, "rl_fieldcontrolconsole", self.hazardProtection
    )
  else
    world.sendEntityMessage(manager, "clearEffects",
      storage.dungeonId, "rl_fieldcontrolconsole"
    )
  end
  return true
end

function setDungeonTileProtection(_, _, protection)
  if protection == nil then protection = false end
  local currentProtection = world.isTileProtected(self.position)
  if not currentProtection and protection then
    setConsoleAnimation("shieldsup")
    animator.playSound("shieldsUp")
    world.setTileProtection(storage.dungeonId, protection)
    object.setOutputNodeLevel(self.protectionOutputNode, true)
  elseif currentProtection and not protection then
    setConsoleAnimation("shieldsdown")
    animator.playSound("shieldsDown")
    world.setTileProtection(storage.dungeonId, protection)
    object.setOutputNodeLevel(self.protectionOutputNode, false)
  end
end

function setUnregisteredDungeonId(_, _, dungeonId)
  if not self.validateDungeonId(dungeonId) then
    sb.logError("rl_fieldcontrolconsole: invalid dungeonId: %s", dungeonId)
    return
  end
  storage.unregisteredDungeonId = dungeonId
end

function applyInitialConfiguration()
  if type(self.initialConfig) ~= "table" then return end
  if storage.dungeonId then
    sb.logWarn("rl_fieldcontrolconsole: ignoring initialConfiguration: console already activated")
    return
  end
  if self.initialConfig.dungeonId ~= nil then
    if type(self.initialConfig.dungeonId) ~= "number" then
      sb.logError("rl_fieldcontrolconsole: ignoring initialConfiguration: invalid dungeonId: %s", sb.printJson(self.initialConfig.dungeonId))
      return
    end
    self.initialConfig.dungeonId = math.floor(self.initialConfig.dungeonId)
    if not self.validateDungeonId(self.initialConfig.dungeonId) then
      sb.logError("rl_fieldcontrolconsole: ignoring initialConfiguration: invalid dungeonId: %s", self.initialConfig.dungeonId)
      return
    end
    storage.unregisteredDungeonId = self.initialConfig.dungeonId
  elseif self.initialConfig.dungeonIdOffset ~= nil then
    if type(self.initialConfig.dungeonIdOffset) ~= "number" then
      sb.logError("rl_fieldcontrolconsole: ignoring initialConfiguration: invalid dungeonIdOffset: %s", sb.printJson(self.initialConfig.dungeonIdOffset))
      return
    end
    local dungeonId = world.dungeonId(self.position) + self.initialConfig.dungeonIdOffset
    if not self.validateDungeonId(dungeonId) then
      sb.logError("rl_fieldcontrolconsole: ignoring initialConfiguration: invalid dungeonId: %s", dungeonId)
      return
    end
    storage.unregisteredDungeonId = dungeonId
  end
  if not storage.unregisteredDungeonId then
    storage.unregisteredDungeonId = rl_fieldcontrol.currentOrRandomDungeonId(
      self.position, self.validateDungeonId
    )
  end
  if self.initialConfig.activate == true then
    local response = registerDungeonId(_, _, storage.unregisteredDungeonId)
    if not response.success then
      sb.logWarn("rl_fieldcontrolconsole: initialConfiguration failed to activate with dungeonId: %s", response.dungeonId)
    end
  end
  if self.initialConfig.breathable ~= nil then
    if not storage.dungeonId then
      sb.logWarn("rl_fieldcontrolconsole: ignoring initialConfiguration.breathable: console not activated")
    else
      setDungeonBreathable(_, _, not not self.initialConfig.breathable)
    end
  end
  if type(self.initialConfig.gravity) == "number" then
    if not storage.dungeonId then
      sb.logWarn("rl_fieldcontrolconsole: ignoring initialConfiguration.gravity: console not activated")
    else
      setDungeonGravity(_, _, math.floor(self.initialConfig.gravity / 5) * 5)
    end
  end
  if self.initialConfig.hazardProtection ~= nil then
    if not self.enableHazardProtection then
      sb.logWarn("rl_fieldcontrolconsole: ignoring initialConfiguration.hazardProtection: dynamic status effects not supported")
    elseif not storage.dungeonId then
      sb.logWarn("rl_fieldcontrolconsole: ignoring initialConfiguration.hazardProtection: console not activated")
    else
      if #self.hazardProtection > 0 then
        setDungeonHazardProtection(_, _, not not self.initialConfig.hazardProtection)
      end
    end
  end
  if self.initialConfig.tileProtection ~= nil then
    if not storage.dungeonId then
      sb.logWarn("rl_fieldcontrolconsole: ignoring initialConfiguration.protection: console not activated")
    else
      setDungeonTileProtection(_, _, not not self.initialConfig.tileProtection)
    end
  end
  if self.initialConfig.bulkheadMode ~= nil then
    setBulkheadMode(_, _, not not self.initialConfig.bulkheadMode)
  end
end

function buildHazardProtection()
  local hazardProtection = {}

  for _,statusEffect in ipairs(world.environmentStatusEffects({0, 0})) do
    if type(statusEffect) == "string" then
      local blockingStat = self.hazardProtectionConfig[statusEffect]
      if blockingStat then
        hazardProtection[blockingStat.stat] = blockingStat
      end
    end
  end

  for _,statusEffect in ipairs(world.getProperty(
    "rl_dynamicstatuseffects_global"
  ) or {}) do
    if type(statusEffect) == "string" then
      local blockingStat = self.hazardProtectionConfig[statusEffect]
      if blockingStat then
        hazardProtection[blockingStat.stat] = blockingStat
      end
    end
  end

  if storage.dungeonId then
    for _,statusEffect in ipairs(world.getProperty(
      string.format("rl_dynamicstatuseffects_%s", storage.dungeonId)
    ) or {}) do
      if type(statusEffect) == "string" then
        local blockingStat = self.hazardProtectionConfig[statusEffect]
        if blockingStat then
          hazardProtection[blockingStat.stat] = blockingStat
        end
      end
    end
  end

  self.hazardProtection = util.values(hazardProtection)
end

function getDynamicStatusEffectsManager()
  if not self.enableHazardProtection or not storage.dungeonId then return end
  local uid = string.format("rl_dynamicstatuseffects_global")
  local manager = world.loadUniqueEntity(uid)
  if manager == 0 then
    world.spawnStagehand({10, 10}, "rl_dynamicstatuseffectsmanager")
    manager = world.loadUniqueEntity(uid)
  end
  if manager == 0 then
    sb.logError("rl_fieldcontrolconsole: failed to spawn rl_dynamicstatuseffectsmanager")
    return
  end
  return manager
end

-- With rl_dynamicstatuseffects, environment hazards are no longer
-- static. This function checks whether the current hazard protection
-- covers the current set of coverable environment hazards. A return
-- value of `nil` means that rl_dynamicstatuseffects is not in use, the
-- field control console is not activated, no coverable environment
-- hazards exist, or an error occurred. A return value of `false` means
-- that at least one coverable environment hazard is not covered by the
-- current hazard protection, and a return value of `true` means that
-- all coverable environmental hazards are covered.
function getHazardProtectionStatus()
  local manager = getDynamicStatusEffectsManager()
  if not manager then return end
  buildHazardProtection()
  if #self.hazardProtection < 1 then return end
  local effects = world.sendEntityMessage(manager, "getEffects",
    storage.dungeonId, "rl_fieldcontrolconsole"
  ):result()
  for _,blockingStat in ipairs(self.hazardProtection) do
    local effect = effects[blockingStat.stat]
    if type(effect) ~= "table" or not effect.amount or effect.amount <= 0 then
      return false
    end
  end
  return true
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
