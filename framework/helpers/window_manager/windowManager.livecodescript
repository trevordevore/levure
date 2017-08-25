script "Window Manager Library"
local sWindowsA
local sFrameA

on libraryStack
  if the target is not me then pass libraryStack

  # workaround for bug #18997 <http://quality.livecode.com/show_bug.cgi?id=18997>
  _calculateDecorationsForStackStyle "toplevel"
  _calculateDecorationsForStackStyle "palette"
end libraryStack


on releaseStack
  if the target is not me then pass releaseStack

  ## Purge storage when released
  put empty into sWindowsA
end releaseStack


/**
Summary: Marks the current card as initialized.

Description:
Your application MUST pass the openCard message so that it reaches this library. Otherwise the library
cannot track whether or not cards or stacks have been opened in the current session.
*/
on openCard
  # This happens in the library rather than the frontscript as it is at the end of the message chain.
  if windowIsManaged() then

    # Last updated 2017-09-01: LiveCode engine doesn't support setting the effective rect in messages prior
    # to openStack. In order to work around that the stack is hidden if preOpenStack if the rect of the stack
    # is being managed and it hasn't been set yet. Now it is time to show the stack.
    local tStackName, tIsInit

    put the short name of the owner of the target into tStackName
    put windowHasWindowBeenOpened(tStackName) into tIsInit

    if not tIsInit and not the visible of the owner of the target and windowWasVisibleInPreOpenStack(tStackName) then
      set the visible of the owner of the target to true
    end if

    windowSetCardInitializedState the short name of the owner of the target, the short name of the target, true
  end if

  pass openCard
end openCard


/**
Summary: Determines the stack of the current event's target.

Returns: stack name
*/
function windowResolveTargetStack
  local tStack

  if word 1 of the target is "card" then
    put the long id of the owner of the target into tStack
  else if word 1 of the target is "stack" then
    put the long id of the target into tStack
  else
    local tOffset
    put the long id of the target into tStack
    put offset(" of stack", tStack) into tOffset
    if tOffset > 0 then
      delete char 1 to (tOffset + 3) of tStack
      put the long id of tStack into tStack
    end if
  end if

  return tStack
end windowResolveTargetStack


/**
Summary: Returns a window manager property for a stack.

pProperty: The property to get.
pStackName: The name of the stack the property is attached to. If empty then the owner of the target is assumed.

Returns: mixed

Description:
The Window Manager library uses properties assigned to a stack to determine
whether or not the library is managed by the library. The properties are stored
in the uWindowManager custom property set. This handler accesses that property set.
*/
function windowGetProperty pStackName, pProperty
  if pStackName is empty then put the short name of the owner of the target into pStackName
  return the uWindowManager[pProperty] of stack pStackName
end windowGetProperty


/**
Summary: Use this command to set Window Manager library properties on a stack.

pProperty: The property to set.
pValue: The value to set the property to.
pStackName: The name of the stack the property is attached to. If empty then the owner of the target is assumed.

Returns: empty

*/
command windowSetProperty pStackName, pProperty, pValue
  if pStackName is empty then put the short name of the owner of the target into pStackName
  set the uWindowManager[pProperty] of stack pStackName to pValue
  return empty
end windowSetProperty


/**
Summary: Returns the name of the frontmost stack of with mode of pMode or lower.

pMode: The maximum mode the returned stack can have.

Returns: Stack name or empty

Description:
The stack must have a mode no higher than pMode and be visible.
*/
function windowTopMostWindowWithModeOfCeiling pMode
  local tMode

  repeat for each line tStack in the openstacks
    if tStack is empty then next repeat

    put the mode of stack tStack into tMode
    if tMode > 0 and tMode <= pMode and the visible of stack tStack then
      return tStack
    end if
  end repeat

  return empty
end windowTopMostWindowWithModeOfCeiling


