script "levureFramework"
##########
## This script must be assigned to a behavior of a stack that will be built as a standalone.
##########
constant kVersion = "0.9.9"
constant kAppStackName = "app"
constant kApplicationExternals = "levureAppExternals"
constant kLiveCodeExtensions = "livecode,livecodescript"
constant kLiveCodeModule = "lcm"
constant kLevureErr = "levureerr,"
constant kUIKey = "ui"
constant kUITemplatesKey = "templates"
constant kNestedKeysDelimiter = ">"

local sAppFolder              # Folder where the `app` stack resides
local sAppA
local sRuntimePropertiesA

on mouseUp pBtnNum
  # Load app if user clicks on button in standalone stack
  if sRuntimePropertiesA["state"] is empty then
    if pBtnNum is 1 and word 1 of the target is "button" and the owner of the owner of the target is me then
      levureInitializeAndRunApplication
      exit mouseUp
    end if
  end if

  pass mouseUp
end mouseUp


after startup
  levureInitializeAndRunApplication
end startup


on shutdown
  if the environment is not "development" then
    levureShutdownApplication
  end if

  pass shutdown
end shutdown


on relaunch
  if sRuntimePropertiesA["state"] is "running" then
    if sAppA["multiple instances"] then
      pass relaunch
    else
      dispatch "RelaunchApplication" to stack kAppStackName

      local i, tParams

      repeat with i = 1 to the paramcount
        put param(i) & cr after tParams
      end repeat
      delete the last char of tParams

      #
      # If `background` is returned then the engine won't bring any stacks forward.
      #
      # `send` is used to processed outside of relaunch. Saw instances where
      # url processing opened a pref window but pref window would not come forward
      # when called. Main window stayed in front. Adding the send in time fixed it.
      # My guess is code brough a stack forward and then engine brought forward the defaultStack
      # after relaunch finished. This may no longer be a bug. Need to test. In any case,
      # send in time is desirable as engine is going to bring defaultStack forward and
      # then developer code can handle any special cases.
      if tParams is not empty then
        # This handler is defined in a helper
        send "ProcessCommandLineParameters tParams" to stack kAppStackName in 0 milliseconds
      end if

      if sAppA["relaunch in background"] then
        return "background"
      end if
    end if
  end if
end relaunch


/**
Summary: Displays errors that occur in a standalone during initialization or cleanup.

Description:
If an error occurs in a standalone while the framework is loading or shutting down the application
then the error will be displayed and the application will quit. The assumption is that something
unexpected happened and you don't want your application lingering around in memory unable to quit.
*/
on errorDialog pError
  if the environment is "development" OR sRuntimePropertiesA["state"] is "running" then pass errorDialog

  answer error pError
  quit
end errorDialog


/**
Summary: Returns the version of the Levure framework in use.

Returns: The version in format x.x.x.x
*/
function levureVersion
  return kVersion
end levureVersion


/**
Summary: Returns true if a helper is loaded.

pHelperFolderName: The name of the helper folder.

Example:
put levureIsHelperLoaded("preferences") into tUsePrefs

Returns: True/False
*/
function levureIsHelperLoaded pHelperFolderName
  local i

  set the itemDelimiter to "/"

  repeat with i = 1 to the number of elements of sAppA["helpers"]
    if sAppA["helpers"][i]["filename"] ends with pHelperFolderName then
      return true
    end if
  end repeat
  return false
end levureIsHelperLoaded


/**
Summary: Packages up a levure application for distribution.

pBuildProfile: The profile to build (e.g. `release` or `beta`). The profile must be defined in your `app.yml` file.

Description:
When you are ready to package up your application for distribution to someone you call this handler.
The build profile that you pass in is the value that will be returned by `levureBuildProfile()` when
running the standalones.

When packaging the application stacks will be encrypted if A) the `encrypted stacks` property is true in the `app.yml`
file and B) a password can be located. The password can be stored in the `app.yml` file (not advisable if you store your
project in a version control system) or in the `.env` file that sits alongside the `app.yml` file (add a PASSWORD=VALUE line).

During the packaging process any properties defined in the `build profiles` > `all profiles` and `build profiles` > `pBuildProfile`
sections of your `app.yml` file will affect how the application is packaged. Below is a description of properties you can define.

The `packager callback stackfiles` property in `app.yml` points to a stack that will receive the
`finalizePackagedAssets pBuildProfile, pBuildProfile, @xAppA, pAppFolder`,
`finalizeStandaloneForPlatform pBuildProfile, pPlatform, pAppA, pAppFolder, pFolderSavedIn`,
`finalizePackageForPlatform pBuildProfile, pPlatform, pAppA, pAppFolder, pOutputFolder`,
and `packagingComplete pBuildProfile, pOutputFolder` messages.

The `certificates` > `macos` > `name` property is the name of the certificate that the packager should use to sign your applications on macOS.
The packager will prefix the certificate with `Developer ID Application:` for apps being distributed outside of the Mac App Store
and with `3rd Party Mac Developer Application:` for apps being distributed through the Mac App Store, and with `Mac Developer:` for apps built
for testing Mac App Store applications. The packager assumes you are
distributing through the Mac App Store if the name of pBuildProfile is "mac app store" and for development if pBuildProfile is
"mac app store development".

The `copy files` property determines which files will be copied into the output folder.

Example:
levurePackageApplication "release"

Returns: Error message
*/
command levurePackageApplication pBuildProfile
  local tError, tStackFilename

  if the environment is not "development" then put "can only be run in development environment" into tError

  if tError is empty then
    _initializePackaging pBuildProfile, tStackFilename
    put the result into tError
  end if

  if tError is empty then
    local tStandaloneStack, tBuildProfile

    put the effective filename of me into tStandaloneStack
    # This stack will be removed from memory so send in time
    send "packagerPackageApplication tStandaloneStack, pBuildProfile" to stack tStackFilename in 10 milliseconds
  end if

  return tError for error
end levurePackageApplication


/**
Summary: Message sent from the packager script.

Description:
Move along. Nothing to see here.
*/
command packagerDidFinishPackagingApplication pStandaloneStackFilename, pBuildProfile
  # Remove from memory after packaging is complete
  if there is a stack "Levure Framework Application Packager FrontScript" then
    delete stack "Levure Framework Application Packager FrontScript"
  end if
  delete stack "Levure Framework Application Packager"

  if pBuildProfile is among the items of "ios simulator,android simulator" then
    go stack pStandaloneStackFilename
    dispatch "revIDEDeployAction" to stack "revDeployLibrary"
  end if
end packagerDidFinishPackagingApplication


/**
Summary: Message sent from the packager script.

Description:
Move along. Nothing to see here.
*/
command packagerDidFinishBuildingStandaloneForTesting
  # Remove from memory after building standalone is complete
  if there is a stack "Levure Framework Application Packager FrontScript" then
    delete stack "Levure Framework Application Packager FrontScript"
  end if
  delete stack "Levure Framework Application Packager"
end packagerDidFinishBuildingStandaloneForTesting


/**
Summary: Builds a standalone that loads all of your development files when launched.

Description:
This handler will create standalone engines that can be used for testing on your target platforms.
A `test` folder will be created in the `builds` folder that is configured in your `app.yml` file.
The `test` folder will have executables for each desktop platform that you standalone.livecode stack
has been configured for in Standalone Settings.

None of the actual application stacks are bundled with the executables. When you launch any of
the executables the executable will load the files from your development folder. This allows you
to quickly test changes while running from a standalone.

The Levure packager will attempt to include the Remote Debugger
(available in LiveCode 9 and above for Business licenses) if it is available.

Example:
levureBuildStandalonesForTesting

Returns: Error message
*/
command levureBuildStandalonesForTesting
  local tError, tStackFilename

  if the environment is not "development" then return "can only be run in development environment"

  if tError is empty then
    _initializePackaging empty, tStackFilename
    put the result into tError
  end if

  if tError is empty then
    local tStandaloneStack

    put the effective filename of me into tStandaloneStack
    # This stack will be removed from memory so send in time
    send "packagerBuildStandaloneForTesting tStandaloneStack, true" to stack tStackFilename in 10 milliseconds
  end if

  return tError for error
end levureBuildStandalonesForTesting


private command _initializePackaging pBuildProfile, @rPackagerFilename
  local tError
  if sAppA is not an array then
    start using me

    levureLoadAppConfig pBuildProfile
    put the result into tError
  end if

  if tError is empty then
    set the itemdelimiter to "/"

    put levureFrameworkFolder() into rPackagerFilename
    put "packager/packager.livecodescript" into the last item of rPackagerFilename
  end if

  return tError
end _initializePackaging


/**
Summary: Starts the server that listens for changes to application stack scripts.

[pPort]: Pass in a port if you plan on having two different Levure applications open in two different instances of the IDE. Otherwise the default port should suffice.

Description:
This handler allows you to work on a Levure application in the IDE and edit all of your script only stacks using
an external editor. The handler loads a stack into the IDE that starts a server on the `localhost`. The server listens
for requests notifying the server that a script only stack has been updated. The server will then update the script
of the matching stack in memory.

This handler is typically called in the `InitializeApplication` message that is sent to the `app` stack.

Currently Sublime Text is the only editor that will work using this setup. If you have the LiveCode language module
installed for LiveCode then each time you save a LiveCode file in Sublime Text a request is sent to the server.

Example:
command InitializeApplication
  if the environment is "development" then
    levureLoadExternalEditorServer
  end if
end InitializeApplication

Returns: Empty
*/
command levureLoadExternalEditorServer pPort
  local tStackFilename, tStackPath

  set the itemdelimiter to "/"

  put levureFrameworkFolder() into tStackFilename
  put "utils/external_editor_server/external_editor_server.livecodescript" into tStackPath
  put tStackPath into the last item of tStackFilename
  if there is a stack tStackFilename then
    if pPort is not an integer then
      local tEnvA
      put levureAppGetENV() into tEnvA
      put tEnvA["EXTERNAL_EDITOR_PORT"] into pPort
    end if
    dispatch "levureExternalEditorStartServer" to stack tStackFilename with pPort
  else
    answer error tStackPath && "was not found"
  end if

  return empty
end levureLoadExternalEditorServer


/**
Summary: Returns the name of the `app` stack.

Description:
If you ever need to refer to the `app` stack by name you can call this function. It
saves you from hard coding `app` in your code.

Example:
dispatch "MyCustomMessage" to stack levureAppStackName()

Returns: "app"
*/
function levureAppStackName
  return kAppStackName
end levureAppStackName


/**
Summary: Returns the filename of the `app` stack file.

Example:
put levureAppStackFilename() into tAppStackFilename

Returns: Path to file
*/
function levureAppStackFilename
  return the filename of stack kAppStackName
end levureAppStackFilename


/**
Summary: Initializes and runs the application.

Description:
This handler is used internally by the framework to initialize and run the application.

Typically you will never need to call this handler as it is called automatically at `startup`
when your application is running in a standalone or when you click the button in the
`standalone.livecode` stack.

Example:
# In this example "MyStandalone" is the name of the standalone.livecode stack
start using stack "MyStandalone"
dispatch "levureInitializeAndRunApplication" to stack "MyStandalone"

Returns: Empty
*/
command levureInitializeAndRunApplication
  local tError

  put "loading" into sRuntimePropertiesA["state"]

  set visible of me to false
  set the loc of me to the screenloc
  start using me

  levureInitializeFramework
  put the result into tError

  if tError is empty then
    ## Use a send so that if any dialogs are displayed in developer handled messages the
    ## loading process will not stop
    send "levureRunApplication" to me in 0 milliseconds
  end if

  if tError is not empty then
    answer error "An error occurred while initializing the application [" &  tError & "]."

    if the environment is not "development" then
      quit
    end if
  end if

  return empty
end levureInitializeAndRunApplication


