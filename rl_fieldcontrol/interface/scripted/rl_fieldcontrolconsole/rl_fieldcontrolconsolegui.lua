require "/scripts/rl_fieldcontrol.lua"
require "/scripts/util.lua"

local fccHazardProtectionStatus = rl_fieldcontrol.fccHazardProtectionStatus

function init()
  self.beginTransaction = rl_fieldcontrol.beginTransaction
  self.initTransactions = rl_fieldcontrol.initTransactions
  self.processTransactions = rl_fieldcontrol.processTransactions
  self.registerTransaction = rl_fieldcontrol.registerTransaction

  self.validateDungeonId = rl_fieldcontrol.dungeonIdValidator(
    rl_fieldcontrol.fccDungeonIdRange
  )

  self.regDungeonIdTemplate = config.getParameter("regDungeonIdTemplate")
  self.unregErrorTemplate = config.getParameter("unregErrorTemplate")
  self.unregHelpTemplate = config.getParameter("unregHelpTemplate")
  self.unregUnknownError = config.getParameter("unregUnknownError")

  self.btnLockConfigImages = config.getParameter("btnLockConfigImages")
  self.imgLockStatusImages = config.getParameter("imgLockStatusImages")
  self.lblLockStatusValues = config.getParameter("lblLockStatusValues")
  self.lblBreathableValues = config.getParameter("lblBreathableValues")
  self.lblGravityTemplate = config.getParameter("lblGravityTemplate")
  self.lblHazardProtectValues = config.getParameter("lblHazardProtectValues")
  self.sounds = config.getParameter("sounds")

  self.gravityRange = config.getParameter("sldGravityRange")
  self.visibilityModeButtons = config.getParameter("visibilityModeButtons")

  self.passwordHash = config.getParameter("passwordHash")
  widget.setButtonImages("btnLockConfig",
    self.btnLockConfigImages[tostring(not not self.passwordHash)]
  )

  self.registeredDungeonId = config.getParameter("registeredDungeonId")
  self.unregisteredDungeonId = config.getParameter("unregisteredDungeonId")
  self.gravity = config.getParameter("gravity")
  self.gravityOverride = not not config.getParameter("gravityOverride")
  self.gravityWired = not not config.getParameter("gravityWired")
  self.shielding = not not config.getParameter("tileProtection")
  self.shieldingWired = not not config.getParameter("tileProtectionWired")
  self.breathable = not not config.getParameter("breathable")
  self.breathableWired = not not config.getParameter("breathableWired")
  self.oxygenAvailable = not not config.getParameter("oxygenAvailable")
  self.hazardProtect = not not config.getParameter("hazardProtection")
  self.hazardProtectStatus = config.getParameter("hazardProtectionStatus") or
    fccHazardProtectionStatus.unavailable
  self.hazardProtectWired = not not config.getParameter("hazardProtectionWired")

  -- Wait 1 second between sync checks.
  self.syncFieldDataTime = 1
  self.syncFieldDataTimer = self.syncFieldDataTime

  self.initTransactions(function()
      self.syncFieldDataMsg = nil
      self.syncFieldDataTimer = nil
    end, function()
      self.syncFieldDataTimer = self.syncFieldDataTime
    end)

  self.registerTransaction("resetPassword", function(r)
      self.passwordHash = nil
      widget.setButtonImages("btnLockConfig", self.btnLockConfigImages["false"])
      pane.playSound(self.sounds.unlock)
      btnDismissLockConfigPressed()
    end, function(e)
      pane.playSound(self.sounds.error)
      logError("failed to call resetPassword")
    end)

  self.registerTransaction("setPassword", function(r)
      self.passwordHash = self.newPasswordHash
      self.newPasswordHash = nil
      widget.setButtonImages("btnLockConfig", self.btnLockConfigImages["true"])
      pane.playSound(self.sounds.lock)
      btnDismissLockConfigPressed()
    end, function(e)
      pane.playSound(self.sounds.error)
      logError("failed to call setPassword")
      self.newPasswordHash = nil
    end)

  self.registerTransaction("deregisterDungeonId", function(r)
      widget.setText("ovlUnreg.dungeonId", self.registeredDungeonId)
      self.registeredDungeonId = nil
      self.gravity = nil
      self.gravityOverride = nil
      self.gravityWired = nil
      self.shielding = nil
      self.shieldingWired = nil
      self.breathable = nil
      self.breathableWired = nil
      self.oxygenAvailable = nil
      self.hazardProtect = nil
      self.hazardProtectStatus = fccHazardProtectionStatus.unavailable
      self.hazardProtectWired = nil
      swapMainPane()
    end, function(e)
      pane.playSound(self.sounds.error)
      logError("failed to call deregisterDungeonId")
    end)

  self.registerTransaction("registerDungeonId", function(r)
      if r.success then
        self.registeredDungeonId = r.dungeonId
        self.gravity = r.gravity
        self.gravityOverride = r.gravityOverride
        self.gravityWired = r.gravityWired
        self.shielding = r.tileProtection
        self.shieldingWired = r.tileProtectionWired
        self.breathable = r.breathable
        self.breathableWired = r.breathableWired
        self.oxygenAvailable = r.oxygenAvailable
        self.hazardProtect = r.hazardProtection
        self.hazardProtectStatus = r.hazardProtectionStatus
        self.hazardProtectWired = r.hazardProtectionWired
        swapMainPane()
      else
        widget.setText("ovlUnreg.lblError", formatUnregError(r.dungeonId))
        widget.setVisible("ovlUnreg.lblError", true)
        widget.focus("ovlUnreg.dungeonId")
        pane.playSound(self.sounds.error)
      end
    end, function(e)
      widget.setText("ovlUnreg.lblError", self.unregUnknownError)
      widget.setVisible("ovlUnreg.lblError", true)
      widget.focus("ovlUnreg.dungeonId")
      pane.playSound(self.sounds.error)
      logError("failed to call registerDungeonId")
    end)

  self.registerTransaction("setUnregisteredDungeonId", function(r) end, function(e)
      pane.playSound(self.sounds.error)
      logError("failed to call setUnregisteredDungeonId")
    end)

  self.registerTransaction("setGravity", function(r) end, function(e)
      pane.playSound(self.sounds.error)
      logError("failed to call setGravity")
    end)

  self.registerTransaction("setGravityOverride", function(r)
      if not r then
        self.gravityOverride = self.oldGravityOverride
        widget.setChecked("ovlReg.btnGravityOverride", self.oldGravityOverride)
        pane.playSound(self.sounds.error)
        logError("failed to toggle gravity override")
      end
      self.oldGravityOverride = nil
    end, function(e)
      self.gravityOverride = self.oldGravityOverride
      widget.setChecked("ovlReg.btnGravityOverride", self.oldGravityOverride)
      pane.playSound(self.sounds.error)
      logError("failed to call setGravity (override)")
      self.oldGravityOverride = nil
    end)

  self.registerTransaction("setBreathable", function(r)
      if not r then
        self.breathable = self.oldBreathable
        widget.setChecked("ovlReg.btnBreathable", self.oldBreathable)
        pane.playSound(self.sounds.error)
        logError("failed to toggle breathable")
      end
      self.oldBreathable = nil
    end, function(e)
      self.breathable = self.oldBreathable
      widget.setChecked("ovlReg.btnBreathable", self.oldBreathable)
      pane.playSound(self.sounds.error)
      logError("failed to call setBreathable")
      self.oldBreathable = nil
    end)

  self.registerTransaction("setHazardProtection", function(r)
      if not r then
        self.hazardProtect = self.oldHazardProtect
        widget.setChecked("ovlReg.btnHazardProtect", self.oldHazardProtect)
        pane.playSound(self.sounds.error)
        logError("failed to toggle hazard protection")
      end
      self.oldHazardProtect = nil
    end, function(e)
      self.hazardProtect = self.oldHazardProtect
      widget.setChecked("ovlReg.btnHazardProtect", self.oldHazardProtect)
      pane.playSound(self.sounds.error)
      logError("failed to call setHazardProtection")
      self.oldHazardProtect = nil
    end)

  self.registerTransaction("setTileProtection", function(r)
      if not r then
        self.shielding = self.oldShielding
        widget.setChecked("ovlReg.btnShielding", self.oldShielding)
        pane.playSound(self.sounds.error)
        logError("failed to toggle shielding")
      end
      self.oldShielding = nil
    end, function(e)
      self.shielding = self.oldShielding
      widget.setChecked("ovlReg.btnShielding", self.oldShielding)
      pane.playSound(self.sounds.error)
      logError("failed to call setTileProtection")
      self.oldShielding = nil
    end)

  self.registerTransaction("setVisibilityMode", function(r) end, function(e)
      pane.playSound(self.sounds.error)
      logError("failed to call setVisibilityMode")
    end)

  self.visibilityMode = tonumber(config.getParameter("visibilityMode"))
  if self.visibilityMode ~= nil then
    self.visibilityMode = math.floor(self.visibilityMode)
  end
  rl_fieldcontrol.updateVisibilityModeButtons(self.visibilityModeButtons)

  swapMainPane(true)
