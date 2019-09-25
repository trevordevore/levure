script "Logger Library"
constant kBuiltInLogTypes = "developer,error,extensions,network,msg"
constant kDefaultLogTypes = "developer,error,network"

local sLogTarget
local sLogA
local sNetworkFilters
local sColDelim, sRowDelim
local sIncludeLogType
local sLoggingSuspended = "false"


on libraryStack
  if the target is not me then pass libraryStack

  local tLogTypes, tColDelim, tRowDelim, tIncludeLogType

  put kDefaultLogTypes into tLogTypes
  if levureAppHasProperty("logger>types") then put levureAppGet ("logger>types") into tLogTypes
  loggerSetTypes tLogTypes

  if levureAppHasProperty("logger>target") then put levureAppGet ("logger>target") into sLogTarget

  put 9 into tColDelim
  if levureAppHasProperty("logger>column delimiter") then put levureAppGet ("logger>column delimiter") into tColDelim
  loggerSetColumnDelimiter tColDelim

  put 10 into tRowDelim
  if levureAppHasProperty("logger>row delimiter") then put levureAppGet ("logger>row delimiter") into tRowDelim
  loggerSetRowDelimiter tRowDelim

  put true into tIncludeLogType
  if levureAppHasProperty("logger>include log type") then put levureAppGet ("logger>include log type") into tIncludeLogType
  loggerSetIncludeLogType tIncludeLogType
end libraryStack


on releaseStack
  if the target is not me then pass releaseStack
end releaseStack


/**
Summary: Sets where log messages will be sent.

Parameters:
pTarget: `console`, `<filename>`, or field reference (e.g. `<the long id field>`).

Description:
You can target the "console", a file, or a field. "console" writes the log message to `stdout`.

Examples:
loggerSetTarget "console"
loggerSetTarget specialFolderPath("desktop") & "/log_file.txt"
loggerSetTarget the long id of field "Log" of me # using just field "x" of me will instead try to use the _contents_ of the field.

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

Parameters:
pTypes: A comma-delimited list of types to log.  Levure provides special handling for `all`, `developer`, `network`, `msg`, `extensions`, and `error`.  You can also specify your own types.

Description:
Use this command to filter the types of messages that are logged.  Types that are not specified are ignored.

The following types receive special handling from Levure
`all`: All of the below special message types
`developer`: Default message logged using `loggerLogMsg`.
`network`: Messages logged by libURL.
`msg`: Any `put` statements that do not have a target. E.g. `put "testing"`
`extensions`: Messages logged by an extension using the `log` command in LiveCode Builder.

Examples:
loggerSetTypes "developer,network"
loggerSetTypes "timer,oops" #custom types I want to use with loggerLogMsg

Returns: Empty
*/
command loggerSetTypes pTypes
  local tPreAssignBool, tType, tTypeToAssign

  put "all" is among the items of pTypes into tPreAssignBool

  repeat for each item tType in kBuiltInLogTypes
    put tPreAssignBool into sLogA[tType]
  end repeat

  repeat for each item tTypeToAssign in pTypes
    put true into sLogA[tTypeToAssign]
  end repeat

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

Parameters:
pType: The type of message to start logging.  This can be one of Levure's special types or any one that you define.

Examples:
loggerAddType "msg"
loggerAddType "oops" #a custom type

Returns: Empty
*/
command loggerAddType pType
  put true into sLogA[pType]
  _activateExternalLogger sLogA["network"] is true
  return empty
end loggerAddType


/**
Summary: Stop logging a specific message type.

Parameters:
pType: The type of message to start logging.  This can be one of Levure's special types or any one that you define.

Examples:
loggerAddType "msg"
loggerAddType "oops" #a custom type

Returns: Empty
*/
command loggerRemoveType pType
  put false into sLogA[pType]
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

Parameters:
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
Summary: Sets column delimiter in the log.

