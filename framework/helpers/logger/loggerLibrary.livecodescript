script "Logger Library"
constant kBuiltInLogTypes = "developer,extensions,network,msg"

local sLogTarget, sLogPresetTarget
local sLogA
local sNetworkFilters
local sColDelim, sRowDelim
local sIncludeLogTypeBool
local sLoggingSuspended


on libraryStack
  if the target is not me then pass libraryStack
  put false into sLoggingSuspended
  #<Initial settings>
    #<log types>
      put "developer" into logtypes #default
      if levureAppHasProperty("logger>types") then put levureAppGet ("logger>types") into logtypes
      loggerSetTypes logTypes
    #</log types>

    #<log target>
      put empty into logTarget #default, i.e. ignore log messages
      if levureAppHasProperty("logger>target") then put levureAppGet ("logger>target") into slogPresetTarget #can't set the target to a field if the stack containing the field isn't open - which will be true for any stack at startup.
    #<log target>

    #<column delimiter>
      put 9 into colDelim #default tab
      if levureAppHasProperty("logger>column-delimiter") then put levureAppGet ("logger>column-delimiter") into colDelim
      loggerSetColumnDelimiter colDelim
    #</column delimiter>

   #<row delimiter>
      put 10 into rowDelim #default LF
      if levureAppHasProperty("logger>row-delimiter") then put levureAppGet ("logger>row-delimiter") into rowDelim
      loggerSetRowDelimiter rowDelim
    #</row delimiter>

    #<report log type boolean>
      put true into includeLogTypeBool #default
      if levureAppHasProperty("logger>include-log-type") then put levureAppGet ("logger>include-log-type") into includeLogTypeBool
      loggerSetIncludeLogType includeLogTypeBool
    #</report log type boolean>
  #</Initial settings>
end libraryStack


on releaseStack
  if the target is not me then pass releaseStack
end releaseStack


/**
Summary: Sets where log messages will be sent.

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
      end if #tSecondChar > 0
    end if #tFirstChar > 0
  end if #sLogTarget begins with "field "

  return empty
end loggerSetTarget


/**
Summary: Returns the current target where log messages are sent.

Returns: empty, `console`, `<filename>`, or field reference
*/
function loggerGetTarget
  return _logTarget()
end loggerGetTarget



private function _logTarget
  /*
   Returns the current log target.  Do it as a function b/c if the user pre-sets the target to a field in app.yml, the stack containing the field won't be open
   when logger is initialized, which will result in an error when we try to retrieve the long id of the field.
   */
  if sLogPresetTarget is not empty and sLogTarget is empty then loggerSetTarget sLogPresetTarget # target was set in app.yml, but not set in logger yet.  This happens the first time b/c presetting a target to a field fails if the stack that contains the field isn't open yet, which is what we have at startup, when the helper is loaded.
  return sLogTarget
end _logTarget


/**
Summary: Set the type of messages to log.

pTypes: A comma-delimited list of types to log.  Levure provides special handling for `all`, `developer`, `network`, `msg`, `extensions`.  You can also specify your own types.

Description:
Use this command to filter the types of messages that are logged.  Types that are not specified are ignored.

The following types receive special handling from Levure
`all`: All of the below special message types
`developer`: Default message logged using `loggerLogMsg`.
`network`: Messages logged by libURL.
`msg`: Any `put` statements that do not have a target. E.g. `put "testing"`
`extensions`: Messages logged by an extension using the `log` command in LiveCode Builder.

Examples:
loggerSetTypes "'"developer,network"
loggerSetTypes "error,oops" #custom types I want to use with loggerLogMsg

Returns: Empty
*/
command loggerSetTypes pTypes
  #<Initialize True/False for the special built-in types>
    put "all" is among the items of pTypes into preAssignBool

    repeat for each item tType in kBuiltInLogTypes
      put preAssignBool into sLogA[tType]
    end repeat # for each item tType in kBuiltInLogTypes
  #</Initialize True/False for the special built-in types>

  repeat for each item typeToAssign in pTypes #in case there are any others in the list (custom ones from the developer).  No harm in going over again for specials.
    put true into sLogA[typeToAssign]
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

colDelim: One or more ascii (numeric) codes, joined by "+".


Examples:
loggerSetColumnDelimiter 9

Returns: Empty
*/
command loggerSetColumnDelimiter pColDelim
  set the itemDelimiter to "+"
  repeat for each item theAsciiCode in pColDelim
    put numtochar(theAsciiCode) after sColDelim
  end repeat
end loggerSetColumnDelimiter



/**
Summary: Sets row delimiter in the log.

rowDelim: One or more ascii (numeric) codes, joined by "+"


Examples:
loggerSetRowDelimiter 13
loggerSetRowDelimiter 13+10

Returns: Empty
*/
command loggerSetRowDelimiter pRowDelim
  set the itemDelimiter to "+"
  repeat for each item theAsciiCode in pRowDelim
    put numtochar(theAsciiCode) after sRowDelim
  end repeat
end loggerSetRowDelimiter



/**
Summary: Sets whether to include the log type in the log.

includeLogTypeBool: Whether to include the log type in each entry or not

Description:
Each entry in the log can include the type or type of log entry (or not, your choice).  This will be in its own column, surrounded by square brackets, e.g. [developer]

Examples:
loggerSetIncludeLogType true

Returns: Empty
*/
command loggerSetIncludeLogType bool
  put bool into sIncludeLogTypeBool
end loggerSetIncludeLogType



/**
Summary: Logs a message.

pMsg: The message to log.
[pLogType]:  Type of the message.  Default is "developer"

Returns: Error message
*/
command loggerLogMsg pMsg, pLogType
 local tError

  if _logTarget() is empty then return empty #ignore message if no target is set
  if pLogType is empty then put "developer" into pLogType #default
  if not sLogA[pLogType] then return empty #if we're not logging this type then ignore
  

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



private command _log pMsg, logType
  local tError
  local msgInfo

  if sLoggingSuspended then return empty for error

  #<build log entry>
    put _squareBracket(the internet date) & sColDelim into msgInfo #date/time stamp
    if sIncludeLogTypeBool then put sColDelim & _squareBracket(logType) & sColDelim after msgInfo # log type
    put msgInfo before pMsg
    put sRowDelim after pMsg
  #</build log entry>


  #<output>
    put _logTarget() into logTarget
    if logTarget is "console" then
      write pMsg & cr to stdout
    else if logTarget begins with "field " and there is a logTarget then
      put pMsg after field id (word 3 of logTarget) of stack (word -2 to -1 of logTarget)
    else #file
      open file logTarget for append
      put the result into tError

      if tError is empty then
        write textEncode(pMsg, "utf8") to file logTarget
      end if

      close file logTarget
    end if #logTarget is "console"
  #</output>

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
  if sLogA["extensions"] AND _logTarget() is not empty then
    _log pMsg
    return true
  else
    return false
  end if
end _loggerLogChanged


# libURL
on _loggeruLogIt pMsg
  if sLogA["network"] AND _logTarget() is not empty then
    _logLibURLMessage pMsg
    return true
  else
    return false
  end if
end _loggeruLogIt


# Message Box
on _loggerMsgChanged
  if sLogA["msg"] and msg is not empty then
    _log "msg changed:" && msg, "msg"
    return true
  else 
    return false
  end if
end _loggerMsgChanged


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

  _log pMsg, "network"
end _logLibURLMessage



private function _squareBracket what
  return "[" & what & "]"
end _squareBracket
