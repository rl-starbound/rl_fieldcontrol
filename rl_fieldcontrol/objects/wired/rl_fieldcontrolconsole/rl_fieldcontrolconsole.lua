require "/scripts/rl_fieldcontrol.lua"
require "/scripts/util.lua"
require "/scripts/vec2.lua"

local fccHazardProtectionStatus = rl_fieldcontrol.fccHazardProtectionStatus
local fccVisibilityValue = rl_fieldcontrol.fccVisibilityValue

function init()
  self.position = entity.position()
  self.spaces = util.map(object.spaces(), function(v)
      return vec2.add(self.position, v)
    end)

  local versioning = root.assetJson("/versioning.config")

  self.fuCompatibility = not not versioning.FrackinUniverse

  self.enableHazardProtection = not not versioning.rl_dynamicstatuseffects
  self.hazardProtectionConfig = self.enableHazardProtection and
    root.assetJson("/rl_fieldcontrol_hazardprotection.config") or {}

  self.initialConfig = config.getParameter("initialConfiguration")

  self.validateDungeonId = rl_fieldcontrol.dungeonIdValidator(
    rl_fieldcontrol.fccDungeonIdRange
  )

  if storage.bulkheadMode then
    -- Migrate to v2 visibility format.
    storage.visibilityMode = fccVisibilityValue.bulkhead
    storage.bulkheadMode = nil
  end

  if storage.gravityOverride == nil then
    -- Prior to v3, gravity override was assumed active if the field
    -- control console was active.
    storage.gravityOverride = not not storage.dungeonId
  end

  local tileProtection = isTileProtectionActive()
  getHazardProtectionStatus()

  if storage.dungeonId then
    -- Aggressively reset the dungeon ID of tiles underlying the console.
    resetUnderlyingTiles()

    setConsoleAnimation(tileProtection and "shieldsup" or "shieldsdown")
  else
    setConsoleAnimation("unregistered")
  end

  self.iNodes = {
    gravityOverride=0,
    tileProtection=1,
    breathable=2,
    hazardProtection=3
  }

  self.oNodes = {
    gravityOverride=0,
    tileProtection=1,
    breathable=2,
    hazardProtection=3,
    fccActive=4
  }

  object.setOutputNodeLevel(self.oNodes.fccActive, storage.dungeonId)
  object.setOutputNodeLevel(self.oNodes.gravityOverride,
    storage.dungeonId and storage.gravityOverride
  )
  object.setOutputNodeLevel(self.oNodes.tileProtection,
    storage.dungeonId and isTileProtectionActive()
  )
  object.setOutputNodeLevel(self.oNodes.breathable,
    storage.dungeonId and self.oxygenAvailable and isBreathable()
  )
  object.setOutputNodeLevel(self.oNodes.hazardProtection,
    storage.dungeonId and self.hazardProtectionActive
  )

  -- Wait 1 second before attempting to apply initial configuration.
  self.initialConfigDelayTime = 1

  -- Wait 1 second between sync checks.
  self.fieldSyncTime = 1
  self.fieldSyncTimer = self.fieldSyncTime

  message.setHandler("deregisterDungeonId", deregisterDungeonId)
  message.setHandler("registerDungeonId", registerDungeonId)
  message.setHandler("setBreathable", setBreathable)
  message.setHandler("setGravity", setGravity)
  message.setHandler("setHazardProtection", setHazardProtection)
  message.setHandler("setPassword", setPassword)
  message.setHandler("setTileProtection", setTileProtection)
  message.setHandler("setUnregisteredDungeonId", setUnregisteredDungeonId)
  message.setHandler("setVisibilityMode", setVisibilityMode)
  message.setHandler("syncFieldData", syncFieldData)
end

function die(smash)
  deregisterDungeonId(_, _, true)
end

function onInputNodeChange(args)
  if args.node == self.iNodes.gravityOverride then
    setGravity(_, _, args.level)
  elseif args.node == self.iNodes.tileProtection then
    setTileProtection(_, _, args.level)
  elseif args.node == self.iNodes.breathable then
    setBreathable(_, _, args.level)
  elseif args.node == self.iNodes.hazardProtection then
    setHazardProtection(_, _, args.level)
  else
    logWarn("unknown input node: %s", args.node)
  end
end

