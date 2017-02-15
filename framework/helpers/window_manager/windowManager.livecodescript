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

  pass libraryStack
end libraryStack


on releaseStack
  if the target is not me then pass releaseStack

  ## Purge storage when released
  put empty into sWindowsA
  pass releaseStack
end releaseStack


/**
* Marks the current card as initialized.
* This happens in the library rather than the frontscrip as it is at the end of the message chain.
*
*/
on openCard
  if windowIsManaged() then
    ## MARK CARD AND STACK AS HAVING BEEN INITIALIZED
    windowSetCardInit the short name of the owner of the target, the short name of the target, true
  end if

  pass openCard
end openCard


--> API


function windowGetProperty pProperty, pStackName
  if pStackName is empty then put the short name of the owner of the target into pStackName
  return the uWindowManager[pProperty] of stack pStackName
end windowGetProperty


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


function windowTopMostWindowOfMode pMode
  repeat for each line tStack in the openstacks
    if tStack is empty then next repeat

    if the mode of stack tStack = pMode and the visible of stack tStack then
      return tStack
    end if
  end repeat

  return empty
end windowTopMostWindowOfMode


on windowResizeMenu pStackName
  local tRect

  if there is a group (the menubar of stack pStackName) of stack pStackName then
    put the rect of group (the menubar of stack pStackName) into tRect
    put the width of the target + 10 into item 3 of tRect
    set rect of group (the menubar of stack pStackName) to tRect
  end if
end windowResizeMenu


on windowSaveWindowPosition pStackName
  local tRect

  put the rect of stack pStackName into tRect
  appSetPref "window."& pStackName &".rect", tRect
  appSetPref "window."& pStackName &".card", the short name of the current card of stack pStackName
end windowSaveWindowPosition


/**
* Returns true if a window is being managed by this library.  False otherwise.
*
* @param  pWindow    short name of the stack window.  default is current stack.
* @return empty
*/
function windowIsManaged pWindow
  if pWindow is empty then put short name of this stack into pWindow
  return windowGetProperty("managed properties", pWindow) is not empty
end windowIsManaged


function windowPropertyIsManaged pWindow, pProperty
  local tProps
  set the wholematches to true
  put windowGetProperty("managed properties", pWindow) into tProps
  return tProps is "all" or pProperty is among the items of tProps
end windowPropertyIsManaged


/**
* Returns true if the window has been initialized, false otherwise.
*
* @param  pWindow    short name of the stack window.  default is current stack.
* @return Boolean
*/
function windowIsInit pWindow
  if pWindow is empty then put short name of this stack into pWindow
  ## IF YOU GO CARD IN A PREOPENSTACK HANDLER IT CAN ALTER THE ORDER OF FIRED EVENTS -
  ## openCard WILL COME BEFORE openStack.  SO WE COMBINE BOTH EVENTS TO SEE IF A STACK HAS BEEN INITED.
  return sWindowsA[pWindow]["initcard"] and sWindowsA[pWindow]["initstack"]
end windowIsInit


command windowClearWindowCache pWindow
  if pWindow is empty then put short name of this stack into pWindow
  delete local sWindowsA[pWindow]
end windowClearWindowCache


function windowHasBeenOpened pStackName
  return windowIsInit(pStackName)
end windowHasBeenOpened


/**
* Sets the initialized state of a window.
*
* @param  pWindow    name of window.  default is the short name of current stack.
* @param  pIsInit    Boolean.
* @return Boolean
*/
on windowSetInit pWindow, pIsInit
  if pWindow is empty then put short name of this stack into pWindow
  put pIsInit is true into sWindowsA[pWindow]["initstack"]
  put sWindowsA[pWindow]["initstack"] into sWindowsA[pWindow]["initcard"]
end windowSetInit


/**
* Returns true if the card has been opened.
*
* @param  pWindow    short name of the stack window.  default is current stack.
* @param  pCard    short name of card.  default is current card.
* @return Boolean
*/
function windowIsCardInit pWindow, pCard
  if pWindow is empty then put short name of this stack into pWindow
  if pCard is empty then put the short name of this card into pCard
  return sWindowsA[pWindow][pCard]["init"] is true
end windowIsCardInit


function windowCardHasBeenOpened pStack, pCard
  return windowIsCardInit(pStack, pCard)
end windowCardHasBeenOpened


