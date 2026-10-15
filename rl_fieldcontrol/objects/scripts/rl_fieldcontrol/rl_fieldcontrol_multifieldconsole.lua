------------------------------------------------------------------------
-- This script is not intended to be used directly as an object script.
-- Instead, it is intended to be loaded by a shim script.
--
-- The shim must provide an `init` function that ensures the correct
-- version of Field Control Technology is installed before loading this
-- script and calling `rl_fieldcontrol_multifieldconsole_init` with a
-- mandatory `worldType` parameter and an optional `previous_init`
-- parameter.
--
-- The shim must either set, or ensure that a previous script sets,
-- `storage.dungeonIdSet` before any of this object's functionality can
-- be used.
--
-- Functions that must be provided by the shim:
--
-- logError(fmt, ...)
-- logWarn(fmt, ...)
-- logInfo(fmt, ...)
-- setConsoleAnimation(state)
--
-- Functions that may be provided by the shim:
--
-- onInteraction_preReturn(interactData)
-- syncFieldData_preReturn(fieldData)
------------------------------------------------------------------------

require "/scripts/rl_fieldcontrol.lua"
require "/scripts/util.lua"
require "/scripts/vec2.lua"

local fccHazardProtectionStatus = rl_fieldcontrol.fccHazardProtectionStatus

