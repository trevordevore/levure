# logger

The Logger helper provides an API for managing how debug messages are logged in an application. It provides the following features:

* Sends log output to `console`, a file, a field, or logger's built-in palette.
* Optionally logs libURL messages, `put` statements with no target (or that target the message box), `log` messages in LiveCode Builder modules, and messages logged using the `loggerLogMsg` command.
* Allows regex patterns to be defined for replacing content in libURL messages. This allows you to remove sensitive data if need be.

## Contents

* [Example log output](#example-log-output)
* [Activate the logger framework helper](#activate-the-logger-framework-helper)
* [Configuring Logging](#configuring-logging)
* [Specifying settings in app.yml](#configuring-app.yml)
* [Logging your own messages](#logging-your-own-messages)
* [Filtering network traffic](#filtering-network-traffic)
* [Monitoring log messages while debugging](#monitoring-log-messages-while-debugging)
* [API](#api)

## Example log output

Here is an example of what logger will output (when including the message type column)

```
[Sat, 8 Dec 2018 09:33:26 -0500]        [developer] This is a test
[Sat, 8 Dec 2018 09:33:37 -0500]        [myTest]    You forgot something
```

## Activate the Logger framework helper

To add the Logger helper to your application add it under the `helpers` section of the `app.yml` file:

```
# app.yml

helpers:
  - filename: "[[FRAMEWORK]]/helpers/logger" #in levure, "filename" points to your helper's folder.  "folder" points to a parent folder that contains multiple helper folders.
```

## Configuring Logging

You configure the Logger helper by specifying several settings:

1. Which types of messages you would like to log
2. Where you would like messages to be logged
3. The row and column delimiters
4. Whether to include the log type with each message in the log

### Specifying which types of messages to log

You can specify which types of messages will be logged. The types are `all`, `developer`, `error`, network`, `msg`, `extensions`.

|  Type  |  Description  |
|------------|---------------|
| `all` | log all messages that Levure tracks.  Messages that are added to the list in the future will be automatically added. |
| `developer` | messages logged with `loggerLogMsg` without specifying a type |
| `error` | Use to log error messages within your app.
| `network` | messages logged by libURL |
| `msg` | `put` messages with no target, or targeting the message box (empty messages will be ignored) |
| `extensions` | messages from LiveCode builder extensions. |
| `[custom type]` | Any other custom type that the developer uses and wishes to track. |

There are three commands you can use to configure the types of messages to log:

* `loggerSetTypes pTypes`: Pass in a comma-delimted list of types of messages to log.
* `loggerAddType pType`: Specify that a specific type of message should be logged.
* `loggerRemoveType pType`: Do not log a specific type of message.

#### Example:

```
# Only log developer and internet log messages
loggerSetTypes "developer,network"
```

`loggerGetTypes()` returns a comma-delimited list of types that are being logged.  NOTE:  `all` is not a type.  The specific types that are active are returned.

#### Example:

```
loggerSetTypes ("all")
loggerGetTypes()
```

Will return

```
developer,error,network,msg,extensions
```

### Specifying where to log messages

Call `loggerSetTarget pTarget` to specify where messages should be logged to. Set the target to `console`, `<filename>`, or the long id  of a field. If the value is empty then messages will be discarded without logging them anywhere.

Examples:

```
loggerSetTarget "console"
loggerSetTarget specialFolderPath("desktop") & "/log_file.txt"
loggerSetTarget field 1007 of stack "levureSampleWindow"
```

You can check where log messages are being sent using the `loggerGetTarget()` function.



## Configuring app.yml

You can optionally pre-configure logger using your app.yml file.
First, add a ```logger``` section.

Next, any of the following values can be assigned.  All are optional:

|  Type  |  Description  |
|------------|---------------|
| `types` | Comma-delimited list of [log message types](#Specifying-which-types-of-messages-to-log) |
| `target` | Specifies [where your log messages should be sent](#Specifying-where–to-log-messages)|
| `column delimiter` | One or more ASCII codes joined by ```+``` to be used to separate columns in the log
| `row delimiter` | One or more ASCII codes joined by ```+``` to be used to separate rows in the log
| `include log type` | (boolean) Include (or exclude) a column with the log message type. |

### Example:
```
#app.yml

logger:
   types: developer,error,timer #in this case "timer" is a custom type
   target: console
   column delimiter: 9
   row delimiter: 10+13
   include log type: true
```



## Logging your own messages

Call `loggerLogMsg pMsg [,messageType]` to log messages. Calls to `loggerLogMsg` can be added to your code to help troubleshoot issues in your application when it is running on a user's computer. Logging can be turned off by default but if you provide a way for users to turn logging on then `loggerLogMsg` handler calls can add troubleshooting information to the log file.
**Note:**  Your custom message types are treated like any other type of log message.  You must specifically turn on logging for your custom log message types using ```loggerSetTypes``` or ```loggerAddType``` or logger will ignore them.

## Filtering network traffic

Logging internet traffic can be useful when troubleshooting certain issues. You or your customers may have sensitive information the is passing through libURL. libURL log messages will run the regex filters specified using `loggerSetNetworkTrafficFilters` on any data prior to adding the data to the log. Use this feature to remove the sensitive data before it is ever stored in your log files.

### Example:

```
# Remove username/password from url
put ":\/\/[^:]*:([^@]*)@" & tab & "://USERNAME:PASSWORD@" into tFilter
loggerSetNetworkTrafficFilters tFilter
```


You can see what the current filters are by calling the `loggerGetNetworkTrafficFilters()` function.

## Monitoring log messages while debugging

The [`loggerOpenLogMonitor`](https://github.com/trevordevore/levure/wiki/helper-logger#loggerOpenLogMonitor) command will open a palette that displays all log messages. This can be helpful when you need to see log messages in order to debug something in the IDE or while running in a standalone.

<br>

## API

- [loggerAddType](#loggerAddType)
- [loggerGetNetworkTrafficFilters](#loggerGetNetworkTrafficFilters)
- [loggerGetTarget](#loggerGetTarget)
- [loggerGetTypes](#loggerGetTypes)
- [loggerLogMsg](#loggerLogMsg)
>
- [loggerOpenLogMonitor](#loggerOpenLogMonitor)
- [loggerRemoveType](#loggerRemoveType)
- [loggerResume](#loggerResume)
- [loggerSetColumnDelimiter](#loggerSetColumnDelimiter)
- [loggerSetIncludeLogType](#loggerSetIncludeLogType)
>
- [loggerSetNetworkTrafficFilters](#loggerSetNetworkTrafficFilters)
- [loggerSetRowDelimiter](#loggerSetRowDelimiter)
- [loggerSetTarget](#loggerSetTarget)
- [loggerSetTypes](#loggerSetTypes)
- [loggerSuspend](#loggerSuspend)

<br>

## <a name="loggerAddType"></a>loggerAddType

**Type**: command

**Syntax**: `loggerAddType <pType>`

**Summary**: Start logging a specific message type.

**Returns**: Empty

**Parameters**:

| Name | Description |
|:---- |:----------- |
| `pType` |  The type of message to start logging.  This can be one of Levure's special types or any one that you define. |

<br>

## <a name="loggerGetNetworkTrafficFilters"></a>loggerGetNetworkTrafficFilters

**Type**: function

**Syntax**: `loggerGetNetworkTrafficFilters()`

**Summary**: Returns the list of filters that are being applied to libURL messages.

<br>

## <a name="loggerGetTarget"></a>loggerGetTarget

**Type**: function

**Syntax**: `loggerGetTarget()`

**Summary**: Returns the current target where log messages are sent.

**Returns**: empty, `console`, `<filename>`, or field reference

<br>

## <a name="loggerGetTypes"></a>loggerGetTypes

**Type**: function

**Syntax**: `loggerGetTypes()`

**Summary**: Returns the types of messages that are being logged.

**Returns**: Comma-delimited list

<br>

## <a name="loggerLogMsg"></a>loggerLogMsg

**Type**: command

**Syntax**: `loggerLogMsg <pMsg>,<pLogType>`

**Summary**: Logs a message.

**Returns**: Error message

**Parameters**:

| Name | Description |
|:---- |:----------- |
| `pMsg` |  The message to log. |
| `pLogType` |  Type of the message.  Default is `developer`. |

<br>

## <a name="loggerOpenLogMonitor"></a>loggerOpenLogMonitor

**Type**: command

**Syntax**: `loggerOpenLogMonitor `

**Summary**: Opens a palette stack that displays log messages.

**Returns**: Empty

**Description**:

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

<br>

## <a name="loggerRemoveType"></a>loggerRemoveType

**Type**: command

**Syntax**: `loggerRemoveType <pType>`

**Summary**: Stop logging a specific message type.

**Returns**: Empty

**Parameters**:

| Name | Description |
|:---- |:----------- |
| `pType` |  The type of message to start logging.  This can be one of Levure's special types or any one that you define. |

<br>

## <a name="loggerResume"></a>loggerResume

**Type**: command

**Syntax**: `loggerResume `

**Summary**: Resumes logging


<br>

## <a name="loggerSetColumnDelimiter"></a>loggerSetColumnDelimiter

**Type**: command

**Syntax**: `loggerSetColumnDelimiter <pColDelim>`

**Summary**: Sets column delimiter in the log.

**Returns**: Empty

**Parameters**:

| Name | Description |
|:---- |:----------- |
| `pColDelim` |  One or more ascii (numeric) codes, joined by "+". |

<br>

## <a name="loggerSetIncludeLogType"></a>loggerSetIncludeLogType

**Type**: command

**Syntax**: `loggerSetIncludeLogType <pIncludeLogType>`

**Summary**: Sets whether to include the log type in the log.

**Returns**: Empty

**Parameters**:

| Name | Description |
|:---- |:----------- |
| `pIncludeLogType` |  Boolean specifying whether or not to include the log type in each entry. |

**Description**:

Each entry in the log can include the type or type of log entry (or not, your choice).
This will be in its own column, surrounded by square brackets, e.g. [developer]

<br>

## <a name="loggerSetNetworkTrafficFilters"></a>loggerSetNetworkTrafficFilters

**Type**: command

**Syntax**: `loggerSetNetworkTrafficFilters <pFilters>`

**Summary**: Registers regex filters that will be applied to libURL messages that are logged.

**Returns**: Empty

**Parameters**:

| Name | Description |
|:---- |:----------- |
| `pFilters` |  A CR-delimited list of filters to apply to libURL messages. Each line is a tab-delimited list where item 1 is a regex pattern and item 2 is the value to use as a replacement. |

**Description**:

You can set network traffic log filters to remove sensitive data from logs that you generate.

<br>

## <a name="loggerSetRowDelimiter"></a>loggerSetRowDelimiter

**Type**: command

**Syntax**: `loggerSetRowDelimiter <pRowDelim>`

**Summary**: Sets row delimiter in the log.

**Returns**: Empty

**Parameters**:

| Name | Description |
|:---- |:----------- |
| `pRowDelim` |  One or more ascii (numeric) codes, joined by "+" |

<br>

## <a name="loggerSetTarget"></a>loggerSetTarget

**Type**: command

**Syntax**: `loggerSetTarget <pTarget>`

**Summary**: Sets where log messages will be sent.

**Returns**: Empty

**Parameters**:

| Name | Description |
|:---- |:----------- |
| `pTarget` |  `console`, `<filename>`, or field reference (e.g. `<the long id field>`). |

**Description**:

You can target the "console", a file, or a field. "console" writes the log message to `stdout`.

<br>

## <a name="loggerSetTypes"></a>loggerSetTypes

**Type**: command

**Syntax**: `loggerSetTypes <pTypes>`

**Summary**: Set the type of messages to log.

**Returns**: Empty

**Parameters**:

| Name | Description |
|:---- |:----------- |
| `pTypes` |  A comma-delimited list of types to log.  Levure provides special handling for `all`, `developer`, `network`, `msg`, `extensions`, and `error`.  You can also specify your own types. |

**Description**:

Use this command to filter the types of messages that are logged.  Types that are not specified are ignored.

The following types receive special handling from Levure
`all`: All of the below special message types
`developer`: Default message logged using `loggerLogMsg`.
`network`: Messages logged by libURL.
`msg`: Any `put` statements that do not have a target. E.g. `put "testing"`
`extensions`: Messages logged by an extension using the `log` command in LiveCode Builder.

<br>

## <a name="loggerSuspend"></a>loggerSuspend

**Type**: command

**Syntax**: `loggerSuspend `

**Summary**: Suspends logging




