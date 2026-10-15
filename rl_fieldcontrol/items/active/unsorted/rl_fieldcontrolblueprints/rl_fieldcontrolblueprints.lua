------------------------------------------------------------------------
-- Scripting for an activeitem that teaches multiple blueprints. The
-- activeitem must contain either or both of `recipes` and
-- `speciesRecipes`. If specified, `recipes` must be a list of item
-- names to teach to the player. If specified, `speciesRecipes` must be
-- a table mapping species names to a list of item names to teach to
-- players of the given species. If `speciesRecipes` is given, then
-- `speciesRecipesDefault` should be given also, and if specified, must
-- be a list of item names to teach to players of species not in
-- `speciesRecipes`.
------------------------------------------------------------------------

function init()
  self.recipes = config.getParameter("recipes", {})
  self.speciesRecipes = config.getParameter("speciesRecipes", {})
  self.speciesRecipesDefault = config.getParameter("speciesRecipesDefault", {})
  self.swingTime = config.getParameter("swingTime")
  activeItem.setArmAngle(-math.pi / 2)
end

function update(dt, fireMode, shiftHeld)
  updateAim()

  if player and not self.swingTimer and fireMode == "primary" then
    self.swingTimer = self.swingTime
  end

  if self.swingTimer then
    self.swingTimer = math.max(0, self.swingTimer - dt)

    activeItem.setArmAngle((-math.pi / 2) * (self.swingTimer / self.swingTime))

    if self.swingTimer == 0 then
      learnBlueprints()
    end
  end
end

function learnBlueprints()
  for _,itemName in ipairs(self.recipes) do
    player.giveBlueprint(itemName)
  end

  local speciesRecipes = self.speciesRecipes[player.species()] or self.speciesRecipesDefault
  for _,itemName in ipairs(speciesRecipes) do
    player.giveBlueprint(itemName)
  end

  animator.playSound("learnBlueprint")

  item.consume(1)
end

function updateAim()
  self.aimAngle, self.aimDirection = activeItem.aimAngleAndDirection(0, activeItem.ownerAimPosition())
  activeItem.setFacingDirection(self.aimDirection)
end
