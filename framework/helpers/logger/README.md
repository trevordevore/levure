# logger Helper

The **logger** helper adds logging capabilities to your application. It supports logging custom messages, network (libURL) messages, log messages from LiveCode Builder extensions, and `put` statements with no target (e.g. `put tVariable`).

## Usage

To turn logging on you specify a target for log messages. A target can be a field, a filename, or the `console`. `console` writes log messages to `stdout`.

```
appSetLogTarget specialFolderPath("desktop") & "/my_log_file.txt"
```

You can specify which categories of messages will be logged. The categories are `developer`, `network`, `msg`, and `extensions`.

|  Category  |  Description  |
|------------|---------------|
| `developer` | messages logged with `appLogMsg`|
| `network` | messages logged by libURL |
| `msg` | `put` messages with no target |
| `extensions` | `log` messages from LiveCode builder extensions. |

```
# Only log developer and internet log messages
appSetLogTypes "developer,network"
```

## Filtering Network Messages

Because network log messages may contain sensitive data you can specify filters that should be applied to any `network` messages before the message is written to the log target. A filter is a CR-delimited list of filters. A filter is a regex pattern followed by the tab character followed by the value to replace the regex pattern with.

```
# Remove username/password from url
put ":\/\/[^:]*:([^@]*)@" & tab & "://USERNAME:PASSWORD@" into tFilter
appSetNetworkTrafficLogFilters tFilter
```