/**
Summary: Initializes the application without running it.

Description:
This handler is used internally by the framework to load the configuration information, load
all helpers, libraries, frontscripts, backscripts, behaviors, and ui assets. The `PreloadApplication`
message will be dispatched to the `app` stack.

Typically you will never need to call this handler. If you need to troubleshoot something
without runing your application you can call this handler after opening the `standalone.livecode`
file in the IDE. See example.

Example:
# In this example "MyStandalone" is the name of the standalone.livecode stack
start using stack "MyStandalone"
dispatch "levureInitializeFramework" to stack "MyStandalone"
put levureAppGetConfig() into tA
put tA["version"]

Returns: Error message
*/
command levureInitializeFramework
  local tError

  if the long id of me is the long id of this me OR word 1 of the long id of me is not "stack" then
    put "the framework is not assigned to a stack as a behavior" into tError
  end if

  if tError is empty then
    levureLoadAppConfig levureBuildProfile()
    put the result into tError
  end if

  if tError is empty then
    createApplicationDataFolders
    put the result into tError
  end if

  if tError is empty then
    dispatch "PreloadApplication" to stack kAppStackName
  end if

  if tError is empty then
    loadExternals sAppA["externals to load"]
    put the result into tError
  end if

  # extensions
  if tError is empty then
    loadExtensions sAppA
    put the result into tError
  end if

  if tError is empty then
    repeat with i = 1 to the number of elements of sAppA["helpers"]
      loadExtensions sAppA["helpers"][i]
      put the result into tError

      if tError is not empty then
        exit repeat
      end if
    end repeat
  end if

  if tError is empty then
    loadAppAssets
    put the result into tError
  end if

  return tError for error
end levureInitializeFramework


/**
Summary: Begins running the application during the startup sequence.

Description:
This handler is called "in time" during the startup sequence. You will not call this handler
in your code.

Returns: Empty
*/
command levureRunApplication
  local tError, tStacksInApp

  if tError is empty then
    loadCommandLineArguments
  end if

  # Add lookup for all stacks in app. They will be loaded into memory as needed
  # when referenced by name.
  if tError is empty then
    dispatch "InitializeApplication" to stack kAppStackName
    if it is "handled" and the result is false then
      ## user can quit app if they want
      if lockMessages is true then unlock messages
      unloadApp

      ## Only quit if not in development. This allows developer to troubleshoot.
      if the environment is not "development" then
        quit
        exit to top
      end if
    else
      ## On macOS we need a delay here so that appleEvents can be processed
      ## `OpenApplication` is sent to the application. This allows URLs that
      ## launched application to be tucked away in "process url"
      ## We don't want a delay when running on mobile platforms, however, as
      ## it can introduce a brief flicker when transitioning from splash screen
      ## to the first stack.
      if the platform is "macos" then
        send "levureFinishLoadingApplication" to me in 10 milliseconds
      else
        levureFinishLoadingApplication
      end if
    end if
  end if

  -- display tError
  return empty
end levureRunApplication


