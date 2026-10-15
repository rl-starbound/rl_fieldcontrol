require "/scripts/rl_fieldcontrol.lua"
require "/scripts/util.lua"

function init()
  self.gravityRange = config.getParameter("sldGravityRange")
  self.visibilityModeButtons = config.getParameter("visibilityModeButtons")

  rl_fieldcontrol_multifieldconsolegui_init()

  self.visibilityMode = tonumber(config.getParameter("visibilityMode"))
  if self.visibilityMode ~= nil then
    self.visibilityMode = math.floor(self.visibilityMode)
  end
  rl_fieldcontrol.updateVisibilityModeButtons(self.visibilityModeButtons)

  self.registerTransaction("setVisibilityMode", function(r) end, function(e)
      pane.playSound(self.sounds.error)
      logError("failed to call setVisibilityMode")
    end)

  swapMainPane(true)
end

------------------------------------------------------------------------
-- Mandatory utility functions
------------------------------------------------------------------------

function logError(fmt, ...)
  sb.logError(
    "rl_playershipconsolegui: %s", string.format(fmt, table.unpack({...}))
  )
end

function logWarn(fmt, ...)
  sb.logWarn(
    "rl_playershipconsolegui: %s", string.format(fmt, table.unpack({...}))
  )
end

function logInfo(fmt, ...)
  sb.logInfo(
    "rl_playershipconsolegui: %s", string.format(fmt, table.unpack({...}))
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

function setVisibilityMode(widgetName, widgetData)
  self.visibilityMode = widget.getChecked(widgetName) and widgetData or nil
  rl_fieldcontrol.updateVisibilityModeButtons(self.visibilityModeButtons)
  self.beginTransaction("setVisibilityMode", world.sendEntityMessage(
    pane.sourceEntity(), "setVisibilityMode", self.visibilityMode
  ))
end

function checkExtraWidgets(r)
  if type(r.visibilityMode) == "number" then
    r.visibilityMode = math.floor(r.visibilityMode)
  else
    r.visibilityMode = nil
  end
  return self.visibilityMode ~= r.visibilityMode
end

function showExtraWidgets(visible)
  widget.setVisible("lblBulkhead", visible)
  widget.setButtonEnabled("btnBulkheadMode", self.environmentValid)
  widget.setVisible("btnBulkheadMode", visible)
  widget.setVisible("lblHidden", visible)
  widget.setButtonEnabled("btnHiddenMode", self.environmentValid)
  widget.setVisible("btnHiddenMode", visible)
end

function syncExtraWidgets(r)
  if type(r.visibilityMode) == "number" then
    r.visibilityMode = math.floor(r.visibilityMode)
  else
    r.visibilityMode = nil
  end
  self.visibilityMode = r.visibilityMode
  rl_fieldcontrol.updateVisibilityModeButtons(self.visibilityModeButtons)
end