function onNodeConnectionChange()
  if object.isInputNodeConnected(self.iNodes.gravityOverride) then
    setGravity(_, _,
      object.getInputNodeLevel(self.iNodes.gravityOverride)
    )
  end
  if object.isInputNodeConnected(self.iNodes.tileProtection) then
    setTileProtection(_, _,
      object.getInputNodeLevel(self.iNodes.tileProtection)
    )
  end
  if object.isInputNodeConnected(self.iNodes.breathable) then
    setBreathable(_, _,
      object.getInputNodeLevel(self.iNodes.breathable)
    )
  end
  if object.isInputNodeConnected(self.iNodes.hazardProtection) then
    setHazardProtection(_, _,
      object.getInputNodeLevel(self.iNodes.hazardProtection)
    )
  end
end

function onInteraction()
  if not storage.initialConfigApplied then return end
  if storage.dungeonId then
    -- Aggressively reset the dungeon ID of tiles underlying the console.
    resetUnderlyingTiles()
  end
  if not storage.unregisteredDungeonId then
    storage.unregisteredDungeonId = rl_fieldcontrol.currentOrRandomDungeonId(
      self.position, self.validateDungeonId
    )
  end

  local interactData = root.assetJson(config.getParameter("interactData"))
  interactData.passwordHash = storage.passwordHash
  interactData.registeredDungeonId = storage.dungeonId
  interactData.unregisteredDungeonId = storage.unregisteredDungeonId
  interactData.visibilityMode = storage.visibilityMode
  if storage.dungeonId then
    local hazardProtectionStatus = getHazardProtectionStatus()

    interactData.gravity = getGravity(true)
    interactData.gravityOverride = storage.gravityOverride
    interactData.gravityWired = object.isInputNodeConnected(self.iNodes.gravityOverride)
    interactData.tileProtection = isTileProtectionActive(true)
    interactData.tileProtectionWired = object.isInputNodeConnected(self.iNodes.tileProtection)
    interactData.breathable = isBreathable(true, true, true)
    interactData.breathableWired = object.isInputNodeConnected(self.iNodes.breathable)
    interactData.oxygenAvailable = self.oxygenAvailable
    interactData.hazardProtection = self.hazardProtectionActive
    interactData.hazardProtectionStatus = hazardProtectionStatus
    interactData.hazardProtectionWired = object.isInputNodeConnected(self.iNodes.hazardProtection)
  end

  -- This function syncs the fields, so no need to follow it immediately
  -- with another sync.
  self.fieldSyncTimer = self.fieldSyncTime

  return {config.getParameter("interactAction"), interactData}
end

function update(dt)
  if not storage.initialConfigApplied then
    self.initialConfigDelayTime = self.initialConfigDelayTime - dt
    if self.initialConfigDelayTime <= 0 then
      applyInitialConfiguration()
      storage.initialConfigApplied = true
    end
  end

  -- World properties can be changed independently of this console, so
  -- ensure that object state is synced with world state.
  if storage.dungeonId then
    self.fieldSyncTimer = self.fieldSyncTimer - dt
    if self.fieldSyncTimer <= 0 then
      -- Aggressively reset the dungeon ID of tiles underlying the console.
      resetUnderlyingTiles()

      getGravity(true)

      isTileProtectionActive(true)

      -- Without calling `getHazardProtectionStatus` in every sync
      -- interval, we must use cached values for `self.oxygenAvailable`
      -- and `self.hazardProtectionActive`. These may become out of sync
      -- with the world, but that avoids making an expensive function
      -- call in every sync interval. They will be synced every time the
      -- player interacts with the field control console.

      isBreathable(true)

      if self.hazardProtectionActive ~= object.getOutputNodeLevel(self.oNodes.hazardProtection) then
        object.setOutputNodeLevel(self.oNodes.hazardProtection, self.hazardProtectionActive)
      end

      self.fieldSyncTimer = self.fieldSyncTime
    end
  end
end

------------------------------------------------------------------------
-- Message Handlers
------------------------------------------------------------------------