/**
* Sets the initialized state of a window.
*
* @param  pWindow    short name of the stack window.  default is current stack.
* @param  pCard    short name of card in window.  default is current card.
* @param  pIsInit    Boolean.
* @return Boolean
*/
on windowSetCardInit pWindow, pCard, pIsInit
  if pWindow is empty then put short name of this stack into pWindow
  if pCard is empty then put the short name of the current card into pCard
  put pIsInit is true into sWindowsA[pWindow][pCard]["init"]
  if pIsInit then
    put true into sWindowsA[pWindow]["initstack"]
    put true into sWindowsA[pWindow]["initcard"]
  end if
end windowSetCardInit


/**
* Opens a stack window and loads the card that was open the last time the stack window was closed.
* if the stack window has not been opened before then it goes to card 1.  Stack window must be in
* memory.
*
* @param  pWindow    Stack window name.
* @param  pMode    mode to open window in.  default is "toplevel".
* @return empty
*/
on windowGoStack pWindow, pMode
  local tStackReference, tCard
  local tDo

  if pMode is empty then put "toplevel" into pMode

  put quote & pWindow & quote into tStackReference

  if not windowIsInit(pWindow) then
    put appGetPref("window."& pWindow &".card") into tCard
    if tCard is empty then
      put line 1 of the cardnames of stack pWindow into tCard
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
* Returns true if the current cards rect has changed since it was last closed.  Useful when
* opening a card to see if elements need to be resized.  if the card has never been opened
* before then this function returns true.
*
* @return Boolean
*/
on windowHasCardRectChanged
  local tCard, tWindow

  put short name of this stack into tWindow
  put the short name of the current card into tCard
  return sWindowsA[tWindow][tCard]["lastrect"] is not the rect of this card
end windowHasCardRectChanged


/**
* \brief Sizes and positions a stack window on screen within the working screen rect.
*
* \param pWindowName Name of the stack to position on the screen. Default is 'this stack'.
* \param pRestoreFromPrefs If set to true then this function will fetch the last saved position of the window from prefs and use that rect to position the window.
*
* This handler will use uWindowManager["default width"] and uWindowManager["default height"] to size a window that \
* is being opened for the first time. This handler is called automatically for windows that have uWindowManager["manage window"] set to true.
*
* \return empty
*/
command windowPositionWithinConstraints pWindowName, pRestoreFromPrefs
  local msgsAreLocked,tHeight,tLoc,tRect
  local tScreenRect,tStack,tWidth

  put the lockMessages into msgsAreLocked
  unlock messages

  if pWindowName is empty then
    put the short name of this stack into pWindowName
  end if
  put the long id of stack pWindowName into tStack

  ## FIRST RUN GETS DEFAULT SETTINGS CENTERED ON SCREEN
  if pRestoreFromPrefs then
    put appGetPref("window."& pWindowName &".rect") into tRect
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

      put windowGetProperty("default width", pWindowName) into tDefaultWidth
      put windowGetProperty("default height", pWindowName) into tDefaultHeight
      put windowGetProperty("default loc", pWindowName) into tLoc

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
        put the width of stack pWindowName into tWidth
        put the height of stack pWindowName into tHeight
      end if
      put min(tWidth, item 3 of tScreenRect - item 1 of tScreenRect) into tWidth
      put min(tHeight, item 4 of tScreenRect - item 2 of tScreenRect) into tHeight

      put the screenLoc into tLoc
    else
      ## PROGRAM HAS BEEN RUN BEFORE
      put item 3 of tRect - item 1 of tRect into tWidth
      put item 4 of tRect - item 2 of tRect into tHeight
    end if
  end if

  ## VALIDATE WIDTH/HEIGHT AGAINST STACK MIN/MAX VALUES
  put min( max(tWidth, the minWidth of tStack), the maxWidth of tStack) into tWidth
  put min( max(tHeight, the minHeight of tStack), the maxHeight of tStack) into tHeight

  put item 1 of tRect + tWidth into item 3 of tRect
  put item 2 of tRect + tHeight into item 4 of tRect

  ## DETERMINE LOC AFTER ADJUSTMENTS
  if tLoc is not a point then
    if windowGetProperty("center window on screen") \
          or tRect is not a rect or tWidth is not an integer or tHeight is not an integer then
      put the screenLoc into tLoc
    else
      put item 1 of tRect + floor(tWidth / 2) & "," & item 2 of tRect + floor(tHeight / 2) into tLoc
    end if
  end if

  set the lockMessages to msgsAreLocked

  ## PLACE STACK ON SCREEN
  lock screen

  set rect of stack pWindowName to tRect
  set loc of stack pWindowName to tLoc

  get tRect

  # Bug 18997 workaround <http://quality.livecode.com/show_bug.cgi?id=18997>
  put the rect of stack pWindowName into tRect
  subtract sFrameA["left"] from item 1 of tRect
  subtract sFrameA["top"] from item 2 of tRect
  add sFrameA["right"] to item 3 of tRect
  add sFrameA["bottom"] to item 4 of tRect
  # end bug workaround

  windowMoveWindowOnScreen pWindowName, tRect
  unlock screen

  return empty
