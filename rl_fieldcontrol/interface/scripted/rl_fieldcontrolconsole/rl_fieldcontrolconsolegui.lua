require "/scripts/rl_fieldcontrol.lua"

function init()
  self.validateDungeonId = rl_fieldcontrol.dungeonIdValidator(
    rl_fieldcontrol.fccDungeonIdRange)

  self.helpTemplate = config.getParameter("helpTemplate")
  self.errorTemplate = config.getParameter("errorTemplate")
  self.sounds = config.getParameter("sounds")

  self.registeredDungeonId = config.getParameter("registeredDungeonId")
  self.unregisteredDungeonId = config.getParameter("unregisteredDungeonId")
  self.breathable = config.getParameter("breathable")
  self.gravity = config.getParameter("gravity")
  self.protection = config.getParameter("protection")

  self.bulkheadMode = config.getParameter("bulkheadMode")
  widget.setChecked("bulkheadMode", self.bulkheadMode)

  swapMainPane()
end

function dismissed()
  for _, sound in pairs(self.sounds) do pane.stopAllSounds(sound) end
end

function update(dt)
  local changed = false
  if self.deregisterDungeonIdMessage then
    self.deregisterDungeonIdMessage = rl_fieldcontrol.awaitOnMessage(
      self.deregisterDungeonIdMessage, function(r)
        widget.setText(
          "unregisteredOverlay.dungeonId", self.registeredDungeonId)
        self.registeredDungeonId = nil
        self.breathable = nil
        self.gravity = nil
        self.protection = nil
        changed = true
      end, function(e)
        pane.playSound(self.sounds.error)
        sb.logError("rl_fieldcontrolconsolegui: Failed to deregister.")
      end)
  elseif self.registerDungeonIdMessage then
    self.registerDungeonIdMessage = rl_fieldcontrol.awaitOnMessage(
      self.registerDungeonIdMessage, function(r)
        if r.success then
          self.registeredDungeonId = r.dungeonId
          self.breathable = r.breathable
          self.gravity = r.gravity
          self.protection = r.protection
          changed = true
        else
          widget.setText(
            "unregisteredOverlay.errorLabel", errorMessage(r.dungeonId))
          widget.setVisible("unregisteredOverlay.errorLabel", true)
          pane.playSound(self.sounds.error)
        end
      end, function(e)
        widget.setText(
          "unregisteredOverlay.errorLabel", "Unknown error occurred.")
        widget.setVisible("unregisteredOverlay.errorLabel", true)
        pane.playSound(self.sounds.error)
        sb.logError("rl_fieldcontrolconsolegui: Failed to register.")
      end)
  end
  if changed then
    swapMainPane()
  end
end

function setDungeonId(widgetName, widgetData)
  local dungeonId = tonumber(widget.getText("unregisteredOverlay.dungeonId"))
  if self.validateDungeonId(dungeonId) then
    widget.setButtonEnabled("unregisteredOverlay.activateButton", true)
    world.sendEntityMessage(
      pane.sourceEntity(), "setUnregisteredDungeonId", dungeonId)
  else
    widget.setButtonEnabled("unregisteredOverlay.activateButton", false)
  end
  widget.setVisible("unregisteredOverlay.errorLabel", false)
end

function randomizeButtonPressed(widgetName, widgetData)
  widget.setText("unregisteredOverlay.dungeonId", math.random(
    rl_fieldcontrol.fccDungeonIdRange[1],
    rl_fieldcontrol.fccDungeonIdRange[2]))
end

function activateButtonPressed(widgetName, widgetData)
  if self.registeredDungeonId then return end
  local dungeonId = tonumber(widget.getText("unregisteredOverlay.dungeonId"))
  if not self.validateDungeonId(dungeonId) then return end
  self.registerDungeonIdMessage = world.sendEntityMessage(
    pane.sourceEntity(), "registerDungeonId", dungeonId)
end

function deactivateButtonPressed(widgetName, widgetData)
  if not self.registeredDungeonId then return end
  self.deregisterDungeonIdMessage = world.sendEntityMessage(
    pane.sourceEntity(), "deregisterDungeonId", true)
end

function setBulkheadMode(widgetName, widgetData)
  self.bulkheadMode = widget.getChecked("bulkheadMode")
  world.sendEntityMessage(
    pane.sourceEntity(), "setBulkheadMode", self.bulkheadMode)
end

function setDungeonBreathable(widgetName, widgetData)
  if not self.registeredDungeonId then return end
  self.breathable = widget.getChecked("registeredOverlay.breathable")
  world.sendEntityMessage(
    pane.sourceEntity(), "setDungeonBreathable", self.breathable)
end

function setDungeonGravity(widgetName, widgetData)
  if not self.registeredDungeonId then return end
  self.gravity = sliderToGravity(
    widget.getSliderValue("registeredOverlay.gravitySlider"))
  world.sendEntityMessage(
    pane.sourceEntity(), "setDungeonGravity", self.gravity)
end

function setDungeonTileProtection(widgetName, widgetData)
  if not self.registeredDungeonId then return end
  self.protection = widget.getChecked("registeredOverlay.protection")
  world.sendEntityMessage(
    pane.sourceEntity(), "setDungeonTileProtection", self.protection)
end

function swapMainPane()
  if self.registeredDungeonId then
    widget.setVisible("unregisteredOverlay", false)
    widget.setText(
      "registeredOverlay.dungeonId", self.registeredDungeonId)
    widget.setSliderValue(
      "registeredOverlay.gravitySlider", gravityToSlider(self.gravity))
    widget.setChecked("registeredOverlay.breathable", self.breathable)
    widget.setChecked("registeredOverlay.protection", self.protection)
    widget.setVisible("registeredOverlay", true)
  else
    widget.setVisible("registeredOverlay", false)
    local dungeonId = tonumber(widget.getText("unregisteredOverlay.dungeonId"))
    if not dungeonId then
      dungeonId = self.unregisteredDungeonId
      widget.setText("unregisteredOverlay.dungeonId", dungeonId)
    end
    widget.setButtonEnabled(
      "activateButton", self.validateDungeonId(dungeonId))
    widget.setText("unregisteredOverlay.helpLabel", helpMessage())
    widget.setVisible("unregisteredOverlay", true)
  end
end

function gravityToSlider(gravity)
  return math.floor(gravity / 5) + 2
end

function sliderToGravity(slider)
  return (slider - 2) * 5
end

function helpMessage()
  return string.format(self.helpTemplate,
    rl_fieldcontrol.fccDungeonIdRange[1], rl_fieldcontrol.fccDungeonIdRange[2])
end

function errorMessage(dungeonId)
  return string.format(self.errorTemplate, dungeonId)
end
