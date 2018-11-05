# logger

# logger

The Logger helper provides an API for managing how debug messages are logged in an application. It provides the following features:

* Sends log output to `console`, a file, or a field.
* Optionally logs libURL messages, `put` statements with no target, `log` messages in LiveCode Builder modules, and messages logged using the `loggerLogMsg` command.
* Allows regex patterns to be defined for replacing content in libURL messages. This allows you to remove sensitive data if need be.

## Contents

* [Activate the logger framework helper](#activate-the-logger-framework-helper)
* [Configuring Logging](#configuring-logging)
* [Logging your own messages](#logging-your-own-messages)
* [Filtering network traffic](#filtering-network-traffic)
* [Monitoring log messages while debugging](#monitoring-log-messages-while-debugging)
* [API](#api)

## Activate the Logger framework helper

To add the Logger helper to your application add it under the `helpers` section of the `app.yml` file:

```
# app.yml

helpers:
  - folder: ./helpers
  - filename: "[[FRAMEWORK]]/helpers/logger"
```

## Configuring Logging

You configure the Logger helper by specifying two settings:

1. Which types of messages you would like to log.
2. Where you would like messages to be logged.

### Specifying which types of messages to log

You can specify which types of messages will be logged. The types are `all`, `developer`, `network`, `msg`, and `extensions`.

|  Type  |  Description  |
|------------|---------------|
| `all` | All currently supported message types. |
| `developer` | Messages logged with `loggerLogMsg`. |
| `network` | Mmessages logged by libURL. |
| `msg` | `put` messages with no target (empty messages will be ignored). |
| `extensions` | `log` messages from LiveCode builder extensions. |

There are three commands you can use to configure the types of messages to log:

* `loggerSetTypes pTypes`: Pass in a comma-delimted list of types of messages to log.
* `loggerAddType pType`: Specify that a specific type of message should be logged.
* `loggerRemoveType pType`: Do not log a specific type of message.

```
# Only log developer and internet log messages
loggerSetTypes "developer,network"
```

`loggerGetTypes()` returns a comma-delimited list of types that are being logged.  NOTE:  `all` is not a type.  The specific types that are active are returned. For example:

```
loggerSetTypes ("all")
loggerGetTypes()
```

will return:

```
developer,network,msg,extensions
```

### Specifying where to log messages

Call `loggerSetTarget pTarget` to specify where messages should be logged to. Set the target to `console`, `<filename>`, or the long id  of a field. If the value is empty then messages will be discarded without logging them anywhere.

Examples:

```
loggerSetTarget "console"
loggerSetTarget specialFolderPath("desktop") & "/log_file.txt"
loggerSetTarget the long id of field "Log" of me
```

You can check where log messages are being sent using the `loggerGetTarget()` function.

## Logging your own messages

Call `loggerLogMsg pMsg` to log messages. Calls to `loggerLogMsg` can be added to your code to help troubleshoot issues in your application when it is running on a user's computer. Logging can be turned off by default but you provide a way for user's to turn logging on. When the user turns logging than all `loggerLogMsg` handler calls will add troubleshooting information to the log file.

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

The [`loggerOpenLogMonitor`](#loggerOpenLogMonitor) command will open a palette that displays all log messages. This can be helpful when you need to see log messages in order to debug something in the IDE or while running in a standalone.

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
- [loggerSetNetworkTrafficFilters](#loggerSetNetworkTrafficFilters)
- [loggerSetTarget](#loggerSetTarget)
- [loggerSetTypes](#loggerSetTypes)

<br>

## <a name="loggerAddType"></a>loggerAddType

**Type**: command

**Syntax**: `loggerAddType <pType>`

**Summary**: Start logging a specific message type.

**Returns**: Empty

**Parameters**:

| Name | Description |
|:---- |:----------- |
| `pType` |  `developer`, `network`, `msg`, `extensions`. |

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

**Syntax**: `loggerLogMsg <pMsg>`

**Summary**: Logs a message. The message is of type `developer`.

**Returns**: Error message

**Parameters**:

| Name | Description |
|:---- |:----------- |
| `pMsg` |  The message to log. |

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
| `pType` |  `developer`, `network`, `msg`, `extensions`. |

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

## <a name="loggerSetTarget"></a>loggerSetTarget

**Type**: command

**Syntax**: `loggerSetTarget <pTarget>`

**Summary**: Sets the field where log messages will be sent.

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
| `pTypes` |  A comma-delimited list of types to log. |

**Description**:

Use this command to filter the types of messages that are logged.

`all` : All currently supported message types.
`developer`: Any message logged using `loggerLogMsg`.
`network`: Messages logged by libURL.
`msg`: Any `put` statements that do not have a target. E.g. `put "testing"`
`extensions`: Messages logged by an extension using the `log` command in LiveCode Builder.