function deregisterDungeonId(_, _, skipAnimation)
  if not storage.dungeonId then return end

  local manager = getDynamicStatusEffectsManager()
  if manager then
    world.sendEntityMessage(manager, "clearEffects",
      storage.dungeonId, "rl_fieldcontrolconsole"
    )
    world.sendEntityMessage(manager, "clearEffects",
      storage.dungeonId, "rl_fieldcontrolconsole_airless"
    )
  elseif self.enableHazardProtection then
    -- If Belter Dungeons is installed, we want to see a log message
    -- for this condition, because it means that an error occurred. If
    -- it's not installed, the condition is expected and normal.
    logError("possibly failed to clear dungeon %s status effects", storage.dungeonId)
  end

  world.setDungeonBreathable(storage.dungeonId, storage.origBreathable)
  world.setDungeonGravity(storage.dungeonId, storage.origGravity)
  if isTileProtectionActive() then
    world.setTileProtection(storage.dungeonId, false)
  end

  object.setAllOutputNodes(false)
  object.setUniqueId()

  storage.dungeonId = nil
  storage.origBreathable = nil
  storage.gravityOverride = false
  storage.origGravity = nil
  storage.targetGravity = nil

  if not skipAnimation then
    setConsoleAnimation("unregistered")
    animator.playSound("deregister")
  end
end

function registerDungeonId(_, _, dungeonId, skipAudio)
  if storage.dungeonId then
    logError("console already activated")
    return {success=false, dungeonId=dungeonId}
  end
  if not self.validateDungeonId(dungeonId) then
    logError("invalid dungeonId: %s", dungeonId)
    return {success=false, dungeonId=dungeonId}
  end
  if world.loadUniqueEntity(rl_fieldcontrol.fccUid(dungeonId)) ~= 0 then
    logInfo("dungeonId %s is already controlled; no action taken", dungeonId)
    return {success=false, dungeonId=dungeonId}
  end

  local origBreathable = world.breathable(self.position)
  local origGravity = world.gravity(self.position)

  local tiles = rl_fieldcontrol.getUnderlyingDungeonIds(self.spaces)
  rl_fieldcontrol.setUnderlyingDungeonId(tiles, dungeonId)
  if isTileProtectionActive() then
    logInfo("dungeonId %s is reserved; reverting", dungeonId)
    rl_fieldcontrol.setUnderlyingDungeonId(tiles)
    return {success=false, dungeonId=dungeonId}
  end

  self.fieldSyncTimer = self.fieldSyncTime
  storage.dungeonId = dungeonId
  storage.origBreathable = origBreathable
  storage.origGravity = origGravity
  storage.targetGravity = storage.targetGravity or origGravity

  object.setUniqueId(rl_fieldcontrol.fccUid(dungeonId))
  object.setOutputNodeLevel(self.oNodes.fccActive, true)
  if not skipAudio then animator.playSound("register") end

  local hazardProtectionStatus = getHazardProtectionStatus()

  -- You've just changed the dungeonId of the region under this object.
  -- Depending on the world, that new dungeonId might have different
  -- properties than the previous one. Set the properties of the new
  -- dungeonId to match the original, while respecting the input nodes,
  -- if they are connected.
  if object.isInputNodeConnected(self.iNodes.gravityOverride) then
    setGravity(_, _,
      object.getInputNodeLevel(self.iNodes.gravityOverride)
    )
  else
    setGravity(_, _, false)
  end
  if object.isInputNodeConnected(self.iNodes.tileProtection) then
    setTileProtection(_, _,
      object.getInputNodeLevel(self.iNodes.tileProtection), true
    )
  else
    setTileProtection(_, _, false, true)
  end
  if object.isInputNodeConnected(self.iNodes.breathable) then
    setBreathable(_, _,
      object.getInputNodeLevel(self.iNodes.breathable), true
    )
  else
    setBreathable(_, _, origBreathable, true)
  end
  if object.isInputNodeConnected(self.iNodes.hazardProtection) then
    setHazardProtection(_, _,
      object.getInputNodeLevel(self.iNodes.hazardProtection), true
    )
  else
    setHazardProtection(_, _, false, true)
  end

  return {
    success=true,
    dungeonId=dungeonId,
    gravity=storage.targetGravity,
    gravityOverride=storage.gravityOverride,
    gravityWired=object.isInputNodeConnected(self.iNodes.gravityOverride),
    tileProtection=isTileProtectionActive(),
    tileProtectionWired=object.isInputNodeConnected(self.iNodes.tileProtection),
    breathable=isBreathable(),
    breathableWired=object.isInputNodeConnected(self.iNodes.breathable),
    oxygenAvailable=self.oxygenAvailable,
    hazardProtection=self.hazardProtectionActive,
    hazardProtectionStatus=hazardProtectionStatus,
    hazardProtectionWired=object.isInputNodeConnected(self.iNodes.hazardProtection)
  }
end

