function init()
  storage.state = nil
  for i=0,object.outputNodeCount()-1 do
    object.setOutputNodeLevel(i, false)
  end
  object.setInteractive(false)
  animator.setAnimationState("switchState", "dead")
  object.setLightColor({0, 0, 0, 0})
end
