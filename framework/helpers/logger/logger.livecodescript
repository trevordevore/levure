script "appLogger"
constant kLogTypes = "developer,extensions,network,msg"

local sLogTarget
local sLogA
local sNetworkFilters


on libraryStack
  if the target is not me then pass libraryStack

  put true into sLogA["developer"]
  put false into sLogA["extensions"]
  put false into sLogA["network"]
  put false into sLogA["msg"]
end libraryStack


command appSetLogTarget pTarget
  put pTarget into sLogTarget

  if sLogTarget begins with "field " then
    put the long id of sLogTarget into sLogTarget
    # Trim off substack
    local tFirstChar, tSecondChar

    put offset(" of stack " & quote, sLogTarget) into tFirstChar
    if tFirstChar > 0 then
      put offset(" of stack " & quote, sLogTarget, tFirstChar) into tSecondChar
      if tSecondChar > 0 then
        delete char (tFirstChar + tSecondChar) to -1 of sLogTarget
      end if
    end if
  end if
end appSetLogTarget


function appGetLogTarget
  return sLogTarget
end appGetLogTarget


command appSetLogTypes pTypes
  if pTypes is "all" then
    local tType
    repeat for each item tType in kLogTypes
      put true into sLogA[tType]
    end repeat
  else
    put "developer" is among the items of pTypes into sLogA["developer"]
    put "network" is among the items of pTypes into sLogA["network"]
    put "msg" is among the items of pTypes into sLogA["msg"]
    put "extensions" is among the items of pTypes into sLogA["extensions"]
  end if
  return empty
end appSetLogTypes


command appAddLogType pType
  if pType is among the items of kLogTypes then
    put true into sLogA[pType]
  end if
  return empty
end appAddLogType


command appRemoveLogType pType
  if pType is among the items of kLogTypes then
    put false into sLogA[pType]
  end if
  return empty
end appRemoveLogType


function appGetLogTypes
  local pTypes

  repeat for each key tKey in sLogA
    if sLogA[tKey] then
      put tKey & "," after pTypes
    end if
  end repeat
  delete the last char of pTypes
  sort items of pTypes

  return pTypes
end appGetLogTypes


command appSetNetworkTrafficLogFilters pFilters
  put pFilters into sNetworkFilters
end appSetNetworkTrafficLogFilters


function appGetNetworkTrafficLogFilters
  return sNetworkFilters
end appGetNetworkTrafficLogFilters


command appLogMsg pMsg
  if not sLogA["developer"] OR sLogTarget is empty then return empty

  local tError

  put "[" & the internet date & "] " && pMsg & cr into pMsg

  if sLogTarget is "console" then
    write pMsg & cr to stdout
  else if sLogTarget begins with "field " and there is a sLogTarget then
    put pMsg after field id (word 3 of sLogTarget) of stack (word -2 to -1 of sLogTarget)
  else
    open file sLogTarget for append
    put the result into tError

    if tError is empty then
      write pMsg to file sLogTarget
    end if

    close file sLogTarget
  end if

  return tError for error
end appLogMsg

# LCB
on logChanged pMsg
  if sLogA["extensions"] AND sLogTarget is not empty then
    appLogMsg pMsg
  else
    pass logChanged
  end if
end logChanged

# libURL
on ulLogIt pMsg
  if sLogA["network"] AND sLogTarget is not empty then
    _logLibURLMessage pMsg
  else
    pass ulLogIt
  end if
end ulLogIt

# Message Box
on msgChanged
  if sLogA["msg"] then
    appLogMsg "Message box" & cr & "Object:" && messageBoxLastObject() & cr & "Message:" && msg
  end if
  pass msgChanged
end msgChanged


private command _logLibURLMessage pMsg
  local tFilter

  if the last char of pMsg is cr then delete the last char of pMsg

  replace CRLF with CR in pMsg

  set the itemDelimiter to tab
  repeat for each line tFilter in sNetworkFilters
    -- item 1 of tFilter: regex
    -- item 2 of tFilter: replacement
    put replaceText(pMsg, item 1 of tFilter, item 2 of tFilter) into pMsg
  end repeat

  appLogMsg pMsg
end _logLibURLMessage
