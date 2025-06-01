function init(args)
  if object.inputNodeCount() > 0 then
    onInputNodeChange({node=0, level=object.getInputNodeLevel(0)})
  end

  message.setHandler("getFieldMarkerPosition", getFieldMarkerPosition)
end

function getFieldMarkerPosition(_, _)
  return entity.position()
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