/**
Summary: Returns the name of the frontmost stack with a mode of pMode.

pMode: An integer representing the mode the stack must have. See the `mode` propery for stacks in the dictionary for more information.

Returns: Stack name or empty

Description:
The stack must have the same mode as pMode and be visible.
*/
function windowTopMostWindowOfMode pMode
  repeat for each line tStack in the openstacks
    if tStack is empty then next repeat

    if the mode of stack tStack = pMode and the visible of stack tStack then
      return tStack
    end if
  end repeat

  return empty
end windowTopMostWindowOfMode


/**
Summary: Resizes a stack's menu to fill the width of the stack.

pStackName: The name of the target stack.

Description:
A stack's menu is the group name assigned to the `menubar` property of the stack.
*/
command windowResizeMenu pStackName
  local tRect

  if there is a group (the menubar of stack pStackName) of stack pStackName then
    put the rect of group (the menubar of stack pStackName) into tRect
    put the width of the target + 10 into item 3 of tRect
    set rect of group (the menubar of stack pStackName) to tRect
  end if

  return empty
end windowResizeMenu


/**
Summary: Saves the coordinates of the stack in preferences.

pStackName: The name of the target stack.

Description:
This handler requires the Preferences helper.
*/
command windowSaveWindowPosition pStackName
  local tRect

  put the rect of stack pStackName into tRect
  prefsSetPref "window."& pStackName &".rect", tRect
  prefsSetPref "window."& pStackName &".card", the short name of the current card of stack pStackName

  return empty
end windowSaveWindowPosition


/**
Summary Returns true if a window is being managed by this library.

pStackName: The name of the target stack. The default is `this stack`.

Returns: true/false

Description:
A stack is considered to be manaaged by this library if the
`uWindowManager["managed properties"]` custom property is not empty.
*/
function windowIsManaged pStackName
  if pStackName is empty then put short name of this stack into pStackName
  return windowGetProperty(pStackName, "managed properties") is not empty
end windowIsManaged


/**
Summary Returns true if a specific property of the window is being managed by this library.

pStackName: The name of the target stack. The default is `this stack`.

Returns: true/false

Description:
A property is considered to be manaaged by this library if the
`uWindowManager["managed properties"]` custom property is `all` or contains the property.
*/
function windowIsPropertyManaged pWindow, pProperty
  local tProps
  set the wholematches to true
  put windowGetProperty(pWindow, "managed properties") into tProps
  return tProps is "all" or pProperty is among the items of tProps
end windowIsPropertyManaged


/**
Summary: Returns true if the window has been initialized, false otherwise.

pStackName: The name of the target stack. The default is `this stack`.

Returns: true/false
*/
function windowHasWindowBeenOpened pStackName
  if pStackName is empty then put short name of this stack into pStackName

  return sWindowsA[pStackName]["initstack"]
end windowHasWindowBeenOpened


/**
Summary: Clears the internal librar cache for a stack.

pStackName: The name of the target stack. The default is `this stack`.

Returns: empty

Description:
This handler should be called when closing a managed stack that has `destroyStack` set to true.
*/
command windowClearWindowCache pStackName
  if pStackName is empty then put short name of this stack into pStackName
  delete local sWindowsA[pStackName]
  return empty
end windowClearWindowCache


/**
Summary: Sets the initialized state of a window.

pStackName: The name of the target stack. The default is `this stack`.
pIsInit: true/false

Returns: empty
*/
command windowSetInitializedState pStackName, pIsInit
  if pStackName is empty then put short name of this stack into pStackName
  put pIsInit is true into sWindowsA[pStackName]["initstack"]
  return empty
end windowSetInitializedState


/**
Summary: Returns whether or not a card has been opened at least once during the current session.

pStackName: The name of the target stack. The default is `this stack`.
pCard: The name of the target card. The default is `this card`.

Returns: empty

Description:
If you want to know if a card has been opened in your own code you should use the `windowHasCardBeenOpened` handler.
*/
function windowHasCardBeenOpened pStackName, pCard
  if pStackName is empty then put short name of this stack into pStackName
  if pCard is empty then put the short name of this card into pCard
  return sWindowsA[pStackName][pCard]["init"] is true
end windowHasCardBeenOpened