private command loadCommandLineArguments
  if the platform is not "macos" then
    local tValue, tParams, i

    repeat with i = 1 to ($# - 1)
      put value("$" & i) into tValue
      put tValue & cr after tParams
    end repeat
    delete the last char of tParams

    if tParams is not empty then
      dispatch "ProcessCommandLineParameters" with tParams
    end if
  end if
  return empty
end loadCommandLineArguments


/**
Summary: Finishes loading the application during the startup sequence.

Description:
This handler is called "in time" during the startup sequence. You will not call this handler
in your code.

Returns: Empty
*/
command levureFinishLoadingApplication
  local msgsAreLocked

  dispatch "OpenApplication" to stack kAppStackName
  put "running" into sRuntimePropertiesA["state"]

  # Don't fire off any messages when closing the standalone stack
  put the lockMessages into msgsAreLocked
  lock messages
  close me
  set the lockMessages to msgsAreLocked
  return empty
end levureFinishLoadingApplication


/**
Summary: Returns the folder where application data is stored for the application.

pUserOrShared: Pass in `shared` for the shared folder path. Pass in `user` for the user folder path. Default is `user`.

Description:
This handler combines the standard folder where application data is stored
on the current system with the application data folder defined in the `app.yml` file.

Example:
put levureApplicationDataFolder("user") into tUserDataFolder

Returns: Path to folder
*/
function levureApplicationDataFolder pUserOrShared
  local tFolder

  if pUserOrShared is not "shared" then put "user" into pUserOrShared

  if platformApplicationDataFolder(pUserOrShared) is empty then
    throw kLevureErr & param(0) && ": the" && quote & "application data folder" & quote \
          && "property has not been set for the current platform in app.yml"
  end if

  if pUserOrShared is not "shared" then
    switch the platform
      case "win32"
      case "macos"
        put specialFolderPath("support") & "/" into tFolder
        break
      case "linux"
        put specialFolderPath("home") & "/." into tFolder
        break
      case "iphone"
        put specialFolderPath("library") & "/Application Support/" into tFolder
        break
      case "android"
        put specialFolderPath("documents") & "/Application Support/" into tFolder
        break
      default
        return empty
    end switch
  else
    switch the platform
      case "macos"
        put specialFolderPath("asup") & "/" into tFolder
        break
      case "win32"
        put specialFolderPath("35") & "/" into tFolder
        break
      case "linux"
        put "/opt/." into tFolder
        break
      default
        return empty
    end switch
  end if

  put platformApplicationDataFolder(pUserOrShared) after tFolder

  return tFolder
end levureApplicationDataFolder


/**
Summary: Returns the current state of the application.

Description:
Returns a value of `loading`, `running`, or `shutting down`. These values reflect the
internal state of the Levure application.

While Levure is loading application files at startup
the state is `loading`.

When Levure has begun to shut down the application (e.g. the user quit the application) then
the state is `shutting down`.

In all other cases the state is `running`.

Example:
# In app.livecodescript
on appleEvent pClass, pId, pSender
  # don't process events if application isn't running
  if levureApplicationState() is not "running" then pass appleEvent

  ...
end appleEvent

Returns: "loading", "running", "shutting down"
*/
function levureApplicationState
  return sRuntimePropertiesA["state"]
end levureApplicationState


/**
Summary: Returns the internal array that was created when reading the `app.yml` file.

Example:
put levureAppGetConfig() into tAppA
put tAppA["name"]

Returns: Array
*/
function levureAppGetConfig
  return sAppA
end levureAppGetConfig


/**
Summary: Returns a text representation of the internal array that was created when reading the `app.yml` file.

Example:
put levureAppPrintConfig()

Returns: Array
*/
function levureAppPrintConfig
  return _printArray(sAppA,,true)
end levureAppPrintConfig


/**
Summary: Returns an environmental variable stored in the `.env` file.

Description:
During development you can place an `.env` file alongside the `app.yml` file. The format is
a key=value pair, one per line. This function will return a key value.

Use the `.env` file to store values you don't want stored in a git repository. For example,
you should store the `password` used to password protect your application in the `.env` file.
As long as the `.env` file is not stored in your version control repository the password
will not be stored in the repository.

The Levure application packager will use this function to check for a password when packaging
your application.

Example:
# Assumes your .env file has a PASSWORD=VALUE line in it
put levureAppGetENV("password") into tPassword

Returns: String
*/
function levureAppGetENV
  local tError, tEnvA

  put readFileContents(sAppFolder & "/.env") into tEnvA
  put the result into tError

  if tError is empty then
    local tKey

    split tEnvA by CR AND "="
    repeat for each key tKey in tEnvA
      put word 1 to -1 of line 1 of tEnvA[tKey] into tEnvA[tKey]
    end repeat
  end if

  return tEnvA
end levureAppGetENV


/**
Summary: Use to check if a property name is among the keys in the application configuration array.

Parameters:
pProp: The property to check. This can be a string or an indexed lookup array. If a string then nested keys can be separated by the `>` character.

Syntax: levureAppHasProperty(<pProp>)
Syntax: levureAppHasProperty(<pIndexedArray>)

Description:
This handler targets the internal array that was created when the app.yml file was loaded. If it is possible
that an application property doesn't exist then use this function before calling `levureAppGet()` or
`levureAppSet`. Both handlers will throw an error if the target property doesn't exist.

Example:
put levureAppHasProperty("preferences filename>user>default")

Example:
# Use an indexed lookup array
put "preferences filename" into tIndexA[1]
put "user" into tIndexA[2]
put "default" into tIndexA[3]
put levureAppHasProperty(tIndexA)

Returns: True/False
*/
function levureAppHasProperty pProp
  local tIndexA

  set the itemDelimiter to ">"
  if the number of items of pProp > 1 then
    split pProp by ">"
  end if

  if pProp is an array then
    put pProp into tIndexA
    put tIndexA[the number of elements of tIndexA] into pProp
    delete variable tIndexA[the number of elements of tIndexA]
  end if

  if tIndexA is an array then
    return pProp is among the keys of sAppA[tIndexA]
  else
    return pProp is among the keys of sAppA
  end if
end levureAppHasProperty


/**
Summary: Gets an app property.

Parameters:
pProp: The property to check. This can be a string or an indexed lookup array. If a string then nested keys can be separated by the `>` character.
pCheckExistence: Pass in `true` to throw an error if `pProp` does not exist in the internal `sAppA` array. This can be used to ensure that a valid setting is being added to `app.yml`.

Syntax: levureAppGet(<pProp>)
Syntax: levureAppGet(<pIndexedArray>)

Description:
This handler targets the internal array that was created when the app.yml file
was loaded.

If the property passed in does not exist then an error will be thrown.

Example:
put levureAppGet("preferences filename>user>default")

Example:
# Use an indexed lookup array
put "preferences filename" into tIndexA[1]
put "user" into tIndexA[2]
put "default" into tIndexA[3]
put levureAppGet(tIndexA)

Returns: Mixed as it depends on property value
*/
function levureAppGet pProp, pCheckExistence
  local tIndexA

  put pCheckExistence is true into pCheckExistence

  set the itemDelimiter to ">"
  if pProp is not an array and the number of items of pProp > 1 then
    split pProp by ">"
  end if

  if pProp is an array then
    put pProp into tIndexA
    put tIndexA[the number of elements of tIndexA] into pProp
    delete variable tIndexA[the number of elements of tIndexA]
  end if

  if the number of elements of tIndexA >= 1 then
    if not pCheckExistence or pProp is among the keys of sAppA[tIndexA] then
      return sAppA[tIndexA][pProp]
    else
      throw kLevureErr & "invalid levure app property:" && _printPropParameter(pProp, tIndexA)
    end if
  else
    if not pCheckExistence or pProp is among the keys of sAppA then
      return sAppA[pProp]
    else
      throw kLevureErr & "invalid levure app property:" && _printPropParameter(pProp, tIndexA)
    end if
  end if
end levureAppGet


/**
Summary: Sets an app property for the life of the current session.

Parameters:
pProp: The property to check. This can be a string or an indexed lookup array. If a string then nested keys can be separated by the `>` character.
pValue: The value to set the property to.
pCheckExistence: Pass in `true` to throw an error if `pProp` does not exist in the internal `sAppA` array. This can be used to ensure that a valid setting is being added to `app.yml`.

Syntax: levureAppSet <pProp>, <pValue>
Syntax: levureAppSet <pIndexedArray>, <pValue>

Description:
This handler targets the internal array that was created when the app.yml file
was loaded. The value will only be updated for the current session. The app.yml
file is not updated.

Example:
levureAppSet "multiple instances", true

Example:
put "preferences filename" into tIndexA[1]
put "user" into tIndexA[2]
put "default" into tIndexA[3]
levureAppSet tIndexA, "com.mycompanyname.myapp-shared"

Returns: Empty
*/
command levureAppSet pProp, pValue, pCheckExistence
  local tIndexA

  put pCheckExistence is true into pCheckExistence

  set the itemDelimiter to ">"
  if pProp is not an array and the number of items of pProp > 1 then
    split pProp by ">"
  end if

  if pProp is an array then
    put pProp into tIndexA
    put tIndexA[the number of elements of tIndexA] into pProp
    delete variable tIndexA[the number of elements of tIndexA]
  end if

  if the number of elements of tIndexA > 1 then
    if not pCheckExistence or pProp is among the keys of sAppA[tIndexA] then
      put pValue into sAppA[tIndexA][pProp]
    else
      throw kLevureErr & "invalid levure app property:" && _printPropParameter(pProp, tIndexA)
    end if
  else
    if not pCheckExistence or pProp is among the keys of sAppA then
      put pValue into sAppA[pProp]
    else
      throw kLevureErr & "invalid levure app property:" && _printPropParameter(pProp, tIndexA)
    end if
  end if

  return empty for error
end levureAppSet


private function _printPropParameter pProp, pIndexA
  local i, tProp

  repeat with i = 1 to the number of elements of pIndexA
    put pIndexA[i] & " > " after tProp
  end repeat
  put pProp after tProp
  return tProp
end _printPropParameter


/**
Summary: Returns an array of all `ui` category assets.

Returns: Numerically indexed array. "name", "filename", and "key". "key" is the key the UI assets is listed under in app.yml.
 */
function levureGetUIStacks
  local tKey, tLookupA, i, j, tStacksA

  repeat for each key tKey in sAppA["registered components"]["ui"]
    put tKey into tLookupA
    split tLookupA by kNestedKeysDelimiter

    repeat with i = 1 to the number of elements of sAppA[tLookupA]
      add 1 to j
      put sAppA[tLookupA][i] into tStacksA[j]
      put tKey into tStacksA[j]["key"]
    end repeat
  end repeat

  return tStacksA
end levureGetUIStacks


/**
Summary: Returns the name of the build profile used to package the version of the application that is running.

Description:
When you package an application you package a specific build profile. This handler
returns the name of the build profile that was used. When running in the IDE "development"
is returned.

Example:
put levureAppGet("version") into tVersionString
if the levureBuildProfile() is "beta" then
  put " (BETA)" after tVersionString
end if

Returns: Build profile name
*/
function levureBuildProfile
  if the environment is "development" then
    return "development"
  else
    return the uBuildProfile of me # Assigned at build time
  end if
end levureBuildProfile


private command normalizeAppArray
  put sAppA["multiple instances"] is true into sAppA["multiple instances"]
  put sAppA["relaunch in background"] is true into sAppA["relaunch in background"]

  # kUIKey and kUITemplatesKey are always a registered "ui" component
  put empty into sAppA["registered components"]["ui"][kUIKey]
  put empty into sAppA["registered components"]["ui"][kUITemplatesKey]
  put false into sAppA["registered components"]["ui"][kUITemplatesKey]["encrypt binary stacks"]

  repeat for each item tGroup in "user,shared"
    repeat for each item tPlatform in "default,macos,windows,linux,ios,android"
      if tGroup is "shared" and tPlatform is in "ios,android" then exit repeat

      put normalizeFolderPath(sAppA["application data folder"][tGroup][tPlatform]) into sAppA["application data folder"][tGroup][tPlatform]

      repeat while char 1 of sAppA["application data folder"][tGroup][tPlatform] is "/"
        delete char 1 of sAppA["application data folder"][tGroup][tPlatform]
      end repeat
    end repeat
  end repeat

  repeat for each item tKey in "password,file extensions,file extension groups"
    if tKey is not among the keys of sAppA then
      put empty into sAppA[tKey]
    end if
  end repeat

  return empty for value
end normalizeAppArray


private command unloadApp
  # Unload assets in reverse order
  unloadAssets sAppA

  repeat with i = the number of elements of sAppA["helpers"] down to 1
    unloadAssets sAppA["helpers"][i]
  end repeat

  unloadExternals
end unloadApp


private command unloadAssets pArrayA
  repeat for each item tKey in "frontscripts,backscripts,libraries"
    repeat with i = the number of elements of pArrayA["frontscripts"] down to 1
      remove the script of stack pArrayA["frontscripts"][i]["filename"] from front
    end repeat
    repeat with i = the number of elements of pArrayA["backscripts"] down to 1
      remove the script of stack pArrayA["backscripts"][i]["filename"] from back
    end repeat
    repeat with i = the number of elements of pArrayA["libraries"] down to 1
      stop using stack pArrayA["libraries"][i]["filename"]
    end repeat
  end repeat
end unloadAssets


/**
Summary: Cleans up and shuts down the application when running in a standalone.

Description:
You should not need to call this handler in your own code. The framework calls this handler
when the `shutdown` message is received. An auto updater would call this function as well
when unloading the application prior to update.

When this handler is called it will dispatch `PreShutdownApplication` to the `app` stack.

Returns: empty
*/
command levureShutdownApplication
  local tError, tCurrentState

  # Don't allow multiple calls to this.
  if sRuntimePropertiesA["state"] is "shutting down" then exit levureShutdownApplication

  put sRuntimePropertiesA["state"] into tCurrentState
  put "shutting down" into sRuntimePropertiesA["state"]

  ## Just in case it is still open after an error during launch
  close me

  if tCurrentState is "running" then
    dispatch "PreShutdownApplication" to stack kAppStackName

    # TODO: helpers should register to be notified when application is shutting down
    if levureIsHelperLoaded("preferences") then
      if prefsIsCategoryConfigured("user") then
        prefsSave "user"
        put the result into tError
        if tError is not empty then
          answer "An error occurred while saving user preferences:" && tError & "."
        end if
      end if

      if prefsIsCategoryConfigured("shared") then
        prefsSave "shared"
        put the result into tError
        if tError is not empty then
          answer "An error occurred while saving shared preferences:" && tError & "."
        end if
      end if
    end if

    unloadApp
  end if

  # Cleanup anything that might keep application from shutting down properly
  repeat until the pendingMessages is empty
    cancel item 1 of line 1 of the pendingMessages
  end repeat
  repeat until the openProcesses is empty
    close process (line 1 of the openprocesses)
  end repeat

  stop using me

  put empty into sRuntimePropertiesA["state"]

  return empty for value
end levureShutdownApplication


/**
Summary: Loads the app configuration data into memory and resolves all file references in it.

pBuildProfile: This will be used to filter out assets using the "build profiles filter" property of each asset.

Description:
When calling this command in the IDE the app.yml file will be read into memory.
When calling this command in a standalone the configuration information is stored as a
custom property of the `app` stack.

The app.yml file can contain relative folder and file references. All relative references
will be resolved when calling this handler.

Example:
levureLoadAppConfig
answer levureAppGet("name")

Returns: Error message
*/
command levureLoadAppConfig pBuildProfile
  local tError
  local tSource
  local tKey

  # set sAppFolder and load kAppStackName into memory
  loadApplicationStack

  put empty into sAppA["filtered out filenames"]

  if (the environment is not "development") and (the uAppA of stack kAppStackName is an array) then
    # Packaged application: app stack is already in memory and all folders have been expanded
    put the uAppA of stack kAppStackName into sAppA

    expandPackagedAppArrayFilenames sAppA, sAppFolder

    put expandHelperAssetsFileReferenceArray(pBuildProfile, sAppA["helpers"], sAppFolder) into sAppA["helpers"]
    put the result into tError

    if tError is empty then
      resolveHelperAssets pBuildProfile
      put the result into tError
    end if

    if tError is empty then
      ##########
      ## Load all behaviors into memory. See note below for reason why
      ## behaviors are loaded in this handler.
      ##########
      loadAllBehaviorsIntoMemory
    end if
  else

    # Development: Load config file and expand all folders in config
    put yamlFileToArray(sAppFolder & "/app.yml") into sAppA
    put the result into tError

    if tError is empty then
      normalizeAppArray
    end if

    if tError is empty then
      local i, j
      local tFilesA

      ##########
      # Extensions, Libaries, Backscripts, Frontscripts, and Behaviors
      ##########
      local tExtensions

      repeat for each item tSource in "extensions,libraries,backscripts,frontscripts,behaviors"
        put empty into tFilesA
        put 0 into j

        repeat with i = 1 to the number of elements of sAppA[tSource]
          add 1 to j
          put sAppA[tSource][i] into tFilesA[j]
        end repeat

        if the number of elements of tFilesA > 0 then
          if tSource is "extensions" then
            put kLiveCodeModule into tExtensions
          else
            put kLiveCodeExtensions into tExtensions
          end if
          put expandMessagePathAssetsFileReferenceArray(pBuildProfile, tFilesA, sAppFolder, tExtensions) into sAppA[tSource]
        end if
      end repeat

      ##########
      # Helpers
      ##########
      put empty into tFilesA
      put 0 into j

      repeat with i = 1 to the number of elements of sAppA["helpers"]
        add 1 to j
        put sAppA["helpers"][i] into tFilesA[j]
      end repeat

      if the number of elements of tFilesA > 0 then
        put expandHelperAssetsFileReferenceArray(pBuildProfile, tFilesA, sAppFolder) into sAppA["helpers"]
        put the result into tError

        if tError is empty then
          resolveHelperAssets pBuildProfile
          put the result into tError
        end if
      end if

      ##########
      # Get keys registered by helpers
      ##########
      if tError is empty then
        local tKeyIndex, tKind, tCallbackStack, k

        repeat with i = 1 to the number of elements of sAppA["helpers"]
          repeat with tKeyIndex = 1 to the number of elements of sAppA["helpers"][i]["register components"]
            put sAppA["helpers"][i]["register components"][tKeyIndex]["key"] into tKey
            put sAppA["helpers"][i]["register components"][tKeyIndex]["kind"] into tKind

            switch tKind
              case "ui"
                if tKey is not among the keys of sAppA["registered components"][tKind] then
                  put empty into sAppA["registered components"][tKind][tKey]
                  put sAppA["helpers"][i]["register components"][tKeyIndex]["encrypt binary stacks"] is not false \
                        into sAppA["registered components"][tKind][tKey]["encrypt binary stacks"]
                end if
              case "files"
                if tKey is not among the keys of sAppA["registered components"][tKind] then
                  put empty into sAppA["registered components"][tKind][tKey]
                  put sAppA["helpers"][i]["register components"][tKeyIndex]["distribute"] is not false \
                        into sAppA["registered components"][tKind][tKey]["distribute"]
                end if
                break
              case "copy files"
                # Copy files are only loaded in development
                if the environment is "development" then
                  if tKey is not among the keys of sAppA["registered components"][tKind] then
                    put empty into sAppA["registered components"][tKind][tKey]
                    put sAppA["helpers"][i]["register components"][tKeyIndex]["target platform"] \
                          into sAppA["registered components"][tKind][tKey]["target platform"]
                    put sAppA["helpers"][i]["register components"][tKeyIndex]["destination"] \
                          into sAppA["registered components"][tKind][tKey]["destination"]
                  end if
                end if
                break
            end switch

            if sAppA["helpers"][i]["register components"][tKeyIndex]["callback stackfile"] is not empty then
              put resolveFilenameReference(sAppA["helpers"][i]["register components"][tKeyIndex]["callback stackfile"], sAppA["helpers"][i]["filename"]) \
                      into sAppA["registered components"][tKind][tKey]["callback stackfile"]
            end if
          end repeat

          # Register callbacks defined in helper
          if the environment is "development" then
            if sAppA["helpers"][i]["packager callbacks stackfile"] is not empty then
              put resolveFilenameReference(sAppA["helpers"][i]["packager callbacks stackfile"], sAppA["helpers"][i]["filename"]) \
                    into line (the number of lines of sAppA["packager callbacks stackfiles"] + 1) \
                    of sAppA["packager callbacks stackfiles"]
            end if
          end if

        end repeat

        ##########
        ## Load all behaviors into memory.
        ## When retrieving UI stack names the UI stack will be brought into memory.
        ## This will load any stacks listed in the stackfiles property of the UI stack.
        ## If one of those stacks relies on a behavior then that behavior must be loaded
        ## beforehand.
        ##########
        loadAllBehaviorsIntoMemory

        ##########
        # ui components (includes "ui" key by default)
        ##########
        repeat for each key tKey in sAppA["registered components"]["ui"]
          put empty into tFilesA
          put 0 into j

          split tKey by kNestedKeysDelimiter

          repeat with i = 1 to the number of elements of sAppA[tKey]
            add 1 to j
            put sAppA[tKey][i] into tFilesA[j]
          end repeat

          if the number of elements of tFilesA > 0 then
            put expandUIAssetsFileReferenceArray(pBuildProfile, tFilesA, sAppFolder) into sAppA[tKey]
          end if

          # Stacks acting as templates will not have binary stacks encrypted
          if sAppA["registered components"]["ui"][tKey]["encrypt binary stacks"] is false then
            dontEncryptBinaryStacks sAppA[tKey]
          end if
        end repeat

        ##########
        # files components
        ##########
        repeat for each key tKey in sAppA["registered components"]["files"]
          put empty into tFilesA
          put 0 into j

          split tKey by kNestedKeysDelimiter

          repeat with i = 1 to the number of elements of sAppA[tKey]
            add 1 to j
            put sAppA[tKey][i] into tFilesA[j]
          end repeat

          if the number of elements of tFilesA > 0 then
            put expandFileAssetsFileReferenceArray(pBuildProfile, tFilesA, sAppFolder) into sAppA[tKey]
          end if
        end repeat
      end if
    end if
  end if

  # Cleanup
  delete local sAppA["filtered out filenames"]

  if tError is empty then
    if sAppA is not an array then
      put "invalid app.yml file" into tError
    end if
  end if

  return tError for error
end levureLoadAppConfig


/**
Summary: Finds and loads the app stack into memory.

Description:
If the app stack isn't already in memory then searches for `app.livecodescript`
or `app.livecode` is in `sAppFolder`.

Returns: empty
*/
private command loadAppStackIntoMemory
  if there is not a stack kAppStackName then
    if there is not a stack (sAppFolder & "/app.livecodescript") then
      if there is not a stack (sAppFolder & "/app.livecode") then
        throw kLevureErr & "app stack not found"
      end if
    end if
  end if

  return empty
end loadAppStackIntoMemory


/**
Summary: Loads the app stack and sets sAppFolder.

Returns: empty
*/
private command loadApplicationStack
  local tFolders, tFolder, tRootSearchFolder

  set the itemDelimiter to "/"

  # Get folder where `standalone.livecode` resides
  put the effective filename of me into tRootSearchFolder
  delete the last item of tRootSearchFolder

  # Find the app stack and set sAppFolder
  if there is a stack kAppStackName then
    put the filename of stack kAppStackName into sAppFolder
    delete the last item of sAppFolder
  else if doesFolderContainAppFile(tRootSearchFolder) then
    put tRootSearchFolder into sAppFolder
  else
    if the environment is not "development" then
      # Running "test" standalone which has this function defined.
      put levureTestingStandaloneAppFolder() into sAppFolder
    else
      put folderListing(tRootSearchFolder) into tFolders

      repeat for each line tFolder in tFolders
        if doesFolderContainAppFile(tFolder) then
          put tFolder into sAppFolder
          exit repeat
        end if
      end repeat
    end if
  end if

  if sAppFolder is empty then throw kLevureErr & "app stack not found"

  # Make sure app stack is in memory
  loadAppStackIntoMemory

  # Put in message path so shutdown, shutdownrequest, etc. are handled.
  start using stack kAppStackName

  return empty
end loadApplicationStack


/**
Summary: Returns true if a folder contains app.yml, app.livecodescript, or app.livecode

Description:
app.livecodescript and app.livecode only exist if they are actual stacks. This
means that the `app` stack will be in memory after calling this function.

Returns: true/false
*/
private function doesFolderContainAppFile pFolder
  return there is a file (pFolder & "/app.yml") \
        OR there is a stack (pFolder & "/app.livecodescript") \
        OR there is a stack (pFolder & "/app.livecode")
end doesFolderContainAppFile


private command createApplicationDataFolders
  local tError, tRootFolder

  if the platform is "iphone" then
    createSubfolders specialFolderPath("library"), "Application Support"
  else if the platform is "android" then
    createSubfolders specialFolderPath("documents"), "Application Support"
  end if

  if platformApplicationDataFolder("user") is not empty then
    put levureApplicationDataFolder("user") into tRootFolder
    replace "/" & platformApplicationDataFolder("user") with empty in tRootFolder
    createSubfolders tRootFolder, platformApplicationDataFolder("user")
    put the result into tError
  end if

  if tError is empty and platformApplicationDataFolder("shared") is not empty then
    put levureApplicationDataFolder("shared") into tRootFolder
    replace "/" & platformApplicationDataFolder("shared") with empty in tRootFolder
    createSubfolders tRootFolder, platformApplicationDataFolder("shared")
    put the result into tError
  end if

  return tError for error
end createApplicationDataFolders


private function platformApplicationDataFolder pUserOrShared
  local tPlatform, tA, tDefaultFolder, tPlatformFolder

  switch the platform
    case "win32"
      put "windows" into tPlatform
      break
    case "iphone"
      put "ios" into tPlatform
      break
    default
      put the platform into tPlatform
  end switch

  put "application data folder" into tA[1]
  put pUserOrShared into tA[2]
  put "default" into tA[3]
  put levureAppGet(tA) into tDefaultFolder

  put tPlatform into tA[3]
  put levureAppGet(tA) into tPlatformFolder

  if word 1 to -1 of tPlatformFolder is not empty then
    return tPlatformFolder
  else
    if word 1 to -1 of tDefaultFolder is not empty then
      return tDefaultFolder
    else
      return empty
    end if
  end if
end platformApplicationDataFolder


private command createSubfolders pRootFolder, pSubfolder
  local tError, tTargetFolder

  set the itemdelimiter to "/"

  repeat for each item tFolder in pSubfolder
    put pRootFolder & "/" & tFolder into tTargetFolder
    if there is not a folder tTargetFolder then
      create folder tTargetFolder
      put the result into tError
      if tError is not empty then
        put "unable to create folder" && pRootFolder & ":" && tError into tError
        exit repeat
      end if
    end if

    put pRootFolder & "/" & tFolder into pRootFolder
  end repeat

  return tError for error
end createSubfolders


private command loadAppAssets
  local tError
  local tRenameAnswerDialog = "false"
  local tRenameAskDialog = "false"
  local tStackFiles, tLoaded, i

  # "registered components.ui"
  if tError is empty then
    put the stackFiles of stack kAppStackName into tStackFiles
    if tStackFiles is not empty then put cr after tStackFiles

    local tKey

    repeat for each key tKey in sAppA["registered components"]["ui"]
      split tKey by kNestedKeysDelimiter

      repeat with i = 1 to the number of elements of sAppA[tKey]
        put sAppA[tKey][i]["name"] & "," & \
              sAppA[tKey][i]["filename"] & cr after tStackFiles

        if sAppA[tKey][i]["autoload"] then
          put there is a stack sAppA[tKey][i]["filename"] into tLoaded
        end if

        # If app uses custom Ask/Answer dialogs then rename LiveCode ones
        if sAppA[tKey][i]["name"] is "Answer Dialog" then
          put there is a stack "Answer Dialog" into tRenameAnswerDialog
        end if
        if sAppA[tKey][i]["name"] is "Ask Dialog" then
          put there is a stack "Ask Dialog" into tRenameAskDialog
        end if
      end repeat
    end repeat
  end if

  # helper ui stacks
  if tError is empty then
    local j

    repeat with i = 1 to the number of elements of sAppA["helpers"]
      repeat with j = 1 to the number of elements of sAppA["helpers"][i]["ui"]
        put sAppA["helpers"][i]["ui"][j]["name"] & "," & sAppA["helpers"][i]["ui"][j]["filename"] & cr after tStackFiles
        if sAppA["helpers"][i]["ui"][j]["autoload"] then
          put there is a stack sAppA["helpers"][i]["ui"][j]["filename"] into tLoaded
        end if
      end repeat
    end repeat

    delete the last char of tStackFiles
    set the stackFiles of stack kAppStackName to tStackFiles
  end if

  # libraries, frontscripts, backscripts
  if tError is empty then
    repeat with i = 1 to the number of elements of sAppA["helpers"]
      # Note that behaviors were already loaded
      loadMessagePathAssets sAppA["helpers"][i]
      put the result into tError

      if tError is not empty then exit repeat
    end repeat

  end if

  if tError is empty then
    loadMessagePathAssets sAppA
    put the result into tError
  end if

  if tError is empty then
    if tRenameAnswerDialog then
      if the environment is "development" then
        set the name of stack "Answer Dialog" to "Answer Dialog (LiveCode)"
      else
        delete stack "Answer Dialog"
      end if
    end if

    if tRenameAskDialog then
      if the environment is "development" then
        set the name of stack "Ask Dialog" to "Ask Dialog (LiveCode)"
      else
        delete stack "Ask Dialog"
      end if
    end if
  end if

  # Now that all helper files have been loaded
  # load registered components.files files
  if tError is empty then
    repeat for each key tKey in sAppA["registered components"]["files"]
      _loadRegisteredKeyFiles tKey
      put the result into tError

      if tError is not empty then exit repeat
    end repeat
  end if

  return tError
end loadAppAssets


/**
Summary: Sends message to helpers that need to process a registered key.

Description:
Dispatches the `loadRegisteredKeyFile` message to the stack specified by the helper
in the `register component` > `callback stack` setting. The message allows the helper
to process the file in some way. For example, if the helper works with yaml files
then the helper can read the yaml files when this message is sent.

The helper can add data to the internal array by marking the parameter as being passed
by reference in the handler definition.

Returns: error
*/
private command _loadRegisteredKeyFiles pKey
  local tError, tCallbackStack, i

  put sAppA["registered components"]["files"][pKey]["callback stackfile"] into tCallbackStack

  if tCallbackStack is not empty then
    split pKey by kNestedKeysDelimiter

    repeat with i = 1 to the number of elements of sAppA[pKey]
      dispatch "loadRegisteredKeyFile" to stack tCallbackStack with sAppA[pKey][i]
      put the result into tError

      if tError is not empty then exit repeat
    end repeat
  end if

  return tError for error
end _loadRegisteredKeyFiles


command levureReloadRegisteredKey pKey
  local tError

  set the wholematches to true

  if pKey is among the keys of sAppA["registered components"]["files"] then
    _loadRegisteredKeyFiles pKey
    put the result into tError
  end if

  return tError for error
end levureReloadRegisteredKey


private command loadAllBehaviorsIntoMemory
  local tHelperA, tBehaviorA, tStack

  repeat for each element tHelperA in sAppA["helpers"]
    loadBehaviorsIntoMemory tHelperA
  end repeat
  loadBehaviorsIntoMemory sAppA

  # Now that all behaviors are in memory send a message to let each behavior know
  # it has been loaded. This allows a behavior to set its own behavior without
  # needing to worry about the loading order.
  repeat for each element tBehaviorA in sAppA["behaviors"]
    put tBehaviorA["filename"] into tStack
    dispatch "LoadBehavior" to stack tStack

    # for packaged apps
    repeat for each line tStack in the substacks of stack tBehaviorA["filename"]
      dispatch "LoadBehavior" to stack tStack
    end repeat
  end repeat

  repeat for each element tHelperA in sAppA["helpers"]
    repeat for each element tBehaviorA in tHelperA["behaviors"]
      put tBehaviorA["filename"] into tStack
      dispatch "LoadBehavior" to stack tStack

      # for packaged apps
      repeat for each line tStack in the substacks of stack tBehaviorA["filename"]
        dispatch "LoadBehavior" to stack tStack
      end repeat
    end repeat
  end repeat
end loadAllBehaviorsIntoMemory


private command loadBehaviorsIntoMemory pArrayA
  local tFileIsLoaded

  repeat with i = 1 to the number of elements of pArrayA["behaviors"]
    put there is a stack pArrayA["behaviors"][i]["filename"] into tFileIsLoaded
  end repeat
end loadBehaviorsIntoMemory


private command loadMessagePathAssets pArrayA
  local tError, i, j
  local tStacksA, tStack, tIsLoaded

  try
    # Note: tStack will contain the name of the last stack that this handler
    #       tried to load. If an error occurs then include tStack in the error report.
    repeat with i = 1 to the number of elements of pArrayA["libraries"]
      put pArrayA["libraries"][i]["filename"] into tStack

      if pArrayA["libraries"][i]["autoload"] is not false then
        start using stack tStack
      else
        # Try to access property so that error is thrown if it can't be found
        put the name of stack tStack into tIsLoaded
      end if
      # for packaged apps
      put the uStacksToLoad of stack tStack into tStacksA
      repeat with j = 1 to the number of elements of tStacksA
        if tStacksA[j]["autoload"] is not false then
          put tStacksA[j]["name"] into tStack
          start using stack tStack
        end if
      end repeat
    end repeat

    repeat with i = 1 to the number of elements of pArrayA["backscripts"]
      put pArrayA["backscripts"][i]["filename"] into tStack

      if pArrayA["backscripts"][i]["autoload"] is not false then
        insert script of stack tStack into back
      else
        # Try to access property so that error is thrown if it can't be found
        put the name of stack tStack into tIsLoaded
      end if
      # for packaged apps
      put the uStacksToLoad of stack tStack into tStacksA
      repeat with j = 1 to the number of elements of tStacksA
        if tStacksA[j]["autoload"] is not false then
          put tStacksA[j]["name"] into tStack
          insert script of stack tStack into back
        end if
      end repeat
    end repeat

    repeat with i = 1 to the number of elements of pArrayA["frontscripts"]
      put pArrayA["frontscripts"][i]["filename"] into tStack

      if pArrayA["frontscripts"][i]["autoload"] is not false then
        insert script of stack tStack into front
      else
        # Try to access property so that error is thrown if it can't be found
        put the name of stack tStack into tIsLoaded
      end if
      # for packaged apps
      put the uStacksToLoad of stack tStack into tStacksA
      repeat with j = 1 to the number of elements of tStacksA
        if tStacksA[j]["autoload"] is not false then
          put tStacksA[j]["name"] into tStack
          insert script of stack tStack into front
        end if
      end repeat
    end repeat
  catch e
    put "error loading stack" & quote & tStack & quote & cr & e into tError
  end try

  return tError for error
end loadMessagePathAssets


private command loadExtensions pArrayA
  local tError
  local tExtA, tTargetPlatform

  put targetPlatform() into tTargetPlatform

  repeat for each element tExtA in pArrayA["extensions"]
    if tExtA["engine version"] is not empty and not _useFileWithThisEngine(tExtA["engine version"]) then next repeat
    if tExtA["platform"] is not empty and tTargetPlatform is not among the items of tExtA["platform"] then next repeat

    if tExtA["resource folder"] is not empty then
      load extension from file tExtA["filename"] with resource path tExtA["resource folder"]
    else
      load extension from file tExtA["filename"]
    end if
    if the result is not empty and the result is not "module already loaded" then
      put the result & ":" && tExtA["filename"] & cr after tError
    end if
  end repeat

  delete the last char of tError

  return tError for error
end loadExtensions


/**
Summary: Builds extensions configured in the app.yml file.

Parameters:
pOnlyBuildMissing: Pass in true to only build extensions which don't already exist.

Description:
If the app.yml file includes references to the source code files (*.lcb) for extensions then
this command will compile the source code and update the .lcm file for the extension.

This command can be useful if you are running the application for the first time on a system
that doesn't have compiled versions of the extensions.

Example:
levureBuildExtensions

Returns: Error message
*/
command levureBuildExtensions pOnlyBuildMissing
  local tError

  if tError is empty then
    buildExtensions sAppA["extensions"], pOnlyBuildMissing
    put the result into tError
  end if

  if tError is empty then
    local tHelper

    repeat for each element tHelper in sAppA["helpers"]
      if tHelper["extensions"] is an array then
        buildExtensions tHelper["extensions"], pOnlyBuildMissing
        put the result into tError

        if tError is not empty then
          exit repeat
        end if
      end if
    end repeat
  end if

  return tError for error
end levureBuildExtensions


private command buildExtensions pArrayA, pOnlyBuildMissing
  local tError, i
  local tNewExtensionFile, tTempFolder

  put the temporary folder & "/_buildLevureExtension_" & the milliseconds into tTempFolder

  repeat with i = 1 to the number of elements of pArrayA
    if pOnlyBuildMissing and there is a file pArrayA[i]["filename"] then next repeat

    local tFilesA
    put empty into tFilesA
    if pArrayA[i]["source"] is an array then
      repeat with j = 1 to the number of elements of pArrayA[i]["source"]
        if there is a file pArrayA[i]["source"][j] then
          put pArrayA[i]["source"][j] into tFilesA[j]
        end if
      end repeat
    else if there is a file pArrayA[i]["source"] then
      put pArrayA[i]["source"] into tFilesA[1]
    end if

    if item 2 of extents(tFilesA) is the number of elements in tFilesA then
      create folder tTempFolder
      put the result into tError

      -- build in temp folder
      if tError is empty then
        buildExtension tFilesA, tTempFolder
        put the result into tError
      end if

      -- replace existing file with new file
      if tError is empty then
        delete file pArrayA[i]["filename"]
        rename file (tTempFolder & "/module.lcm") to pArrayA[i]["filename"]
      end if

      revDeleteFolder tTempFolder
      if tError is empty then # don't overwrite existing error
        put the result into tError
      end if

      if tError is not empty then exit repeat
    end if
  end repeat

  return tError for error
end buildExtensions


private command buildExtension pFilesA, pOutputFolder
  local tCmd

  # Path to compiler
  if the platform is "win32" then
    put shellFormat(revIDESpecialFolderPath("Toolchain") & "/lc-compile.exe") into tCmd
  else
    put shellFormat(revIDESpecialFolderPath("Toolchain") & "/lc-compile") into tCmd
  end if

  # The folder to put the .lci file
  put shellFormat(pOutputFolder, "modulepath") after tCmd

  # The built-in module path
  put shellFormat(revIDESpecialFolderPath("Toolchain") & "/modules/lci", "modulepath") after tCmd

  # Installed module path
  put shellFormat(revIDESpecialFolderPath("user extensions") & "/interface", "modulepath") after tCmd

  # Look in folder of pFilesA[1] as well as 'lci' subdirectory of pFilesA[1] folder.
  set the itemDelimiter to "/"
  put shellFormat(item 1 to -2 of pFilesA[1], "modulepath") after tCmd
  put shellFormat(item 1 to -2 of pFilesA[1] & "/lci", "modulepath") after tCmd

  # The manifest target
  put shellFormat(pOutputFolder & "/manifest.xml", "manifest") after tCmd

  # The output
  put shellFormat(pOutputFolder & "/module.lcm", "output") after tCmd

  # Target the .lcb file
  repeat with i = the number of elements of pFilesA down to 1
    put shellFormat(pFilesA[i]) after tCmd
  end repeat

  local tHideConsoleWindows
  put the hideConsoleWindows into tHideConsoleWindows
  set the hideConsoleWindows to true

  local tShellOutput, tShellResult
  put shell(tCmd) into tShellOutput
  put the result into tShellResult

  set the hideConsoleWindows to tHideConsoleWindows

  if tShellResult is not 0 then
    return "failed to compile module:" && tShellOutput for error
  end if

  if there is not a file (pOutputFolder & "/module.lcm") then
    return "failed to compile module" for error
  end if

  return empty for value
end buildExtension


private function shellFormat pArg, pSwitch
  local tOutput

  if pSwitch is not empty then
    put "--" & pSwitch & " " into tOutput
  end if

  return tOutput & quote & pArg & quote & " "
end shellFormat


private command resolveHelperAssets pBuildProfile
  local tError, tConfigA, i
  local tExternalPackagesInMemory

  put levureExternalsLoadedInMemory() into tExternalPackagesInMemory

  repeat with i = 1 to the number of elements of sAppA["helpers"]
    resolveHelperFolderAssets pBuildProfile, sAppA["helpers"][i], tExternalPackagesInMemory
    put the result into tError

    if tError is not empty then exit repeat
  end repeat

  # If macos and not in development then need to point to the MacOS folder and not the Resources/_MacOS folder
  if the platform is "macos" and the environment is not "development" then
    replace "/Resources/_MacOS/" with "/MacOS/" in sAppA["externals to load"]
  end if

  return tError for error
end resolveHelperAssets


// For packager
function __useLevureFileWithThisEngine pVersionRange
  return _useFileWithThisEngine(pVersionRange)
end __useLevureFileWithThisEngine


private function _useFileWithThisEngine pVersionRange
  local tChar, tVersion, tOperator, tEngineVersion

  repeat for each char tChar in pVersionRange
    if tChar is among the chars of "<=>" then
      put tChar after tOperator
    else
      put tChar after tVersion
    end if
  end repeat

  # FYI: This is a very limited major/minor comparison
  set the itemDelimiter to "."
  put item 1 to 2 of the version into tEngineVersion

  switch tOperator
    case "<"
      return tVersion < tEngineVersion

    case ">"
      return tVersion > tEngineVersion

    case "<="
        return tVersion <= tEngineVersion

    case ">="
      return tVersion >= tEngineVersion

    default
      return false
  end switch
end _useFileWithThisEngine


private command resolveHelperFolderAssets pBuildProfile, @xHelperA, pExternalPackagesInMemory
  local tError
  local tConfigA

  put xHelperA into tConfigA

  if tError is empty then
    local tPlatform, tTargetPlatform

    # stack files
    repeat with j = 1 to the number of elements of tConfigA["ui"]
      put xHelperA["filename"] & "/" & normalizeRelativeFilename(tConfigA["ui"][j]["filename"]) into tConfigA["ui"][j]["filename"]
      put ensureStackNameIsPresent(tConfigA["ui"][j]) into tConfigA["ui"][j]
    end repeat

    put targetPlatform() into tTargetPlatform

    set the wholematches to true

    # externals
    repeat for each key tPlatform in tConfigA["externals"]
      repeat with j = 1 to the number of elements of tConfigA["externals"][tPlatform]
        put xHelperA["filename"] & "/" & normalizeRelativeFilename(tConfigA["externals"][tPlatform][j]["filename"]) into \
                tConfigA["externals"][tPlatform][j]["filename"]

        if tConfigA["externals"][tPlatform][j]["engine version"] is not empty and not _useFileWithThisEngine(tConfigA["externals"][tPlatform][j]["engine version"]) then
          next repeat
        end if

        if tPlatform is tTargetPlatform and tConfigA["externals"][tTargetPlatform][j]["name"] is not empty \
              and tConfigA["externals"][tTargetPlatform][j]["name"] is not among the lines of pExternalPackagesInMemory then
          put tConfigA["externals"][tTargetPlatform][j]["filename"] into \
                line (the number of lines of sAppA["externals to load"] + 1) of sAppA["externals to load"]
          put tConfigA["externals"][tTargetPlatform][j]["name"] into \
                line (the number of lines of sAppA["externals packages to verify"] + 1) of sAppA["externals packages to verify"]
        end if
      end repeat
    end repeat

    # extensions
    repeat with j = 1 to the number of elements of tConfigA["extensions"]
      put xHelperA["filename"] & "/" & normalizeRelativeFilename(tConfigA["extensions"][j]["filename"]) into \
            tConfigA["extensions"][j]["filename"]

      if tConfigA["extensions"][j]["resource folder"] is not empty then
        put xHelperA["filename"] & "/" & normalizeRelativeFilename(tConfigA["extensions"][j]["resource folder"]) into \
              tConfigA["extensions"][j]["resource folder"]
      end if

      if tConfigA["extensions"][j]["source"] is not empty then
        if tConfigA["extensions"][j]["source"] is an array then
          repeat with k = 1 to the number of elements of tConfigA["extensions"][j]["source"]
            put resolveRelativeFilenameReference(tConfigA["extensions"][j]["source"][k], xHelperA["filename"]) into tConfigA["extensions"][j]["source"][k]
          end repeat
        else
          put resolveRelativeFilenameReference(tConfigA["extensions"][j]["source"], xHelperA["filename"]) into tConfigA["extensions"][j]["source"]
        end if
      end if
    end repeat

    # behaviors, libraries, frontscripts, backscripts
    repeat with j = 1 to the number of elements of tConfigA["behaviors"]
      put xHelperA["filename"] & "/" & normalizeRelativeFilename(tConfigA["behaviors"][j]["filename"]) into \
            tConfigA["behaviors"][j]["filename"]
    end repeat

    repeat with j = 1 to the number of elements of tConfigA["libraries"]
      put xHelperA["filename"] & "/" & normalizeRelativeFilename(tConfigA["libraries"][j]["filename"]) into \
            tConfigA["libraries"][j]["filename"]
    end repeat

    repeat with j = 1 to the number of elements of tConfigA["backscripts"]
      put xHelperA["filename"] & "/" & normalizeRelativeFilename(tConfigA["backscripts"][j]["filename"]) into \
            tConfigA["backscripts"][j]["filename"]
    end repeat

    repeat with j = 1 to the number of elements of tConfigA["frontscripts"]
      put xHelperA["filename"] & "/" & normalizeRelativeFilename(tConfigA["frontscripts"][j]["filename"]) into \
            tConfigA["frontscripts"][j]["filename"]
    end repeat
  end if

  if tError is empty then
    put tConfigA into xHelperA
  end if

  return tError for error
end resolveHelperFolderAssets


private command loadExternals pFilenames
  local tError

  if pFilenames is empty then return empty for value

  if there is a stack kApplicationExternals then
    delete stack kApplicationExternals
  end if

  reset the templatestack
  set the destroyWindow of the templatestack to true
  set the destroyStack of the templatestack to true
  set the visible of the templatestack to false
  set the style of the templatestack to "palette"

  set the externals of the templatestack to pFilenames

  local msgsAreLocked
  put the lockMessages into msgsAreLocked
  lock messages
  create stack kApplicationExternals
  reset the templatestack

  go stack kApplicationExternals
  start using stack kApplicationExternals
  set the lockMessages to msgsAreLocked

  if tError is empty then
    local tExternalPackagesInMemory

    put levureExternalsLoadedInMemory() into tExternalPackagesInMemory
    repeat for each line tExternalPackageName in sAppA["externals packages to verify"]
      if tExternalPackageName is not among the lines of tExternalPackagesInMemory then
        put "unable to load external" && tExternalPackageName & cr after tError
      end if
    end repeat
    delete the last char of tError
  end if

  return tError for error
end loadExternals


## deleting externals stack when app aborts during initialization routines
## was causing crashes on OS 10.7.3 (glxapp framework). Stack is only purged when
## developer explicitly calls this handler via glxapp_unloadExternals.
## Note: only enable this if we see similar crashes in 8+
private command unloadExternals --pPurgeFromMemory
  if there is a stack kApplicationExternals then
    stop using stack kApplicationExternals
    --if pPurgeFromMemory then
    delete stack kApplicationExternals
    --else
    --close stack kApplicationExternals
    --end if
  end if
end unloadExternals


private function normalizeRelativeFilename pFilename
  if char 1 of pFilename is "/" then
    delete char 1 of pFilename
  else if char 1 to 2 of pFilename is "./" then
    delete char 1 to 2 of pFilename
  end if
  return pFilename for value
end normalizeRelativeFilename


private function normalizeFolderPath pFilename
  repeat while the last char of pFilename is "/"
    delete the last char of pFilename
  end repeat

  return pFilename
end normalizeFolderPath


/**
Summary: Returns path to the folder where the app.yml file is located.

Example:
put levureAppFolder() into tAppFolder

Returns: Path to file
*/
function levureAppFolder
  return sAppFolder for value
end levureAppFolder


/**
Summary: Returns the path to the folder where the app.yml file is located relative to the location where the standalone stack is located.

Description:
If standalone.livecode and app.yml are in the same directory then this function returns empty.

Example:
put levureRelativeAppFolderPath() into tRelativePath

Returns: Relative path to folder
*/
function levureRelativeAppFolderPath
  local tPath

  put sAppFolder into tPath
  replace levureStandaloneFolder() with empty in tPath
  if char 1 of tPath is "/" then delete char 1 of tPath
  return tPath
end levureRelativeAppFolderPath


/**
Summary: Returns the short name of the `standalone.livecode` stack.

Example:
put levureStandaloneStackName() into tStackName

Returns: Stack short name
*/
function levureStandaloneStackName
  return the short name of me
end levureStandaloneStackName


/**
Summary: Returns the path to the folder the application standalone is in.

Description:
On macOS the path points to the folder where the application bundle is located,
not the actual executable file inside of the application bundle.

If called in the IDE this returns the path where the standalone.livecode stack file is located.

Example:
put levureStandaloneFolder() into tAppFolder

Returns: Path to folder
*/
function levureStandaloneFolder
  local tFolder

  put the effective filename of me into tFolder
  set the itemDelimiter to "/"
  delete the last item of tFolder
  if the environment is not "development" and the platform is "macos" then
    if tFolder contains ".app/Contents/MacOS" then
      delete item -3 to -1 of tFolder
    end if
  end if
  return tFolder for value
end levureStandaloneFolder


/**
Summary: Returns the path of the application standalone.

Example:
put levureStandaloneFilename() into tAppFilename

Returns: Path to file
*/
function levureStandaloneFilename
  local tFilename

  if the environment is "development" then
    put the cRevStandaloneSettings["name"] of me into tFilename
    switch the platform
      case "macos"
        put ".app" after tFilename
        break
      case "win32"
        put ".exe" after tFilename
        break
      case "linux"
      default
        break
    end switch
  else
    set the itemDelimiter to "/"
    switch the platform
      case "macos"
        put specialFolderPath("engine") into tFilename
        delete item -2 to -1 of tFilename # /Contents/MacOS
        put the last item of tFilename into tFilename
        break
      case "win32"
      case "linux"
      default
        put the last item of the address into tFilename
        break
    end switch
  end if
  return levureStandaloneFolder() & "/" & tFilename
end levureStandaloneFilename


/**
Summary: Returns the folder where the packager will place builds.

Example:
put levureBuildFolder() into tBuildFolder
launch document tBuildFolder & "/build.log"

Returns: Path to folder
*/
function levureBuildFolder
  return resolveFilenameReference(sAppA["build folder"], levureAppFolder())
end levureBuildFolder


/**
Summary: Returns the path to the folder where the levureFramework.livecodescript file is located.

Example:
put the levureFrameworkFolder() into tFolder

Returns: Path to folder
*/
function levureFrameworkFolder
  local tFolder

  put levureFrameworkFilename() into tFolder
  set the itemDelimiter to "/"
  delete the last item of tFolder
  return tFolder for value
end levureFrameworkFolder


/**
Summary: Returns the path to the levureFramework.livecodescript file.

Example:
put the levureFrameworkFilename() into tFile

Returns: Path to stack file
*/
function levureFrameworkFilename
  return the filename of (the long id this me)
end levureFrameworkFilename


/**
Summary: Expand "filenames" for every asset except Helpers
*/
private command expandPackagedAppArrayFilenames @xAppA, pRootFolder
  local tAssets, tKeys, tKey

  put "libraries,backscripts,frontscripts,behaviors,extensions" into tAssets
  put the keys of sAppA["registered components"]["ui"] into tKeys
  if tKeys is not empty then
    replace cr with "," in tKeys
    put tKeys into item (the number of items of tAssets + 1) of tAssets
  end if
  put the keys of sAppA["registered components"]["files"] into tKeys
  if tKeys is not empty then
    replace cr with "," in tKeys
    put tKeys into item (the number of items of tAssets + 1) of tAssets
  end if

  repeat for each item tKey in tAssets
    split tKey by kNestedKeysDelimiter

    repeat with i = 1 to the number of elements of xAppA[tKey]
      replaceVariablesInPaths xAppA[tKey][i]
      put resolveFilenameReference(xAppA[tKey][i]["filename"], pRootFolder) into xAppA[tKey][i]["filename"]
    end repeat
  end repeat
end expandPackagedAppArrayFilenames


private function expandMessagePathAssetsFileReferenceArray pBuildProfile, pFilesA, pRootFolder, pExtensions
  local tFilesA, i, j, tPropsA, tProp

  replaceVariablesInPaths pFilesA

  repeat with i = 1 to the number of elements of pFilesA
    put empty into tPropsA

    if pFilesA[i]["folder"] is not empty then
      put resolveFilenameReference(pFilesA[i]["folder"], pRootFolder) into pFilesA[i]["folder"]

      repeat for each item tProp in "distribute,build profiles filter,encrypt,autoload"
        if tProp is among the keys of pFilesA[i] then
          put pFilesA[i][tProp] into tPropsA[tProp]
        end if
      end repeat

      # expand the folder listing. Assume every file is a file to load.
      addFolderToFilesArray pBuildProfile, pFilesA[i]["build profiles filter"], pFilesA[i]["folder"], tFilesA, tPropsA, pExtensions

      put the number of elements of tFilesA into j

    else if pFilesA[i]["filename"] is not empty then
      put resolveFilenameReference(pFilesA[i]["filename"], pRootFolder) \
            into pFilesA[i]["filename"]

      if _isFileIncludedInBuildProfile(pBuildProfile, pFilesA[i]["build profiles filter"], pFilesA[i]["filename"]) \
            and isFilenameUniqueInFilesArray(pFilesA[i]["filename"], tFilesA) then
        add 1 to j
        put pFilesA[i]["filename"] into tFilesA[j]["filename"]

        if "source" is among the keys of pFilesA[i] then
          if pFilesA[i]["source"] is an array then
            repeat with k = 1 to the number of elements of pFilesA[i]["source"]
              put resolveRelativeFilenameReference(pFilesA[i]["source"][k], pRootFolder) into tFilesA[j]["source"][k]
            end repeat
          else
            put resolveFilenameReference(pFilesA[i]["source"], pRootFolder) \
                  into tFilesA[j]["source"]
          end if
        end if
        repeat for each item tProp in "distribute,build profiles filter,encrypt,autoload"
          if tProp is among the keys of pFilesA[i] then
            put pFilesA[i][tProp] into tFilesA[j][tProp]
          end if
        end repeat
      end if
    end if
  end repeat

  return tFilesA
end expandMessagePathAssetsFileReferenceArray


private function expandFileAssetsFileReferenceArray pBuildProfile, pFilesA, pRootFolder
  local tFilesA, i, j, tPropsA, tProp

  replaceVariablesInPaths pFilesA

  repeat with i = 1 to the number of elements of pFilesA
    put empty into tPropsA

    if pFilesA[i]["folder"] is not empty then
      put resolveFilenameReference(pFilesA[i]["folder"], pRootFolder) into pFilesA[i]["folder"]

      repeat for each key tProp in pFilesA[i]
        if tProp is not "folder" then
          put pFilesA[i][tProp] into tPropsA[tProp]
        end if
      end repeat

      # expand the folder listing. Assume every file is a file to load.
      addFolderToFilesArray pBuildProfile, pFilesA[i]["build profiles filter"], pFilesA[i]["folder"], tFilesA, tPropsA

      put the number of elements of tFilesA into j

    else if pFilesA[i]["filename"] is not empty then
      put resolveFilenameReference(pFilesA[i]["filename"], pRootFolder) \
            into pFilesA[i]["filename"]

      if _isFileIncludedInBuildProfile(pBuildProfile, pFilesA[i]["build profiles filter"], pFilesA[i]["filename"]) \
            and isFilenameUniqueInFilesArray(pFilesA[i]["filename"], tFilesA) then
        add 1 to j

        # Move over all defined keys (filename will be included)
        repeat for each key tProp in pFilesA[i]
          put pFilesA[i][tProp] into tFilesA[j][tProp]
        end repeat
      end if
    end if
  end repeat

  return tFilesA
end expandFileAssetsFileReferenceArray


private function expandHelperAssetsFileReferenceArray pBuildProfile, pFilesA, pRootFolder
  local tError, tFilesA, tFileA, i, j, tProp

  set the wholematches to true

  replaceVariablesInPaths pFilesA

  repeat with i = 1 to the number of elements of pFilesA
    if pFilesA[i]["folder"] is not empty then
      put resolveFilenameReference(pFilesA[i]["folder"], pRootFolder) into pFilesA[i]["folder"]

      # expand the folder listing. Assume every folder is a helper to load.
      local tFile

      repeat for each line tFile in folderListing(pFilesA[i]["folder"])
        if _isFileIncludedInBuildProfile(pBuildProfile, pFilesA[i]["build profiles filter"], tFile) \
              and isFilenameUniqueInFilesArray(tFile, tFilesA) then
          put empty into tFileA
          put tFile into tFileA["filename"]

          # Merge in helper config information
          loadHelperConfigurationFile tFileA
          put the result into tError

          if tError is empty then
            add 1 to j
            put tFileA into tFilesA[j]
          else
            exit repeat
          end if
        end if
      end repeat
    else if pFilesA[i]["filename"] is not empty then
      put resolveFilenameReference(pFilesA[i]["filename"], pRootFolder) \
            into pFilesA[i]["filename"]

      if _isFileIncludedInBuildProfile(pBuildProfile, pFilesA[i]["build profiles filter"], pFilesA[i]["filename"]) \
            and isFilenameUniqueInFilesArray(pFilesA[i]["filename"], tFilesA) then
        # Merge in helper config information
        loadHelperConfigurationFile pFilesA[i]
        put the result into tError

        if tError is empty then
          add 1 to j
          put pFilesA[i] into tFilesA[j]
        else
          exit repeat
        end if
      end if
    end if

    if tError is not empty then
      exit repeat
    end if
  end repeat

  if tError is not empty then
    return tError for error
  else
    return tFilesA for value
  end if
end expandHelperAssetsFileReferenceArray


/**
Summary: Fill in a helper using the helper.yml file
*/
private command loadHelperConfigurationFile @xHelperA
  local tError, tKeys, tKey, tAlreadyFilledIn, tConfigA

  # When packaged the array will already be filled in.
  put the keys of xHelperA into tKeys
  set the wholematches to true
  repeat for each item tKey in "libraries,backscripts,frontscripts,behaviors,ui,extensions,externals"
    if tKey is among the lines of tKeys then
      put true into tAlreadyFilledIn
      exit repeat
    end if
  end repeat

  if not tAlreadyFilledIn then
    if there is a file (xHelperA["filename"] & "/helper.yml") then
      put yamlFileToArray(xHelperA["filename"] & "/helper.yml") into tConfigA
      put the result into tError
    else
      # Load up any ui stacks
      local tFile, tIsAStack, j

      put 0 into j
      put empty into tConfigA
      set the itemDelimiter to "/"

      repeat for each line tFile in fileListing(xHelperA["filename"])
        put there is a stack tFile into tIsAStack
        if tIsAStack then
          add 1 to j

          put the short name of stack tFile into tConfigA["ui"][j]["name"]
          put the last item of tFile into tConfigA["ui"][j]["filename"]
          delete stack tFile
        end if
      end repeat
    end if
  else
    put xHelperA into tConfigA
  end if

  # Move properties defined in app.yml into array created from helper.yml
  put xHelperA["filename"] into tConfigA["filename"]
  put xHelperA["encrypt"] is not false into tConfigA["encrypt"]
  put xHelperA["build profiles filter"] into tConfigA["build profiles filter"]

  put tConfigA into xHelperA

  return tError for error
end loadHelperConfigurationFile


private function expandUIAssetsFileReferenceArray pBuildProfile, pFilesA, pRootFolder
  local tFilesA, i, j
  local tProp, tPropsA

  replaceVariablesInPaths pFilesA

  repeat with i = 1 to the number of elements of pFilesA
    put empty into tPropsA

    if pFilesA[i]["folder"] is not empty then
      put resolveFilenameReference(pFilesA[i]["folder"], pRootFolder) into pFilesA[i]["folder"]

      # expand the folder listing. Assume every folder is a ui to load.
      local tFolder

      repeat for each item tProp in "distribute,build profiles filter,encrypt,autoload"
        if tProp is among the keys of pFilesA[i] then
          put pFilesA[i][tProp] into tPropsA[tProp]
        end if
      end repeat

      repeat for each line tFolder in folderListing(pFilesA[i]["folder"])
        addUIStacksToFilesArray pBuildProfile, pFilesA[i]["build profiles filter"], tFolder, tFilesA, tPropsA
      end repeat
      put the number of elements of tFilesA into j

    else if pFilesA[i]["filename"] is not empty then
      put resolveFilenameReference(pFilesA[i]["filename"], pRootFolder) \
            into pFilesA[i]["filename"]

      # If filename points to a folder then load up the entire folder
      # Otherwise the target is a single file within the ui folder. Probably using different encryption setting.
      if there is a folder pFilesA[i]["filename"] then
        repeat for each item tProp in "distribute,build profiles filter,encrypt,autoload"
          if tProp is among the keys of pFilesA[i] then
            put pFilesA[i][tProp] into tPropsA[tProp]
          end if
        end repeat
        addUIStacksToFilesArray pBuildProfile, pFilesA[i]["build profiles filter"], pFilesA[i]["filename"], tFilesA, tPropsA
        put the number of elements of tFilesA into j
      else
        # points directly to a stack file
        put ensureStackNameIsPresent(pFilesA[i]) into pFilesA[i]

        if pFilesA[i]["name"] is not empty \
              and _isFileIncludedInBuildProfile(pBuildProfile, pFilesA[i]["build profiles filter"], pFilesA[i]["filename"]) \
              and isFilenameUniqueInFilesArray(pFilesA[i]["filename"], tFilesA) then
          add 1 to j
          put pFilesA[i]["filename"] into tFilesA[j]["filename"]
          put pFilesA[i]["name"] into tFilesA[j]["name"]
          repeat for each item tProp in "distribute,build profiles filter,encrypt,autoload"
            if tProp is among the keys of pFilesA[i] then
              put pFilesA[i][tProp] into tFilesA[j][tProp]
            end if
          end repeat
        end if
      end if
    end if
  end repeat

  return tFilesA
end expandUIAssetsFileReferenceArray


private command addFolderToFilesArray pBuildProfile, pBuildProfilesFilter, pFolder, @xFilesA, pPropsA, pExtensions
  local tFolder, tFiles, tFile, tProp, i

  put the number of elements of xFilesA into i

  put fileListing(pFolder) into tFiles
  if pExtensions is not empty then
    filter tFiles with regex pattern regExForFileExtensions(pExtensions)
  end if

  repeat for each line tFile in tFiles
    if _isFileIncludedInBuildProfile(pBuildProfile, pBuildProfilesFilter, tFile) \
          and isFilenameUniqueInFilesArray(tFile, xFilesA) then
      add 1 to i
      put tFile into xFilesA[i]["filename"]
      repeat for each key tProp in pPropsA
        put pPropsA[tProp] into xFilesA[i][tProp]
      end repeat
    end if
  end repeat

  repeat for each line tFolder in folderListing(pFolder)
    addFolderToFilesArray pBuildProfile, pBuildProfilesFilter, tFolder, xFilesA, pPropsA, pExtensions
  end repeat

  return empty for value
end addFolderToFilesArray


private command addUIStacksToFilesArray pBuildProfile, pBuildProfilesFilter, pFolder, @xFilesA, pPropsA
  local tError, tFiles, tFile, tFileA, tKey, i

  put the number of elements of xFilesA into i

  put fileListing(pFolder) into tFiles
  filter tFiles with regex pattern regExForFileExtensions(kLiveCodeExtensions)

  repeat for each line tFile in tFiles
    if not _isFileIncludedInBuildProfile(pBuildProfile, pBuildProfilesFilter, tFile) \
          or not isFilenameUniqueInFilesArray(tFile, xFilesA) then
      next repeat
    end if

    put empty into tFileA

    put tFile into tFileA["filename"]
    put ensureStackNameIsPresent(tFileA) into tFileA

    if tFileA["name"] is not empty then
      add 1 to i
      put tFileA into xFilesA[i]
      repeat for each key tKey in pPropsA
        put pPropsA[tKey] into xFilesA[i][tKey]
      end repeat
    end if
  end repeat

  return empty
end addUIStacksToFilesArray


private command replaceVariablesInPaths @pFilesA
  local tUserExtensionsFolder, tFrameworkFolder
  local tKey, i

  put userExtensionsFolder() into tUserExtensionsFolder
  put levureFrameworkFolder() into tFrameworkFolder

  repeat with i = 1 to the number of elements of pFilesA
    repeat for each item tKey in "filename,folder,source"
      if tKey is among the keys of pFilesA[i] then
        if pFilesA[i][tKey] is an array then
          repeat with j = 1 to the number of elements of pFilesA[i][tKey]
            replace "[[USER_EXTENSIONS]]" with tUserExtensionsFolder in pFilesA[i][tKey][j]

            if pFilesA[i][tKey][j] contains "[[FRAMEWORK]]" then
              replace "[[FRAMEWORK]]" with tFrameworkFolder in pFilesA[i][tKey][j]
            end if
          end repeat
        else
          replace "[[USER_EXTENSIONS]]" with tUserExtensionsFolder in pFilesA[i][tKey]

          if pFilesA[i][tKey] contains "[[FRAMEWORK]]" then
            replace "[[FRAMEWORK]]" with tFrameworkFolder in pFilesA[i][tKey]
          end if
        end if
      end if
    end repeat
  end repeat

  return empty for value
end replaceVariablesInPaths


private function userExtensionsFolder
  local tUserExtensionsFolder

  if the environment is "development" then
    put revEnvironmentCustomizationPath() into tUserExtensionsFolder
  else
    try
      put levureTestingRevCustomizationFolder() into tUserExtensionsFolder
    catch e
      # This won't be packaged application
    end try
  end if

  return tUserExtensionsFolder
end userExtensionsFolder


private function isFilenameUniqueInFilesArray pFilename, pFilesA
  local i

  repeat with i = 1 to the number of elements of pFilesA
    if pFilesA[i]["filename"] is pFilename then
      return false
    end if
  end repeat

  return true
end isFilenameUniqueInFilesArray


private function regExForFileExtensions pExtensions
  local tFilter, tExtension

  repeat for each item tExtension in pExtensions
    put ".*\." & tExtension & "$|" after tFilter
  end repeat
  delete the last char of tFilter
  return tFilter
end regExForFileExtensions


private function ensureStackNameIsPresent pFileA
  # Grab stack name in memory if not provided.
  if pFileA["name"] is empty then
    local tStackIsLoaded, msgsAreLocked

    put the lockMessages into msgsAreLocked
    lock messages
    put there is a stack pFileA["filename"] into tStackIsLoaded
    if tStackIsLoaded then
      put the short name of stack pFileA["filename"] into pFileA["name"]
      delete stack pFileA["filename"]
    end if
    set the lockMessages to msgsAreLocked
  end if

  return pFileA
end ensureStackNameIsPresent


private command dontEncryptBinaryStacks @xFilesA
  local i, tStackIsLoaded, msgsAreLocked

  put the lockMessages into msgsAreLocked

  repeat with i = 1 to the number of elements of xFilesA
    lock messages
    put there is a stack xFilesA[i]["filename"] into tStackIsLoaded
    if tStackIsLoaded then
      if not the scriptonly of stack xFilesA[i]["filename"] then
        put false into xFilesA[i]["encrypt"]
      end if
      delete stack xFilesA[i]["filename"]
    end if
  end repeat

  set the lockMessages to msgsAreLocked

  return empty
end dontEncryptBinaryStacks


private function resolveFilenameReference pFilename, pRootFolder
  repeat while the last char of pFilename is "/"
    delete the last char of pFilename
  end repeat

  if isFilenameRelative(pFilename) then
    put normalizeRelativeFilename(pFilename) into pFilename

    if pFilename begins with "../" then
      return resolveRelativeFilenameReference(pFilename, pRootFolder) for value
    else
      return pRootFolder & "/" & pFilename for value
    end if
  else
    return pFilename for value
  end if
end resolveFilenameReference


private function isFilenameRelative pFilename
  set the itemDelimiter to "/"
  -- [[ is for variables
  return not ((the platform is "win32" and item 1 of pFilename contains ":") or pFilename begins with "/" or pFilename begins with "[[")
end isFilenameRelative


private function fileExtension pFilename
  local tExtension

  set the itemdelimiter to "/"
  put the last item of pFilename into tExtension
  set the itemdelimiter to "."
  if the number of items of tExtension > 1 then
    return the last item of tExtension
  else
    return empty
  end if
end fileExtension


private function resolveRelativeFilenameReference pFilename, pRootFolder
  set the itemDelimiter to "/"

  repeat while pFilename begins with "../"
    if pRootFolder is empty then
      return "relative path is too deep for root folder" for error
    else
      delete the last item of pRootFolder
      delete char 1 to 3 of pFilename
    end if
  end repeat

  return pRootFolder & "/" & pFilename for value
end resolveRelativeFilenameReference


private function folderListing pFilename
  local tFolders, tFolder, tFullPathFolders

  put folders(pFilename) into tFolders
  if line 1 of tFolders is ".." then delete line 1 of tFolders

  repeat for each line tFolder in tFolders
    put pFilename & "/" & tFolder & cr after tFullPathFolders
  end repeat
  delete the last char of tFullPathFolders

  return tFullPathFolders for value
end folderListing


private function fileListing pFilename
  local tFiles, tFile, tFullPathFiles

  put files(pFilename) into tFiles

  repeat for each line tFile in tFiles
    put pFilename & "/" & tFile & cr after tFullPathFiles
  end repeat
  delete the last char of tFullPathFiles

  return tFullPathFiles for value
end fileListing


/**
Summary: Returns true if pString passes pFilter
*/
private function _isFileIncludedInBuildProfile pString, pFilter, pTargetFilename
  set the wholematches to true
  if pTargetFilename is among the lines of sAppA["filtered out filenames"] then return false

  if pFilter is empty then return true

  local tFilter
  local tPerformedAPositiveMatchCheck = "false"

  repeat for each item tFilter in pFilter
    if char 1 of tFilter is "!" then
      # Match means false
      if pString is char 2 to -1 of tFilter then
        put pTargetFilename & cr after sAppA["filtered out filenames"]
        return false
      end if
    else
      # Match means true
      if pString is tFilter then
        return true
      else
        put true into tPerformedAPositiveMatchCheck
      end if
    end if
  end repeat

  # If nothing matched but a check for a positive match was performed then
  # return false. Otherwise return true.
  if tPerformedAPositiveMatchCheck then
    put pTargetFilename & cr after sAppA["filtered out filenames"]
    return false
  else
    return true
  end if
end _isFileIncludedInBuildProfile


/**
Summary: Returns a list of externals that are loaded into memory and available in the message path.

Example:
set the wholematches to true
put levureExternalsLoadedInMemory() into tExternals
put "revXML" among the lines of tExternals

Returns: CR delimited list of external package names
*/
function levureExternalsLoadedInMemory
  local tPackage,tPackages,tPackagesA,tStack
  local tStacks,tSubstack,tSubstacks

  put stacksInUse into tStacks
  if the environment is "development" then
    put "home" into line (the number of lines of tStacks + 1) of tStacks
  end if

  repeat for each line tStack in tStacks
    put the externalPackages of stack tStack into tPackages
    repeat for each line tPackage in tPackages
      put empty into tPackagesA[tPackage]
    end repeat

    put substacks of stack tStack into tSubstacks
    repeat for each line tSubstack in tSubstacks
      put the externalPackages of stack tSubstack into tPackages
      repeat for each line tPackage in tPackages
        put empty into tPackagesA[tPackage]
      end repeat
    end repeat
  end repeat

  return keys of tPackagesA
end levureExternalsLoadedInMemory


/**
Summary: Massages `the platform` into a value that Levure expects.
*/
private function targetPlatform
  if the platform is "win32" then
    return "windows"
  else if the platform is "iphone" then
    return "ios"
  else
    return the platform
  end if
end targetPlatform


/**
Summary: Converts a YAML file to an array.

pFilename: Path to YAML file.

Description:
Converts a YAML file to an array. You must use the same spacing throughout the file for indentation.

Note that there are some limitations with regards to YAML that is supported:
1. Comments are not supported.
2. - is not supported

Example:
put yamlFileToArray(tFilename) into tYamlA
put the keys of tYamlA

Returns:
the result: Error message
it: Array
*/
function yamlFileToArray pFilename
  local tError, tYaml

  put readFileContents(pFilename) into tYaml
  put the result into tError

  if tError is empty then
    YAMLToArray textDecode(tYaml, "utf8")
    if the result is empty then
      return it for value
    else
      return "File:" & pFilename & cr & the result for error
    end if
  else
    return tError for error
  end if
end yamlFileToArray


private function readFileContents pFilename
  local tError

  open file pFilename for read
  put the result into tError

  if tError is empty then
    read from file pFilename until eof
    if the result is not "eof" then
      put the result into tError
    end if

    close file pFilename
  end if

  if tError is empty then
    return it for value
  else
    return tError && "(" & pFilename & ")" for error
  end if
end readFileContents


private function _printArray pArray, pDimension, pFullData
  local tKeys, tKey, tText

  if pDimension is empty then put 0 into pDimension

  put the keys of pArray into tKeys
  sort tKeys numeric

  repeat for each line tKey in tKeys
    if pArray[tKey] is an array then
      put _printCharXTimes(space, pDimension * 3) & tKey & cr after tText
      put _printArray(pArray[tKey], pDimension + 1, pFullData) after tText
    else
      if pFullData then
        put _printCharXTimes(space, pDimension * 3) &  tKey & ":" && pArray[tKey] & cr after tText
      else
        put _printCharXTimes(space, pDimension * 3) &  tKey & ":" && line 1 of pArray[tKey] & cr after tText
      end if
    end if
  end repeat

  return tText
end _printArray


private function _printCharXTimes pChar, pTimes
  local tStr

  repeat with i = 1 to pTimes
    put pChar after tStr
  end repeat
  return tStr
end _printCharXTimes


## Monte's YAMLToArray command
constant kMultiLineModeNone = 0
constant kMultiLineModeLiteral = 1
constant kMultiLineModeFolded = 2

command YAMLToArray pYaml
  local tInDocument = true
  local tPath
  local tArray
  local tPathLists
  local tReferences
  local tMultiLineMode
  local tCharNo
  local lineNumber = 0

  put kMultiLineModeNone into tMultiLineMode

  local tMultiLine
  repeat for each line tLine in pYaml
    add 1 to lineNumber

    -- ignore directives
    if tLine begins with "%" then
      next repeat
    end if

    if tLine begins with "---" then
      put true into tInDocument
      next repeat
    end if

    if not tInDocument then
      next repeat
    end if

    if tLine begins with "..." then
      if tMultiLineMode is not kMultiLineModeNone then
        __ClearQuotes tMultiLine
        put tMultiLine into tArray[tPath]
        put kMultiLineModeNone into tMultiLineMode
      end if
      put false into tInDocument
      next repeat
    end if

    local tPathElement, tListItem
    put __PathElement(tLine, tListItem, tPathLists) into tPathElement

    -- comment lines
    put __unquotedCharOffset("#", tLine) into tCharNo
    if tCharNo > 0 then
      delete char tCharNo to -1 of tLine
    end if

    -- remain in multiline until indent is lower
    if tMultiLineMode is not kMultiLineModeNone then
      if tPathElement < the number of elements of tPath + 1 and tLine is not empty then
        __ClearQuotes tMultiLine
        put tMultiLine into tArray[tPath]
        put kMultiLineModeNone into tMultiLineMode
      else
        -- add back any stripped literal indents
        if tPathElement > the number of elements of tPath + 1 then
          repeat for tPathElement - (the number of elements of tPath + 1)
            put "    " before tLine
          end repeat
        end if

        -- empty lines and indented lines are literal even in folded mode
        if tMultiLineMode is kMultiLineModeLiteral then
          if tMultiLine is not empty then
            put return after tMultiLine
          end if
          put tLine after tMultiLine
        else
          if tLine is empty then
            put return after tMultiLine
          else if char 1 of tLine is space or \
                the last line of tMultiLine is empty or \
                the last line of tMultiLine begins with space then
            if tMultiLine is not empty then
              put return after tMultiLine
            end if
            put tLine after tMultiLine
          else
            if tMultiLine is not empty then
              put space after tMultiLine
            end if
            put tLine after tMultiLine
          end if
        end if

        next repeat
      end if
    end if

    -- empty lines
    if tLine is empty then
      next repeat
    end if

    local tElements
    put the number of elements of tPath into tElements
    if tPathLists[tPathElement] and \
          tListItem and \
          tPath[tPathElement] is an integer then
      add 1 to tPath[tPathElement]
      repeat with tIndex = tElements down to tPathElement + 1
        delete variable tPath[tIndex]
        delete variable tPathLists[tIndex]
      end repeat
      add 1 to tPathElement
    else
      if tPathElement < tElements then
        repeat with tIndex = tElements down to tPathElement + 1
          delete variable tPath[tIndex]
          delete variable tPathLists[tIndex]
        end repeat
      else if tPathElement > tElements + 1 then
        return "Line:"&lineNumber & cr & quote & tLine & quote & cr & "Invalid YAML - line indented too far" for error
      end if

      put tListItem into tPathLists[tPathElement]
      if tListItem then
        put 1 into tPath[tPathElement]
        add 1 to tPathElement
      end if
    end if

    -- handle line with just list marker
    if the number of words of tLine is 0 then
      next repeat
    end if

    -- map
    if not (word 1 of tLine begins with "{") and not (word 1 of tLine begins with "[") then
      put __unquotedCharOffset(":", tLine) into tCharNo
    end if
    if tCharNo > 0 then
      local tKey

      put char 1 to tCharNo-1 of tLine into tKey
      put char tCharNo+1 to -1 of tLine into tLine
      __ClearQuotes tKey

      if tKey is empty then
        return "Line:" & lineNumber & cr & "Invalid YAML - key is empty" for error
      end if

      put false into tPathLists[tPathElement]
      put tKey into tPath[tPathElement]

      -- clean whitespace
      put word 1 to -1 of tLine into tLine

      -- referenced element
      local tRef
      if tLine begins with "&" then
        put word 1 of tLine into tRef
        put "*" into char 1 of tRef
        delete word 1 of tLine
      else
        put empty into tRef
      end if

      -- check for referenced element
      if tLine is not empty and word 1 of tLine is among the keys of tReferences then
        put tArray[tReferences[word 1 of tLine]] into tLine
      end if

      -- store referenced element
      if tRef is not empty then
        put tPath into tReferences[tRef]
      end if

      -- ignore explicit typing
      if tLine begins with "!" then
        delete word 1 of tLine
      end if

      if tLine is "|" then
        put kMultiLineModeLiteral into tMultiLineMode
        put empty into tMultiLine
      else if tLine is ">" then
        put kMultiLineModeFolded into tMultiLineMode
        put empty into tMultiLine
      else
        __AddToArray tLine, tArray[tPath]
      end if
    else
      __AddToArray tLine, tArray[tPath]
    end if
  end repeat

  if tMultiLineMode is not kMultiLineModeNone then
    __ClearQuotes tMultiLine
    put tMultiLine into tArray[tPath]
  end if

  return tArray for value
end YAMLToArray


private function __unquotedCharOffset pChar, pLine
  local tOffset = 0
  local tChar
  local tInQuote = "false"

  repeat with tOffset = 1 to the number of chars of pLine
    put char tOffset of pLine into tChar

    if tInQuote and tChar is "\" and char tOffset+1 of pLine is quote then
      add 1 to tOffset
      next repeat
    end if

    if tChar is quote then
      put not tInQuote into tInQuote
    else if tChar is pChar and not tInQuote then
      return tOffset
    end if
  end repeat

  return 0
end __unquotedCharOffset


private function _splitYAMLStringAtDelimiter pString, pDelimiter
  local tBuffer, tDataA, tIndex
  local tOffset = 0
  local tEscapeChar = "'"
  local tQuoteChars, tQuoteChar, tChar
  local tInQuote = "false"

  put "'" into tQuoteChar
  put quote & ",'" into tQuoteChars

  if pDelimiter is empty then put "," into pDelimiter
  # name: started_at, type: timestamp, default: "strftime('%s','now')"
  repeat with tOffset = 1 to the number of chars of pString
    put char tOffset of pString into tChar

    if tInQuote and tChar is tEscapeChar and char tOffset+1 of pString is tQuoteChar then
      add 1 to tOffset
      put tQuoteChar after tBuffer
      next repeat
    end if

    if tInQuote then
      if tChar is tQuoteChar then
        put false into tInQuote
      end if
    else
      put tChar is among the items of tQuoteChars into tInQuote
      if tInQuote then
        put tChar into tQuoteChar
        if tChar is quote then
          put "\" into tEscapeChar
        else
          put "'" into tEscapeChar
        end if
      end if
    end if

    if not tInQuote then
      if tChar is pDelimiter then
        add 1 to tIndex
        put tBuffer into tDataA[tIndex]
        put empty into tBuffer
      else
        put tChar after tBuffer
      end if
    else
      put tChar after tBuffer
    end if
  end repeat

  if tBuffer is not empty then
    add 1 to tIndex
    put tBuffer into tDataA[tIndex]
    put empty into tBuffer
  end if

  return tDataA
end _splitYAMLStringAtDelimiter


private command __AddToArray pLine, @xElement
  local tElements, tKey
  -- trim whitespace
  if pLine is not an array then
    put word 1 to -1 of pLine into pLine
    if pLine begins with "[" and pLine ends with "]" then
      -- support single line flow sequence
      put char 2 to -2 of pLine into pLine
      put _splitYAMLStringAtDelimiter(pLine) into pLine
      put the number of elements of pLine into tElements
      repeat with tIndex = 1 to tElements
        put word 1 to -1 of pLine[tIndex] into pLine[tIndex]
        __ClearQuotes pLine[tIndex]
      end repeat
    else if pLine begins with "{" and pLine ends with "}" then
      -- support single line flow sequence
      put char 2 to -2 of pLine into pLine
      put _splitYAMLStringAtDelimiter(pLine) into pLine
      set the itemDelimiter to ":"

      local tLine
      put the number of elements of pLine into tElements
      repeat with tIndex = 1 to tElements
        put word 1 to -1 of pLine[tIndex] into pLine[tIndex]

        local tValue
        put word 1 to -1 of item 1 of pLine[tIndex] into tKey
        __ClearQuotes tKey
        put word 1 to -1 of item 2 to -1 of pLine[tIndex] into tValue
        __ClearQuotes tValue

        put tValue into tLine[tKey]
      end repeat
      put tLine into pLine
    else
      __ClearQuotes pLine
    end if
  end if

  put pLine into xElement
end __AddToArray

private command __ClearQuotes @xLine
  if xLine begins with quote and xLine ends with quote then
    put format( char 2 to -2 of xLine) into xLine
  else if xLine begins with "'" and xLine ends with "'" then
    put char 2 to -2 of xLine into xLine
  end if
end __ClearQuotes

private function __PathElement @xLine, @rListItem, pPathLists
  local tPathElement = 1

  put false into rListItem
  repeat
    if xLine begins with "  " then
      add 1 to tPathElement
    else if xLine begins with "- " then
      -- list
      put true into rListItem
    else
      return tPathElement
    end if
    delete char 1 to 2 of xLine
  end repeat
end __PathElement
