# levure 

Levure is an application development framework for LiveCode. The primary goals of Levure are the following:

1. Lightweight. The actual framework code is not complicated. Common functionality is added via Helpers.
2. Designed for use with version management. Wherever possible configuration and scripts are text based files. While developers can take advantage of the efficiency of binary stack files for the UI, all scripts should be handled via behaviors. Behaviors are stored as script only stacks in a `behaviors` folder alongside the binary stack. Each behavior stack is assigned to the `stackfiles` property of the binary stack so that the engine automatically finds them when the stack is opened.

## Try Out Sample Application

1. Open the `app/levure.livecode` stack in LiveCode 8+.
2. `dispatch "InitializeFramework" to stack "levureLibrary" with "/Users/USERNAME/development/levure/sample_app"`
3. `dispatch "RunApplication" to stack "levureLibrary"`
4. The `MyApp` stack should open up and display some information in a field.

The `MyApp` stack shows how to use behaviors for the stack scripts. The app also loads a library that the stack uses.

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
    name: [stack name in memory]
    filename: [relative path to stack file within components folder]
  ...
libraries:
  1: [relative path to stack file within libraries folder]
  ...
frontscripts:
  1: [relative path to stack file within frontscripts folder]
  ...
backscripts:
  1: [relative path to stack file within backscripts folder]
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

This stack is used to build the standalone for the supported platforms. Its primary function is to load the `levure.livecode` stack and dispatch the `RunApplication` message to it. It will also process the `relaunch` message and call the helper functions that extract command line parameters from that. The stack name in memory is `levureStandaloneLauncher`.

## app.livecode

This stack has the following handlers for handling framework messages:

- `InitializeApplication`: Initialize your application. Framework has loaded at this point.
- `OpenApplication`: Open your application window.
- `ProcessURL`: First parameter is line delimited list of urls that your app has been requested to process.
- `ProcessFiles`: First parameter is line delimited list of files that your application supports and that you should process.
  
## Loading

The framework logic is located in the `levure.livecode` file. `InitializeFramework` must be called first. Then the `RunApplication` message is sent. This is what is happening:

1. if an sAppA script local exists and the stack is running in the development environment  then use values from that. It means the app has been packaged. Otherwise load the `app.yml` file. If `app.yml` is not found then app cannot be loaded.
2. Process any command line arguments using the `app_files_and_urls` helper.
3. Load `app.livecode`
4. Load helpers (Load externals, libraries, backscripts, and frontscripts. Add ui stacks to list of stackFiles to be assigned to `app` stack). `PreloadExternals` message is sent to `app` stack so that developer can add or remove from list of externals prior to loading.*
8. Add list of stacks defined in `components` key in config file to stackFiles list.
5. Load app libraries and start using.
6. Load app backscripts and insert.
7. Load app frontscripts and insert.
9. Assign stackFiles list to stackFiles property of `app` stack.
10. Dispatch `InitializeApplication` to `app` stack.
11. Dispatch `OpenApplication` to `app` stack.

[*] As an alternative the developer could add or remove helpers as needed during packaging. We move the entire folder over to tmp folder, developer can prune it, and that gets packaged up. No need to dispatch message. Currently this message is not being sent.
  
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

## Helpers Included with Framework

### app_files_and_urls

`ProcessFiles` message sent to `app` stack. Check `appGetFilesToProcessOnOpen` when app opens for files passed on command line.

`ProcessURL` message sent to `app` stack. Check `appGetURLsToProcessOnOpen()` when app opens for urls passed on the command line.

## Helpers to build:

- preference
- window manager
- logging
- MAS (security-scoped filenames and licensing)
- auto update
- error dialog