script "Window Manager Frontscript"
on desktopChanged
  if the platform is "win32" then pass desktopChanged ## Windows appears to resize our stacks for us, Mac doesn't

  repeat for each line tStackName in the openstacks
    if tStackName is not empty then
      if windowPropertyIsManaged(tStackName, "rect") then
        windowPositionWithinConstraints tStackName
      end if
    end if
  end repeat

  pass desktopChanged
end desktopChanged


on closeStack
  local tMode, tStack, tOpenStack
  local quitTheApp = true

  if levureApplicationState() is "shutting down" then pass closeStack

  put windowResolveTargetStack() into tStack

  if tStack is not empty then
    local tStackName, tCard

    put the short name of tStack into tStackName

    if windowIsManaged(tStackName) then
      if levureApplicationState() is "running" and windowPropertyIsManaged(tStackName, "rect") then
        windowSaveWindowPosition tStackName
      end if

      if the destroyStack of tStack then
        windowClearWindowCache tStackName
      end if
    end if

    put the mode of tStack into tMode

    ## ANY MODE GREATER THAN MODELESS SHOULD NOT TRIGGER AN APPLICATION QUIT
    if tMode > 3 or (the platform is "macos" and levureAppGet("shutdown when all windows are closed") is not true) then
      pass closeStack
    end if

    # If explicitly set to false then don't quit
    if levureAppGet("shutdown when all windows are closed") is "false" then
      pass closeStack
    end if

    ## AS LONG AS MODE 1 OR 2 IS OPEN WE DON'T QUIT
    ## AS LONG AS MODE 3 IS OPEN AND VISIBLE WE DON'T QUIT
    repeat for each line tOpenStack in the openstacks
      if tOpenStack is tStackName then next repeat

      put the mode of stack tOpenStack into tMode
      ## TOPLEVEL, MODELESS, and MODAL STACKS KEEP THE APP OPEN REGARDLESS OF VISIBILITY
      if (tMode > 0 and tMode < 4) or tMode is 12 then
        put false into quitTheApp
        exit repeat
      end if
    end repeat

    if quitTheApp then
      if the environment is not "development" then
        ## Use send so that closeStack passes through hierarchy before we quit
        send "_windowQuitApplication" to me in 0 milliseconds
      end if
    end if
  end if

  pass closeStack
end closeStack


command _windowQuitApplication
  quit
end _windowQuitApplication


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
    put windowIsInit(tStackName, the short name of tCard) into tIsInit

    if not tIsInit and windowPropertyIsManaged(tStackName, "rect") then
      local restoreRectFromPrefs

      lock messages ## Don't send resizeStack message
      put true into restoreRectFromPrefs
      windowPositionWithinConstraints tStackName, restoreRectFromPrefs
      unlock messages
    end if

    ## DISPATCH MESSAGE
    if windowPropertyIsManaged(tStackName, "messages") then
      dispatch "PreOpenWindow" to tCard with tIsInit
    end if

    ## SET COLOR AND MENU EDITING
    if not tIsInit and windowPropertyIsManaged(tStackName, "menu") then
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


-- For managed windows calls PreOpenView AND ResizeView.  PreOpenView is passed
-- one parameter that is true/false.  IF true THEN the card has been opened before.
-- IF false THEN this is the first time the card has been opened.
on preOpenCard
  local tStack

  put windowResolveTargetStack() into tStack

  if tStack is not empty then
    local tStackName

    put the short name of tStack into tStackName
    if not windowPropertyIsManaged(tStackName, "messages") then pass preOpenCard

    ## DISPATCH MESSAGE
    local tCard

    put the long id of the current card of tStack into tCard
    dispatch "PreOpenView" to tCard with windowIsCardInit(tStackName, the short name of tCard)
    dispatch "ResizeView" to tCard with the width of tCard, the height of tCard
  end if

  pass preOpenCard
end preOpenCard


-- For managed windows sends windowOpen to the stack.  One parameter is passed which
-- is true/false.  IF true, THEN the stack has been opened before.  False IF it has not.
on openStack
  local tStack

  put windowResolveTargetStack() into tStack

  if tStack is not empty then
    local tStackName

    put the short name of tStack into tStackName
    if not windowPropertyIsManaged(tStackName, "messages") then pass openStack

    ## DISPATCH MESSAGE
    dispatch "OpenWindow" to the current card of tStack with windowIsInit(tStackName, the short name of the current card of tStack)
  end if

  pass openStack
end openStack


-- For managed windows calls OpenView.  OpenView is passed one parameter that is true/false.
-- IF it is true THEN the card has been opened before.  IF it is false THEN it has not been
-- opened before.
on openCard
  local tStack

  put windowResolveTargetStack() into tStack

  if tStack is not empty then
    local tStackName

    put the short name of tStack into tStackName

    if not windowPropertyIsManaged(tStackName, "messages") then pass openCard

    ## DISPATCH MESSAGES
    dispatch "OpenView" to the current card of tStack with windowIsCardInit(tStackName, the short name of the current card of tStack)
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
    if not windowPropertyIsManaged(tStackName, "messages") then pass resizeStack

    if windowPropertyIsManaged(tStackName, "menu") then
      windowResizeMenu tStackName
    end if

    if windowPropertyIsManaged(tStackName, "messages") then
      dispatch "ResizeView" to the current card of tStack with pWidth, pHeight, pOldWidth, pOldHeight
    end if
  end if

  pass resizeStack
end resizeStack


on moveStack pNewH, pNewV
  local tStackName

  put the short name of the owner of the target into tStackName
  if not windowPropertyIsManaged(tStackName, "messages") then pass moveStack

  _cancelMessage "_windowCheckForMoveStackEnd", the long id of me
  send "_windowCheckForMoveStackEnd tStackName" to me in 100 milliseconds
end moveStack


command _windowCheckForMoveStackEnd pStackName
  if there is not a stack pStackName then exit _windowCheckForMoveStackEnd

  if mouse(1) is "up" then
    windowPositionWithinConstraints pStackName
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