-- `breathable` can be altered only when the console is active and
-- either the breathable input node is not wired, or the desired
-- breathable state equals the wiring's input level. Evaluating hazard
-- protection is somewhat burdensome, so `skipBuildHazardProtection` can
-- be set to true if and only if it has already been evaluated during
-- this tick. If `skipWarning` is true, the airless warning will not be
-- evaluated; this should be set only if something else will evaluate
-- that warning during this tick.
function setBreathable(_, _, breathable, skipBuildHazardProtection, skipWarning)
  if not storage.dungeonId then return end
  if breathable == nil then breathable = true else breathable = not not breathable end
  if object.isInputNodeConnected(self.iNodes.breathable) and
     object.getInputNodeLevel(self.iNodes.breathable) ~= breathable
  then
    logError("cannot alter atmosphere: wired")
    return
  end
  world.setDungeonBreathable(storage.dungeonId, breathable)
  if not skipBuildHazardProtection then buildHazardProtection() end
  object.setOutputNodeLevel(self.oNodes.breathable, self.oxygenAvailable and breathable)
  if not skipWarning then warnAirless(breathable) end
  return true
end

-- `targetGravity` can be altered regardless of activation state or
-- wiring, but the world gravity will only be altered if the console is
-- active and the gravity override is on. `gravityOverride` can only be
-- altered when the console is active and either the gravity input node
-- is not wired, or the desired gravity state equals the wiring's input
-- level.
function setGravity(_, _, gravityOverride, targetGravity)
  gravityOverride = not not gravityOverride
  if not object.isInputNodeConnected(self.iNodes.gravityOverride) or
     object.getInputNodeLevel(self.iNodes.gravityOverride) == gravityOverride
  then
    if storage.dungeonId then storage.gravityOverride = gravityOverride end
    retval = true
  elseif storage.dungeonId then
    logError("cannot alter gravity override: wired")
  end
  if type(targetGravity) == "number" then storage.targetGravity = targetGravity end
  if storage.dungeonId then
    world.setDungeonGravity(storage.dungeonId,
      storage.gravityOverride and storage.targetGravity or storage.origGravity
    )
    object.setOutputNodeLevel(self.oNodes.gravityOverride, storage.gravityOverride)
  end
  return retval
end

-- `protection` can be altered only when the console is active and
-- either the hazard protection input node is not wired, or the desired
-- protection state equals the wiring's input level. Evaluating hazard
-- protection is somewhat burdensome, so `skipBuildHazardProtection` can
-- be set to true if and only if it has already been evaluated during
-- this tick.
function setHazardProtection(_, _, protection, skipBuildHazardProtection)
  if not storage.dungeonId then return end
  if protection == nil then protection = false else protection = not not protection end
  if object.isInputNodeConnected(self.iNodes.hazardProtection) and
     object.getInputNodeLevel(self.iNodes.hazardProtection) ~= protection
  then
    logError("cannot alter hazard protection: wired")
    return
  end
  if not skipBuildHazardProtection then buildHazardProtection() end
  if #self.hazardProtection < 1 then
    self.hazardProtectionActive = true
    object.setOutputNodeLevel(self.oNodes.hazardProtection, true)
    return protection
  end
  local manager = getDynamicStatusEffectsManager()
  if not manager then
    if self.enableHazardProtection then
      -- If Belter Dungeons is installed, we want to see a log message
      -- for this condition, because it means that an error occurred. If
      -- it's not installed, the condition is expected and normal.
      logError("failed to set or clear dungeon %s status effects", storage.dungeonId)
    end
    self.hazardProtectionActive = false
    object.setOutputNodeLevel(self.oNodes.hazardProtection, false)
    return not protection
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
  self.hazardProtectionActive = protection
  object.setOutputNodeLevel(self.oNodes.hazardProtection, protection)
  return true
end

function setPassword(_, _, passwordHash)
  storage.passwordHash = passwordHash
end

-- `protection` can be altered only when the console is active and
-- either the tile protection input node is not wired, or the desired
-- protection state equals the wiring's input level. If `skipAudio` is
-- set to true, the animation sound of the shield raising or lowering
-- will be skipped.
function setTileProtection(_, _, protection, skipAudio)
  if not storage.dungeonId then return end
  if protection == nil then protection = false else protection = not not protection end
  if object.isInputNodeConnected(self.iNodes.tileProtection) and
     object.getInputNodeLevel(self.iNodes.tileProtection) ~= protection
  then
    logError("cannot alter tile protection: wired")
    return
  end
  local currentTileProtection = world.isTileProtected(self.position)
  if not currentTileProtection and protection then
    world.setTileProtection(storage.dungeonId, true)
    if not skipAudio then animator.playSound("shieldsUp") end
  elseif currentTileProtection and not protection then
    world.setTileProtection(storage.dungeonId, false)
    if not skipAudio then animator.playSound("shieldsDown") end
  end
  setConsoleAnimation(protection and "shieldsup" or "shieldsdown")
  object.setOutputNodeLevel(self.oNodes.tileProtection, protection)
  return true
