levure
=====================

# Levure Application Framework

Levure is an application development framework for LiveCode. The primary goals of Levure are the following:

1. Lightweight. The framework has a minimal amount of code for loading, managing, and packaging your application. Common functionality is added via libraries and helpers.
2. Designed for use with version control systems. Wherever possible configuration and scripts are text based files. While developers can take advantage of the efficiency of binary stack files for the UI, almost all of the scripts should be handled via behaviors. Behaviors are stored as script only stacks in a `behaviors` folder alongside the binary stack. Each behavior stack is assigned to the `stackfiles` property of the binary stack so that the engine automatically finds them when the stack is opened. If the LiveCode engine supports a version control friendly version of stacks with UI in the future then the framework will seamlessly support it.

# Screencasts

- [Thoughts on using script only stacks and levure framework](https://www.youtube.com/watch?v=e1p_FTRi1-Q)
- [Creating Script Only Behaviors with LiveCode 9](https://www.youtube.com/watch?v=eyggLzIbeSU)

# Try Out Sample Application

1. Open the `sample_app/standalone.livecode` stack in LiveCode 8+. The `framework/levureFramework.livecodescript` stack is a behavior of this stack.
2. Switch to the browser tool and click on the `Open Application` button.
3. The `MyApp` stack should open up and display some information in a field.

The `MyApp` stack shows how to use behaviors for the stack scripts. The app also loads a library that the stack uses.

# Including levure as a submodule in a git project

If you are using git to manage your application then you can include the `levure` project as a submodule.

```
git submodule add https://github.com/trevordevore/levure.git levure
```

# Organizing a Levure Framework Application

- The framework is distributed in a `framework` folder that can be stored anywhere on your computer. The `levure.livecodescript` stack file is assigned as a behavior to the mainstack in the `standalone.livecode` stack file.
- Your app is configured using the `app.yml` YAML file. This file can be alongside the `standalone.livecode` stack file or directly within a folder that resides alongside the `standalone.livecode` stack file.
- Alongside the `app.yml` file is the `app.livecodescript` stack file.
- Alongside the `app.yml` file you may have a `components`, `libraries`, `frontscripts`, `backscripts`, `behaviors`, and `helpers` folders.
- The `components` folder is where you will store the stacks used for your user interface. Each UI stack consists of at least one stack file that is the stack for the UI. If you are using version control with your application then it is recommended that you place a `behaviors` folder alongside the stack file. Create a script only stack for each script in your stack and place the scripts in this folder. Assign each script only stack file to the `stackfiles` property of the UI stack so that the behavior stacks will be loaded automatically when the stack is opened.
- The `libraries`, `frontscripts`, `backscripts`, and `behaviors` folders hold individual stack files that will be used globally. Libraries will be loaded using `start using`. Frontscripts will be loaded using `insert ... into front`. Backscripts will be loaded using `insert ... into back`. Behaviors will be loaded into memory so that the stack is available globally. After the stack is loaded into memory the `LoadBehavior` message will dispatched to it. This enables a script only stack to set its own behavior.
- The `helpers` folder is for files that work together to add a specific piece of functionality to an application. The folder can contain stack files meant to be used for UI, libraries, frontscripts, or backscripts. It can also contain externals or extensions.
- In the `app.yml` file you can load components, libraries, backscripts, frontscripts, and helpers from any location on your computer, even the LiveCode User Extensions folder. When your application is packaged up all of the necessary resources will be brought together to build the final application.

## An example

- app.yml
- app.livecodescript
- standalone.livecode
- framework/levure.livecodescript
- framework/libraries/appFilesAndURLs.livecodescript
- framework
  - helpers
    - logger/
      - helper.yml
      - logger.livecodescript
    - preferences/
      - helper.yml
      - preferences.livecodescript
      - preference.bundle
    ...
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
version: x[.x[.x]]
build: [x]
multiple instances: true|false
relaunch in background: true|false
application data folder: [relative path to app data folder with user or shared data folders on the computer]
creator code: [app creator code registered with Apple]
shutdown when all windows are closed: true|false
components:
  1:
    filename: [relative path to stack file within components folder]
  2:
    folder: [path to folder containing components]
extensions:
  1:
    filename: [relative path to .lcm extension file]
  2:
    folder: [relative path to folder containing .lcm extensions]
  ...
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
preferences:
  user:
    macos:
      filename: [com.mycompany.myproduct]
    windows:
      filename: [relative path to preference file within user app data folder] e.g. ./MyApp/1.0/MyApp.pref
  shared:
    macos:
      filename: [relative path to preference file within shared app data folder]
    windows:
      filename: [relative path to preference file within shared app data folder]
file extensions:
  [Description]: [Extensions (comma-delimited)]
file extension groups:
  [Group Name]:
    1:
      name: [Category Name]
      extensions: [Extensions (comma-delimited)]
    ...
build folder: ../../myapp-distribution
build profiles:
  default:
    post build script: [relative path to LiveCode file that will be run post build.
    macos:
      certificate name: [name of certificate to sign OS X applications with]
    copy files:
      all:
        1:
          filename: [relative path to file or folder that should be copied to build folder]
          destination: [relative destination folder without build folder]
        ...
      macos:
        ...
      windows:
        ...
      linux:
        ...
    base auto update url: [URL where updates to your application can be found]
  development:
  beta:
  release:
```

## libraries, frontscripts, backscripts, and behaviors

Libraries, frontscripts, backscripts, and behaviors can be loaded individually or in bulk. If you point to a folder then every file in that folder should be a LiveCode stack. The folder will be loaded recursively so any subfolders will be loaded as well.

```
libraries:
  1:
    filename: ../../shared/mylibrary.livecodescript
  2:
    folder: ./libraries
```

## components

There are two different ways to load extensions. The first is to target a specific stack that represents the component. The second is to specify a folder containing folders of components.

### Example 1

```
components:
  1:
    filename: ./components/main_window/main_window.livecode
```

### Example 2

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

## Extensions

You can configure extensions used by the application in the configuration file. When configuring an extension you can point to both the filename and the source file for the extension. If you provide the source file then the framework can compile all of your extensions for you and place them in the specified location.

In the following example the `filename` points to the actual extension module. The `source` points to the source file used to create the module. If you call `levureBuildExtensions` then the `animated_progress_dots.lcm` file will be recreated using the source file.

```
extensions:
  1:
    filename: extensions/animated_progress_dots.lcm
    source: ../extensions_source/animated_progress_dots.lcb
  ...
```

If your extensions rely on any other modules then put the `.lci` files for the other modules in the same directory as the source file or in an `lci` subfolder.

If you have your extensions installed in your IDE user extensions folder and include those extensions when building your standalone then you don't have to worry about building the extensions with `levureBuildExtensions`. For someone who may be trying to run your application on a different computer without your same IDE setup this tool can build the modules and get them up and running right away, however.

## Helpers

Helpers consist of a folder with a `helper.yml` file in it. The `helper.yml` file specifies what the other files in the folder should be used for. A helper can be made up of the following:

- stacks
- libraries
- backscripts
- frontscripts
- behaviors
- externals
- extensions

If no `helper.yml` file is found then the framework will try to load up each file in the folder as a stack.

If your helper includes an extension then you can also specify a resource folder for the extension. This is the folder where any resources that your widget loads will come from. For example, if you use `image from resource file mResource` and it is a relative reference then the LiveCode engine will look in the resource folder.

If no resource file is specified and a `./resources` folder exists alongside your `app.yml` file then that folder will be used.

```
extensions:
  1:
    filename: myextension.lcm
    resource folder: ./ext_resources
    source file: ../../extensions/myextension/myextension.lcb
```

TODO: example helper.yml file

## Targeting files in the LiveCode user extensions folder.

You can use the `{{USER_EXTENSIONS}}` variable in a any path to use the value returned by `revEnvironmentCustomizationPath()` in the IDE. This allows you to store commonly used resources in your LiveCode User Extension folder.

### Example:

```
helpers:
  1: {{USER_EXTENSIONS}}/Helpers"
```

## file extensions example

```
file extensions:
  JPEG Files: jpg,jpeg
```

## file extension groups example

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

## Examples of where to put resource files

TODO: Describe a resource and then show where to put it

## standalone.livecode

This stack is used to build the standalone application. The `levureFramework.livecodescript` stack file should be assigned to the stackFiles of this stack. The `levureFramework` stack should be assigned as the behavior of this stack. This stack can be named whatever you would like in memory.

## app.livecodescript

This stack file must be located directly alongside the `app.yml` file. The stack must be named `app` in memory. It has the following handlers for handling framework messages:

- `PreloadApplication`: Perform any operations that need to happen before your application files are loaded into memory.
- `InitializeApplication`: Initialize your application. Framework has loaded at this point.
- `OpenApplication`: Open your application window.
- `PreShutdownApplication`: Sent before the application shuts down. Perform any cleanup.
- `ProcessURL`: First parameter is line delimited list of urls that your app has been requested to process. Requires the `{{FRAMEWORK}}/helpers/files_and_urls helper`.
- `ProcessFiles`: First parameter is line delimited list of files that your application supports and that you should process. Requires the `{{FRAMEWORK}}/helpers/files_and_urls` helper.

## levureFramework.livecodescript

The framework logic is located in the `levure.livecodescript` file. The stack must be assigned as the behavior of another stack which is assumed to be the `standalone.livecode` stack. The `levureInitializeAndRunApplication` will initialize and load the framework. Here is what happens during loading:

1. If an sAppA script local exists and the stack is running in the development environment then use values from that. It means the app has been packaged. Otherwise load the `app.yml` file, searching first alongside the `standalone.livecode` stack file and then directly within any folders that are alongside the `standalone.livecode` stack. If `app.yml` is not found then app cannot be loaded.
2. Process any command line arguments using the `app_files_and_urls` helper (if `app.yml` explicitly loads this helper).
3. Load `app.livecodescript` from folder containing the `app.yml` file.
4. Load externals.
5. Load helpers whose "preload" property is true. Any helper that ships with the framework is preloaded. When a helper is loaded all extensions, libraries, backscripts, and frontscripts that make up a helper will be loaded. UI stacks are added to list of stackFiles of the `app` stack.
6. Create application data folders.
7. Dispatch `PreloadApplication` to the `app` stack.
8. Load remaining application assets. Extensions, libraries, backscripts, frontscripts are loaded into memory. UI stacks are added to list of stackFiles of the `app` stack.
9. Dispatch `InitializeApplication` to `app` stack.
10. Dispatch `OpenApplication` to `app` stack.

# Relaunching Application

In the `app.yml` file you can configure a `multiple instances` property. Set to true if you want your application to support multiple instances. If `multiple instances` is `false` and you don't want the defaultStack to come forward when the user relaunches the application then set `relaunch in background` to true.

When the `relaunch` message is processed by the levure standalone, a `RelaunchApplication` message will be dispatched to the `app` stack. If your application requires any special logic for bringing windows forward then it should be handled here. If any command line parameters are passed to `relaunch` then the `ProcessCommandLineParameters` message will be dispatched to the `app` stack as well.

# Version information

There are two properties you will deal with for versioning: `version` and `build`. `version` is in the [major].[minor].[revision] format. This is what you would display to users. `build` is an integer that you should increment each time you build your application. The build number is used to uniquely identify your application for the Sparkle update framework as well as identify each package in a 'release train' that you submit to the Mac App Store when preparing to release a version to the public. You can start the build number at 1 and then increment by one each time you package your application and send it to someone.

# Building executables for testing

The framework supports building stub executables that can be used to launch your app in a standalone environment for testing. By using the stub executables for testing, you can be working on your application in the IDE and instantly test your work running in a standalone.

To build the stub executables open your standalone stack and call the function `levureBuildStandalonesForTesting` from the message box. The LiveCode standalone builder will be used to build standalones based on your settings. MacOS X, Windows, and Linux standalone files will be moved to a `test` folder inside of the `build folder` that you have configured in `app.yml`.

# Packaging an Application

Levure will package up an application for distribution. To package your application for a specific build profile call the following handler:

```
levurePackageApplication pBuildProfile
```

- Creates a folder named after the build profile in the `build folder`.
- Within that folder a folder is created using the version and build number.
- The packaged applications will be placed in folders for each platform you build your application for.
- Any files in your `copy files` settings will be copied over. Variable replacement will be performed on any files.
- If you are building on OS X and have configured a `certificate name` then the app will be signed.
- If you are building for a profile named "mas" or "Mac App Store" then the app will be signed, zipped up, and prepared for upload to the Mac App Store.

# Helpers Included with Framework

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

- If you use scripts for all behaviors then you have to manually construct behaviors with behaviors when a stack opens. A script only stack can't have a behavior property assigned to it. This is not an issue for behaviors stored in the `./behaviors` folder as the `LoadBehavior` message is dispatched to each stack and it can set its own behavior. For behaviors that are part of your components you need to make sure that you assign the parent behavior somewhere else (e.g. in a `preopenstack` message or in the `InitializeApplicaiton` message).
- Window manager increases height of stacks when they are reopened on OS X.
