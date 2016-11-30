script "Window Manager Frontscript"
on shutdown
  levureShutdownApplication
  
  pass shutdown
end shutdown


on desktopChanged
  if the platform is "win32" then pass desktopChanged ## Windows appears to resize our stacks for us, Mac doesn't
  
  repeat for each line tStackName in the openstacks
    if tStackName is not empty then
      if windowIsManaged(tStackName) then
        windowPositionWithinConstraints tStackName
      end if
    end if
  end repeat
  
  pass desktopChanged
end desktopChanged


on closeStack
  local tMode, tStack, tStackThatIsClosing
  local quitTheApp = true
  
  if levureApplicationState() is "shutting down" then pass closeStack
  
  if windowIsManaged(the short name of the owner of the target) and levureApplicationState() is "running" \
        and windowGetProperty("save window state") is not "false" then
    windowSaveWindowPosition the short name of the owner of the target
  end if
  
  put the mode of this stack into tMode
  
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
  put the short name of the owner of the target into tStackThatIsClosing
  repeat for each line tStack in the openstacks
    if tStack is tStackThatIsClosing then next repeat
    
    put the mode of stack tStack into tMode
    ## TOPLEVEL AND MODELESS STACKS KEEP THE APP OPEN REGARDLESS OF VISIBILITY
    if tMode > 0 and tMode < 4 or tMode is 12 then
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
  
  pass closeStack
end closeStack


command _windowQuitApplication
  quit
end _windowQuitApplication


-- For managed windows sends windowInitialize to the stack.  One parameter is passed which
-- is true/false.  IF true, THEN the stack has been opened before.  False IF it has not.
on preOpenStack
  if char 1 to 3 of the short name of the owner of the target is "rev" then pass preOpenStack   
  
  if not windowIsManaged() then pass preOpenStack
  
  if not windowIsInit() then
    lock messages ## Don't send resizeStack message
    put true into restoreRectFromPrefs
    windowPositionWithinConstraints empty, restoreRectFromPrefs
    unlock messages      
  end if
  
  ## DISPATCH MESSAGE
  dispatch "PreOpenWindow" to the target with windowIsInit()
  
  ## SET COLOR AND MENU EDITING
  if not windowIsInit() then
    if there is a group (the menubar of this stack) of this stack then
      set backgroundcolor of group (the menubar of this stack) of this stack to effective backgroundcolor of this stack
    end if
    
    if the environment is "development" then
      set the editmenus of this stack to true
    end if
    
    windowResizeMenu the short name of the owner of the target
  end if
  
  pass preOpenStack
end preOpenStack


-- For managed windows calls PreOpenView AND ResizeView.  PreOpenView is passed
-- one parameter that is true/false.  IF true THEN the card has been opened before.
-- IF false THEN this is the first time the card has been opened.
on preOpenCard   
  if not windowIsManaged() then pass preOpenCard
  
  ## DISPATCH MESSAGE
  dispatch "PreOpenView" to the target with windowIsCardInit()
  dispatch "ResizeView" to the target with the width of this card, the height of this card
  
  pass preOpenCard
end preOpenCard


-- For managed windows sends windowOpen to the stack.  One parameter is passed which
-- is true/false.  IF true, THEN the stack has been opened before.  False IF it has not.
on openStack   
  if not windowIsManaged() then pass openStack
  
  ## DISPATCH MESSAGE
  dispatch "OpenWindow" to the target with windowIsInit()
  
  pass openStack
end openStack


-- For managed windows calls OpenView.  OpenView is passed one parameter that is true/false.
-- IF it is true THEN the card has been opened before.  IF it is false THEN it has not been 
-- opened before.
on openCard   
  if not windowIsManaged() then pass openCard
  
  ## DISPATCH MESSAGES
  dispatch "OpenView" to the target with windowIsCardInit()
  
  ## Card is marked as being initialized in a library stack
  pass openCard
end openCard


-- Sends the ResizeView message to managed cards.
on resizeStack pWidth, pHeight, pOldWidth, pOldHeight
  if not windowIsManaged() then pass resizeStack
  
  windowResizeMenu the short name of the owner of the target
  
  dispatch "ResizeView" to the target with pWidth, pHeight, pOldWidth, pOldHeight
  
  pass resizeStack
end resizeStack