end

function setUnregisteredDungeonId(_, _, dungeonId)
  if not self.validateDungeonId(dungeonId) then
    logError("invalid dungeonId: %s", dungeonId)
    return
  end
  storage.unregisteredDungeonId = dungeonId
end

function setVisibilityMode(_, _, mode)
  -- Validate the numeric visibility `mode`. Any value other than
  -- "bulkhead" or "hidden" will result in `nil` being used.
  mode = tonumber(mode)
  if mode ~= nil then mode = math.floor(mode) end
  local modeStr = rl_fieldcontrol.fccVisibility[mode]
  if mode ~= nil and modeStr == nil then
    logError("setVisibilityMode: ignoring invalid mode: %s", mode)
    mode = nil
  end
  if mode == nil and storage.visibilityMode ~= nil then
    -- We are leaving a special visibility mode. Probe to find the
    -- current state of the object.
    storage.visibilityMode = mode
    if storage.dungeonId then
      setConsoleAnimation(isTileProtectionActive() and "shieldsup" or "shieldsdown")
    else
      setConsoleAnimation("unregistered")
    end
  elseif mode ~= nil then
    storage.visibilityMode = mode
    setConsoleAnimation(modeStr)
  end
end

function syncFieldData(_, _)
  return {
    dungeonId=storage.dungeonId,
    passwordHash=storage.passwordHash,
    gravity=getGravity(),
    gravityOverride=storage.gravityOverride,
    gravityWired=object.isInputNodeConnected(self.iNodes.gravityOverride),
    tileProtection=isTileProtectionActive(),
    tileProtectionWired=object.isInputNodeConnected(self.iNodes.tileProtection),
    breathable=isBreathable(),
    breathableWired=object.isInputNodeConnected(self.iNodes.breathable),
    oxygenAvailable=self.oxygenAvailable,
    hazardProtection=self.hazardProtectionActive,
    hazardProtectionWired=object.isInputNodeConnected(self.iNodes.hazardProtection),
    unregisteredDungeonId=storage.unregisteredDungeonId,
    visibilityMode=storage.visibilityMode
  }
end

------------------------------------------------------------------------
-- Accessors / Remediation
--
-- Each accessor returns the current state of the relevant dungeon ID
-- belonging to this console. If `doRemediation` is true, then if the
-- current state does not match the wired state (if applicable), it will
-- be corrected before returning the state. If `doRemediation` is not
-- true, then the returned state may be inconsistent with the wired
-- state (if applicable).
------------------------------------------------------------------------

function getGravity(doRemediation)
  local retval = storage.gravityOverride and world.gravity(self.position) or
    storage.targetGravity or storage.origGravity

  if doRemediation and storage.gravityOverride then
    storage.targetGravity = retval
  end

  return retval
end

function isBreathable(doRemediation, skipBuildHazardProtection, forceWarning)
  local retval = world.breathable(self.position)

  if doRemediation then
    local wired = nil
    if object.isInputNodeConnected(self.iNodes.breathable) then
      wired = object.getInputNodeLevel(self.iNodes.breathable)
    end
    if wired ~= nil and retval ~= wired then
      retval = wired
      setBreathable(_, _, retval, skipBuildHazardProtection, forceWarning)
    else
      local output = self.oxygenAvailable and retval
      if output ~= object.getOutputNodeLevel(self.oNodes.breathable) then
        object.setOutputNodeLevel(self.oNodes.breathable, output)
      end
    end

    -- For complete correctness, we should always warn users if the
    -- dungeon has been made airless by an external entity, or always
    -- remove the warning if air has been provided by an external
    -- entity. If done naively, this would result in this code updating
    -- dynamic status effects on nearly every sync, which we don't want,
    -- so we must ensure it happens only on interaction, and accept that
    -- the warning may be out of sync sometimes.
    if forceWarning then warnAirless(retval) end
  end

  return retval
end

