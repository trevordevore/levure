# levure 

Levure is an application development framework for LiveCode. The primary goals of Levure are the following:

1. Lightweight. The actual framework code is not complicated. Common functionality is added via libraries and helpers.
2. Designed for use with version control systems. Wherever possible configuration and scripts are text based files. While developers can take advantage of the efficiency of binary stack files for the UI, all scripts should be handled via behaviors. Behaviors are stored as script only stacks in a `behaviors` folder alongside the binary stack. Each behavior stack is assigned to the `stackfiles` property of the binary stack so that the engine automatically finds them when the stack is opened. If the LiveCode engine supports a version control friendly version of stacks with UI in the future then the framework will seamlessly support it.

## Try Out Sample Application

1. Open the `sample_app/standalone.livecode` stack in LiveCode 8+. The `framework/levureFramework.livecodescript` stack is a behavior of this stack.
2. Switch to the browser tool and click on the `Run Application` button.
3. The `MyApp` stack should open up and display some information in a field.

The `MyApp` stack shows how to use behaviors for the stack scripts. The app also loads a library that the stack uses.

## Organizing a Levure Framework Application

- The framework is distributed in a `framework` folder that can be stored anywhere on your computer. The `levure.livecodescript` stack file is assigned as a behavior to the mainstack in the `standalone.livecode` stack file.
- Your app is configured using the `app.yml` YAML file. This file can be alongside the `standalone.livecode` stack file or directly within a folder that resides alongside the `standalone.livecode` stack file.
- Alongside the `app.yml` file is the `app.livecodescript` stack file.
- Alongside the `app.yml` file you may have a `components`, `libraries`, `frontscripts`, `backscripts`, `behaviors`, and `helpers` folders. 
- The `components` folder is where you will store the stacks used for your user interface. Each UI stack consistes of at least one stack file that is the stack for the UI. If you are using version control with your application then it is recommended that you place a `behaviors` folder alongside the stack file. Create a script only stack for each script in your stack and place the scripts in this folder. Assign each script only stack file to the `stackfiles` property of the UI stack so that the behavior stacks will be loaded automatically when the stack is opened.
- The `libraries`, `frontscripts`, `backscripts`, and `behaviors` folders hold individual stack files that will be used globally. Libraries will be loaded using `start using`. Frontscripts will be loaded using `insert ... into front`. Backscripts will be loaded using `insert ... into back`. Behaviors will be loaded into memory so that the stack is available globally. After the stack is loaded into memory the `LoadBehavior` message will sent dispatched to it. This enables a script only stack to set its own behavior.
- The `helpers` folder is for files that work together to add a specific piece of functionality to an application. The folder can contain stack files meant to be used for UI, libraries, frontscripts, or backscripts. It can also contain externals.
- In the `app.yml` file you can load components, libraries, backscripts, frontscripts, and helpers from any location on your computer, even the LiveCode User Extensions folder. When your application is packaged up all of the necessary resources will be brought together to build the final application.

### An example

- app.yml
- app.livecodescript
- standalone.livecode
- framework/levure.livecodescript
- framework/libraries/appFilesAndURLs.livecodescript
- components/
  - preferences/
    - preferences.livecode
    - behaviors/
      - card.livecodescript
      - stack.livecodescript
  - document window/
    - document.livecode
    - behaviors/
      - card.livecodescript
      - stack.livecodescript
      - tools.livecodescript
- behaviors/
  - field_editor.livecodescript
- libraries/
  - libcontrols.livecodescript
  - libdatahelpers.livecodescript
- backscripts/
  - mybackscript.livecodescript
- frontscripts/
  - myfrontscript.livecodescript
- helpers/
  - logging/
    - helper.yml
    - library.livecodescript
  - preferences/
    - helper.yml
    - library.livecodescript
    - preference.bundle
  - oauth2
    - helper.yml
    - ui.livecode
    - behaviors/stack.livecode
    - oauthlib.livecodescript
  - my external
    - helper.yml
    - macos.bundle
    - windows.dll
    - linux.so
  
## app.yml

The `app.yml` file is a YAML file that describes your application. The framework will use these settings when loading your application into the IDE as well as when packaging your application for distribution.

Important note: Make sure you use the same number of spaces for each indentation level in the YAML file. The current YAML parser is rather limited and may not load your configuration file correctly if you use two spaces to indent one level but three spaces to indicate indentation in a different level.

```
password: ?????
multiple instances: true|false
relaunch in background: true|false
components:
  1:
    filename: [relative path to stack file within components folder]
  2:
    folder: [path to folder containing components]
behaviors:
  1: 
    filename: [relative path to stack file within behaviors folder]
  2: 
    folder: [relative path a folder with behavior stack files]
  ...
libraries:
  1: 
    filename: [relative path to stack file within libraries folder]
  2: 
    folder: [relative path a folder with library stack files]
  ...
frontscripts:
  1: 
    filename: [relative path to stack file within frontscripts folder]
  2: 
    folder: [relative path a folder with frontscript stack files]
  ...
backscripts:
  1: 
    filename: [relative path to stack file within backscript folder]
  2: 
    folder: [relative path a folder with backscript stack files]
  ...
helpers:
  1: 
    filename: [relative path to folder containing helper]
  2: 
    folder: [relative path a folder with helper folders]
  ...
file extensions:
  [Description]: [Extensions (comma-delimited)]
file extension groups:
  [Group Name]:
    1:
      name: [Category Name]
      extensions: [Extensions (comma-delimited)]
    ...
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

### libraries, frontscripts, backscripts, and behaviors

Libraries, frontscripts, backscripts, and behaviors can be loaded individually or in bulk. If you point to a folder then every file in that folder should be a LiveCode stack. The folder will be loaded recursively so any subfolders will be loaded as well.

```
libraries:
  1: 
    filename: ../../shared/mylibrary.livecodescript
  2: 
    folder: ./libraries
