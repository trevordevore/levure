script "appLogging"
local sLogFile
local sLogNetworkTraffic = "false"
local sNetworkFilters


command appSetLogFile pFilename
  put pFilename into sLogFile
end appSetLogFile


function appGetLogfile
  return sLogFile
end appGetLogfile


command appLogNetworkTraffic pBoolean
  put pBoolean is true into sLogNetworkTraffic
end appLogNetworkTraffic


command appSetNetworkTrafficLogFilters pFilters
  put pFilters into sNetworkFilters
end appSetNetworkTrafficLogFilters


function appGetNetworkTrafficLogFilters
  return sNetworkFilters
end appGetNetworkTrafficLogFilters


command appLogMsg pMsg
  local tError

  if sLogFile is "console" then
    write pMsg & cr to stdout
  else if sLogFile is not empty then
    open file sLogFile for append
    put the result into tError

    if tError is empty then
      write "[" & the internet date & "] " && pMsg & cr to file sLogFile
    end if

    close file sLogFile
  end if

  return tError for error
end appLogMsg

# LCB
on logChanged pMsg
  if sLogFile is not empty then
    appLogMsg pMsg
  else
    pass logChanged
  end if
end logChanged

# libURL
on ulLogIt pMsg
  if sLogNetworkTraffic AND sLogFile is not empty then
    _logLibURLMessage pMsg
  else
    pass ulLogIt
  end if
end ulLogIt


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
