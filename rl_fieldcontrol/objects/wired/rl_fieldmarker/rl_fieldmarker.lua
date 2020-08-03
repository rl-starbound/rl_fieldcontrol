require "/scripts/vec2.lua"

function init(args)
  if object.inputNodeCount() > 0 then
    onInputNodeChange({node=0, level=object.getInputNodeLevel(0)})
  end

  message.setHandler("getFieldMarkerBounds", getFieldMarkerBounds)
end

function getFieldMarkerBounds(_, _)
  local pos = vec2.floor(entity.position())
  return {pos[1], pos[2], pos[1] + 1, pos[2] + 1}
end

function onInputNodeChange(args)
  if args.level then
    animator.setAnimationState("light", "on")
    object.setLightColor({24, 60, 24})
  else
    animator.setAnimationState("light", "off")
    object.setLightColor({0, 0, 0})
  end
end
