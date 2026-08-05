require "/scripts/rl_fieldcontrol.lua"

function init()
  self.validateDungeonId = rl_fieldcontrol.dungeonIdValidator(
    rl_fieldcontrol.fccDungeonIdRange
  )

  self.helpTemplate = config.getParameter("helpTemplate")
  self.errorTemplate = config.getParameter("errorTemplate")
  self.sounds = config.getParameter("sounds")

  self.registeredDungeonId = config.getParameter("registeredDungeonId")
  self.unregisteredDungeonId = config.getParameter("unregisteredDungeonId")
  self.breathable = config.getParameter("breathable")
  self.gravity = config.getParameter("gravity")
  self.hazardProtection = config.getParameter("hazardProtection")
  self.protection = config.getParameter("protection")

  self.visibilityModeButtons = config.getParameter("visibilityModeButtons")
  self.visibilityMode = tonumber(config.getParameter("visibilityMode"))
  if self.visibilityMode ~= nil then
    self.visibilityMode = math.floor(self.visibilityMode)
  end
  getActiveVisibilityModeButton()
  updateVisibilityModeButtons()

  swapMainPane()
end

function dismissed()
  for _,sound in pairs(self.sounds) do pane.stopAllSounds(sound) end
end

function update(dt)
  local changed = false
  if self.deregisterDungeonIdMessage then
    self.deregisterDungeonIdMessage = rl_fieldcontrol.awaitOnMessage(
      self.deregisterDungeonIdMessage, function(r)
        widget.setText(
          "unregisteredOverlay.dungeonId", self.registeredDungeonId
        )
        self.registeredDungeonId = nil
        self.breathable = nil
        self.gravity = nil
        self.hazardProtection = nil
        self.protection = nil
        changed = true
      end, function(e)
        pane.playSound(self.sounds.error)
        sb.logError("rl_fieldcontrolconsolegui: failed to deactivate")
      end)
  elseif self.registerDungeonIdMessage then
    self.registerDungeonIdMessage = rl_fieldcontrol.awaitOnMessage(
      self.registerDungeonIdMessage, function(r)
        if r.success then
          self.registeredDungeonId = r.dungeonId
          self.breathable = r.breathable
          self.gravity = r.gravity
          self.hazardProtection = r.hazardProtection
          self.protection = r.protection
          changed = true
        else
          widget.setText(
            "unregisteredOverlay.errorLabel", errorMessage(r.dungeonId)
          )
          widget.setVisible("unregisteredOverlay.errorLabel", true)
          pane.playSound(self.sounds.error)
        end
      end, function(e)
        widget.setText(
          "unregisteredOverlay.errorLabel", "Unknown error occurred."
        )
        widget.setVisible("unregisteredOverlay.errorLabel", true)
        pane.playSound(self.sounds.error)
        sb.logError("rl_fieldcontrolconsolegui: failed to activate")
      end)
  end
  if changed then
    swapMainPane()
  end
  if self.toggleHazardProtectionMessage then
    self.toggleHazardProtectionMessage = rl_fieldcontrol.awaitOnMessage(
      self.toggleHazardProtectionMessage, function(r)
        self.oldHazardProtection = nil
      end, function(e)
        self.hazardProtection = self.oldHazardProtection
        widget.setChecked("registeredOverlay.hazardProtection",
          self.oldHazardProtection
        )
        self.oldHazardProtection = nil
        pane.playSound(self.sounds.error)
        sb.logError("rl_fieldcontrolconsolegui: failed to change dungeon status effects")
      end)
  end
end

function setDungeonId(widgetName, widgetData)
  local dungeonId = tonumber(widget.getText("unregisteredOverlay.dungeonId"))
  if self.validateDungeonId(dungeonId) then
    widget.setButtonEnabled("unregisteredOverlay.activateButton", true)
    world.sendEntityMessage(
      pane.sourceEntity(), "setUnregisteredDungeonId", dungeonId
    )
  else
    widget.setButtonEnabled("unregisteredOverlay.activateButton", false)
  end
  widget.setVisible("unregisteredOverlay.errorLabel", false)
end

function randomizeButtonPressed(widgetName, widgetData)
  widget.setText("unregisteredOverlay.dungeonId", math.random(
    rl_fieldcontrol.fccDungeonIdRange[1],
    rl_fieldcontrol.fccDungeonIdRange[2]
  ))
end

