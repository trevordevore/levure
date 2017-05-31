script "Window Manager Library"
local sWindowsA
local sFrameA

on libraryStack
  if the target is not me then pass libraryStack

  # workaround for bug #18997 <http://quality.livecode.com/show_bug.cgi?id=18997>
  lock messages
  local tStack, tEffectiveRect, tRect

  put "DetermineWindowDecorationDimensions" into tStack
  create invisible stack tStack
  put the effective rect of stack tStack into tEffectiveRect
  put the rect of stack tStack into tRect
  delete stack tStack
  unlock messages

  put item 1 of tRect - item 1 of tEffectiveRect into sFrameA["left"]
  put item 2 of tRect - item 2 of tEffectiveRect into sFrameA["top"]
  put item 3 of tEffectiveRect - item 3 of tRect into sFrameA["right"]
  put item 4 of tEffectiveRect - item 4 of tRect into sFrameA["bottom"]
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
Summary: Sizes and positions a stack window on screen within the working screen rect.

pStackName: The name of the target stack. The default is `this stack`.
pRestoreFromPrefs: If set to true then this function will fetch the last saved position of the window from prefs and use that rect to position the window.

Returns: empty

Description:
This handler will use uWindowManager["default width"] and uWindowManager["default height"] to size a window that
is being opened for the first time. This handler is called automatically if the "rect" property is managed for a
stack that is being opened.
*/
command windowPositionWithinConstraints pStackName, pRestoreFromPrefs
  local msgsAreLocked,tHeight,tLoc,tRect
  local tScreenRect,tStack,tWidth

  put the lockMessages into msgsAreLocked
  unlock messages

  if pStackName is empty then
    put the short name of this stack into pStackName
  end if
  put the long id of stack pStackName into tStack

  ## FIRST RUN GETS DEFAULT SETTINGS CENTERED ON SCREEN
  if pRestoreFromPrefs then
    put prefsGetPref("window."& pStackName &".rect") into tRect
    if tRect is a rect then
      put _locOfRect(tRect) into tLoc
    end if
  else
    put the rect of tStack into tRect
    put the loc of tStack into tLoc
  end if

  if not the resizable of tStack then ## WE DON'T TOUCH RECT OF STACKS THAT CAN'T BE RESIZED
    put the rect of tStack into tRect
    if tLoc is not a point then put the screenLoc into tLoc
    put item 3 of tRect - item 1 of tRect into tWidth
    put item 4 of tRect - item 2 of tRect into tHeight
  else
    if tRect is not a rect then
      put "0,0,0,0" into tRect
      put the working screenRect into tScreenRect

      local tDefaultWidth, tDefaultHeight, tPercent

      put windowGetProperty(pStackName, "default width") into tDefaultWidth
      put windowGetProperty(pStackName, "default height") into tDefaultHeight
      put windowGetProperty(pStackName, "default loc") into tLoc

      if tDefaultWidth is not empty then
        put item 3 of tScreenRect - item 1 of tScreenRect into tWidth
        put item 4 of tScreenRect - item 2 of tScreenRect into tHeight

        if the last char of tDefaultWidth is "%" then
          put char 1 to -2 of tDefaultWidth into tPercent
          put round(tWidth * ("." & tPercent)) into tWidth
        else if tDefaultWidth > 0 then
          put tDefaultWidth into tWidth
        else if tDefaultWidth is -1 then
          -- we already have proper value
        end if

        if the last char of tDefaultHeight is "%" then
          put char 1 to -2 of tDefaultHeight into tPercent
          put round(tHeight * ("." & tPercent)) into tHeight
        else if tDefaultHeight > 0 then
          put tDefaultHeight into tHeight
        else if tDefaultHeight is -1 then
          -- we already have proper value
        end if
      else
        put the width of stack pStackName into tWidth
        put the height of stack pStackName into tHeight
      end if
      put min(tWidth, item 3 of tScreenRect - item 1 of tScreenRect) into tWidth
      put min(tHeight, item 4 of tScreenRect - item 2 of tScreenRect) into tHeight

      put the screenLoc into tLoc
    else
      # stack has not been opened before
      put item 3 of tRect - item 1 of tRect into tWidth
      put item 4 of tRect - item 2 of tRect into tHeight
    end if
  end if

  # Validate width/height against stack min/max values
  put min( max(tWidth, the minWidth of tStack), the maxWidth of tStack) into tWidth
  put min( max(tHeight, the minHeight of tStack), the maxHeight of tStack) into tHeight

  put item 1 of tRect + tWidth into item 3 of tRect
  put item 2 of tRect + tHeight into item 4 of tRect

  # Determine loc after adjustments
  if tLoc is not a point then
    if windowGetProperty(empty, "center window on screen") \
          or tRect is not a rect or tWidth is not an integer or tHeight is not an integer then
      put the screenLoc into tLoc
    else
      put item 1 of tRect + floor(tWidth / 2) & "," & item 2 of tRect + floor(tHeight / 2) into tLoc
    end if
  end if

  set the lockMessages to msgsAreLocked

  ## Place stack on screen
  lock screen

  set rect of stack pStackName to tRect
  set loc of stack pStackName to tLoc

  get tRect

  # Bug 18997 workaround <http://quality.livecode.com/show_bug.cgi?id=18997>
  put the rect of stack pStackName into tRect
  subtract sFrameA["left"] from item 1 of tRect
  subtract sFrameA["top"] from item 2 of tRect
  add sFrameA["right"] to item 3 of tRect
  add sFrameA["bottom"] to item 4 of tRect
  # end bug workaround

  windowMoveWindowOnScreen pStackName, tRect
  unlock screen

  return empty