end

function dismissed()
  for _,sound in pairs(self.sounds) do pane.stopAllSounds(sound) end
end

function update(dt)
  if self.syncFieldDataMsg then
    self.syncFieldDataMsg = rl_fieldcontrol.awaitOnMessage(
      self.syncFieldDataMsg, function(r)
        if self.registeredDungeonId ~= r.dungeonId then
          pane.dismiss()
          return
        end

        if self.passwordHash ~= r.passwordHash then
          if not self.inLockedPane then
            pane.dismiss()
            return
          else
            self.passwordHash = r.passwordHash
          end
        end

        if type(r.visibilityMode) == "number" then
          r.visibilityMode = math.floor(r.visibilityMode)
        else
          r.visibilityMode = nil
        end
        if self.gravity ~= r.gravity or
           self.gravityOverride ~= r.gravityOverride or
           self.gravityWired ~= r.gravityWired or
           self.shielding ~= r.tileProtection or
           self.shieldingWired ~= r.tileProtectionWired or
           self.breathable ~= r.breathable or
           self.breathableWired ~= r.breathableWired or
           self.oxygenAvailable ~= r.oxygenAvailable or
           self.hazardProtect ~= r.hazardProtection or
           self.hazardProtectWired ~= r.hazardProtectionWired or
           self.visibilityMode ~= r.visibilityMode
        then
          self.gravity = r.gravity
          self.gravityOverride = not not r.gravityOverride
          self.gravityWired = not not r.gravityWired
          self.shielding = not not r.tileProtection
          self.shieldingWired = not not r.tileProtectionWired
          self.breathable = not not r.breathable
          self.breathableWired = not not r.breathableWired
          self.oxygenAvailable = not not r.oxygenAvailable
          self.hazardProtect = not not r.hazardProtection
          self.hazardProtectWired = not not r.hazardProtectionWired
          self.visibilityMode = r.visibilityMode
          rl_fieldcontrol.updateVisibilityModeButtons(self.visibilityModeButtons)
          if not self.inLockConfigPane and
             not self.inLockedPane and
             not self.inUnregisteredPane
          then
            swapMainPane()
          end
        end

        if self.unregisteredDungeonId ~= r.unregisteredDungeonId then
          self.unregisteredDungeonId = r.unregisteredDungeonId
          if self.inUnregisteredPane then
            widget.setText("ovlUnreg.dungeonId", self.unregisteredDungeonId)
            widget.setButtonEnabled("ovlUnreg.btnActivate", true)
            widget.setText("ovlUnreg.lblError", "^red;Frequency change unexpected.^reset;")
            widget.setVisible("ovlUnreg.lblError", true)
            widget.focus("ovlUnreg.dungeonId")
            pane.playSound(self.sounds.error)
          end
        end

        self.syncFieldDataTimer = self.syncFieldDataTime
      end, function(e)
        logError("failed to call syncFieldData")
        self.syncFieldDataTimer = self.syncFieldDataTime
      end)
  end

  self.processTransactions()

  if self.syncFieldDataTimer then
    self.syncFieldDataTimer = self.syncFieldDataTimer - dt
    if self.syncFieldDataTimer <= 0 then
      if not self.syncFieldDataMsg then
        self.syncFieldDataMsg = world.sendEntityMessage(
          pane.sourceEntity(), "syncFieldData"
        )
        self.syncFieldDataTimer = nil
      end
    end
  end
