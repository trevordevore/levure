script "Logger Log Monitor"
local sOrigTarget, sOrigLocTypes

on preOpenStack
  if there is not a field "LogMessages" then
    set the label of me to "Log Monitor"
    set the minwidth of me to 450
    set the minheight of me to 400
    set the destroyStack of me to true

    set the visible of me to true

    lock messages
    create field "LogMessages"
    set the vscrollbar of it to true
    set the hscrollbar of it to true
    create button "ClearLog"
    set the label of it to "Clear Log"
    set the style of it to "rectangle"
    set the height of it to 23
    set the width of it to 82
    create button "LogNetworkTraffic"
    set the label of it to "Log Network Traffic"
    set the style of it to "checkbox"
    set the hiliteBorder of it to false
    set the height of it to 23
    set the width of it to 150
    create button "CopyToClipboard"
    set the label of it to "Copy to Clipboard"
    set the style of it to "rectangle"
    set the height of it to 23
    set the width of it to 140
    unlock messages
    resizeStack the width of this stack, the height of this stack
  end if
end preOpenStack

on preOpenCard
   put empty into field "LogMessages" of me
   set the hilite of button "LogNetworkTraffic" to false

   if there is a stack "Logger Library" then
      put loggerGetTypes() into sOrigTarget
      put loggerGetTypes() into sOrigLocTypes

      loggerSetTarget the long id of field "LogMessages" of me
      loggerSetTypes "developer,msg,extensions"
   else
      set the text of field "LogMessages" of me to "Logger helper is not available"
   end if
end preOpenCard


on closeCard
   if there is a stack "Logger Library" then
      loggerSetTarget sOrigTarget
      loggerSetTypes sOrigLocTypes
   end if

   put empty into field "LogMessages" of me
   set the hilite of button "LogNetworkTraffic" to false
end closeCard


on resizeStack pNewWidth, pNewHeight, pOldWidth, pOldHeight
  set the bottomleft of button "ClearLog" to 13, pNewHeight - 13
  set the rect of field "LogMessages" to 0,0,pNewWidth, the top of button "ClearLog" - 13
  set the loc of button "LogNetworkTraffic" to \
        the right of button "ClearLog" + 20 + (the width of button "LogNetworkTraffic" / 2), item 2 of the loc of button "ClearLog"
  set the bottomright of button "CopyToClipboard" to pNewWidth - 13, the bottom of button "ClearLog"
end resizeStack


on mouseUp pBtnNum
  if pBtnNum is 1 then
    switch the short name of the target
    case "ClearLog"
      uiClearLog
      break
    case "LogNetworkTraffic"
      uiSetLogNetworkTraffic
      break
    case "CopyToClipboard"
      uiCopyToClipboard
      break
    end switch
  end if
end mouseUp


command uiClearLog
  set the text of field "LogMessages" to empty
end uiClearlog


command uiSetLogNetworkTraffic
  if the hilite of button "LogNetworkTraffic" then
    loggerAddType "network"
  else
    loggerRemoveType "network"
  end if
end uiSetLogNetworkTraffic


command uiCopyToClipboard
  set the clipboardData to the text of field "LogMessages"
end uiCopyToClipboard