end windowPositionWithinConstraints


/**
Summary: Repositions a stack so that it appears within a visible portion of the screen.

pStackName: The name of the target stack. The default is `this stack`.

Returns: empty

Description:
This handler is called from windowPositionWithinConstraints to ensure that a window appears in a visible \
area of the screen. You can call this function in other circumstances if need be.
*/
command windowMoveWindowOnScreen pStackName, pEffectiveRect -- http://quality.livecode.com/show_bug.cgi?id=18997
  local tConstraintRect, tHeight, tWidth
  local tMaxHeight, tMaxWidth, tRect, tScreenNo

  if pStackName is empty then
    put the short name of this stack into pStackName
  end if

  put the screen of stack pStackName into tScreenNo
  put line tScreenNo of the working screenrects into tConstraintRect
  if tConstraintRect is not a rect then put line 1 of the working screenrects into tConstraintRect

  # What widths/heights are we working with?
  put item 3 of tConstraintRect - item 1 tConstraintRect into tMaxWidth
  put item 4 of tConstraintRect - item 2 tConstraintRect into tMaxHeight

  put pEffectiveRect into tRect
  if tRect is not a rect then
    put the effective rect of stack pStackName into tRect
  end if
  put item 3 of tRect - item 1 of tRect into tWidth
  put item 4 of tRect - item 2 of tRect into tHeight

  # Ensure stack height/width fits within constraints
  if tWidth > tMaxWidth or tHeight > tMaxHeight then
    if tWidth > tMaxWidth then
      put item 1 of tConstraintRect into item 1 of tRect
      put item 3 of tConstraintRect into item 3 of tRect
    end if

    if tHeight > tMaxHeight then
      put item 2 of tConstraintRect into item 2 of tRect
      put item 4 of tConstraintRect into item 4 of tRect
    end if

    set effective rect of stack pStackName to tRect
  else
    # If height/width check out then ensure entire window is on screen

    # Anything less than this and stack is repositioned on screen
    local tBuffer
    put 25 into tBuffer

    # Added temporary workarounds until bug is fixed
    # http://quality.livecode.com/show_bug.cgi?id=18997
    if item 2 of tRect < item 2 of tConstraintRect then
      --set the effective top of stack pStackName to item 2 of tConstraintRect
      set the top of stack pStackName to item 2 of tConstraintRect + 25 -- 25 is so title shows up.
    else if item 2 of tRect > item 4 of tConstraintRect - tBuffer then
      --set the effective bottom of stack pStackName to item 4 of tConstraintRect
      set the bottom of stack pStackName to item 4 of tConstraintRect - 10
    end if
    if item 1 of tRect > item 3 of tConstraintRect - tBuffer then
      ## LEFT CAN'T BE PAST RIGHT
      --set the effective right of stack pStackName to item 3 of tConstraintRect
      set the right of stack pStackName to item 3 of tConstraintRect - 10
    else if item 3 of tRect < item 1 of tConstraintRect + tBuffer then
      ## RIGHT CAN'T BE PAST LEFT
      --set the effective left of stack pStackName to item 1 of tConstraintRect
      set the left of stack pStackName to item 1 of tConstraintRect + 10
    end if
  end if

  return empty
end windowMoveWindowOnScreen


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
