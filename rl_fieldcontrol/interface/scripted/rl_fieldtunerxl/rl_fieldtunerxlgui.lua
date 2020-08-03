require "/scripts/rl_fieldcontrol.lua"

function init()
  self.validateDungeonId = rl_fieldcontrol.dungeonIdValidator(
    rl_fieldcontrol.universeDungeonIdRange)

  self.helpTemplate = config.getParameter("helpTemplate")
  self.errorTemplate = config.getParameter("errorTemplate")
  self.sounds = config.getParameter("sounds")

  self.dungeonId = config.getParameter("dungeonId")

  widget.setText("inactiveOverlay.dungeonId", self.dungeonId)
  widget.setText("inactiveOverlay.helpLabel", helpMessage())
  widget.setButtonEnabled(
    "inactiveOverlay.activateButton", self.validateDungeonId(self.dungeonId))
end

function dismissed()
  for _, sound in pairs(self.sounds) do pane.stopAllSounds(sound) end
end

function update(dt)
  if self.tuneToDungeonIdMessage then
    self.tuneToDungeonIdMessage = rl_fieldcontrol.awaitOnMessage(
      self.tuneToDungeonIdMessage, function(r)
        if r then
          pane.dismiss()
        else
          widget.setText(
            "inactiveOverlay.errorLabel", errorMessage(self.dungeonId))
          widget.setVisible("inactiveOverlay.errorLabel", true)
          widget.setButtonEnabled("inactiveOverlay.activateButton",
            self.validateDungeonId(self.dungeonId))
          pane.playSound(self.sounds.error)
        end
      end, function(e)
        widget.setText(
          "inactiveOverlay.errorLabel", "Unknown error occurred.")
        widget.setVisible("inactiveOverlay.errorLabel", true)
        widget.setButtonEnabled("inactiveOverlay.activateButton",
          self.validateDungeonId(self.dungeonId))
        pane.playSound(self.sounds.error)
        sb.logError("rl_fieldcontrolconsolegui: Failed to activate.")
      end)
  end
end

function setDungeonId(widgetName, widgetData)
  self.dungeonId = tonumber(widget.getText("inactiveOverlay.dungeonId"))
  if self.validateDungeonId(self.dungeonId) then
    widget.setButtonEnabled("inactiveOverlay.activateButton", true)
    world.sendEntityMessage(
      pane.sourceEntity(), "setInactiveDungeonId", self.dungeonId)
  else
    widget.setButtonEnabled("inactiveOverlay.activateButton", false)
  end
  widget.setVisible("inactiveOverlay.errorLabel", false)
end

function activateButtonPressed(widgetName, widgetData)
  self.dungeonId = tonumber(widget.getText("inactiveOverlay.dungeonId"))
  if not self.validateDungeonId(self.dungeonId) then return end
  widget.setButtonEnabled("inactiveOverlay.activateButton", false)
  self.tuneToDungeonIdMessage = world.sendEntityMessage(
    pane.sourceEntity(), "tuneToDungeonId", self.dungeonId)
end

function helpMessage()
  return string.format(self.helpTemplate,
    rl_fieldcontrol.universeDungeonIdRange[1],
    rl_fieldcontrol.universeDungeonIdRange[2])
end

function errorMessage(dungeonId)
  return string.format(self.errorTemplate, dungeonId)
end