```

### components

There are two different ways to load extensions. The first is to target a specific stack that represents the component. The second is to specify a folder containing folders of components.

#### Example 1

```
components:
  1: 
    filename: ./components/main_window/main_window.livecode
```

#### Example 2

```
components:
  1: 
    folder: ./components
```

If you specify a folder containing folders of components (Example 2) then the framework will assume that the first file ending in *.livecode or *.livecodescript is the stack to use for the component. As long as you only have one stack file for each component then you can load components this way.

You can mix targeting specific files to load with bulk loading. For example, let's say you have 10 components and one of the components has two stack files in its folder but the rest only have one stack file.

```
components:
  1: 
    filename: ./components/complex_component/ui.livecode
  2: 
    folder: ./components
```

The component the you target with `filename` will be loaded first and then the folder of components will be loaded. The framework will see that the `complex_component` has already been loaded and will skip it when loading the folder of components.

### Helpers

Helpers consist of a folder with a `helper.yml` file in it. The `helper.yml` file specifics what the other files in the folder should be used for. A helper can be made up of the following:

- stacks
- libraries
- backscripts
- frontscripts
- behaviors
- externals

If no `helper.yml` file is found then the framework will try to load up each file in the folder as a stack.

TODO: example config.yml file

### Targeting files in the LiveCode user extensions folder.

You can use the `{{USER_EXTENSIONS}}` variable in a any path to use the value returned by `revEnvironmentCustomizationPath()` in the IDE. This allows you to store commonly used resources in your LiveCode User Extension folder.

#### Example:

```
helpers:
  1: {{USER_EXTENSIONS}}/Helpers"
```

### file extensions example

```
file extensions:
  JPEG Files: jpg,jpeg
```

### file extension groups example

```
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
```

### Examples of where to put resource files

TODO: Describe a resource and then show where to put it

## standalone.livecode

This stack is used to build the standalone application. The `levureFramework.livecodescript` stack file should be assigned to the stackFiles of this stack. The `levureFramework` stack should be assigned as the behavior of this stack. This stack can be named whatever you would like in memory.

## app.livecodescript

This stack file must be located directly alongside the `app.yml` file. The stack must be named `app` in memory. It has the following handlers for handling framework messages:

- `InitializeApplication`: Initialize your application. Framework has loaded at this point.
- `OpenApplication`: Open your application window.
- `ProcessURL`: First parameter is line delimited list of urls that your app has been requested to process.
- `ProcessFiles`: First parameter is line delimited list of files that your application supports and that you should process.
  
## levureFramework.livecodescript

The framework logic is located in the `levure.livecodescript` file. The stack must be assigned as the behavior of another stack which is assumed to be the `standalone.livecode` stack. The `levureInitializeAndRunApplication` will initialize and load the framework. Here is what happens during loading:

1. if an sAppA script local exists and the stack is running in the development environment  then use values from that. It means the app has been packaged. Otherwise load the `app.yml` file, searching first alongside the `standalone.livecode` stack file and then directly within any folders that are alongside the `standalone.livecode` stack. If `app.yml` is not found then app cannot be loaded.
2. Process any command line arguments using the `app_files_and_urls` helper.
3. Load `app.livecodescript` from folder containing the `app.yml` file.
4. Load helpers. By default any helpers in a folder named `helpers` that sits alongside the `levure.livecodescript` file or the `app.yml` file will be loaded. You can configure additional folders where helpers are located using the `helper source folders` config property. ` All externals, libraries, backscripts, and frontscripts will be loaded into memory. The ui stacks will be added to the list of stackFiles to be assigned to `app` stack. `PreloadExternals` message is sent to `app` stack so that developer can add or remove from list of externals prior to loading.*
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

## Helpers Included with Framework

### app_files_and_urls

Helps with files associated with your application as well as when the OS asks your application to process a url. Also includes functions for generating file dialog type filter strings.

`ProcessFiles` message sent to `app` stack. Check `appGetFilesToProcessOnOpen` when app opens for files passed on command line.

`ProcessURL` message sent to `app` stack. Check `appGetURLsToProcessOnOpen()` when app opens for urls passed on the command line.

## Helpers to build:

- preference
- window manager
- logging
- MAS (security-scoped filenames and licensing)
- auto update
- error dialog

## Known Issues

- If you use scripts for all behaviors then you have to manually construct behaviors with behaviors when a stack opens. A script only stack can't have a behavior property assigned to it.