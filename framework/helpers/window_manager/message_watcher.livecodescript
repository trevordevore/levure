script "Window Manager Frontscript"
on desktopChanged
  if the platform is "win32" then pass desktopChanged ## Windows appears to resize our stacks for us, Mac doesn't

  repeat for each line tStackName in the openstacks
    if tStackName is not empty then
      if windowIsPropertyManaged(tStackName, "rect") then
        windowPositionWithinConstraints tStackName
      end if
    end if
  end repeat

  pass desktopChanged
end desktopChanged


on closeStack
  local tStack

  if levureApplicationState() is "shutting down" then pass closeStack

  put windowResolveTargetStack() into tStack

  if tStack is not empty then
    local tStackName, tCard

    put the short name of tStack into tStackName

    if windowIsManaged(tStackName) then
      if levureApplicationState() is "running" and windowIsPropertyManaged(tStackName, "rect") then
        windowSaveWindowPosition tStackName
      end if

      if the destroyStack of tStack then
        windowClearWindowCache tStackName
      end if
    end if
  end if

  pass closeStack
end closeStack


-- For managed windows sends windowInitialize to the stack.  One parameter is passed which
-- is true/false.  IF true, THEN the stack has been opened before.  False IF it has not.
on preOpenStack
  local tStack

  put windowResolveTargetStack() into tStack

  if tStack is not empty then
    local tStackName, tCard

    put the short name of tStack into tStackName
    put the long id of the current card of tStack into tCard

    if char 1 to 3 of tStackName is "rev" then pass preOpenStack

    if not windowIsManaged(tStackName) then pass preOpenStack

    local tIsInit
    put windowHasWindowBeenOpened(tStackName, the short name of tCard) into tIsInit

    if not tIsInit and windowIsPropertyManaged(tStackName, "rect") then
      local restoreRectFromPrefs

      lock messages ## Don't send resizeStack message
      put true into restoreRectFromPrefs
      windowPositionWithinConstraints tStackName, restoreRectFromPrefs
      unlock messages
    end if

    ## DISPATCH MESSAGE
    if windowIsPropertyManaged(tStackName, "messages") then
      dispatch "PreOpenWindow" to tCard with tIsInit
    end if

    ## SET COLOR AND MENU EDITING
    if not tIsInit and windowIsPropertyManaged(tStackName, "menu") then
      if there is a group (the menubar of tStack) of tStack then
        set backgroundcolor of group (the menubar of tStack) of tStack to effective backgroundcolor of tStack
      end if

      if the environment is "development" then
        set the editmenus of tStack to true
      end if

      windowResizeMenu tStackName
    end if
  end if

  pass preOpenStack
end preOpenStack


on preOpenCard
  local tStack

  put windowResolveTargetStack() into tStack

  if tStack is not empty then
    local tStackName

    put the short name of tStack into tStackName
    if not windowIsPropertyManaged(tStackName, "messages") then pass preOpenCard

    ## DISPATCH MESSAGE
    local tCard

    put the long id of the current card of tStack into tCard
    dispatch "PreOpenView" to tCard with windowHasCardBeenOpened(tStackName, the short name of tCard)
    dispatch "ResizeView" to tCard with the width of tCard, the height of tCard
  end if

  pass preOpenCard
end preOpenCard


on openStack
  local tStack

  put windowResolveTargetStack() into tStack

  if tStack is not empty then
    local tStackName

    put the short name of tStack into tStackName
    if not windowIsPropertyManaged(tStackName, "messages") then pass openStack

    ## DISPATCH MESSAGE
    dispatch "OpenWindow" to the current card of tStack with windowHasWindowBeenOpened(tStackName, the short name of the current card of tStack)
  end if

  pass openStack
end openStack


on openCard
  local tStack

  put windowResolveTargetStack() into tStack

  if tStack is not empty then
    local tStackName

    put the short name of tStack into tStackName

    if not windowIsPropertyManaged(tStackName, "messages") then pass openCard

    ## DISPATCH MESSAGES
    dispatch "OpenView" to the current card of tStack with windowHasCardBeenOpened(tStackName, the short name of the current card of tStack)
  end if

  ## Card is marked as being initialized in a library stack
  pass openCard
end openCard


-- Sends the ResizeView message to managed cards.
on resizeStack pWidth, pHeight, pOldWidth, pOldHeight
  local tStack

  put windowResolveTargetStack() into tStack

  if tStack is not empty then
    local tStackName

    put the short name of tStack into tStackName
    if not windowIsPropertyManaged(tStackName, "messages") then pass resizeStack

    if windowIsPropertyManaged(tStackName, "menu") then
      windowResizeMenu tStackName
    end if

    if windowIsPropertyManaged(tStackName, "messages") then
      dispatch "ResizeView" to the current card of tStack with pWidth, pHeight, pOldWidth, pOldHeight
    end if
  end if

  pass resizeStack
end resizeStack


on moveStack pNewH, pNewV
  local tStackName

  put the short name of the owner of the target into tStackName
  if not windowIsPropertyManaged(tStackName, "messages") then pass moveStack

  _cancelMessage "_windowCheckForMoveStackEnd", the long id of me
  send "_windowCheckForMoveStackEnd tStackName" to me in 100 milliseconds
end moveStack


command _windowCheckForMoveStackEnd pStackName
  if there is not a stack pStackName then exit _windowCheckForMoveStackEnd

  if mouse(1) is "up" then
    if windowIsPropertyManaged(pStackName, "rect") then
      windowPositionWithinConstraints pStackName
    end if
    dispatch "moveStackEnd" to the current card of stack pStackName
  else
    # User might stop moving stack but not release mouse button
    _cancelMessage "_windowCheckForMoveStackEnd", the long id of me
    send "_windowCheckForMoveStackEnd pStackName" to me in 100 milliseconds
  end if
end _windowCheckForMoveStackEnd


private command _cancelMessage pMsg, pTargetObject
  local tMessage, tMessages, tString

  put "," & pMsg & "," into tString
  if pTargetObject is not empty then put pTargetObject after tString

  repeat until tString is not in the pendingMessages
    put the pendingMessages into tMessages
    filter tMessages with "*" & tString & "*"
    repeat for each line tMessage in tMessages
      cancel item 1 of tMessage
    end REPEAT
  end repeat
end _cancelMessage


-- Handle message sent to app stack before shutting down application
command PreShutdownApplication
  local tStack

  repeat for each line tStack in the openStacks
    if tStack is empty then next repeat
    if windowIsManaged(tStack) then
      windowSaveWindowPosition tStack
    end if
  end repeat

  pass PreShutdownApplication
end PreShutdownApplication
