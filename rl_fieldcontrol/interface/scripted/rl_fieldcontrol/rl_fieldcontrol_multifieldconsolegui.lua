------------------------------------------------------------------------
-- This script is not intended to be used directly as an interface
-- script. Instead, it is intended to be loaded by a shim script.
--
-- The shim must provide an `init` function that ensures the correct
-- version of Field Control Technology is installed before loading this
-- script and calling `rl_fieldcontrol_multifieldconsolegui_init`. The
-- last call of the shim's init function must be `swapMainPane(true)`.
--
-- The shim must provide all callbacks required by the interface pane,
-- but these may be stubs. This script may override any such callbacks.
--
-- Functions that must be provided and implemented by the shim:
--
--   logError(fmt, ...)
--   logWarn(fmt, ...)
--   logInfo(fmt, ...)
--   gravityToSlider(gravity)
--   sliderToGravity(sldValue)
--
-- Functions that may be provided by the shim:
--
--   checkExtraWidgets(data)
--   showExtraWidgets(visible)
--   syncExtraWidgets(data)
------------------------------------------------------------------------

require "/scripts/rl_fieldcontrol.lua"
require "/scripts/util.lua"

local fccHazardProtectionStatus = rl_fieldcontrol.fccHazardProtectionStatus

function rl_fieldcontrol_multifieldconsolegui_init()
  self.beginTransaction = rl_fieldcontrol.beginTransaction
  self.initTransactions = rl_fieldcontrol.initTransactions
  self.processTransactions = rl_fieldcontrol.processTransactions
  self.registerTransaction = rl_fieldcontrol.registerTransaction

  local icon = config.getParameter("windowTitleIcon")
  if icon then pane.setTitleIcon(icon) end

  self.btnLockConfigImages = config.getParameter("btnLockConfigImages")
  self.imgLockStatusImages = config.getParameter("imgLockStatusImages")
  self.lblLockStatusValues = config.getParameter("lblLockStatusValues")
  self.lblBreathableValues = config.getParameter("lblBreathableValues")
  self.lblGravityTemplate = config.getParameter("lblGravityTemplate")
  self.lblHazardProtectValues = config.getParameter("lblHazardProtectValues")
  self.lblSystemStatusValues = config.getParameter("lblSystemStatusValues")
  self.sounds = config.getParameter("sounds")

  self.environmentValid = not not config.getParameter("environmentValid")
  widget.setText("ovlReg.lblSystemStatus",
    self.lblSystemStatusValues[tostring(self.environmentValid)]
  )

  self.passwordHash = config.getParameter("passwordHash")
  widget.setButtonImages("btnLockConfig",
    self.btnLockConfigImages[tostring(not not self.passwordHash)]
  )

  self.gravity = config.getParameter("gravity")
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

  self.registerTransaction("setGravity", function(r) end, function(e)
      pane.playSound(self.sounds.error)
      logError("failed to call setGravity")
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
end

function dismissed()
  for _,sound in pairs(self.sounds) do pane.stopAllSounds(sound) end
end

function update(dt)
  if self.syncFieldDataMsg then
    self.syncFieldDataMsg = rl_fieldcontrol.awaitOnMessage(
      self.syncFieldDataMsg, function(r)
        if self.passwordHash ~= r.passwordHash then
          if not self.inLockedPane then
            pane.dismiss()
            return
          else
            self.passwordHash = r.passwordHash
          end
        end

        if self.gravity ~= r.gravity or
           self.shielding ~= r.tileProtection or
           self.shieldingWired ~= r.tileProtectionWired or
           self.breathable ~= r.breathable or
           self.breathableWired ~= r.breathableWired or
           self.oxygenAvailable ~= r.oxygenAvailable or
           self.hazardProtect ~= r.hazardProtection or
           self.hazardProtectWired ~= r.hazardProtectionWired or
           (checkExtraWidgets and checkExtraWidgets(r))
        then
          self.gravity = r.gravity
          self.shielding = not not r.tileProtection
          self.shieldingWired = not not r.tileProtectionWired
          self.breathable = not not r.breathable
          self.breathableWired = not not r.breathableWired
          self.oxygenAvailable = not not r.oxygenAvailable
          self.hazardProtect = not not r.hazardProtection
          self.hazardProtectWired = not not r.hazardProtectionWired
          if syncExtraWidgets then syncExtraWidgets(r) end
          if not self.inLockConfigPane and
             not self.inLockedPane
          then
            swapMainPane()
          end
        end

        self.syncFieldDataTimer = self.syncFieldDataTime
      end, function(e)
        logError("failed to call syncFieldData")
        self.syncFieldDataTimer = self.syncFieldDataTime
      end)
  end

  self.processTransactions()

  if self.environmentValid and self.syncFieldDataTimer then
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
-- Registered Overlay Callbacks
------------------------------------------------------------------------

function btnBreathablePressed(_, _)
  if not self.oxygenAvailable then return end
  self.oldBreathable = self.breathable
  self.breathable = widget.getChecked("ovlReg.btnBreathable")
  self.beginTransaction("setBreathable", world.sendEntityMessage(
    pane.sourceEntity(), "setBreathable", self.breathable
  ))
end

-- This replaces the shim callback.
function setGravity(_, _)
  self.gravity = sliderToGravity(widget.getSliderValue("ovlReg.sldGravity"))
  widget.setText("ovlReg.lblGravity",
    string.format(self.lblGravityTemplate, math.floor(self.gravity))
  )
  self.beginTransaction("setGravity", world.sendEntityMessage(
    pane.sourceEntity(), "setGravity", self.gravity
  ))
end

function btnHazardProtectPressed(_, _)
  if self.hazardProtectStatus ~= fccHazardProtectionStatus.available then
    return
  end
  self.oldHazardProtect = self.hazardProtect
  self.hazardProtect = widget.getChecked("ovlReg.btnHazardProtect")
  self.beginTransaction("setHazardProtection", world.sendEntityMessage(
    pane.sourceEntity(), "setHazardProtection", self.hazardProtect
  ))
end

function btnShieldingPressed(_, _)
  self.oldShielding = self.shielding
  self.shielding = widget.getChecked("ovlReg.btnShielding")
  self.beginTransaction("setTileProtection", world.sendEntityMessage(
    pane.sourceEntity(), "setTileProtection", self.shielding
  ))
end

------------------------------------------------------------------------
-- State
------------------------------------------------------------------------

function btnLockConfigPressed(_, _)
  self.inLockConfigPane = true
  self.inLockedPane = nil

  widget.setVisible("ovlLocked", false)
  widget.setVisible("ovlReg", false)

  widget.setVisible("btnLockConfig", false)
  widget.setVisible("btnDismissLockConfig", true)
  widget.setVisible("close", false)

  if showExtraWidgets then showExtraWidgets(false) end

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

-- This replaces the shim function.
function swapMainPane(isInit)
  self.inLockConfigPane = nil
  self.inLockedPane = nil

  if isInit and self.passwordHash then
    -- When the GUI is inited, if there is a password, then show the
    -- lock screen before allowing access.
    self.inLockedPane = true

    widget.setVisible("ovlLockConfig", false)
    widget.setVisible("ovlReg", false)

    widget.setVisible("btnLockConfig", false)
    widget.setVisible("btnDismissLockConfig", false)
    widget.setVisible("close", true)

    widget.setVisible("ovlLocked", true)

    if showExtraWidgets then showExtraWidgets(false) end

    widget.focus("ovlLocked.password")
  else
    widget.setVisible("ovlLockConfig", false)
    widget.setVisible("ovlLocked", false)

    if self.environmentValid then widget.setVisible("btnLockConfig", true) end
    widget.setVisible("btnDismissLockConfig", false)
    widget.setVisible("close", true)

    widget.setText("ovlReg.lblGravity",
      string.format(self.lblGravityTemplate, math.floor(self.gravity))
    )
    widget.setSliderValue("ovlReg.sldGravity", gravityToSlider(self.gravity))
    widget.setChecked("ovlReg.btnShielding", self.shielding)
    widget.setButtonEnabled("ovlReg.btnShielding",
      self.environmentValid and not self.shieldingWired
    )
    widget.setText("ovlReg.lblBreathable",
      self.lblBreathableValues[tostring(self.oxygenAvailable)]
    )
    widget.setChecked("ovlReg.btnBreathable", self.breathable)
    widget.setButtonEnabled("ovlReg.btnBreathable",
      self.environmentValid and not self.breathableWired
    )
    widget.setVisible("ovlReg.btnBreathable", self.oxygenAvailable)
    widget.setText("ovlReg.lblHazardProtect",
      self.lblHazardProtectValues[self.hazardProtectStatus]
    )
    widget.setChecked("ovlReg.btnHazardProtect", self.hazardProtect)
    widget.setButtonEnabled("ovlReg.btnHazardProtect",
      self.environmentValid and not self.hazardProtectWired
    )
    widget.setVisible("ovlReg.btnHazardProtect",
      self.hazardProtectStatus == fccHazardProtectionStatus.available
    )

    widget.setVisible("ovlReg", true)

    if showExtraWidgets then showExtraWidgets(true) end
  end
end
