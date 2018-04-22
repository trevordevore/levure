script "Window Manager Frontscript"
# Need a bit of a delay between end of moveStack and sending a moveStackEnd message to the widnow.
# If the window ends up being resized then the engine doesn't redraw the window properly.
# 100 doesn't work on a Retina 5K, 27-inch Late 2015 iMac.
# 300 does.
constant kCheckForWindowMoveEndDelay = 300

local sVisibleStateInPreOpenStackA


on desktopChanged
  if the platform is "win32" then pass desktopChanged ## Windows appears to resize our stacks for us, Mac doesn't

  repeat for each line tStackName in the openstacks
    if tStackName is not empty then
      if windowIsPropertyManaged(tStackName, "rect") then
        windowCheckWindowAfterDesktopChanged tStackName
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
    put windowHasWindowBeenOpened(tStackName) into tIsInit

    if the environment is "development" then
      set the editmenus of tStack to true
    end if

    # Last Updated 2017-09-01: If the window size is being managed then hide the stack. Ideally the stack would be resized here
    # but the LiveCode engine doesn't allow you to set `the effective rect` in `preOpenStack`. `openStack` is the first
    # handler where you can set the effective rect.
    if not tIsInit and windowIsPropertyManaged(tStackName, "rect") then
      put the visible of tStack into sVisibleStateInPreOpenStackA[tStackName]
      if sVisibleStateInPreOpenStackA[tStackName] then
        set the visible of tStack to false
      end if
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

      windowResizeMenu tStackName
    end if
  end if

  pass preOpenStack
end preOpenStack


/**
Summary: Used by the `openCard` handler in the windowManager library to check if a window should be shown in `openCard`.

Returns: Boolean
*/
function windowWasVisibleInPreOpenStack pStackName
  local tState

  # Clean up memory. This is only accesse once during the opening of the stack.
  put sVisibleStateInPreOpenStackA[pStackName] into tState
  delete local sVisibleStateInPreOpenStackA[pStackName]

  return tState
end windowWasVisibleInPreOpenStack


on preOpenCard
  local tStack

  put windowResolveTargetStack() into tStack

  if tStack is not empty then
    local tStackName

    put the short name of tStack into tStackName
    if not windowIsPropertyManaged(tStackName, "messages") then pass preOpenCard

    # Last Updated 2017-09-01: If the stack rect is being managed then the stack will be
    # resized in `openStack`. That is the first message where the `effective rect` can be set.
    # If stack size hasn't been set yet then do not send `ResizeView` in this handler.
    local tIsInit
    put windowHasWindowBeenOpened(tStackName) into tIsInit

    ## DISPATCH MESSAGE
    local tCard

    put the long id of the current card of tStack into tCard
    dispatch "PreOpenView" to tCard with windowHasCardBeenOpened(tStackName, the short name of tCard)
    if tIsInit or not windowIsPropertyManaged(tStackName, "rect") then
      _dispatchResizeView tCard
    end if
  end if

  pass preOpenCard
end preOpenCard


on openStack
  local tStack, tMsgsAreManaged

  put windowResolveTargetStack() into tStack

  if tStack is not empty then
    local tStackName

    put the short name of tStack into tStackName
    put windowIsPropertyManaged(tStackName, "messages") into tMsgsAreManaged

    ## Position window
    # Last Updated 2017-09-01: This is the first message where `the effective rect` can be set. Set the rect,
    # dispatch the `ResizeView` message, and show the stack.
    local tIsInit
    put windowHasWindowBeenOpened(tStackName) into tIsInit

    if not tIsInit and windowIsPropertyManaged(tStackName, "rect") then
      local restoreRectFromPrefs

      put true into restoreRectFromPrefs
      windowSetWindowRectBeforeOpening tStackName, restoreRectFromPrefs

      if tMsgsAreManaged then
        _dispatchResizeView the long id of the current card of tStack
      end if
    end if

    ## DISPATCH MESSAGE
    if tMsgsAreManaged then
      dispatch "OpenWindow" to the current card of tStack with windowHasWindowBeenOpened(tStackName)
    end if
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
      _dispatchResizeView the long id of the current card of tStack, pWidth, pHeight, pOldWidth, pOldHeight
    end if
  end if

  pass resizeStack
end resizeStack


on moveStack pNewH, pNewV
  local tStackName

  put the short name of the owner of the target into tStackName
  if not windowIsPropertyManaged(tStackName, "messages") then pass moveStack

  _cancelMessage "_windowCheckForMoveStackEnd", the long id of me
  send "_windowCheckForMoveStackEnd tStackName" to me in kCheckForWindowMoveEndDelay milliseconds
end moveStack


private command _dispatchResizeView pCardRef, pWidth, pHeight, pOldWidth, pOldHeight
  if pWidth is empty then put the width of pCardRef into pWidth
  if pHeight is empty then put the height of pCardRef into pHeight
  dispatch "ResizeView" to pCardRef with pWidth, pHeight, pOldWidth, pOldHeight
end _dispatchResizeView


command _windowCheckForMoveStackEnd pStackName
  if there is not a stack pStackName then exit _windowCheckForMoveStackEnd

  if mouse(1) is "up" then
    if windowIsPropertyManaged(pStackName, "rect") then
      windowCheckWindowAfterMove pStackName
    end if
    dispatch "moveStackEnd" to the current card of stack pStackName
  else
    # User might stop moving stack but not release mouse button
    _cancelMessage "_windowCheckForMoveStackEnd", the long id of me
    send "_windowCheckForMoveStackEnd pStackName" to me in kCheckForWindowMoveEndDelay milliseconds
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
    if windowIsManaged(tStack) and windowIsPropertyManaged(tStack, "rect") then
      windowSaveWindowPosition tStack
    end if
  end repeat

  pass PreShutdownApplication
end PreShutdownApplication