function isTileProtectionActive(doRemediation)
  local retval = world.isTileProtected(self.position)

  if doRemediation then
    local wired = nil
    if object.isInputNodeConnected(self.iNodes.tileProtection) then
      wired = object.getInputNodeLevel(self.iNodes.tileProtection)
    end
    if wired ~= nil and retval ~= wired then
      retval = wired
      setTileProtection(_, _, retval)
    else
      setConsoleAnimation(retval and "shieldsup" or "shieldsdown")
      if retval ~= object.getOutputNodeLevel(self.oNodes.tileProtection) then
        animator.playSound(retval and "shieldsUp" or "shieldsDown")
        object.setOutputNodeLevel(self.oNodes.tileProtection, retval)
      end
    end
  end

  return retval
end

function resetUnderlyingTiles()
  for _,v in ipairs(self.spaces) do
    world.setDungeonId({v[1], v[2], v[1] + 1, v[2] + 1}, storage.dungeonId)
  end
end

------------------------------------------------------------------------
-- Initial Configuration
------------------------------------------------------------------------

-- For use in pre-built dungeons, the parameters JSON table may contain
-- an `initialConfiguration` key, which must contain a JSON table. All
-- keys in this table are optional. For example:
--
--   {
--     "dungeonIdOffset" : 10,
--     "activate" : true,
--     "password" : "Password1!",
--     "visibilityMode" : "bulkhead",
--     "targetGravity" : 10,
--     "gravityOverride" : true,
--     "tileProtection" : true,
--     "breathable" : true,
--     "hazardProtection" : true
--   }
--
-- If given, "dungeonId" must be a valid dungeon ID. If a static ID is
-- not desirable, "dungeonIdOffset" may be given, and will be added to
-- the current dungeon ID at position to generate the desired dungeon
-- ID; this must resolve to a valid ID, if given. If neither "dungeonId"
-- nor "dungeonIdOffset" are given, the dungeon ID of position will be
-- used if it is valid, otherwise a random dungeon ID will be used.
--
-- The keys "password", "visibilityMode", and "targetGravity" may be
-- given regardless of whether the console is activated. The other keys
-- will be used only if the console is activated.
function applyInitialConfiguration()
  local cfg = self.initialConfig
  if not cfg then return end
  if type(cfg) ~= "table" then
    logError("aborting initialConfiguration: invalid configuration")
    return
  end

  if storage.dungeonId then
    logWarn("aborting initialConfiguration: console already activated")
    return
  end

  if cfg.dungeonId ~= nil then
    if type(cfg.dungeonId) ~= "number" then
      logError("aborting initialConfiguration: invalid dungeonId: %s", sb.printJson(cfg.dungeonId))
      return
    end
    cfg.dungeonId = math.floor(cfg.dungeonId)
    if not self.validateDungeonId(cfg.dungeonId) then
      logError("aborting initialConfiguration: invalid dungeonId: %s", cfg.dungeonId)
      return
    end
    storage.unregisteredDungeonId = cfg.dungeonId
  elseif cfg.dungeonIdOffset ~= nil then
    if type(cfg.dungeonIdOffset) ~= "number" then
      logError("aborting initialConfiguration: invalid dungeonIdOffset: %s", sb.printJson(cfg.dungeonIdOffset))
      return
    end
    local dungeonId = world.dungeonId(self.position) + math.floor(cfg.dungeonIdOffset)
    if not self.validateDungeonId(dungeonId) then
      logError("aborting initialConfiguration: invalid dungeonId: %s", dungeonId)
      return
    end
    storage.unregisteredDungeonId = dungeonId
  end
  if not storage.unregisteredDungeonId then
    storage.unregisteredDungeonId = rl_fieldcontrol.currentOrRandomDungeonId(
      self.position, self.validateDungeonId
    )
  end

  if cfg.password ~= nil then
    if type(cfg.password) ~= "string" or #cfg.password == 0 then
      logError("initialConfiguration: ignoring invalid password")
    else
      storage.passwordHash = util.hashString(cfg.password)
    end
  end

  if cfg.targetGravity ~= nil then
    if type(cfg.targetGravity) ~= "number" then
      logError("initialConfiguration: ignoring invalid targetGravity: %s", sb.printJson(cfg.targetGravity))
    else
      setGravity(_, _, nil, math.floor(cfg.targetGravity / 5) * 5)
    end
  end

  if cfg.visibilityMode ~= nil then
    local mode = fccVisibilityValue[cfg.visibilityMode]
    if mode == nil then
      logError("initialConfiguration: ignoring invalid  visibilityMode: %s", sb.printJson(cfg.visibilityMode))
    else
      setVisibilityMode(_, _, mode)
    end
  elseif cfg.bulkheadMode then
    logWarn("initialConfiguration: bulkheadMode is deprecated; use visibilityMode instead")
    setVisibilityMode(_, _, fccVisibilityValue.bulkhead)
  end

  if cfg.activate then
    local response = registerDungeonId(_, _, storage.unregisteredDungeonId, true)
    if not response.success then
      logWarn("initialConfiguration: failed to activate: dungeonId %s", response.dungeonId)
    end
  end

  if cfg.gravityOverride ~= nil then
    if not storage.dungeonId then
      logWarn("initialConfiguration: ignoring gravityOverride: console not activated")
    else
      setGravity(_, _, cfg.gravityOverride)
    end
  elseif cfg.targetGravity == nil and cfg.gravity ~= nil then
    if type(cfg.gravity) ~= "number" then
      logError("initialConfiguration: ignoring invalid gravity: %s", sb.printJson(cfg.gravity))
    else
      if not storage.dungeonId then
        logWarn("initialConfiguration: ignoring gravity: console not activated")
      else
        logWarn("initialConfiguration: gravity is deprecated; use targetGravity and gravityOverride instead")
        setGravity(_, _, true, math.floor(cfg.gravity / 5) * 5)
      end
    end
  end

  if cfg.tileProtection ~= nil then
    if not storage.dungeonId then
      logWarn("initialConfiguration: ignoring tileProtection: console not activated")
    else
      setTileProtection(_, _, cfg.tileProtection, true)
    end
  end

  if cfg.breathable ~= nil then
    if not storage.dungeonId then
      logWarn("initialConfiguration: ignoring breathable: console not activated")
    else
      setBreathable(_, _, cfg.breathable, true)
    end
  end

  if cfg.hazardProtection ~= nil then
    if not self.enableHazardProtection then
      logWarn("initialConfiguration: ignoring hazardProtection: dynamic status effects not installed")
    elseif not storage.dungeonId then
      logWarn("initialConfiguration: ignoring hazardProtection: console not activated")
    else
      setHazardProtection(_, _, cfg.hazardProtection, true)
    end
  end