end windowPositionWithinConstraints


/**
* \brief Repositions a stack so that it appears within a visible portion of the screen.
*
* \param pWindowName Name of the stack to position on the screen. Default is 'this stack'.
*
*  This handler is called from windowPositionWithinConstraints to ensure that a window appears in a visible \
      * area of the screen. You can call this function in other circumstances if need be.
*
* \return empty
*/
command windowMoveWindowOnScreen pWindowName, pEffectiveRect -- http://quality.livecode.com/show_bug.cgi?id=18997
  local tConstraintRect, tHeight, tWidth
  local tMaxHeight, tMaxWidth, tRect, tScreenNo

  if pWindowName is empty then
    put the short name of this stack into pWindowName
  end if

  put the screen of stack pWindowName into tScreenNo
  put line tScreenNo of the working screenrects into tConstraintRect
  if tConstraintRect is not a rect then put line 1 of the working screenrects into tConstraintRect

  ## WHAT WIDTHS/HEIGHTS ARE WE WORKING WITH?
  put item 3 of tConstraintRect - item 1 tConstraintRect into tMaxWidth
  put item 4 of tConstraintRect - item 2 tConstraintRect into tMaxHeight

  put pEffectiveRect into tRect
  if tRect is not a rect then
    put the effective rect of stack pWindowName into tRect
  end if
  put item 3 of tRect - item 1 of tRect into tWidth
  put item 4 of tRect - item 2 of tRect into tHeight

  ## ENSURE STACK HEIGHT/WIDTH FITS WITHIN CONSTRAINTS
  if tWidth > tMaxWidth or tHeight > tMaxHeight then
    if tWidth > tMaxWidth then
      put item 1 of tConstraintRect into item 1 of tRect
      put item 3 of tConstraintRect into item 3 of tRect
    end if

    if tHeight > tMaxHeight then
      put item 2 of tConstraintRect into item 2 of tRect
      put item 4 of tConstraintRect into item 4 of tRect
    end if

    set effective rect of stack pWindowName to tRect
  else
    ## IF HEIGHT/WIDTH CHECK OUT THEN ENSURE ENTIRE WINDOW IS ON SCREEN

    # Anything less than this and stack is repositioned on screen
    local tBuffer
    put 25 into tBuffer

    # Added temporary workarounds until bug is fixed
    # http://quality.livecode.com/show_bug.cgi?id=18997
    if item 2 of tRect < item 2 of tConstraintRect then
      --set the effective top of stack pWindowName to item 2 of tConstraintRect
      set the top of stack pWindowName to item 2 of tConstraintRect + 25 -- 25 is so title shows up.
    else if item 2 of tRect > item 4 of tConstraintRect - tBuffer then
      --set the effective bottom of stack pWindowName to item 4 of tConstraintRect
      set the bottom of stack pWindowName to item 4 of tConstraintRect - 10
    end if
    if item 1 of tRect > item 3 of tConstraintRect - tBuffer then
      ## LEFT CAN'T BE PAST RIGHT
      --set the effective right of stack pWindowName to item 3 of tConstraintRect
      set the right of stack pWindowName to item 3 of tConstraintRect - 10
    else if item 3 of tRect < item 1 of tConstraintRect + tBuffer then
      ## RIGHT CAN'T BE PAST LEFT
      --set the effective left of stack pWindowName to item 1 of tConstraintRect
      set the left of stack pWindowName to item 1 of tConstraintRect + 10
    end if
  end if

  return empty
end windowMoveWindowOnScreen


/**
* \brief Returns the loc of a rectangle.
*
* \param pRect The rectangle to find the loc of.
*
* \return Point
*/
private function _locOfRect pRect
  local tLoc

  put item 1 of pRect + floor( (item 3 of pRect - item 1 of pRect) / 2 ) into item 1 of tLoc
  put item 2 of pRect + floor( (item 4 of pRect - item 2 of pRect) / 2 ) into item 2 of tLoc
  return tLoc
end _locOfRect