/**
Summary: Sets the initialized state of a card.

pStackName: The name of the target stack. The default is `this stack`.
pCard: The name of the target card. The default is `this card`.
pIsInit: true/false

Returns: true/false
*/
command windowSetCardInitializedState pStackName, pCard, pIsInit
  if pStackName is empty then put short name of this stack into pStackName
  if pCard is empty then put the short name of the current card into pCard
  put pIsInit is true into sWindowsA[pStackName][pCard]["init"]
  if pIsInit then
    put true into sWindowsA[pStackName]["initstack"]
  end if
end windowSetCardInitializedState


/**
Summary: Opens a stack window and loads the card that was open the last time the stack window was closed.

pStackName: The name of the target stack. The default is `this stack`.
pMode: The mode to open window in.  Default is "toplevel".

Returns: empty

Description:
If the stack window has not been opened before then it goes to card 1. Stack window must be in
memory.
*/
command windowGoStack pStackName, pMode
  local tStackReference, tCard
  local tDo

  if pMode is empty then put "toplevel" into pMode

  put quote & pStackName & quote into tStackReference

  if not windowHasWindowBeenOpened(pStackName) then
    put prefsGetPref("window."& pStackName &".card") into tCard
    if tCard is empty then
      put line 1 of the cardnames of stack pStackName into tCard
    end if

    ## FILTER OUT card id 1000 STUFF
    if word 1 of tCard is "card" then delete word 1 of tCard
    if word 1 of tCard is not "id" then
      put quote & tCard & quote into tCard
    end if

    put "go to card" && tCard && "of stack" && tStackReference && "as" && pMode into tDo
  else
    put "go stack" && tStackReference && "as" && pMode into tDo
  end if

  do tDo
end windowGoStack


/**
Summary: Called during preOpenStack to position a window before it is displayed.

pStackName: The name of the target stack.
pRestoreFromPrefs: Boolean value specifying whether or not the handler will look for previous stack window rect in prefs.
[pScreenNo]: The screen number to display the stack on. Default is 1. This will be ignored if pRestoreFromPrefs is true.

Returns: empty

Description:
After determining the rect to use the handler then alters the rect as needed in order to ensure the following:

1. That the stack size isn't too lage for the monitor the stack is opening on.
2. That the entire stack will appear on the monitor.
*/
command windowSetWindowRectBeforeOpening pStackName, pRestoreFromPrefs, pScreenNo
  local tRect, tLoc, tScreenNo, tScreenRect

  if pRestoreFromPrefs then
    put prefsGetPref("window."& pStackName &".rect") into tRect
    put _locOfRect(tRect) into tLoc
    put _whichScreenIsRectOn(tRect) into pScreenNo
  else
    put max(1, min(pScreenNo, the number of lines of the screenrects)) into pScreenNo
  end if

  put line pScreenNo of the working screenrects into tScreenRect

  put _calculateWindowRect(pStackName, tScreenRect, tRect, tLoc) into tRect

  if the effective rect of stack pStackName is not tRect then
    local msgsAreLocked

    # Quirk workaround: On macos item 4 of tRect will be reduced by 23 points after setting the
    # `effective rect` below. It seems that setting the rect during preopenstack triggers the stack
    # to scroll and it affects the rect. Manually adding in the 23 pixels fixes the issue.
    -- if the vscroll of stack pStackName > 0 then
    --   add 23 to item 4 of tRect
    -- end if

    put the lockmessages into msgsAreLocked
    lock messages ## Don't send resizeStack message
    set the effective rect of stack pStackName to tRect
    set the lockmessages to msgsAreLocked
  end if

  return empty
end windowSetWindowRectBeforeOpening


/**
Summary: Calculates the rect that should be used to open a stack window.

pStackName: Name of the target stack
[pScreenRect]: Optional screen rect to use to contrain the stack window.
[pRect]: Optional rect for the stack window.
[pLoc]: Optional loc.

Returns: rectangle

Description: The rect returned can be used to set `the effective rect` of the stack. The rect will
size the stack window such that it is entirely visible on the screen it is displayed on.
*/
function windowCalculateRectForWindow pStackName, pScreenRect, pRect, pLoc
  return _calculateWindowRect(pStackName, pScreenRect, pRect, pLoc)