end

------------------------------------------------------------------------
-- Locked Overlay Callbacks
------------------------------------------------------------------------

function btnUnlockPressed(_, _)
  local password = widget.getText("ovlLocked.password")
  widget.setText("ovlLocked.password", "")
  if password and #password > 0 then
    local passwordHash = util.hashString(password)
    if passwordHash == self.passwordHash then
      pane.playSound(self.sounds.unlock)
      widget.setVisible("ovlLocked.lblError", false)
      swapMainPane()
      return
    end
  end
  pane.playSound(self.sounds.error)
  widget.setVisible("ovlLocked.lblError", true)
  widget.focus("ovlLocked.password")
end

function enterUnlockPassword(_, _)
  local password = widget.getText("ovlLocked.password")
  widget.setButtonEnabled("ovlLocked.btnUnlock", password and #password > 0)
end

------------------------------------------------------------------------
-- Lock Config Overlay Callbacks
------------------------------------------------------------------------

function btnDismissLockConfigPressed(_, _)
  widget.setText("ovlLockConfig.newPassword", "")
  widget.setText("ovlLockConfig.newPassword2", "")
  widget.setVisible("ovlLockConfig.imgNewPasswordCheck", false)
  widget.setVisible("ovlLockConfig.imgNewPassword2Check", false)
  swapMainPane()
end

function btnPasswordResetPressed(_, _)
  self.beginTransaction("resetPassword", world.sendEntityMessage(
    pane.sourceEntity(), "setPassword"
  ))
end

function btnPasswordSetPressed(_, _)
  local newPassword = widget.getText("ovlLockConfig.newPassword")
  if not newPassword or #newPassword < 1 then return end
  self.newPasswordHash = util.hashString(newPassword)
  self.beginTransaction("setPassword", world.sendEntityMessage(
    pane.sourceEntity(), "setPassword", self.newPasswordHash
  ))
end

function enterNewPassword(_, _)
  local newPassword = widget.getText("ovlLockConfig.newPassword")
  local newPassword2 = widget.getText("ovlLockConfig.newPassword2")
  if newPassword and #newPassword > 0 then
    widget.setVisible("ovlLockConfig.imgNewPasswordCheck", true)
    if newPassword2 and newPassword == newPassword2 then
      widget.setVisible("ovlLockConfig.imgNewPassword2Check", true)
      widget.setButtonEnabled("ovlLockConfig.btnPasswordSet", true)
    else
      widget.setVisible("ovlLockConfig.imgNewPassword2Check", false)
      widget.setButtonEnabled("ovlLockConfig.btnPasswordSet", false)
    end
  else
    widget.setVisible("ovlLockConfig.imgNewPasswordCheck", false)
    widget.setVisible("ovlLockConfig.imgNewPassword2Check", false)
    widget.setButtonEnabled("ovlLockConfig.btnPasswordSet", false)
  end
end

------------------------------------------------------------------------
-- Unregistered Overlay Callbacks
------------------------------------------------------------------------

function btnActivatePressed(_, _)
  if self.registeredDungeonId then return end
  local dungeonId = tonumber(widget.getText("ovlUnreg.dungeonId"))
  if not self.validateDungeonId(dungeonId) then return end
  self.beginTransaction("registerDungeonId", world.sendEntityMessage(
    pane.sourceEntity(), "registerDungeonId", dungeonId
  ))
end

function btnRandomizePressed(_, _)
  widget.setText("ovlUnreg.dungeonId", math.random(
    rl_fieldcontrol.fccDungeonIdRange[1],
    rl_fieldcontrol.fccDungeonIdRange[2]
  ))
end

function enterDungeonId(_, _)
  local dungeonId = tonumber(widget.getText("ovlUnreg.dungeonId"))
  if self.validateDungeonId(dungeonId) then
    widget.setButtonEnabled("ovlUnreg.btnActivate", true)
    self.unregisteredDungeonId = dungeonId
    self.beginTransaction("setUnregisteredDungeonId", world.sendEntityMessage(
      pane.sourceEntity(), "setUnregisteredDungeonId", dungeonId
    ))
  else
    widget.setButtonEnabled("ovlUnreg.btnActivate", false)
  end
  widget.setVisible("ovlUnreg.lblError", false)
end

------------------------------------------------------------------------
-- Registered Overlay Callbacks
------------------------------------------------------------------------

function btnBreathablePressed(_, _)
  if not self.registeredDungeonId or not self.oxygenAvailable then return end
  self.oldBreathable = self.breathable
  self.breathable = widget.getChecked("ovlReg.btnBreathable")
  self.beginTransaction("setBreathable", world.sendEntityMessage(
    pane.sourceEntity(), "setBreathable", self.breathable
  ))
end

function btnDeactivatePressed(_, _)
  if not self.registeredDungeonId then return end
  self.beginTransaction("deregisterDungeonId", world.sendEntityMessage(
    pane.sourceEntity(), "deregisterDungeonId"
  ))
end

function btnGravityOverridePressed(_, _)
  if not self.registeredDungeonId then return end
  self.oldGravityOverride = self.gravityOverride
  self.gravityOverride = widget.getChecked("ovlReg.btnGravityOverride")
  self.beginTransaction("setGravityOverride", world.sendEntityMessage(
    pane.sourceEntity(), "setGravity", self.gravityOverride
  ))
end

function btnHazardProtectPressed(_, _)
  if not self.registeredDungeonId or
     self.hazardProtectStatus ~= fccHazardProtectionStatus.available
  then return end
  self.oldHazardProtect = self.hazardProtect
  self.hazardProtect = widget.getChecked("ovlReg.btnHazardProtect")
  self.beginTransaction("setHazardProtection", world.sendEntityMessage(
    pane.sourceEntity(), "setHazardProtection", self.hazardProtect
  ))
end

function btnShieldingPressed(_, _)
  if not self.registeredDungeonId then return end
  self.oldShielding = self.shielding
  self.shielding = widget.getChecked("ovlReg.btnShielding")
  self.beginTransaction("setTileProtection", world.sendEntityMessage(
    pane.sourceEntity(), "setTileProtection", self.shielding
  ))
end

function setGravity(_, _)
  if not self.registeredDungeonId then return end
  self.gravity = sliderToGravity(widget.getSliderValue("ovlReg.sldGravity"))
  widget.setText("ovlReg.lblGravity",
    string.format(self.lblGravityTemplate, self.gravity)
  )
  self.beginTransaction("setGravity", world.sendEntityMessage(
    pane.sourceEntity(), "setGravity", self.gravityOverride, self.gravity
  ))
end

------------------------------------------------------------------------
-- Misc Callbacks
------------------------------------------------------------------------

function setVisibilityMode(widgetName, widgetData)
  self.visibilityMode = widget.getChecked(widgetName) and widgetData or nil
  rl_fieldcontrol.updateVisibilityModeButtons(self.visibilityModeButtons)
  self.beginTransaction("setVisibilityMode", world.sendEntityMessage(
    pane.sourceEntity(), "setVisibilityMode", self.visibilityMode
  ))
end

------------------------------------------------------------------------
-- State
------------------------------------------------------------------------

function btnLockConfigPressed(_, _)
  self.inLockConfigPane = true
  self.inLockedPane = nil
  self.inUnregisteredPane = nil

  widget.setVisible("ovlLocked", false)
  widget.setVisible("ovlReg", false)
  widget.setVisible("ovlUnreg", false)

  widget.setVisible("btnLockConfig", false)
  widget.setVisible("btnDismissLockConfig", true)
  widget.setVisible("close", false)

  widget.setVisible("lblBulkhead", false)
  widget.setVisible("btnBulkheadMode", false)
  widget.setVisible("lblHidden", false)
  widget.setVisible("btnHiddenMode", false)

  local passwordHashSet = tostring(not not self.passwordHash)
  widget.setText("ovlLockConfig.lblLockStatus",
    self.lblLockStatusValues[passwordHashSet]
  )
  widget.setImage("ovlLockConfig.imgLockStatus",
    self.imgLockStatusImages[passwordHashSet]
  )

  widget.setText("ovlLockConfig.newPassword", "")
  widget.setText("ovlLockConfig.newPassword2", "")
  widget.setButtonEnabled("ovlLockConfig.btnPasswordReset", self.passwordHash)

  widget.setVisible("ovlLockConfig", true)

  widget.focus("ovlLockConfig.newPassword")
end

function swapMainPane(isInit)
  self.inLockConfigPane = nil
  self.inLockedPane = nil
  self.inUnregisteredPane = nil

  if isInit and self.passwordHash then
    -- When the GUI is inited, if there is a password, then show the
    -- lock screen before allowing access.
    self.inLockedPane = true

    widget.setVisible("ovlLockConfig", false)
    widget.setVisible("ovlReg", false)
    widget.setVisible("ovlUnreg", false)

    widget.setVisible("btnLockConfig", false)
    widget.setVisible("btnDismissLockConfig", false)
    widget.setVisible("close", true)

    widget.setVisible("ovlLocked", true)

    widget.setVisible("lblBulkhead", false)
    widget.setVisible("btnBulkheadMode", false)
    widget.setVisible("lblHidden", false)
    widget.setVisible("btnHiddenMode", false)

    widget.focus("ovlLocked.password")
  elseif self.registeredDungeonId then
    widget.setVisible("ovlLockConfig", false)
    widget.setVisible("ovlLocked", false)
    widget.setVisible("ovlUnreg", false)

    widget.setVisible("btnLockConfig", true)
    widget.setVisible("btnDismissLockConfig", false)
    widget.setVisible("close", true)

    widget.setText("ovlReg.dungeonId", formatRegDungeonId(self.registeredDungeonId))
    widget.setText("ovlReg.lblGravity",
      string.format(self.lblGravityTemplate, math.floor(self.gravity))
    )
    widget.setSliderValue("ovlReg.sldGravity", gravityToSlider(self.gravity))
    widget.setChecked("ovlReg.btnGravityOverride", self.gravityOverride)
    widget.setButtonEnabled("ovlReg.btnGravityOverride", not self.gravityWired)
    widget.setChecked("ovlReg.btnShielding", self.shielding)
    widget.setButtonEnabled("ovlReg.btnShielding", not self.shieldingWired)
    widget.setText("ovlReg.lblBreathable",
      self.lblBreathableValues[tostring(self.oxygenAvailable)]
    )
    widget.setChecked("ovlReg.btnBreathable", self.breathable)
    widget.setButtonEnabled("ovlReg.btnBreathable", not self.breathableWired)
    widget.setVisible("ovlReg.btnBreathable", self.oxygenAvailable)
    widget.setText("ovlReg.lblHazardProtect",
      self.lblHazardProtectValues[self.hazardProtectStatus]
    )
    widget.setChecked("ovlReg.btnHazardProtect", self.hazardProtect)
    widget.setButtonEnabled("ovlReg.btnHazardProtect",
      not self.hazardProtectWired
    )
    widget.setVisible("ovlReg.btnHazardProtect",
      self.hazardProtectStatus == fccHazardProtectionStatus.available
    )

    widget.setVisible("ovlReg", true)

    widget.setVisible("lblBulkhead", true)
    widget.setVisible("btnBulkheadMode", true)
    widget.setVisible("lblHidden", true)
    widget.setVisible("btnHiddenMode", true)
  else
    self.inUnregisteredPane = true

    widget.setVisible("ovlLockConfig", false)
    widget.setVisible("ovlLocked", false)
    widget.setVisible("ovlReg", false)

    widget.setVisible("btnLockConfig", true)
    widget.setVisible("btnDismissLockConfig", false)
    widget.setVisible("close", true)

    widget.setText("ovlUnreg.dungeonId", self.unregisteredDungeonId)
    widget.setButtonEnabled("ovlUnreg.btnActivate", true)
    widget.setText("ovlUnreg.lblHelp", formatUnregHelp())

    widget.setVisible("ovlUnreg", true)

    widget.setVisible("lblBulkhead", true)
    widget.setVisible("btnBulkheadMode", true)
    widget.setVisible("lblHidden", true)
    widget.setVisible("btnHiddenMode", true)

    widget.focus("ovlUnreg.dungeonId")
  end
end

------------------------------------------------------------------------
-- Utility functions
------------------------------------------------------------------------

function logError(fmt, ...)
  sb.logError(
    "rl_fieldcontrolconsolegui: %s", string.format(fmt, table.unpack({...}))
  )
end

function logWarn(fmt, ...)
  sb.logWarn(
    "rl_fieldcontrolconsolegui: %s", string.format(fmt, table.unpack({...}))
  )
end

function logInfo(fmt, ...)
  sb.logInfo(
    "rl_fieldcontrolconsolegui: %s", string.format(fmt, table.unpack({...}))
  )
end

function gravityToSlider(gravity)
  return util.clamp(gravity + 10, self.gravityRange[1], self.gravityRange[2])
end

function sliderToGravity(sldValue)
  return math.floor(sldValue - 10)
end

------------------------------------------------------------------------
-- Misc
------------------------------------------------------------------------

function formatRegDungeonId(dungeonId)
  return string.format(self.regDungeonIdTemplate, dungeonId)
end

function formatUnregError(dungeonId)
  return string.format(self.unregErrorTemplate, dungeonId)
end

function formatUnregHelp()
  return string.format(self.unregHelpTemplate,
    rl_fieldcontrol.fccDungeonIdRange[1], rl_fieldcontrol.fccDungeonIdRange[2]
  )
end