Parameters:
pColDelim: One or more ascii (numeric) codes, joined by "+".

Examples:
loggerSetColumnDelimiter 9

Returns: Empty
*/
command loggerSetColumnDelimiter pColDelim
  local tAsciiCode

  set the itemDelimiter to "+"
  repeat for each item tAsciiCode in pColDelim
    put numToNativeChar(tAsciiCode) after sColDelim
  end repeat
end loggerSetColumnDelimiter


/**
Summary: Sets row delimiter in the log.

Parameters:
pRowDelim: One or more ascii (numeric) codes, joined by "+"

Examples:
loggerSetRowDelimiter 13
loggerSetRowDelimiter 13+10

Returns: Empty
*/
command loggerSetRowDelimiter pRowDelim
  local tAsciiCode

  set the itemDelimiter to "+"
  repeat for each item tAsciiCode in pRowDelim
    put numToNativeChar(tAsciiCode) after sRowDelim
  end repeat
end loggerSetRowDelimiter


/**
Summary: Sets whether to include the log type in the log.

Parameters:
pIncludeLogType: Boolean specifying whether or not to include the log type in each entry.

Description:
Each entry in the log can include the type or type of log entry (or not, your choice).
This will be in its own column, surrounded by square brackets, e.g. [developer]

Examples:
loggerSetIncludeLogType true

Returns: Empty
*/
command loggerSetIncludeLogType pIncludeLogType
  put pIncludeLogType is true into sIncludeLogType
end loggerSetIncludeLogType


/**
Summary: Logs a message.

Parameters:
pMsg: The message to log.
pLogType:  Type of the message.  Default is `developer`.

Returns: Error message
*/
command loggerLogMsg pMsg, pLogType
 local tError

  if sLogTarget is empty then return empty
  if pLogType is empty then put "developer" into pLogType
  if not sLogA[pLogType] then return empty

  _log pMsg, pLogType
  put the result into tError

  return tError for error
end loggerLogMsg


/**
Summary: Suspends logging
*/
command loggerSuspend
  put true into sLoggingSuspended
end loggerSuspend


/**
Summary: Resumes logging
*/
command loggerResume
  put false into sLoggingSuspended
end loggerResume


private command _log pMsg, pLogType
  local tError
  local tMsgInfo

  if sLoggingSuspended then return empty for error

  put _squareBracket(the internet date) & sColDelim into tMsgInfo
  if sIncludeLogType then put sColDelim & _squareBracket(pLogType) & sColDelim after tMsgInfo
  put tMsgInfo before pMsg
  put sRowDelim after pMsg

  if sLogTarget is "console" then
    write pMsg & cr to stdout
  else if sLogTarget begins with "field " and there is a sLogTarget then
    put pMsg after field id (word 3 of sLogTarget) of stack (word -2 to -1 of sLogTarget)
  else #file
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
on _loggerLogChanged pMsg
  if sLogA["extensions"] AND sLogTarget is not empty then
    _log pMsg, "extension"
    return true
  else
    return false
  end if
end _loggerLogChanged


# libURL
on _loggerUlLogIt pMsg
  if sLogA["network"] AND sLogTarget is not empty then
    _logLibURLMessage pMsg
    return true
  else
    return false
  end if
end _loggerUlLogIt


# Message Box
on _loggerMsgChanged
  if sLogA["msg"] and msg is not empty then
    _log msg, "msg"
    return true
  else
    return false
  end if
end _loggerMsgChanged


/**
Summary: Filters and logs a libURL message

Parameters:
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
    # item 1 of tFilter: regex
    # item 2 of tFilter: replacement
    put replaceText(pMsg, item 1 of tFilter, item 2 of tFilter) into pMsg
  end repeat

  if pMsg is not empty then
    _log pMsg, "network"
  end if
end _logLibURLMessage


private function _squareBracket pMsg
  return "[" & pMsg & "]"
end _squareBracket