end windowCalculateRectForWindow


private function _whichScreenIsRectOn pRect
  local i

  if pRect is a rect then
    repeat with i = 1 to the number of lines of the screenrects
      if item 1 to 2 of pRect is within (line i of the screenrects) then
        return i
      end if
    end repeat
  end if
  return 1
end _whichScreenIsRectOn


private function _calculateWindowRect pStackName, pDefaultScreenRect, pDefaultRect, pDefaultLoc
  local tStyle, tStack, tRect, tLoc, tDefaultWidth, tDefaultHeight
  local tScreenRect, tScreenWidth, tWidth, tScreenHeight, tHeight
  local tPercent

  put pDefaultScreenRect into tScreenRect
  put pDefaultRect into tRect
  put pDefaultLoc into tLoc

  put the long id of stack pStackName into tStack
  put the style of tStack into tStyle

  if tScreenRect is not a rect then
    put line 1 of the working screenrects into tScreenRect
  end if
  put item 3 of tScreenRect - item 1 of tScreenRect into tScreenWidth
  put item 4 of tScreenRect - item 2 of tScreenRect into tScreenHeight

  # Rect
  # Don't touch rect of a stack that isn't resizable
  # We only care about the loc from the value stored in prefs
  if tRect is not a rect and not the resizable of tStack then
    put the rect of tStack into tRect
  end if

  if tRect is not a rect then
    put windowGetProperty(pStackName, "default width") into tDefaultWidth
    put windowGetProperty(pStackName, "default height") into tDefaultHeight

    if tDefaultWidth is not empty then
      if the last char of tDefaultWidth is "%" then
        put char 1 to -2 of tDefaultWidth into tPercent
        put round(tScreenWidth * ("." & tPercent)) into tWidth
      else if tDefaultWidth > 0 then
        put tDefaultWidth into tWidth
      else if tDefaultWidth is -1 then
        put tScreenWidth into tWidth
      end if

      if the last char of tDefaultHeight is "%" then
        put char 1 to -2 of tDefaultHeight into tPercent
        put round(tScreenHeight * ("." & tPercent)) into tHeight
      else if tDefaultHeight > 0 then
        put tDefaultHeight into tHeight
      else if tDefaultHeight is -1 then
        put tScreenHeight into tHeight
      end if
    else
      put the width of tStack into tWidth
      put the height of tStack into tHeight
    end if

    put "0,0," & tWidth & "," & tHeight into tRect
  end if

  # Make sure the rect doesn't fall outside of the min/max dimensions
  put item 3 of tRect - item 1 of tRect into tWidth
  put item 4 of tRect - item 2 of tRect into tHeight
  put min(max(the minWidth of tStack, tWidth), the maxWidth of tStack) into tWidth
  put min(max(the minHeight of tStack, tHeight), the maxHeight of tStack) into tHeight
  put item 1 of tRect + tWidth into item 3 of tWidth
  put item 2 of tRect + tHeight into item 4 of tWidth

  # Loc
  if tLoc is not a point then
    put windowGetProperty(pStackName, "default loc") into tLoc

    if tLoc is not a point then
      if the last char of item 1 of tLoc is "%" then
        put char 1 to -2 of item 1 of tLoc into tPercent
        put floor(tScreenWidth * ("." & tPercent)) into item 1 of tLoc
      end if
      if the last char of item 2 of tLoc is "%" then
        put char 1 to -2 of item 2 of tLoc into tPercent
        put floor(tScreenHeight * ("." & tPercent)) into item 2 of tLoc
      end if

      if tLoc is not a point then
        put _locOfRect(line 1 of the working screenrects) into tLoc
      end if
    end if
  end if

  # Now add the decorations
  subtract sFrameA[tStyle]["left"] from item 1 of tRect
  subtract sFrameA[tStyle]["top"] from item 2 of tRect
  add sFrameA[tStyle]["right"] to item 3 of tRect
  add sFrameA[tStyle]["bottom"] to item 4 of tRect

  # Adjust loc using differences in frame sizes on left/right and top/bottom
  subtract floor(abs(sFrameA[tStyle]["left"]-sFrameA[tStyle]["right"])/2) from item 1 of tLoc
  subtract floor(abs(sFrameA[tStyle]["top"]-sFrameA[tStyle]["bottom"])/2) from item 2 of tLoc

  if the resizable of tStack then
    put _constrainWindowDimensionsToScreenDimensions(tScreenRect, tRect) into tRect
  end if
  put _centerRectAroundPoint(tRect, tLoc) into tRect
  put _shiftWindowOnScreen(tScreenRect, tRect) into tRect

  return tRect
