function init()
end

function update()
  localAnimator.clearDrawables()

  local targetingData = animationConfig.animationParameter("targetingData")
  if not targetingData then return end

  local scannerConfig = animationConfig.animationParameter("scannerConfig")
  for _, v in ipairs(targetingData) do
    localAnimator.addDrawable({
      image = scannerConfig.image:gsub("<variant>", tostring(v[2])),
      fullbright = true,
      position = v[1],
      centered = false,
      color = scannerConfig.colors[v[2]]
    }, "overlay")
  end
end