-- Decorate (execute code before and after) the original `init` function.
function rl_fieldcontrol_multifieldconsole_init(worldType, previous_init)
  -- `hullDungeonId` is a dungeon ID that is intended to be permanently
  -- shielded, and will not be unshielded by this console, but its other
  -- properties may be controlled by this console. May be nil.
  self.hullDungeonId = rl_fieldcontrol.hullDungeonIds[worldType]

  -- `mutableDungeonIds` is a list of dungeon IDs that are intended to
  -- be controlled fully by this console.
  self.mutableDungeonIds = rl_fieldcontrol.specialDungeonIds[worldType] or {}

  if previous_init then previous_init() end

  storage.origBreathable = true
  storage.origGravity = 80

  self.environmentValid = true
  if #self.mutableDungeonIds < 1 then
    logWarn("unsupported world type: %s", worldType)
    self.environmentValid = false
  end

  local position = entity.position()
  self.spaces = util.map(object.spaces(), function(v)
      return vec2.add(position, v)
    end)
  if self.hullDungeonId then
    self.spacesMiddleIdx = math.ceil(#self.spaces / 2)
  end

  self.inputNodeCount = object.inputNodeCount()
  self.outputNodeCount = object.outputNodeCount()

  -- Check whether the object's image geometry provides sufficient space
  -- to allow correct functionality. This code assumes a 3x3 rectangle
  -- with 3 input nodes on the left side of the image and 3 output nodes
  -- on the right side of the image, so space will be sufficient unless
  -- a modder changes the image geometry or wiring nodes.
  if #self.spaces <= #self.mutableDungeonIds then
    logError("object geometry too small: critical severity")
    self.environmentValid = false
  elseif self.hullDungeonId then
    if self.spacesMiddleIdx <= #self.mutableDungeonIds then
      logError("object geometry too small: high severity")
      self.environmentValid = false
    else
      local collision = false
      local pos = self.spaces[self.spacesMiddleIdx]
      for i=0,self.inputNodeCount-1 do
        local nPos = object.getInputNodePosition(i)
        if pos[1] == nPos[1] and pos[2] == nPos[2] then collision = true end
      end
      for i=0,self.outputNodeCount-1 do
        local nPos = object.getOutputNodePosition(i)
        if pos[1] == nPos[1] and pos[2] == nPos[2] then collision = true end
      end
      if collision then
        logError("object geometry invalid: wiring impacted")
        self.environmentValid = false
      end
    end
  end

  if not self.environmentValid then script.setUpdateDelta(0) end

  -- `tileAssignments` is a list of lists of the form {position,
  -- dungeonId}. It is initialized such that each space occupied by this
  -- object is assigned to the last mutable dungeon ID. Then, spaces at
  -- the head of the list are assigned to the mutable dungeon IDs in
  -- order. Then, the middle space is assigned to the dungeon ID of the
  -- hull, if applicable. Assuming that the environment is valid, this
  -- ensures that all dungeon IDs controlled by the console can be found
  -- at known positions in the background of the console, and wiring is
  -- not impacted by the permanently-shielded hull dungeon ID.
  self.tileAssignments = {}
  if self.environmentValid then
    for _,pos in ipairs(self.spaces) do
      table.insert(self.tileAssignments,
        {pos, self.mutableDungeonIds[#self.mutableDungeonIds]}
      )
    end
    for idx,dungeonId in ipairs(self.mutableDungeonIds) do
      self.tileAssignments[idx][2] = dungeonId
    end
    if self.hullDungeonId then
      self.tileAssignments[self.spacesMiddleIdx][2] = self.hullDungeonId
    end
  end

  local versioning = root.assetJson("/versioning.config")

  self.fuCompatibility = not not versioning.FrackinUniverse

  self.enableHazardProtection = not not versioning.rl_dynamicstatuseffects
  self.hazardProtectionConfig = self.enableHazardProtection and
    root.assetJson("/rl_fieldcontrol_hazardprotection.config") or {}

  local tileProtection = isTileProtectionActive()
  getHazardProtectionStatus()

  if storage.dungeonIdSet then
    -- Aggressively reset the dungeon IDs of tiles underlying the console.
    resetUnderlyingTiles()
  end

  if self.environmentValid then
    setConsoleAnimation(tileProtection and "shieldsup" or "shieldsdown")
  else
    setConsoleAnimation("error")
  end

  self.iNodes = {
    tileProtection=0,
    breathable=1,
    hazardProtection=2
  }

  self.oNodes = {
    tileProtection=0,
    breathable=1,
    hazardProtection=2
  }

  setOutputNodeLevel(self.oNodes.tileProtection, tileProtection)
  setOutputNodeLevel(self.oNodes.breathable, self.oxygenAvailable and isBreathable())
  setOutputNodeLevel(self.oNodes.hazardProtection, self.hazardProtectionActive)

  -- Wait 1 second between sync checks.
  self.fieldSyncTime = 1
  self.fieldSyncTimer = self.fieldSyncTime

  message.setHandler("setBreathable", setBreathable)
  message.setHandler("setGravity", function(_, _, gravity)
      setGravity(gravity)
    end)
  message.setHandler("setHazardProtection", setHazardProtection)
  message.setHandler("setPassword", setPassword)
  message.setHandler("setTileProtection", setTileProtection)
  message.setHandler("syncFieldData", syncFieldData)
end

-- The implementation is similar to the field control console's
-- `deregisterDungeonId` function.
local previous_die = die
function die(smash)
  if previous_die then previous_die(smash) end
  if not self.environmentValid then return end

  local manager = getDynamicStatusEffectsManager()
  if manager then
    for _,v in ipairs(self.mutableDungeonIds) do
      world.sendEntityMessage(manager, "clearEffects",
        v, "rl_fieldcontrolconsole"
      )
      world.sendEntityMessage(manager, "clearEffects",
        v, "rl_fieldcontrolconsole_airless"
      )
    end
    if self.hullDungeonId then
      world.sendEntityMessage(manager, "clearEffects",
        self.hullDungeonId, "rl_fieldcontrolconsole"
      )
      world.sendEntityMessage(manager, "clearEffects",
        self.hullDungeonId, "rl_fieldcontrolconsole_airless"
      )
    end
  elseif self.enableHazardProtection then
    -- If Belter Dungeons is installed, we want to see a log message
    -- for this condition, because it means that an error occurred. If
    -- it's not installed, the condition is expected and normal.
    logError("possibly failed to clear multi-field status effects")
  end

  for _,v in ipairs(self.mutableDungeonIds) do
    world.setDungeonBreathable(v, storage.origBreathable)
    world.setDungeonGravity(v, storage.origGravity)
    world.setTileProtection(v, false)
  end
  if self.hullDungeonId then
    world.setDungeonBreathable(self.hullDungeonId, storage.origBreathable)
    world.setDungeonGravity(self.hullDungeonId, storage.origGravity)
  end
end

function onInputNodeChange(args)
  if args.node == self.iNodes.tileProtection then
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
  if isInputNodeConnected(self.iNodes.tileProtection) then
    setTileProtection(_, _,
      object.getInputNodeLevel(self.iNodes.tileProtection)
    )
  end
  if isInputNodeConnected(self.iNodes.breathable) then
    setBreathable(_, _,
      object.getInputNodeLevel(self.iNodes.breathable)
    )
  end
  if isInputNodeConnected(self.iNodes.hazardProtection) then
    setHazardProtection(_, _,
      object.getInputNodeLevel(self.iNodes.hazardProtection)
    )
  end
end

function onInteraction()
  if not storage.dungeonIdSet then return end

  -- Aggressively reset the dungeon IDs of tiles underlying the console.
  resetUnderlyingTiles()

  local hazardProtectionStatus = getHazardProtectionStatus()

  local interactData = root.assetJson(config.getParameter("interactData"))
  interactData.windowTitleIcon = config.getParameter("interfaceTitleIcon")
  interactData.environmentValid = self.environmentValid
  interactData.passwordHash = storage.passwordHash
  interactData.gravity = getGravity(true)
  interactData.tileProtection = isTileProtectionActive(true)
  interactData.tileProtectionWired = isInputNodeConnected(self.iNodes.tileProtection)
  interactData.breathable = isBreathable(true, true, true)
  interactData.breathableWired = isInputNodeConnected(self.iNodes.breathable)
  interactData.oxygenAvailable = self.oxygenAvailable
  interactData.hazardProtection = self.hazardProtectionActive
  interactData.hazardProtectionStatus = hazardProtectionStatus
  interactData.hazardProtectionWired = isInputNodeConnected(self.iNodes.hazardProtection)

  if onInteraction_preReturn then onInteraction_preReturn(interactData) end

  -- This function syncs the fields, so no need to follow it immediately
  -- with another sync.
  self.fieldSyncTimer = self.fieldSyncTime

  return {config.getParameter("interactAction"), interactData}
end

-- Decorate (execute code after) the original `update` function.
local previous_update = update
function update(dt)
  if previous_update then previous_update(dt) end

  -- World properties can be changed independently of this console, so
  -- ensure that object state is synced with world state.
  self.fieldSyncTimer = self.fieldSyncTimer - dt
  if self.fieldSyncTimer <= 0 then
    -- Aggressively reset the dungeon IDs of tiles underlying the console.
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

    local outputNodeLevel = getOutputNodeLevel(self.oNodes.hazardProtection)
    if outputNodeLevel ~= nil and self.hazardProtectionActive ~= outputNodeLevel then
      object.setOutputNodeLevel(self.oNodes.hazardProtection, self.hazardProtectionActive)
    end

    self.fieldSyncTimer = self.fieldSyncTime
  end
end

------------------------------------------------------------------------
-- Message Handlers
------------------------------------------------------------------------

-- `breathable` can be altered only when the breathable input node is
-- not wired or the desired breathable state equals the wiring's input
-- level. Evaluating hazard protection is somewhat burdensome, so
-- `skipBuildHazardProtection` can be set to true if and only if it has
-- already been evaluated during this tick. If `skipWarning` is true,
-- the airless warning will not be evaluated; this should be set only if
-- something else will evaluate that warning during this tick.
function setBreathable(_, _, breathable, skipBuildHazardProtection, skipWarning)
  if not storage.dungeonIdSet or not self.environmentValid then return end
  if breathable == nil then breathable = true else breathable = not not breathable end
  if isInputNodeConnected(self.iNodes.breathable) and
     object.getInputNodeLevel(self.iNodes.breathable) ~= breathable
  then
    logError("cannot alter atmosphere: wired")
    return
  end
  for _,v in ipairs(self.mutableDungeonIds) do
    world.setDungeonBreathable(v, breathable)
  end
  if self.hullDungeonId then
    world.setDungeonBreathable(self.hullDungeonId, breathable)
  end
  if not skipBuildHazardProtection then buildHazardProtection() end
  setOutputNodeLevel(self.oNodes.breathable, self.oxygenAvailable and breathable)
  if not skipWarning then warnAirless(breathable) end
  return true
end

function setGravity(targetGravity)
  if type(targetGravity) == "number" then storage.gravity = targetGravity end
  for _,v in ipairs(self.mutableDungeonIds) do
    world.setDungeonGravity(v, storage.gravity or storage.origGravity)
  end
  if self.hullDungeonId then
    world.setDungeonGravity(self.hullDungeonId, storage.gravity or storage.origGravity)
  end
  return true
end

-- `protection` can be altered only when the hazard protection input
-- node is not wired or the desired protection state equals the wiring's
-- input level. Evaluating hazard protection is somewhat burdensome, so
-- `skipBuildHazardProtection` can be set to true if and only if it has
-- already been evaluated during this tick.
function setHazardProtection(_, _, protection, skipBuildHazardProtection)
  if not storage.dungeonIdSet or not self.environmentValid then return end
  if protection == nil then protection = false else protection = not not protection end
  if isInputNodeConnected(self.iNodes.hazardProtection) and
     object.getInputNodeLevel(self.iNodes.hazardProtection) ~= protection
  then
    logError("cannot alter hazard protection: wired")
    return
  end
  if not skipBuildHazardProtection then buildHazardProtection() end
  if #self.hazardProtection < 1 then
    self.hazardProtectionActive = true
    setOutputNodeLevel(self.oNodes.hazardProtection, true)
    return protection
  end
  local manager = getDynamicStatusEffectsManager()
  if not manager then
    if self.enableHazardProtection then
      -- If Belter Dungeons is installed, we want to see a log message
      -- for this condition, because it means that an error occurred. If
      -- it's not installed, the condition is expected and normal.
      logError("failed to set or clear multi-field status effects")
    end
    self.hazardProtectionActive = false
    setOutputNodeLevel(self.oNodes.hazardProtection, false)
    return not protection
  end
  if protection then
    for _,v in ipairs(self.mutableDungeonIds) do
      world.sendEntityMessage(manager, "setEffects",
        v, "rl_fieldcontrolconsole", self.hazardProtection
      )
    end
    if self.hullDungeonId then
      world.sendEntityMessage(manager, "setEffects",
        self.hullDungeonId, "rl_fieldcontrolconsole", self.hazardProtection
      )
    end
  else
    for _,v in ipairs(self.mutableDungeonIds) do
      world.sendEntityMessage(manager, "clearEffects",
        v, "rl_fieldcontrolconsole"
      )
    end
    if self.hullDungeonId then
      world.sendEntityMessage(manager, "clearEffects",
        self.hullDungeonId, "rl_fieldcontrolconsole"
      )
    end
  end
  self.hazardProtectionActive = protection
  setOutputNodeLevel(self.oNodes.hazardProtection, protection)
  return true
end

function setPassword(_, _, passwordHash)
  storage.passwordHash = passwordHash
end

-- `protection` can be altered only when the tile protection input node
-- is not wired, or the desired protection state equals the wiring's
-- input level. If `skipAudio` is set to true, the animation sound of
-- the shield raising or lowering will be skipped.
function setTileProtection(_, _, protection, skipAudio)
  if not storage.dungeonIdSet or not self.environmentValid then return end
  if protection == nil then protection = false else protection = not not protection end
  if isInputNodeConnected(self.iNodes.tileProtection) and
     object.getInputNodeLevel(self.iNodes.tileProtection) ~= protection
  then
    logError("cannot alter tile protection: wired")
    return
  end
  local changed = false
  for i,v in ipairs(self.mutableDungeonIds) do
    local currentTileProtection = world.isTileProtected(self.spaces[i])
    if not currentTileProtection and protection then
      world.setTileProtection(v, true)
      changed = true
    elseif currentTileProtection and not protection then
      world.setTileProtection(v, false)
      changed = true
    end
  end
  if changed then
    setConsoleAnimation(protection and "shieldsup" or "shieldsdown")
    if not skipAudio then
      animator.playSound(protection and "shieldsUp" or "shieldsDown")
    end
    setOutputNodeLevel(self.oNodes.tileProtection, protection)
  end
  return true
end

function syncFieldData(_, _)
  local fieldData = {
    passwordHash=storage.passwordHash,
    gravity=getGravity(),
    tileProtection=isTileProtectionActive(),
    tileProtectionWired=isInputNodeConnected(self.iNodes.tileProtection),
    breathable=isBreathable(),
    breathableWired=isInputNodeConnected(self.iNodes.breathable),
    oxygenAvailable=self.oxygenAvailable,
    hazardProtection=self.hazardProtectionActive,
    hazardProtectionWired=isInputNodeConnected(self.iNodes.hazardProtection)
  }
  if syncFieldData_preReturn then syncFieldData_preReturn(fieldData) end
  return fieldData
end

------------------------------------------------------------------------
-- Accessors / Remediation
--
-- Each accessor returns the current state of the relevant dungeon IDs
-- belonging to this console. If `doRemediation` is true, then if the
-- current state does not match the wired state (if applicable), or if
-- the current state is inconsistent among the dungeon IDs, then it will
-- be corrected before returning the state. If `doRemediation` is not
-- true, then the returned state may be inconsistent with the wired
-- state (if applicable), or inconsistent among the dungeon IDs.
------------------------------------------------------------------------

function getGravity(doRemediation)
  if not self.environmentValid then
    return storage.gravity or storage.origGravity
  end
  local count = 0
  local maxCount = #self.mutableDungeonIds - 1
  local newGravity = nil
  for i,v in ipairs(self.mutableDungeonIds) do
    local gravity = world.gravity(self.spaces[i])
    if newGravity ~= nil and newGravity == gravity then count = count + 1 end
    newGravity = gravity
  end
  if self.hullDungeonId then
    maxCount = maxCount + 1
    local gravity = world.gravity(self.spaces[self.spacesMiddleIdx])
    if newGravity ~= nil and newGravity == gravity then count = count + 1 end
    newGravity = gravity
  end

  if count == maxCount then
    if newGravity ~= storage.gravity then storage.gravity = newGravity end
  elseif doRemediation then
    setGravity()
  end

  return storage.gravity or storage.origGravity
end

function isBreathable(doRemediation, skipBuildHazardProtection, forceWarning)
  if not self.environmentValid then return false end
  local count = 0
  local maxCount = #self.mutableDungeonIds
  for i,v in ipairs(self.mutableDungeonIds) do
    if world.breathable(self.spaces[i]) then count = count + 1 end
  end
  if self.hullDungeonId then
    maxCount = maxCount + 1
    if world.breathable(self.spaces[self.spacesMiddleIdx]) then
      count = count + 1
    end
  end
  local retval = count == maxCount

  if doRemediation then
    local wired = nil
    if isInputNodeConnected(self.iNodes.breathable) then
      wired = object.getInputNodeLevel(self.iNodes.breathable)
    end
    if wired ~= nil and retval ~= wired then
      retval = wired
      setBreathable(_, _, retval, skipBuildHazardProtection, forceWarning)
    elseif count > 0 and count < maxCount then
      setBreathable(_, _, retval, skipBuildHazardProtection, forceWarning)
    else
      local output = self.oxygenAvailable and retval
      local outputNodeLevel = getOutputNodeLevel(self.oNodes.breathable)
      if outputNodeLevel ~= nil and output ~= outputNodeLevel then
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
  if not self.environmentValid then return false end
  local count = 0
  for i,_ in ipairs(self.mutableDungeonIds) do
    if world.isTileProtected(self.spaces[i]) then count = count + 1 end
  end
  local retval = count == #self.mutableDungeonIds

  if doRemediation then
    local wired = nil
    if isInputNodeConnected(self.iNodes.tileProtection) then
      wired = object.getInputNodeLevel(self.iNodes.tileProtection)
    end
    if wired ~= nil and retval ~= wired then
      retval = wired
      setTileProtection(_, _, retval)
    elseif count > 0 and count < #self.mutableDungeonIds then
      setTileProtection(_, _, retval)
    else
      setConsoleAnimation(retval and "shieldsup" or "shieldsdown")
      local outputNodeLevel = getOutputNodeLevel(self.oNodes.tileProtection)
      if outputNodeLevel ~= nil and retval ~= outputNodeLevel then
        animator.playSound(retval and "shieldsUp" or "shieldsDown")
        object.setOutputNodeLevel(self.oNodes.tileProtection, retval)
      end
    end
  end

  return retval
end

function resetUnderlyingTiles()
  for _,v in ipairs(self.tileAssignments) do
    world.setDungeonId({v[1][1], v[1][2], v[1][1] + 1, v[1][2] + 1}, v[2])
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

  for _,v in ipairs(self.mutableDungeonIds) do
    for _,statusEffect in ipairs(world.getProperty(
      string.format("rl_dynamicstatuseffects_%s", v)
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
  if self.hullDungeonId then
    for _,statusEffect in ipairs(world.getProperty(
      string.format("rl_dynamicstatuseffects_%s", self.hullDungeonId)
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
  if not self.enableHazardProtection then return end
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
      for _,v in ipairs(self.mutableDungeonIds) do
        if self.hazardProtectionActive then
          local effects = world.sendEntityMessage(manager, "getEffects",
            v, "rl_fieldcontrolconsole"
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
      if self.hazardProtectionActive and self.hullDungeonId then
        local effects = world.sendEntityMessage(manager, "getEffects",
          self.hullDungeonId, "rl_fieldcontrolconsole"
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
      for _,v in ipairs(self.mutableDungeonIds) do
        world.sendEntityMessage(manager, "clearEffects",
          v, "rl_fieldcontrolconsole_airless"
        )
      end
      if self.hullDungeonId then
        world.sendEntityMessage(manager, "clearEffects",
          self.hullDungeonId, "rl_fieldcontrolconsole_airless"
        )
      end
    else
      for _,v in ipairs(self.mutableDungeonIds) do
        world.sendEntityMessage(manager, "setEffects",
          v, "rl_fieldcontrolconsole_airless", {"biomeairless"}
        )
      end
      if self.hullDungeonId then
        world.sendEntityMessage(manager, "setEffects",
          self.hullDungeonId, "rl_fieldcontrolconsole_airless", {"biomeairless"}
        )
      end
    end
  elseif self.enableHazardProtection then
    -- If Belter Dungeons is installed, we want to see a log message
    -- for this condition, because it means that an error occurred. If
    -- it's not installed, the condition is expected and normal.
    logError("failed to set or clear multi-field airless status effect")
  end
end

------------------------------------------------------------------------
-- Misc
------------------------------------------------------------------------

function isInputNodeConnected(idx)
  if self.inputNodeCount > idx then
    return object.isInputNodeConnected(idx)
  end
  return false
end

function getOutputNodeLevel(idx)
  if self.outputNodeCount > idx then
    return object.getOutputNodeLevel(idx)
  end
  return nil
end

function setOutputNodeLevel(idx, level)
  if self.outputNodeCount > idx then
    object.setOutputNodeLevel(idx, level)
  end
end