end _calculateWindowRect


function windowGetStackRectFromEffectiveStackRect pEffectiveRect, pStyle
  local tLoc

  add sFrameA[pStyle]["left"] to item 1 of pEffectiveRect
  add sFrameA[pStyle]["top"] to item 2 of pEffectiveRect
  subtract sFrameA[pStyle]["right"] from item 3 of pEffectiveRect
  subtract sFrameA[pStyle]["bottom"] from item 4 of pEffectiveRect

  return pEffectiveRect
end windowGetStackRectFromEffectiveStackRect


/**
Summary: Positions a window after the desktop has changed.

pStackName: The name of the target stack.

Returns: empty

Description:
After the desktop changes two things must be checked:
1. That the stack size isn't too lage for the monitor the stack is opening on.
2. That the entire stack will appear on the monitor.
*/
command windowCheckWindowAfterDesktopChanged pStackName
  local tScreenRect, tEffectiveRect, tRect

  put line (the screen of stack pStackName) of the working screenrects into tScreenRect
  put the effective rect of stack pStackName into tEffectiveRect
  put the rect of stack pStackName into tRect

  put _constrainWindowDimensionsToScreenDimensions(tScreenRect, tEffectiveRect) into tEffectiveRect
  put _shiftWindowOnScreen(tScreenRect, tEffectiveRect) into tEffectiveRect

  if the effective rect of stack pStackName is not tEffectiveRect then
    set the effective rect of stack pStackName to tEffectiveRect
  end if

  return empty
end windowCheckWindowAfterDesktopChanged


/**
Summary: Positions a window after the user moves it.

pStackName: The name of the target stack.

Returns: empty

Description:
After the user moves a stack window two things need to be checked:
1. That the stack size isn't too lage for the monitor the stack is now on.
2. That the top and bottom of the title bar are in an actionable area of the screen.
*/
command windowCheckWindowAfterMove pStackName
  local tScreenRect, tEffectiveRect, tRect

  put line (the screen of stack pStackName) of the working screenrects into tScreenRect
  put the effective rect of stack pStackName into tEffectiveRect
  put the rect of stack pStackName into tRect

  put _constrainWindowDimensionsToScreenDimensions(tScreenRect, tEffectiveRect) into tEffectiveRect
  put _ensureTitleBarIsVisibleAfterMove(tScreenRect, tEffectiveRect, tRect) into tEffectiveRect

  if the effective rect of stack pStackName is not tEffectiveRect then
    set the effective rect of stack pStackName to tEffectiveRect
  end if

  return empty
end windowCheckWindowAfterMove


command _calculateDecorationsForStackStyle pStyle
  local msgsAreLocked, tStack, tEffectiveRect, tRect

  put the lockmessages into msgsAreLocked

  lock messages

  put "DetermineWindowDecorationDimensions" into tStack
  set the style of the templateStack to pStyle
  create invisible stack tStack
  put the effective rect of stack tStack into tEffectiveRect
  put the rect of stack tStack into tRect
  delete stack tStack
  reset the templateStack

  put item 1 of tRect - item 1 of tEffectiveRect into sFrameA[pStyle]["left"]
  put item 2 of tRect - item 2 of tEffectiveRect into sFrameA[pStyle]["top"]
  put item 3 of tEffectiveRect - item 3 of tRect into sFrameA[pStyle]["right"]
  put item 4 of tEffectiveRect - item 4 of tRect into sFrameA[pStyle]["bottom"]

  set the lockMessages to msgsAreLocked
