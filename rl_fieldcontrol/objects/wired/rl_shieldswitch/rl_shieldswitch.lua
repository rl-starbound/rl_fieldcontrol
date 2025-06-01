require "/scripts/rl_fieldcontrol.lua"
require "/scripts/util.lua"
require "/scripts/vec2.lua"

function init()
  local validWorldType = config.getParameter("validWorldType")
  if not validateWorldType(validWorldType) then
    transition("error")
    script.setUpdateDelta(0)
    return
  end

  self.dungeonIds = rl_fieldcontrol.specialDungeonIds[validWorldType] or {}
  self.shieldUniqueId = rl_fieldcontrol.shieldswitchUid

  -- Wait 1 second between sync checks.
  self.shieldSyncTime = 1
  self.shieldSyncTimer = self.shieldSyncTime

  if storage.state == nil then storage.state = "dead" end
  object.setInteractive(isInteractive())
  updateAnimationState(storage.state)
  if object.outputNodeCount() > 0 then
    object.setOutputNodeLevel(0, storage.state == "on")
  end

  local spaces = util.map(object.spaces(), function(v)
      return vec2.add(entity.position(), v)
    end)
  self.tileAssignments = {}
  for idx,pos in ipairs(spaces) do
    table.insert(self.tileAssignments, {pos, self.dungeonIds[idx]})
  end

  if isAlive() then
    -- Aggressively reset the dungeonId of tiles underlying a shield switch.
    resetUnderlyingTiles()
  end
end

function die(smash)
  if storage.state == "on" then
    transition("off")
  end
end

function onInteraction(args)
  -- Aggressively reset the dungeonId of tiles underlying a shield switch.
  resetUnderlyingTiles()

  if storage.state == "on" then
    transition("off")
  elseif storage.state == "off" then
    transition("on")
  end
end

function update(dt)
  if entity.uniqueId() ~= self.shieldUniqueId then
    if world.loadUniqueEntity(self.shieldUniqueId) == 0 then
      object.setUniqueId(self.shieldUniqueId)
      transition("off")

      -- Aggressively reset the dungeonId of tiles underlying a shield switch.
      resetUnderlyingTiles()
    else
      transition("dup")
    end
  else
    self.shieldSyncTimer = self.shieldSyncTimer - dt
    if self.shieldSyncTimer <= 0 then
      local newState = storage.state == "on"
      if newState then
        -- If the shield switch was on but something else turned off one
        -- of the shields, then switch them all off.
        for _,v in ipairs(self.tileAssignments) do
          if v[2] then newState = newState and world.isTileProtected(v[1]) end
        end
      else
        -- If the shield switch was off but something else turned on one
        -- of the shields, then switch them all on.
        for _,v in ipairs(self.tileAssignments) do
          if v[2] then newState = newState or world.isTileProtected(v[1]) end
        end
      end
      transition(newState and "on" or "off")
    end
    self.shieldSyncTimer = self.shieldSyncTime
  end
end

-- Returns `true` if the switch is in a live state, e.g., "off" or
-- "on". Returns `false` for non-live states such as `dup` or `error`.
-- Use this function to determine whether the switch is usable.
function isAlive()
  return contains({"off", "on"}, storage.state)
end

-- Currently equivalent to `isAlive`, in the future this function may
-- return `true` for only a subset of the cases for which `isAlive`
-- returns `true`. Use this function to determine whether the switch is
-- currently interactive.
function isInteractive()
  return contains({"off", "on"}, storage.state)
end

function resetUnderlyingTiles()
  for _,v in ipairs(self.tileAssignments) do
    if v[2] then
      world.setDungeonId({v[1][1], v[1][2], v[1][1] + 1, v[1][2] + 1}, v[2])
    elseif #self.dungeonIds > 0 then
      world.setDungeonId({v[1][1], v[1][2], v[1][1] + 1, v[1][2] + 1},
        self.dungeonIds[#self.dungeonIds]
      )
    end
  end
end

function transition(state)
  local oldState = storage.state
  if state ~= oldState then
    storage.state = state
    object.setInteractive(isInteractive())
    updateAnimationState(storage.state, oldState)
    if storage.state == "on" then
      setTileProtection(true)
    elseif oldState == "on" then
      setTileProtection(false)
    end
    if object.outputNodeCount() > 0 then
      object.setOutputNodeLevel(0, storage.state == "on")
    end
  end
end

function setTileProtection(b)
  for _,v in ipairs(self.dungeonIds) do world.setTileProtection(v, b) end
end

function updateAnimationState(state, oldState)
  animator.setAnimationState("switchState", state)
  if state == "on" then
    object.setLightColor(config.getParameter("lightColor"))
    if oldState and oldState ~= "on" then animator.playSound(state) end
  elseif state == "off" then
    object.setLightColor(config.getParameter("lightColor"))
    if oldState and oldState == "on" then animator.playSound(state) end
  elseif state == "error" then
    object.setLightColor(config.getParameter("lightColorError"))
  elseif state == "dup" then
    object.setLightColor(config.getParameter("lightColorError"))
  else -- dead
    object.setLightColor({0, 0, 0, 0})
  end
end

function validateWorldType(validWorldType)
  if validWorldType == "playerstation" then
    return world.type() == "playerstation"
  elseif validWorldType == "clientshipworld" then
    return world.getProperty("ship.fuel") ~= nil
  end
end