end

------------------------------------------------------------------------
-- Hazard Protection
------------------------------------------------------------------------

-- Enumerate all hazards present in the world statically, in the
-- `ffunknownWorldProp` world property, in global dynamic status
-- effects, and in dungeon-specific dynamic status effects. From these,
-- generate a list of `{stat="blockingStat", amount=number}` tables to
-- counteract the known hazards, stored in in `self.hazardProtection`.
-- Also, set `self.oxygenAvailable` to the inverse of whether the
-- `fu_nooxygen` status effect is present.
function buildHazardProtection()
  local hazardProtection = {}
  local oxygenAvailable = true

  for _,statusEffect in ipairs(world.environmentStatusEffects({0, 0})) do
    if type(statusEffect) == "string" then
      if statusEffect == "fu_nooxygen" then oxygenAvailable = false end
      local blockingStat = self.hazardProtectionConfig[statusEffect]
      if blockingStat then
        hazardProtection[blockingStat.stat] = blockingStat
      end
    end
  end

  -- Frackin' Universe includes some world types that are assigned
  -- randomly generated status effects the first time a player beams
  -- down to them.
  if self.fuCompatibility then
    local ffunknownWorldProp = world.getProperty("ffunknownWorldProp")
    if type(ffunknownWorldProp) == "table" and
       type(ffunknownWorldProp.effects) == "table"
    then
      for _,statusEffect in ipairs(ffunknownWorldProp.effects) do
        if type(statusEffect) == "string" then
          if statusEffect == "fu_nooxygen" then oxygenAvailable = false end
          local blockingStat = self.hazardProtectionConfig[statusEffect]
          if blockingStat then
            hazardProtection[blockingStat.stat] = blockingStat
          end
        end
      end
    end
  end

  for _,statusEffect in ipairs(world.getProperty(
    "rl_dynamicstatuseffects_global"
  ) or {}) do
    if type(statusEffect) == "string" then
      if statusEffect == "fu_nooxygen" then oxygenAvailable = false end
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
        if statusEffect == "fu_nooxygen" then oxygenAvailable = false end
        local blockingStat = self.hazardProtectionConfig[statusEffect]
        if blockingStat then
          hazardProtection[blockingStat.stat] = blockingStat
        end
      end
    end
  end

  self.hazardProtection = util.values(hazardProtection)
  self.oxygenAvailable = oxygenAvailable

  if self.debug then
    logInfo("hazard protection available: %s", sb.printJson(self.hazardProtection))
    logInfo("oxygen available: %s", sb.printJson(self.oxygenAvailable))
  end
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
    logError("failed to spawn rl_dynamicstatuseffectsmanager")
    return
  end
  return manager