end _calculateDecorationsForStackStyle


private function _ensureTitleBarIsVisibleAfterMove pScreenRect, pEffectiveStackRect, pStackRect
  local tTitleBarHeight, tDiff

  put item 2 of pStackRect - item 2 of pEffectiveStackRect into tTitleBarHeight

  # Title bar is off bottom
  put item 4 of pScreenRect - (item 2 of pEffectiveStackRect + tTitleBarHeight) into tDiff
  if tDiff < 0 then
    add tDiff to item 2 of pEffectiveStackRect
    add tDiff to item 4 of pEffectiveStackRect
  end if
  return pEffectiveStackRect
end _ensureTitleBarIsVisibleAfterMove


private function _shiftWindowOnScreen pScreenRect, pEffectiveStackRect
  local tDiff

  put item 1 of pScreenRect - item 1 of pEffectiveStackRect into tDiff
  if tDiff > 0 then
    add tDiff to item 1 of pEffectiveStackRect
    add tDiff to item 3 of pEffectiveStackRect
  else
    put item 3 of pEffectiveStackRect - item 3 of pScreenRect into tDiff
    if tDiff > 0 then
      subtract tDiff from item 1 of pEffectiveStackRect
      subtract tDiff from item 3 of pEffectiveStackRect
    end if
  end if

  put item 2 of pScreenRect - item 2 of pEffectiveStackRect into tDiff
  if tDiff > 0 then
    add tDiff to item 2 of pEffectiveStackRect
    add tDiff to item 4 of pEffectiveStackRect
  else
    put item 4 of pEffectiveStackRect - item 4 of pScreenRect into tDiff
    if tDiff > 0 then
      subtract tDiff from item 2 of pEffectiveStackRect
      subtract tDiff from item 4 of pEffectiveStackRect
    end if
  end if

  return pEffectiveStackRect
end _shiftWindowOnScreen


private function _constrainWindowDimensionsToScreenDimensions pScreenRect, pEffectiveStackRect
  local tMaxWidth, tMaxHeight, tWidth, tHeight, tDiff

  put item 3 of pScreenRect - item 1 of pScreenRect into tMaxWidth
  put item 4 of pScreenRect - item 2 of pScreenRect into tMaxHeight
  put item 3 of pEffectiveStackRect - item 1 of pEffectiveStackRect into tWidth
  put item 4 of pEffectiveStackRect - item 2 of pEffectiveStackRect into tHeight

  put tWidth - tMaxWidth into tDiff
  if tDiff > 0 then
    subtract tDiff from item 3 of pEffectiveStackRect
  end if
  put tHeight - tMaxHeight into tDiff
  if tDiff > 0 then
    subtract tDiff from item 4 of pEffectiveStackRect
  end if

  return pEffectiveStackRect
end _constrainWindowDimensionsToScreenDimensions


private function _centerRectAroundPoint pRect, pPoint
  local tWidth, tHeight, tRect

  put (item 3 of pRect - item 1 of pRect) into tWidth
  put (item 4 of pRect - item 2 of pRect) into tHeight

  put item 1 of pPoint - floor(tWidth / 2) into item 1 of tRect
  put item 1 of pPoint + round(tWidth / 2) into item 3 of tRect

  put item 2 of pPoint - floor(tHeight / 2) into item 2 of tRect
  put item 2 of pPoint + round(tHeight / 2) into item 4 of tRect

  return tRect
end _centerRectAroundPoint


/**
Summary: Returns the loc of a rectangle.

pRect: The rectangle to find the loc of.

Returns: point
*/
private function _locOfRect pRect
  local tLoc

  put item 1 of pRect + floor( (item 3 of pRect - item 1 of pRect) / 2 ) into item 1 of tLoc
  put item 2 of pRect + floor( (item 4 of pRect - item 2 of pRect) / 2 ) into item 2 of tLoc
  return tLoc
end _locOfRect
