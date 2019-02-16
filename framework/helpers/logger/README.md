

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
* [API](https://github.com/trevordevore/levure/wiki/helper-logger#api)

## Example log output

Here is an example of what logger will output (when including the message type column)

```
[Sat, 8 Dec 2018 09:33:26 -0500]		[developer]	This is a test
[Sat, 8 Dec 2018 09:33:37 -0500]		[myTest]	You forgot something
```

## Activate the Logger framework helper

To add the Logger helper to your application add it under the `helpers` section of the `app.yml` file:

```
# app.yml

helpers:
  filename: "[[FRAMEWORK]]/helpers/logger" #in levure, "filename" points to your helper's folder.  "folder" points to a parent folder that contains multiple helper folders.
```

## Configuring Logging

You configure the Logger helper by specifying several settings:

1. Which types of messages you would like to log
2. Where you would like messages to be logged
3. The row and column delimiters
4. Whether to include the log type with each message in the log

### Specifying which types of messages to log

You can specify which types of messages will be logged. The types are `all`, `developer`, `network`, `msg`, `extensions`.

|  Type  |  Description  |
|------------|---------------|
| `all` | log all messages that Levure tracks.  Messages that are added to the list in the future will be automatically added. |
| `developer` | messages logged with `loggerLogMsg` without specifying a type |
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
developer,network,msg,extensions
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
| `column-delimiter` | One or more ASCII codes joined by ```+``` to be used to separate columns in the log
| `row-delimiter` | One or more ASCII codes joined by ```+``` to be used to separate rows in the log
| `include-log-type` | (boolean) Include (or exclude) a column with the log message type. |

### Example:
```
#app.yml

logger:
   types: developer,error #in this case "error" is a custom type
   target: console
   column-delimiter: 9
   row-delimiter: 10+13
   include-log-type: true
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
