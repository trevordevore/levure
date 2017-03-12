levure
=====================

# Levure Application Framework

Levure is an application development framework for LiveCode. The primary goals of Levure are the following:

1. Lightweight. The framework has a minimal amount of code for loading, managing, and packaging your application. Common functionality is added via libraries and helper components.
2. Designed for use with version control systems. Wherever possible configuration and scripts are text files. While developers can take advantage of the efficiency of binary stack files for the UI, almost all of the scripts should be stored in script only stack files and assigned as behaviors.

# Screencasts

- [Thoughts on using script only stacks and levure framework](https://www.youtube.com/watch?v=e1p_FTRi1-Q)
- [Creating Script Only Behaviors with LiveCode 9](https://www.youtube.com/watch?v=eyggLzIbeSU)

# Learn How To Use Levure

Visit the [Levure Wiki](./wiki/) to get started.

# Helper Components Included with Framework

The framework ships with a number of helpers that you can use in your application. To load a helper use the {{FRAMEWORK}} variable. Example:

```
helpers:
  1:
    filename: {{FRAMEWORK}}/helpers/preferences
```

Any helpers included with the framework automatically has its `preload` flag set to true. That means the helper will be loaded before the `PreloadApplication` message is sent.

## ./helpers/files_and_urls

Helps with files associated with your application, managing a recent files list, as well as when the OS asks your application to process a url. Also includes functions for generating file dialog type filter strings.

`ProcessFiles` message sent to `app` stack. Check `appGetFilesToProcessOnOpen` when app opens for files passed on command line.

`ProcessURL` message sent to `app` stack. Check `appGetURLsToProcessOnOpen()` when app opens for urls passed on the command line.

## ./helpers/broadcaster

API for broadcasting and listening for messages.

## ./helpers/translate

API for providing translated versions of strings in your app. When you call translateSetLocale the library looks for a `./locales/[LANG_CODE].yml` file alongside your `app.yml` file.

## ./helpers/logger

API for setting up a log file. Has option to log internet traffic. Turning it on will intercept the ulLogit message that libURL uses and log those messages to your log file.

## ./helpers/preferences

API for managing your application preferences. On OS X and external is used so that you can set preferences using the OS X APIs. On Windows and Linux preferences are stored in a file containing data serialized using arrayEncode.

## ./helpers/undo_manager

Manage undo in your application.

## ./helpers/window_manager

Manages windows in your application. Set a flag on a stack and it's position will be stored across sessions. Also keeps stacks on screen when the desktopChanged message is received.

# Helpers to build:

- MAS (security-scoped filenames and licensing)
- auto update
  - Needs module wrapped around WinSparkle: https://winsparkle.org
  - Needs module wrapped around latest Sparkle: https://sparkle-project.org
- error dialog

# TODO

- Move preferences external for OS X to a module.
- Create module for WinSparkle and Sparkle.
- Wrap YAML C++ library in module. YAML support is very limited right now. Ideally we would use `-` instead of `1:, 2:, 3:, etc.` keys.
- Create module for security scoped bookmark APIs.

# Known Issues

- If you use scripts for all behaviors then you have to manually construct behaviors with behaviors when a stack opens. A script only stack can't have a behavior property assigned to it. This is not an issue for behaviors stored in the `./behaviors` folder as the `LoadBehavior` message is dispatched to each stack and it can set its own behavior. For behaviors that are part of your ui components you need to make sure that you assign the parent behavior somewhere else (e.g. in a `preopenstack` message or in the `InitializeApplicaiton` message).
- Window manager increases height of stacks when they are reopened on OS X.
