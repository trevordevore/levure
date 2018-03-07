script "Logger Library"
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


on releaseStack
  if the target is not me then pass releaseStack
end releaseStack


/**
Summary: Sets the field where log messages will be sent.

pTarget: `console`, `<filename>`, or field reference (e.g. `<the long id field>`).

Description:
You can target the "console", a file, or a field. "console" writes the log message to `stdout`.

Examples:
loggerSetTarget "console"
loggerSetTarget specialFolderPath("desktop") & "/log_file.txt"
loggerSetTarget the long id of field "Log" of me

Returns: Empty
*/
command loggerSetTarget pTarget
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

  return empty
end loggerSetTarget


/**
Summary: Returns the current target where log messages are sent.

Returns: empty, `console`, `<filename>`, or field reference
*/
function loggerGetTarget
  return sLogTarget
end loggerGetTarget


/**
Summary: Set the type of messages to log.

pTypes: A comma-delimited list of types to log. `developer`, `network`, `msg`, `extensions`.

Description:
Use this command to filter the types of messages that are logged.

`developer`: Any message logged using `loggerLogMsg`.
`network`: Messages logged by libURL.
`msg`: Any `put` statements that do not have a target. E.g. `put "testing"`
`extensions`: Messages logged by an extension using the `log` command in LiveCode Builder.

Returns: Empty
*/
command loggerSetTypes pTypes
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

  _activateExternalLogger sLogA["network"] is true

  return empty
end loggerSetTypes


/**
Summary: Opens a palette stack that displays log messages.

Description:
Use the log monitor to aid in debugging. It can be used in the IDE or in a standalone. For
example, if you want to open the logger whenever running a `test` standalone add the following
script to `InitializeApplication`:

```
command InitializeApplication
  if levureBuildProfile() is "test" then
    loggerOpenLogMonitor
  end if

  #...
InitializeApplication
```

Returns: Empty
*/
command loggerOpenLogMonitor
  local tFilename, msgsAreLocked

  put the lockmessages into msgsAreLocked
  lock messages

  put the filename of me into tFilename
  set the itemDelimiter to "/"
  put "logger_monitor.livecodescript" into the last item of tFilename
  set the width of stack tFilename to 450
  set the height of stack tFilename to 600
  set the loc of stack tFilename to the screenloc

  set the lockMessages to msgsAreLocked

  palette stack tFilename

  return empty
end loggerOpenLogMonitor


/**
Summary: Start logging a specific message type.

pType: `developer`, `network`, `msg`, `extensions`.

Returns: Empty
*/
command loggerAddType pType
  if pType is among the items of kLogTypes then
    put true into sLogA[pType]
  end if

  _activateExternalLogger sLogA["network"] is true

  return empty
end loggerAddType


/**
Summary: Stop logging a specific message type.

pType: `developer`, `network`, `msg`, `extensions`.

Returns: Empty
*/
command loggerRemoveType pType
  if pType is among the items of kLogTypes then
    put false into sLogA[pType]
  end if

  _activateExternalLogger sLogA["network"] is true

  return empty
end loggerRemoveType


/**
Summary: Returns the types of messages that are being logged.

Returns: Comma-delimited list
*/
function loggerGetTypes
  local pTypes

  repeat for each key tKey in sLogA
    if sLogA[tKey] then
      put tKey & "," after pTypes
    end if
  end repeat
  delete the last char of pTypes
  sort items of pTypes

  return pTypes
end loggerGetTypes


/**
Summary: Registers regex filters that will be applied to libURL messages that are logged.

pFilters: A CR-delimited list of filters to apply to libURL messages. Each line is a tab-delimited list where item 1 is a regex pattern and item 2 is the value to use as a replacement.

Description:
You can set network traffic log filters to remove sensitive data from logs that you generate.

Returns: Empty
*/
command loggerSetNetworkTrafficFilters pFilters
  put pFilters into sNetworkFilters
  return empty
end loggerSetNetworkTrafficFilters


/**
Summary: Returns the list of filters that are being applied to libURL messages.

Return: CR-delimited list of filters.
*/
function loggerGetNetworkTrafficFilters
  return sNetworkFilters
end loggerGetNetworkTrafficFilters


/**
Summary: Logs a message. The message is of type `developer`.

pMsg: The message to log.

Returns: Error message
*/
command loggerLogMsg pMsg
  if not sLogA["developer"] OR sLogTarget is empty then return empty

  local tError

  _log pMsg
  put the result into tError

  return tError for error
end loggerLogMsg


private command _log pMsg
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
      write textEncode(pMsg, "utf8") to file sLogTarget
    end if

    close file sLogTarget
  end if

  return tError for error
end _log


private command _activateExternalLogger pBoolean
  if pBoolean then
    # tsNet just looks for a non-empty value to turn logging on
    dispatch "ulExtSetLogField" with "nothing to see here"
  else
    dispatch "ulExtSetLogField" with empty
  end if
end _activateExternalLogger

# LCB
on logChanged pMsg
  if sLogA["extensions"] AND sLogTarget is not empty then
    _log pMsg
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
  if sLogA["msg"] and msg is not empty then
    _log "msg changed:" && msg
  end if
  pass msgChanged
end msgChanged


/**
Summary: Filters and logs a libURL message

pMsg: The message to log

Description:
Replaces CRLF with CR so that extra lines don't appear in the log. Any filters
set using loggerSetNetworkTrafficFilters will be applied as well.
*/
private command _logLibURLMessage pMsg
  local tFilter, tCR, tLF

  put numToCodePoint(10) into tLF
  put numToCodePoint(13) into tCR

  repeat until the last char of pMsg is not among the items of (tLF & "," & tCR)
    delete the last char of pMsg
  end repeat

  replace tCR & tLF with tCR in pMsg

  set the itemDelimiter to tab
  repeat for each line tFilter in sNetworkFilters
    -- item 1 of tFilter: regex
    -- item 2 of tFilter: replacement
    put replaceText(pMsg, item 1 of tFilter, item 2 of tFilter) into pMsg
  end repeat

  _log pMsg
end _logLibURLMessage
