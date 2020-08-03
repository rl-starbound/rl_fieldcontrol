function init()
  self.dungeonIds = config.getParameter("dungeonIds")
  self.shieldUniqueId = config.getParameter("shieldUniqueId")

  if storage.state == nil then
    storage.state = "dead"
  end
  object.setInteractive(isInteractive())
  updateAnimationState(storage.state)

  if object.outputNodeCount() > 0 then
    object.setOutputNodeLevel(0, storage.state == "on")
  end

  if not validateWorldType(config.getParameter("validWorldType")) then
    transition("error")
    script.setUpdateDelta(0)
  end
end

function die(smash)
  if storage.state == "on" then
    transition("off")
  end
end

function onInteraction(args)
  if storage.state == "on" then
    transition("off")
  elseif storage.state == "off" then
    transition("on")
  end
end

function update(dt)
  if entity.uniqueId() ~= self.shieldUniqueId then
    if world.findUniqueEntity(self.shieldUniqueId):result() == nil then
      object.setUniqueId(self.shieldUniqueId)
      transition("off")
      script.setUpdateDelta(0)
    else
      transition("dup")
    end
  else
    script.setUpdateDelta(0)
  end
end

function isInteractive()
  return storage.state == "off" or storage.state == "on"
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
  for _, v in ipairs(self.dungeonIds) do world.setTileProtection(v, b) end
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
    local techStationUniqueId = config.getParameter("techstationUid")
    return world.findUniqueEntity(techStationUniqueId):result() ~= nil
  end
end
