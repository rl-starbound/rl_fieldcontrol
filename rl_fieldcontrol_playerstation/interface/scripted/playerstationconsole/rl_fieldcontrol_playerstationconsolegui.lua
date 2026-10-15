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

require "/scripts/util.lua"

local function unimplemented(_, _)
  logError("Field Control Technology >= v3.0.0 required")
end

function init()
  self.gravityRange = config.getParameter("sldGravityRange")

  local v = root.assetJson("/versioning.config").rl_fieldcontrol
  if type(v) == "number" and v >= 3 then
    require "/interface/scripted/rl_fieldcontrol/rl_fieldcontrol_multifieldconsolegui.lua"
    rl_fieldcontrol_multifieldconsolegui_init()

    self.registerTransaction("setHideExpansionSlots", function(r) end, function(e)
        pane.playSound(self.sounds.error)
        logError("failed to call setHideExpansionSlots")
      end)
  else
    logError("Field Control Technology >= v3.0.0 required")

    -- This stub enables us to implement transactional logic for pane-
    -- specific callbacks.
    self.beginTransaction = unimplemented

    self.gravity = config.getParameter("gravity")
  end

  self.hideExpansionSlots = config.getParameter("hideExpansionSlots")
  widget.setChecked("btnHideExpansionSlots", self.hideExpansionSlots)

  swapMainPane(true)
end

------------------------------------------------------------------------
-- Mandatory utility functions
------------------------------------------------------------------------

function logError(fmt, ...)
  sb.logError(
    "playerstationconsolegui: %s", string.format(fmt, table.unpack({...}))
  )
end

function logWarn(fmt, ...)
  sb.logWarn(
    "playerstationconsolegui: %s", string.format(fmt, table.unpack({...}))
  )
end

function logInfo(fmt, ...)
  sb.logInfo(
    "playerstationconsolegui: %s", string.format(fmt, table.unpack({...}))
  )
end

function gravityToSlider(gravity)
  return util.clamp(gravity, self.gravityRange[1], self.gravityRange[2])
end

function sliderToGravity(sldValue)
  return math.floor(sldValue)
end

------------------------------------------------------------------------
-- Functions implementing callbacks specific to this interface
------------------------------------------------------------------------

-- This will not be replaced, so implement transactional logic.
function setHideExpansionSlots(_, _)
  self.hideExpansionSlots = widget.getChecked("btnHideExpansionSlots")
  self.beginTransaction("setHideExpansionSlots", world.sendEntityMessage(
    pane.sourceEntity(), "setHideExpansionSlots", self.hideExpansionSlots
  ))
end

function checkExtraWidgets(r)
  return self.hideExpansionSlots ~= not not r.hideExpansionSlots
end

function showExtraWidgets(visible)
  widget.setVisible("lblHideExpansionSlots", visible)
  widget.setVisible("btnHideExpansionSlots", visible)
end

function syncExtraWidgets(r)
  self.hideExpansionSlots = not not r.hideExpansionSlots
  widget.setChecked("btnHideExpansionSlots", self.hideExpansionSlots)
end

------------------------------------------------------------------------
-- Functions that will be replaced if FCT >=3.0.0 is installed
------------------------------------------------------------------------

-- This will be replaced, so don't bother implementing transactional logic.
function setGravity(_, _)
  self.gravity = widget.getSliderValue("ovlReg.sldGravity")
  world.sendEntityMessage(pane.sourceEntity(), "setGravity", self.gravity)
end

function swapMainPane(isInit)
  widget.setText("ovlReg.lblSystemStatus",
    config.getParameter("lblSystemStatusValues")["false"]
  )
  widget.setSliderValue("ovlReg.sldGravity", gravityToSlider(self.gravity))
  widget.setVisible("ovlReg.lblShielding", false)
  widget.setVisible("ovlReg.btnShielding", false)
  widget.setVisible("ovlReg.lblBreathable", false)
  widget.setVisible("ovlReg.btnBreathable", false)
  widget.setVisible("ovlReg.lblHazardProtect", false)
  widget.setVisible("ovlReg.btnHazardProtect", false)
  widget.setVisible("ovlReg", true)
end

btnDismissLockConfigPressed = unimplemented
btnLockConfigPressed = unimplemented
btnPasswordResetPressed = unimplemented
btnPasswordSetPressed = unimplemented
btnUnlockPressed = unimplemented
enterNewPassword = unimplemented
enterUnlockPassword = unimplemented
setBreathable = unimplemented
setHazardProtect = unimplemented
setShielding = unimplemented