function activateButtonPressed(widgetName, widgetData)
  if self.registeredDungeonId then return end
  local dungeonId = tonumber(widget.getText("unregisteredOverlay.dungeonId"))
  if not self.validateDungeonId(dungeonId) then return end
  self.registerDungeonIdMessage = world.sendEntityMessage(
    pane.sourceEntity(), "registerDungeonId", dungeonId
  )
end

function deactivateButtonPressed(widgetName, widgetData)
  if not self.registeredDungeonId then return end
  self.deregisterDungeonIdMessage = world.sendEntityMessage(
    pane.sourceEntity(), "deregisterDungeonId", true
  )
end

function setDungeonBreathable(widgetName, widgetData)
  if not self.registeredDungeonId then return end
  self.breathable = widget.getChecked("registeredOverlay.breathable")
  world.sendEntityMessage(
    pane.sourceEntity(), "setDungeonBreathable", self.breathable
  )
end

function setDungeonGravity(widgetName, widgetData)
  if not self.registeredDungeonId then return end
  self.gravity = sliderToGravity(
    widget.getSliderValue("registeredOverlay.gravitySlider")
  )
  widget.setText("registeredOverlay.gravityLabel",
    string.format("Gravity (%s)", self.gravity)
  )
  world.sendEntityMessage(
    pane.sourceEntity(), "setDungeonGravity", self.gravity
  )
end

function setDungeonHazardProtection(widgetName, widgetData)
  if not self.registeredDungeonId then return end
  self.oldHazardProtection = self.hazardProtection
  self.hazardProtection = widget.getChecked("registeredOverlay.hazardProtection")
  self.toggleHazardProtectionMessage = world.sendEntityMessage(
    pane.sourceEntity(), "setDungeonHazardProtection", self.hazardProtection
  )
end

function setDungeonTileProtection(widgetName, widgetData)
  if not self.registeredDungeonId then return end
  self.protection = widget.getChecked("registeredOverlay.protection")
  world.sendEntityMessage(
    pane.sourceEntity(), "setDungeonTileProtection", self.protection
  )
end

function setVisibilityMode(widgetName, widgetData)
  self.visibilityMode = widget.getChecked(widgetName) and widgetData or nil
  if self.visibilityMode ~= nil then
    self.visibilityMode = math.floor(self.visibilityMode)
  end
  getActiveVisibilityModeButton()
  updateVisibilityModeButtons()
  world.sendEntityMessage(
    pane.sourceEntity(), "setVisibilityMode", self.visibilityMode
  )
end

function swapMainPane()
  if self.registeredDungeonId then
    widget.setVisible("unregisteredOverlay", false)
    widget.setText("registeredOverlay.dungeonId", self.registeredDungeonId)
    widget.setText("registeredOverlay.gravityLabel",
      string.format("Gravity (%s)", self.gravity)
    )
    widget.setSliderValue("registeredOverlay.gravitySlider",
      gravityToSlider(self.gravity)
    )
    widget.setChecked("registeredOverlay.breathable", self.breathable)
    if self.hazardProtection ~= nil then
      widget.setVisible("registeredOverlay.hazardProtectionLabel", true)
      widget.setVisible("registeredOverlay.hazardProtection", true)
      widget.setChecked("registeredOverlay.hazardProtection",
        self.hazardProtection
      )
    else
      widget.setVisible("registeredOverlay.hazardProtectionLabel", false)
      widget.setVisible("registeredOverlay.hazardProtection", false)
      widget.setChecked("registeredOverlay.hazardProtection", false)
    end
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
      "activateButton", self.validateDungeonId(dungeonId)
    )
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

function getActiveVisibilityModeButton()
  local modeStr = self.visibilityModeButtons[self.visibilityMode]
  if modeStr == nil then
    self.visibilityMode = nil
    self.activeVisibilityModeButton = nil
  else
    self.activeVisibilityModeButton = modeStr
  end
end

function updateVisibilityModeButtons()
  for _,v in ipairs(self.visibilityModeButtons) do
    if self.activeVisibilityModeButton == v then
      if not widget.getChecked(v) then
        widget.setChecked(v, true)
      end
    else
      if widget.getChecked(v) then
        widget.setChecked(v, false)
      end
    end
  end
end

function helpMessage()
  return string.format(self.helpTemplate,
    rl_fieldcontrol.fccDungeonIdRange[1], rl_fieldcontrol.fccDungeonIdRange[2])
end

function errorMessage(dungeonId)
  return string.format(self.errorTemplate, dungeonId)
end