end

-- With dynamic status effects (as defined in Belter Dungeons),
-- environment hazards are no longer static. This function checks
-- whether the current hazard protection covers the current set of
-- coverable environment hazards. A return value of `unnecessary` means
-- that no coverable environment hazards have been detected. A return
-- value of `unavailable` means that at least one coverable environment
-- hazard exists but Belter Dungeons is not installed, the field control
-- console is not activated, or an error occurred. A return value of
-- `available` means that at least one coverable environment hazard
-- exists and the field control console is ready and able to cover it.
-- The instance variable `self.hazardProtectionActive` is set to `true`
-- if all coverable environment hazards are covered by the current
-- hazard protection, and `false` otherwise.
--
-- (Note that return values of `unnecessary` or `available` and
-- `self.hazardProtectionActive` set to `true` can occur when hazards
-- that are unknown to this mod are in effect. Such hazards would
-- require mod extensions to cover, e.g., Arcana and Frackin' Universe.)
function getHazardProtectionStatus()
  local retval = fccHazardProtectionStatus.unavailable
  self.hazardProtectionActive = false

  buildHazardProtection()

  if #self.hazardProtection < 1 then
    retval = fccHazardProtectionStatus.unnecessary
    self.hazardProtectionActive = true
  else
    local manager = getDynamicStatusEffectsManager()
    if manager then
      retval = fccHazardProtectionStatus.available
      self.hazardProtectionActive = true

      -- Iterate over the known hazard protections currently available,
      -- and identify if any are not currently enabled.
      local effects = world.sendEntityMessage(manager, "getEffects",
        storage.dungeonId, "rl_fieldcontrolconsole"
      ):result()
      for _,blockingStat in ipairs(self.hazardProtection) do
        local effect = effects[blockingStat.stat]
        if type(effect) ~= "table" or type(effect.amount) ~= "number" or
           effect.amount <= 0
        then
          self.hazardProtectionActive = false
          break
        end
      end
    end
  end

  return retval
end

function warnAirless(breathable)
  -- When using Dynamic Status Effects and we set the dungeon to be
  -- airless, add the `biomeairless` status effect to the dungeon so
  -- that players get warned if they don't have breath protection.
  local manager = getDynamicStatusEffectsManager()
  if manager then
    if breathable then
      world.sendEntityMessage(manager, "clearEffects",
        self.dungeonId, "rl_fieldcontrolconsole_airless"
      )
    else
      world.sendEntityMessage(manager, "setEffects",
        self.dungeonId, "rl_fieldcontrolconsole_airless", {"biomeairless"}
      )
    end
  elseif self.enableHazardProtection then
    -- If Belter Dungeons is installed, we want to see a log message
    -- for this condition, because it means that an error occurred. If
    -- it's not installed, the condition is expected and normal.
    logError("failed to set or clear dungeon %s airless status effect", storage.dungeonId)
  end
end

------------------------------------------------------------------------
-- Utilities
------------------------------------------------------------------------

function logError(fmt, ...)
  sb.logError(
    "rl_fieldcontrolconsole: %s", string.format(fmt, table.unpack({...}))
  )
end

function logWarn(fmt, ...)
  sb.logWarn(
    "rl_fieldcontrolconsole: %s", string.format(fmt, table.unpack({...}))
  )
end

function logInfo(fmt, ...)
  sb.logInfo(
    "rl_fieldcontrolconsole: %s", string.format(fmt, table.unpack({...}))
  )
end

function setConsoleAnimation(state)
  if storage.visibilityMode == fccVisibilityValue.bulkhead then
    animator.setAnimationState("consoleState", "bulkhead")
  elseif storage.visibilityMode == fccVisibilityValue.hidden then
    animator.setAnimationState("consoleState", "hidden")
  else
    animator.setAnimationState("consoleState", state)
  end
end
