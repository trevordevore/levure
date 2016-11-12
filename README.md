# levure 
Application development framework for LiveCode

## File and Folder Organization

Application stack files are organized using folders. Any UI stacks go in the`components` folder. Each stack has a folder for the binary stack and a subfolder named behaviors for any behaviors assigned to the stack. The behavior stacks should be assigned to the `stackfiles` property of the UI stack so that they are loaded into memory as needed.

- app.yml
- app.livecode
- standalone.livecode
- levure.livecode
- components/
  - preferences/
    - preferences.livecode
    - behaviors/
      - card.livecode
      - stack.livecode
  - document window/
    - document.livecode
    - behaviors/
      - card.livecode
      - stack.livecode
      - tools.livecode
- libraries/
  - libcontrols.livecode
  - libdatahelpers.livecode
- backscripts/
  - mybackscript.livecode
- frontscripts/
  - myfrontscripts.livecode
- helpers/
  - miscellaneous/
    - helper.yml
    - ui.livecode
    - frontscript.livecode
    - backscript.livecode
    - library.livecode
  - logging/
    - helper.yml
    - library.livecode
  - preferences/
    - helper.yml
    - library.livecode
    - preference.bundle
  - my external
    - helper.yml
    - macos.bundle
    - windows.dll
    - linux.so
  
## app.yml

An application is configured using the `app.yml` file. 

```
password: ?????
multiple instances: true|false
relaunch in background: true|false
components:
  1:
    ...
  2:
    ...
libraries:
  1:
    ...
  2:
    ...
frontscripts:
  1:
    ...
backscripts:
  1:
    ...
file extensions:
  JPEG File: jpg,jpeg
file extension groups:
  Media Files:
    1:
      name: All Supported Files
      extensions: png,gif,bmp,txt
    2:
      name: Text Files
      extensions: txt
    3:
      name: Image Files
      extensions: png,gif,bmp
copy files:
  all:
    ...
  macos:
    ...
  win:
    ...
  linux:
    ...
```

## standalone.livecode

This stack is used to build the standalone for the supported platforms. Its primary function is to load the levure.livecode stack and dispatch the `RunApplication` message to it. It will also process the `relaunch` message and call the helper functions that extract command line parameters from that. The stack name in memory is `levureStandaloneLauncher`.

## app.livecode

This stack has the following handlers for handling framework messages:

- `InitializeApplication`: Initialize your application. Framework has loaded at this point.
- `OpenApplication`: Open your application window.
- `ProcessURL`: First parameter is line delimited list of urls that your app has been requested to process.
- `ProcessFiles`: First parameter is line delimited list of files that your application supports and that you should process.
  
## Loading

The framework logic is located in the levure.livecode file. When the `RunApplication` message is dispatched to the stack the following occurs:

1. if an sAppA script local exists then use values from that. The presence of the variable means the app has been packaged. Otherwise load the app.yml file that sits alongside the stack file. If app.yml is not found then app cannot be loaded.
2. Load application.livecode
3. Load helpers (Load externals, libraries, backscripts, and frontscripts. Add ui stacks to list of stackFiles to be assigned later). `PreloadExternals` message is sent to `app` stack so that developer can add or remove from list of externals prior to loading.*
4. Load app libraries and start using.
5. Load app backscripts and insert.
6. Load app frontscripts and insert.
8. Add list of stacks in `components` folder to stackFiles list.
9. Assign stackFiles list to stackFiles property of `app` stack.
10. Dispatch `InitializeApplication` to `app` stack.
11. Dispatch `OpenApplication` to `app` stack.

[*] As an alternative the developer could add or remove helpers as needed during packaging. We move the entire folder over to tmp folder, developer can prune it, and that gets packaged up. No need to dispatch message.
  
## Relaunching Application

In the `app.yml` file you can configure a `multiple instances` property. Set to true if you want your application to support multiple instances. If `multiple instances` is `false` and you don't want the defaultStack to come forward when the user relaunches the application then set `relaunch in background` to true. 

When the `relaunch` message is processed by the levure standalone a `RelaunchApplication` message will be dispatched to the `app` stack. If your application requires any special logic for bringing windows forward then it should be handled here. If any command line parameters are passed in to `relaunch` then the `ProcessCommandLineParameters` message will be dispatched to the `app` stack as well.

## Packaging an Application

- Create a stack for behaviors
  - Make all behavior stacks substacks of that stack.

## Helpers (plugins)

Helpers provide additional common functionality to an application. A helper consists of a folder, a config.yml file, and any supporting files. A helper can be made up of the following;

- library stacks
- backscripts
- frontscripts
- ui stacks
- externals

## app_files_and_urls helper

`ProcessFiles` message sent to `app` stack. Check `appGetFilesToProcessOnOpen` when app opens for files passed on command line.

`ProcessURL` message sent to `app` stack. Check `appGetURLsToProcessOnOpen()` when app opens for urls passed on the command line.

### Helper Examples:

- preference
- window manager
- supported files handler
- logging
- MAS (security-scoped filenames and licensing)
- auto update
- error dialog