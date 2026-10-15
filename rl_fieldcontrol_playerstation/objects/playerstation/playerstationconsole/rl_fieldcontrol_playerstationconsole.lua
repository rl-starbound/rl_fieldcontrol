------------------------------------------------------------------------
-- Why does this ugly shim system exist? One problem with the Starbound
-- API is that, while it supports mod dependencies, it does not support
-- mod version dependencies. So if a user with Field Control Technology
-- v1.0.0 adds this mod, the scripts in this mod will try to invoke code
-- that was added in FCT v3.0.0, and will crash because the code doesn't
-- exist in that user's install. So it crashes, what's the big deal? If
-- the `playerstationconsole` crashes, it will permanently corrupt the
-- user's space station. The only resolution would be to delete the
-- `.world` file and start over. So yeah, it's a big deal, and we have
-- to bend over backwards to ensure it doesn't happen, while also
-- prompting the user to upgrade to a supported version of FCT.
------------------------------------------------------------------------

local function setDead(animationState)
  if animationState == nil then animationState = "dead" end
  animator.setAnimationState("consoleState", animationState)
  object.setInteractive(false)
  object.setUniqueId()
  script.setUpdateDelta(0)
  self.environmentValid = false
  for i=0,object.outputNodeCount()-1 do object.setOutputNodeLevel(i, false) end
end

local previous_init = init
function init()
  local worldType = world.type()
  if worldType ~= config.getParameter("validWorldType") then
    setDead("error")
    return
  end

  local v = root.assetJson("/versioning.config").rl_fieldcontrol
  if type(v) == "number" and v >= 3 then
    require "/objects/scripts/rl_fieldcontrol/rl_fieldcontrol_multifieldconsole.lua"
    rl_fieldcontrol_multifieldconsole_init(worldType, previous_init)
  else
    logError("Field Control Technology >= v3.0.0 required")
    previous_init()
  end
end

-- This should never be called.
function die(smash)
  logWarn("die(%s) invoked on unbreakable object", sb.printJson(smash))
end

------------------------------------------------------------------------
-- Mandatory functions
------------------------------------------------------------------------

function logError(fmt, ...)
  sb.logError(
    "playerstationconsole: %s", string.format(fmt, table.unpack({...}))
  )
end

function logWarn(fmt, ...)
  sb.logWarn(
    "playerstationconsole: %s", string.format(fmt, table.unpack({...}))
  )
end

function logInfo(fmt, ...)
  sb.logInfo(
    "playerstationconsole: %s", string.format(fmt, table.unpack({...}))
  )
end

function setConsoleAnimation(state)
  animator.setAnimationState("consoleState", state)
end

------------------------------------------------------------------------
-- Optional functions
------------------------------------------------------------------------

function onInteraction_preReturn(data)
  data.hideExpansionSlots = storage.hideExpansionSlots
end

syncFieldData_preReturn = onInteraction_preReturn
