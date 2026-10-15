require "/scripts/rl_fieldcontrol.lua"

local fccVisibility = rl_fieldcontrol.fccVisibility
local fccVisibilityValue = rl_fieldcontrol.fccVisibilityValue

local function getWorldType()
  local wt = world.type()
  if wt == "unknown" and type(world.getProperty("ship.fuel")) == "number" then
    wt = "clientshipworld"
  end
  return wt
end

local function setDead(animationState)
  if animationState == nil then animationState = "dead" end
  animator.setAnimationState("consoleState", animationState)
  object.setInteractive(false)
  script.setUpdateDelta(0)
  self.environmentValid = false
  for i=0,object.outputNodeCount()-1 do object.setOutputNodeLevel(i, false) end
end

function init()
  local lightColorActive = config.getParameter("lightColorActive")
  local lightColorError = config.getParameter("lightColorError")
  if lightColorActive then
    animator.setLightColor("activeGlow", lightColorActive)
    animator.setLightColor("errorGlow", lightColorActive)
  end
  if lightColorError then
    animator.setLightColor("errorGlow", lightColorError)
  end

  local worldType = getWorldType()
  if worldType ~= config.getParameter("validWorldType") then
    setDead("error")
    return
  end

  local tryUniqueId = rl_fieldcontrol.playershipconsoleUid
  if entity.uniqueId() ~= tryUniqueId then
    if world.findUniqueEntity(tryUniqueId):result() == nil then
      object.setUniqueId(tryUniqueId)
    else
      setDead("dup")
      return
    end
  end

  rl_fieldcontrol_multifieldconsole_init(worldType)

  message.setHandler("setVisibilityMode", setVisibilityMode)

  storage.dungeonIdSet = true
end

------------------------------------------------------------------------
-- Mandatory functions
------------------------------------------------------------------------

function logError(fmt, ...)
  sb.logError(
    "rl_playershipconsole: %s", string.format(fmt, table.unpack({...}))
  )
end

function logWarn(fmt, ...)
  sb.logWarn(
    "rl_playershipconsole: %s", string.format(fmt, table.unpack({...}))
  )
end

function logInfo(fmt, ...)
  sb.logInfo(
    "rl_playershipconsole: %s", string.format(fmt, table.unpack({...}))
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

------------------------------------------------------------------------
-- Optional functions
------------------------------------------------------------------------

function setVisibilityMode(_, _, mode)
  if not self.environmentValid then return end
  -- Validate the numeric visibility `mode`. Any value other than
  -- "bulkhead" or "hidden" will result in `nil` being used.
  mode = tonumber(mode)
  if mode ~= nil then mode = math.floor(mode) end
  local modeStr = fccVisibility[mode]
  if mode ~= nil and modeStr == nil then
    logError("setVisibilityMode: ignoring invalid mode: %s", mode)
    mode = nil
  end
  if mode == nil and storage.visibilityMode ~= nil then
    -- We are leaving a special visibility mode. Probe to find the
    -- current state of the object.
    storage.visibilityMode = mode
    setConsoleAnimation(isTileProtectionActive() and "shieldsup" or "shieldsdown")
  elseif mode ~= nil then
    storage.visibilityMode = mode
    setConsoleAnimation(modeStr)
  end
end

function onInteraction_preReturn(data)
  data.visibilityMode = storage.visibilityMode
end

syncFieldData_preReturn = onInteraction_preReturn
