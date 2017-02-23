script "levureFramework"
##########
## This script must be assigned to a behavior of a stack that will be built as a standalone.
##########
constant kVersion = "0.0.2.0"
constant kAppStackName = "app"
constant kApplicationExternals = "levureAppExternals"

local sRootFolder             # Folder where standalone resides
local sAppFolder              # Folder where the `app` stack resides
local sAppA
local sRuntimePropertiesA

on mouseUp pBtnNum
  # Load app if user clicks on button in standalone stack
  if sRuntimePropertiesA["state"] is empty then
    if pBtnNum is 1 and word 1 of the target is "button" and the owner of the owner of the target is me then
      _startup
      exit mouseUp
    end if
  end if

  pass mouseUp
end mouseUp


after startup
  _startup
end startup


on shutdown
  if the environment is not "development" then
    levureShutdownApplication
  end if

  pass shutdown
end shutdown


private command _startup
  put "loading" into sRuntimePropertiesA["state"]
  set visible of me to false
  set the loc of me to the screenloc
  start using me
  levureInitializeAndRunApplication
end _startup


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
        send "appProcessCommandLineParameters tParams" to stack kAppStackName in 0 milliseconds
      end if

      if sAppA["relaunch in background"] then
        return "background"
      end if
    end if
  end if
end relaunch


on errorDialog pError
  if the environment is "development" OR sRuntimePropertiesA["state"] is "running" then pass errorDialog

  answer error pError
  quit
end errorDialog


function levureVersion
  return kVersion
end levureVersion


function levureAppStackFilename
  return appStackFilename()
end levureAppStackFilename


command levurePackageApplication pBuildProfile
  local tError, tStackFilename

  if the environment is not "development" then put "can only be run in development environment" into tError

  if tError is empty then
    if sAppA is not an array then
      start using me

      levureLoadAppConfig
      put the result into tError
    end if
  end if

  if tError is empty then
    set the itemdelimiter to "/"

    put levureFrameworkFolder() into tStackFilename
    put "packager/packager.livecodescript" into the last item of tStackFilename
  end if

  if tError is empty then
    local tStandaloneStack, tBuildProfile

    put the effective filename of me into tStandaloneStack
    # This stack will be removed from memory so send in time
    send "packagerPackageApplication tStandaloneStack, pBuildProfile" to stack tStackFilename in 10 milliseconds
  end if

  return tError for error
end levurePackageApplication


command packagerDidFinishPackagingApplication
  # Remove from memory after packaging is complete
  delete stack "Levure Framework Application Packager"
end packagerDidFinishPackagingApplication


command packagerDidFinishBuildingStandalone
  # Remove from memory after building standalone is complete
  delete stack "Levure Framework Application Packager"
end packagerDidFinishBuildingStandalone


command levureBuildStandalonesForTesting
  local tError, tStackFilename

  if the environment is not "development" then return "can only be run in development environment"

  if sAppA is not an array then
    start using me

    levureLoadAppConfig
    put the result into tError
  end if

  if tError is empty then
    set the itemdelimiter to "/"

    put levureFrameworkFolder() into tStackFilename
    put "packager/packager.livecodescript" into the last item of tStackFilename
  end if

  if tError is empty then
    local tStandaloneStack, tBuildProfile

    put the effective filename of me into tStandaloneStack
    put "test" into tBuildProfile
    # This stack will be removed from memory so send in time
    send "packagerBuildStandalones tStandaloneStack, tBuildProfile,,true" to stack tStackFilename in 10 milliseconds
  end if

  return tError for error
end levureBuildStandalonesForTesting


command levureLoadExternalEditorServer
  local tStackFilename, tStackPath

  set the itemdelimiter to "/"

  put levureFrameworkFolder() into tStackFilename
  put "utils/external_editor_server/external_editor_server.livecodescript" into tStackPath
  put tStackPath into the last item of tStackFilename
  if there is a stack tStackFilename then
    # TODO: Send port from .env file
    dispatch "levureExternalEditorStartServer" to stack tStackFilename
  else
    answer error tStackPath && "was not found"
  end if

end levureLoadExternalEditorServer


# So no scripts have to hard code name
function levureAppStackName
  return kAppStackName
end levureAppStackName


command levureInitializeAndRunApplication
  local tError

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
end levureInitializeAndRunApplication


command levureInitializeFramework pRootFolder
  local tError

  if the long id of me is the long id of this me OR word 1 of the long id of me is not "stack" then
    put "the framework is not assigned to a stack as a behavior" into tError
  end if

  if tError is empty then
    levureLoadAppConfig
    put the result into tError
  end if

  if tError is empty then
    loadExternals sAppA["externals to load"]
    put the result into tError
  end if

  if tError is empty then
    # Preload special helpers
    loadEarlyHelpers
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
    loadAppAssets
    put the result into tError
  end if

  return tError for error
end levureInitializeFramework


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
      ## Slight delay here so that appleEvents can be sent before
      ## Application is loaded. This allows URLs that launched application
      ## to be tucked away in "process url"
      send "levurefinishLoadingApplication" to me in 10 milliseconds
    end if
  end if

  -- display tError
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
      dispatch "appProcessCommandLineParameters" with tParams
    end if
  end if
end loadCommandLineArguments


command levurefinishLoadingApplication
  local msgsAreLocked

  dispatch "OpenApplication" to stack kAppStackName
  put "running" into sRuntimePropertiesA["state"]

  # Don't fire off any messages when closing the standalone stack
  put the lockMessages into msgsAreLocked
  lock messages
  close me
  set the lockMessages to msgsAreLocked
end levurefinishLoadingApplication


function levureApplicationDataFolder pUserOrShared
  local tFolder

  if sAppA["application data"]["folder"] is empty then return empty

  if pUserOrShared is not "shared" then
    switch the platform
      case "win32"
      case "macos"
        put specialFolderPath("support") & "/" into tFolder
        break
      case "linux"
        put specialFolderPath("home") & "/." into tFolder
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

  put sAppA["application data"]["folder"] after tFolder

  return tFolder
end levureApplicationDataFolder


function levureApplicationState
  return sRuntimePropertiesA["state"]
end levureApplicationState


function levureAppGetConfig
  return sAppA
end levureAppGetConfig


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


function levureAppGet pProp
  # todo: validate that array index lookup is valid
  if pProp is an array or pProp is among the keys of sAppA then
    return sAppA[pProp]
  else
    throw "invalid levure app property:" && pProp
  end if
end levureAppGet


# Sets property for life of session. Doesn't update app.yml file
command levureAppSet pProp, pValue
  if pProp is an array or pProp is among the keys of sAppA then
    put pValue into sAppA[pProp]
  else
    throw "invalid levure app property:" && pProp
  end if
end levureAppSet


function levureBuildProfile
  if the environment is "development" then
    return "development"
  else
    return the uBuildProfile of me # Assigned at build time
  end if
end levureBuildProfile


command levureUnloadApplication
  unloadApp
end levureUnloadApplication


private command normalizeAppArray
  put sAppA["multiple instances"] is true into sAppA["multiple instances"]
  put sAppA["relaunch in background"] is true into sAppA["relaunch in background"]

  put normalizeFolderPath(sAppA["application data"]["folder"]) into sAppA["application data"]["folder"]
  repeat while char 1 of sAppA["application data"]["folder"] is "/"
    delete char 1 of sAppA["application data"]["folder"]
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
    if sAppA["helpers"][i]["preload"] then next repeat
    unloadAssets sAppA["helpers"][i]
  end repeat

  repeat with i = the number of elements of sAppA["helpers"] down to 1
    if not sAppA["helpers"][i]["preload"] then next repeat
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
* \brief Cleans up and shuts down the application. Dispatches PreShutdownApplication.
*
* This command is called by the framework. There is no need for a developer to call this message.
*
* \return empty
*/
command levureShutdownApplication
  local tError, tCurrentState

  # 2016-04-18: Don't allow multiple calls to this.
  if sRuntimePropertiesA["state"] is "shutting down" then exit levureShutdownApplication

  put sRuntimePropertiesA["state"] into tCurrentState
  put "shutting down" into sRuntimePropertiesA["state"]

  ## Just in case it is still open after an error during launch
  close me

  if tCurrentState is "running" then
    dispatch "PreShutdownApplication" to stack kAppStackName

    appSavePrefs "user"
    put the result into tError
    if tError is not empty then
      answer "An error occurred while saving user preferences:" && tError & "."
    end if

    appSavePrefs "shared"
    put the result into tError
    if tError is not empty then
      answer "An error occurred while saving shared preferences:" && tError & "."
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


command levureLoadAppConfig
  local tError
  local tSource

  put levureStandaloneFolder() into sRootFolder

  if (the environment is not "development") and (there is a stack kAppStackName) and (the uAppA of stack kAppStackName is an array) then
    local tRootFolder

    # packaged application, app stack is already in memory
    put the uAppA of stack kAppStackName into sAppA

    set the itemdelimiter to "/"
    put the filename of stack kAppStackName into sAppFolder
    delete the last item of sAppFolder
    put sAppFolder into tRootFolder

    # The engine will tell us that app.livecodescript is in the Contents/MacOS folder
    # It is really in the Contents/Resources/_MacOS folder.
    # Externals are the only resources actually in Contents/MacOS. Use this folder to load
    # all resources but use the actual location of the app.livecodescript folder for
    # sAppFolder. A developer won't be able to find files relative to levureAppFolder() otherwise.
    if the platform is "macos" then
      put "Resources/_MacOS" into item -1 of sAppFolder
    end if

    if tError is empty then
      loadAppStack
      put the result into tError
    end if

    if tError is empty then
      set the itemdelimiter to ","

      repeat for each item tSource in "extensions,libraries,backscripts,frontscripts,behaviors"
        put expandMessagePathAssetsFileReferenceArray(sAppA[tSource], tRootFolder) into sAppA[tSource]
      end repeat

      put expandComponentAssetsFileReferenceArray(sAppA["components"], tRootFolder) into sAppA["components"]

      put expandHelperAssetsFileReferenceArray(sAppA["helpers"], tRootFolder) into sAppA["helpers"]
      resolveHelperAssets
      put the result into tError
    end if
  else
    # Development

    # Search order:
    # 1. root folder which by default is the folder where the standalone resides
    # 2. Directly inside any folders alongside the root folder.

    # Search folders
    local tFolders, tFolder

    if the environment is not "development" then
      put levureTestingStandaloneAppFolder() into sAppFolder
    else
      if there is a file (sRootFolder & "/app.yml") then
        put sRootFolder into sAppFolder
      else
        put folderListing(sRootFolder) into tFolders

        repeat for each line tFolder in tFolders
          if there is a file (tFolder & "/app.yml") then
            put tFolder into sAppFolder
            exit repeat
          end if
        end repeat
      end if
    end if

    put yamlFileToArray(sAppFolder & "/app.yml") into sAppA
    put the result into tError

    if tError is empty then
      normalizeAppArray
    end if

    if tError is empty then
      loadAppStack
      put the result into tError
    end if

    if tError is empty then
      local i, j
      local tFilesA

      ##########
      # Extensions, Libaries, Backscripts, Frontscripts, and Behaviors
      ##########
      repeat for each item tSource in "extensions,libraries,backscripts,frontscripts,behaviors"
        put empty into tFilesA
        put 0 into j

        repeat with i = 1 to the number of elements of sAppA[tSource]
          add 1 to j
          put sAppA[tSource][i] into tFilesA[j]
        end repeat

        if the number of elements of tFilesA > 0 then
          put expandMessagePathAssetsFileReferenceArray(tFilesA, sAppFolder) into sAppA[tSource]
        end if
      end repeat

      ##########
      # Components
      ##########
      put empty into tFilesA
      put 0 into j

      repeat with i = 1 to the number of elements of sAppA["components"]
        add 1 to j
        put sAppA["components"][i] into tFilesA[j]
      end repeat

      if the number of elements of tFilesA > 0 then
        put expandComponentAssetsFileReferenceArray(tFilesA, sAppFolder) into sAppA["components"]
      end if

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
        put expandHelperAssetsFileReferenceArray(tFilesA, sAppFolder) into sAppA["helpers"]
        resolveHelperAssets
        put the result into tError
      end if
    end if
  end if

  if tError is empty then
    if sAppA is not an array then
      put "invalid app.yml file" into tError
    end if
  end if

  return tError for error
end levureLoadAppConfig


private command loadAppStack
  # app stack will already be in memory if this is a packaged app
  if there is not a stack kAppStackName then
    if there is not a stack appStackFilename() then
      return "app stack not found" for error
    end if
  end if

  # Put in message path so shutdown, shutdownrequest, etc. are handled.
  start using stack kAppStackName

  return empty for value
end loadAppStack


private function appStackFilename
  if there is a file (sAppFolder & "/app.livecodescript") then
    return sAppFolder & "/app.livecodescript"
  else if there is a file (sAppFolder & "/app.livecode") then
    return sAppFolder & "/app.livecode"
  else
    return empty
  end if
end appStackFilename


private command createApplicationDataFolders
  local tError

  if sAppA["application data"]["folder"] is not empty then
    local tRootFolder

    if sAppA["application data"]["user"] then
      put levureApplicationDataFolder("user") into tRootFolder
      replace "/" & sAppA["application data"]["folder"] with empty in tRootFolder
      createSubfolders tRootFolder, sAppA["application data"]["folder"]
      put the result into tError
    end if

    if tError is empty and sAppA["application data"]["shared"] then
      put levureApplicationDataFolder("shared") into tRootFolder
      replace "/" & sAppA["application data"]["folder"] with empty in tRootFolder
      createSubfolders tRootFolder, sAppA["application data"]["folder"]
      put the result into tError
    end if
  end if

  return tError for error
end createApplicationDataFolders


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


private command loadEarlyHelpers
  local tError
  local tStackFiles
  local i, j

  put the stackFiles of stack kAppStackName into tStackFiles
  if tStackFiles is not empty then put cr after tStackFiles

  # Load any helpers marked preload=true
  repeat with i = 1 to the number of elements of sAppA["helpers"]
    if sAppA["helpers"][i]["preload"] then
      loadExtensions sAppA["helpers"][i]
      put the result into tError

      if tError is empty then
        loadMessagePathAssets sAppA["helpers"][i]

        repeat with j = 1 to the number of elements of sAppA["helpers"][i]["stacks"]
          put sAppA["helpers"][i]["stacks"][j]["name"] & "," & sAppA["helpers"][i]["stacks"][j]["filename"] & cr after tStackFiles
        end repeat
      end if

      if tError is not empty then exit repeat
    end if
  end repeat

  delete the last char of tStackFiles
  set the stackfiles of stack kAppStackName to tStackFiles

  return tError for error
end loadEarlyHelpers


private command loadAppAssets
  local tError
  local tRenameAnswerDialog = "false"
  local tRenameAskDialog = "false"
  local tStackFiles, i

  # components
  if tError is empty then
    put the stackFiles of stack kAppStackName into tStackFiles
    if tStackFiles is not empty then put cr after tStackFiles

    repeat with i = 1 to the number of elements of sAppA["components"]
      put sAppA["components"][i]["name"] & "," & \
            sAppA["components"][i]["filename"] & cr after tStackFiles

      # If app uses custom Ask/Answer dialogs then rename LiveCode ones
      if sAppA["components"][i]["name"] is "Answer Dialog" then
        put there is a stack "Answer Dialog" into tRenameAnswerDialog
      end if
      if sAppA["components"][i]["name"] is "Ask Dialog" then
        put there is a stack "Ask Dialog" into tRenameAskDialog
      end if
    end repeat
  end if

  # helper stacks
  if tError is empty then
    local j

    repeat with i = 1 to the number of elements of sAppA["helpers"]
      if sAppA["helpers"][i]["preload"] then next repeat
      repeat with j = 1 to the number of elements of sAppA["helpers"][i]["stacks"]
        put sAppA["helpers"][i]["stacks"][j]["name"] & "," & sAppA["helpers"][i]["stacks"][j]["filename"] & cr after tStackFiles
      end repeat
    end repeat

    delete the last char of tStackFiles
    set the stackFiles of stack kAppStackName to tStackFiles
  end if

  # extensions
  if tError is empty then
    loadExtensions sAppA
    put the result into tError

    repeat with i = 1 to the number of elements of sAppA["helpers"]
      if sAppA["helpers"][i]["preload"] then next repeat
      loadExtensions sAppA["helpers"][i]
    end repeat
  end if

  # behaviors, libraries, frontscripts, backscripts
  if tError is empty then
    repeat with i = 1 to the number of elements of sAppA["helpers"]
      if sAppA["helpers"][i]["preload"] then next repeat
      loadMessagePathAssets sAppA["helpers"][i]
    end repeat

    loadMessagePathAssets sAppA

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

  return tError
end loadAppAssets


private command loadMessagePathAssets pArrayA
  local tFileIsLoaded, i
  local tStack

  repeat with i = 1 to the number of elements of pArrayA["behaviors"]
    put there is a stack pArrayA["behaviors"][i]["filename"] into tFileIsLoaded
  end repeat

  # Now that all behaviors are in memory enable a script only
  # behavior stack to set its own behavior
  repeat with i = 1 to the number of elements of pArrayA["behaviors"]
    dispatch "LoadBehavior" to stack pArrayA["behaviors"][i]["filename"]

    # for packaged apps
    repeat for each line tStack in the substacks of stack pArrayA["behaviors"][i]["filename"]
      dispatch "LoadBehavior" to stack tStack
    end repeat
  end repeat

  repeat with i = 1 to the number of elements of pArrayA["libraries"]
    start using stack pArrayA["libraries"][i]["filename"]
    # for packaged apps
    repeat for each line tStack in the uStackLoadOrder of stack pArrayA["libraries"][i]["filename"]
      start using stack tStack
    end repeat
  end repeat

  repeat with i = 1 to the number of elements of pArrayA["backscripts"]
    insert script of stack pArrayA["backscripts"][i]["filename"] into back
    # for packaged apps
    repeat for each line tStack in the uStackLoadOrder of stack pArrayA["backscripts"][i]["filename"]
      insert script of stack tStack into back
    end repeat
  end repeat

  repeat with i = 1 to the number of elements of pArrayA["frontscripts"]
    insert script of stack pArrayA["frontscripts"][i]["filename"] into front
    # for packaged apps
    repeat for each line tStack in the uStackLoadOrder of stack pArrayA["frontscripts"][i]["filename"]
      insert script of stack tStack into front
    end repeat
  end repeat

  return empty for value
end loadMessagePathAssets



private command loadExtensions pArrayA
  local tError, tDefaultResourcesFolder
  local i

  put sAppFolder & "/resources" into tDefaultResourcesFolder
  if there is not a folder tDefaultResourcesFolder then
    put empty into tDefaultResourcesFolder
  end if

  repeat with i = 1 to the number of elements of pArrayA["extensions"]
    if pArrayA["extensions"][i]["resource path"] is not empty then
      load extension from file pArrayA["extensions"][i]["filename"] with resource path pArrayA["extensions"][i]["resource path"]
    else if tDefaultResourcesFolder is not empty then
      load extension from file pArrayA["extensions"][i]["filename"] with resource path tDefaultResourcesFolder
    else
      load extension from file pArrayA["extensions"][i]["filename"]
    end if
    if the result is not empty and the result is not "module already loaded" then
      put the result & cr after tError
    end if
  end repeat

  delete the last char of tError

  return tError for error
end loadExtensions


command levureBuildExtensions
  local tError

  put empty into sAppA
  if sAppA is not an array then
    start using me

    levureLoadAppConfig
    put the result into tError
  end if

  if tError is empty then
    buildExtensions sAppA["extensions"]
    put the result into tError
  end if

  return tError for error
end levureBuildExtensions


private command buildExtensions pArrayA
  local tError, i
  local tNewExtensionFile, tTempFolder

  put the temporary folder & "/_buildLevureExtension_" & the milliseconds into tTempFolder

  repeat with i = 1 to the number of elements of pArrayA
    if there is a file pArrayA[i]["source"] then
      create folder tTempFolder
      put the result into tError

      -- build in temp folder
      if tError is empty then
        buildExtension pArrayA[i]["source"], tTempFolder
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


private command buildExtension pFilename, pOutputFolder
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

  # Look in folder of pFilename as well as 'lci' subdirectory of pFilename folder.
  set the itemDelimiter to "/"
  put shellFormat(item 1 to -2 of pFilename, "modulepath") after tCmd
  put shellFormat(item 1 to -2 of pFilename & "/lci", "modulepath") after tCmd

  # The manifest target
  put shellFormat(pOutputFolder & "/manifest.xml", "manifest") after tCmd

  # The output
  put shellFormat(pOutputFolder & "/module.lcm", "output") after tCmd

  # Target the .lcb file
  put shellFormat(pFilename) after tCmd

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


private command resolveHelperAssets
  local tError, tConfigA, i
  local tExternalPackagesInMemory

  put levureExternalsLoadedInMemory() into tExternalPackagesInMemory

  repeat with i = 1 to the number of elements of sAppA["helpers"]
    resolveHelperFolderAssets sAppA["helpers"][i], tExternalPackagesInMemory
    put the result into tError

    if tError is not empty then exit repeat
  end repeat

  return tError for error
end resolveHelperAssets


private command resolveHelperFolderAssets @xHelperA, pExternalPackagesInMemory
  local tError
  local tConfigA, tKeys, tAlreadyFilledIn

  # When packaged the array will already be filled in.
  put the keys of xHelperA into tKeys
  set the wholematches to true
  repeat for each item tKey in "libraries,backscripts,frontscripts,behaviors,stacks,extensions,externals"
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
      # Load up any stacks
      local tFile, tIsAStack, j

      put 0 into j
      put empty into tConfigA
      set the itemDelimiter to "/"

      repeat for each line tFile in fileListing(xHelperA["filename"])
        put there is a stack tFile into tIsAStack
        if tIsAStack then
          add 1 to j

          put the short name of stack tFile into tConfigA["stacks"][j]["name"]
          put the last item of tFile into tConfigA["stacks"][j]["filename"]
          delete stack tFile
        end if
      end repeat

      set the itemdelimiter to ","
    end if
  else
    put xHelperA into tConfigA
  end if

  if tError is empty then
    local tPlatform, tTargetPlatform

    put xHelperA["filename"] into tConfigA["filename"]
    put xHelperA["preload"] is true into tConfigA["preload"]
    put xHelperA["encrypt"] is true into tConfigA["encrypt"]

    # stack files
    repeat with j = 1 to the number of elements of tConfigA["stacks"]
      put xHelperA["filename"] & "/" & normalizeRelativeFilename(tConfigA["stacks"][j]["filename"]) into tConfigA["stacks"][j]["filename"]
      put ensureStackNameIsPresent(tConfigA["stacks"][j]) into tConfigA["stacks"][j]
    end repeat

    if the platform is "win32" then put "windows" into tTargetPlatform
    else put the platform into tTargetPlatform

    set the wholematches to true

    # externals
    repeat for each key tPlatform in tConfigA["externals"]
      repeat with j = 1 to the number of elements of tConfigA["externals"][tPlatform]
        put xHelperA["filename"] & "/" & normalizeRelativeFilename(tConfigA["externals"][tPlatform][j]["filename"]) into \
                tConfigA["externals"][tPlatform][j]["filename"]

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
        put resolveRelativeFilenameReference(tConfigA["extensions"][j]["source"], xHelperA["filename"]) into tConfigA["extensions"][j]["source"]
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


function levureAppFolder
  return sAppFolder for value
end levureAppFolder


function levureRelativeAppFolderPath
  local tPath

  put sAppFolder into tPath
  replace levureStandaloneFolder() with empty in tPath
  if char 1 of tPath is "/" then delete char 1 of tPath
  return tPath
end levureRelativeAppFolderPath


function levureStandaloneStack
  return the name of me
end levureStandaloneStack


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


function levureBuildFolder
  return resolveFilenameReference(sAppA["build folder"], levureAppFolder())
end levureBuildFolder


function levureFrameworkFolder
  local tFolder

  put the filename of (the long id this me) into tFolder
  set the itemDelimiter to "/"
  delete the last item of tFolder
  return tFolder for value
end levureFrameworkFolder


private function expandMessagePathAssetsFileReferenceArray pFilesA, pRootFolder
  local tFilesA, i, j

  replaceVariablesInPaths pFilesA

  repeat with i = 1 to the number of elements of pFilesA
    if pFilesA[i]["folder"] is not empty then
      put resolveFilenameReference(pFilesA[i]["folder"], pRootFolder) into pFilesA[i]["folder"]

      # expand the folder listing. Assume every file is a file to load.
      addFolderToFilesArray pFilesA[i]["folder"], tFilesA

      put the number of elements of tFilesA into j

    else if pFilesA[i]["filename"] is not empty then
      put resolveFilenameReference(pFilesA[i]["filename"], pRootFolder) \
            into pFilesA[i]["filename"]

      if isFilenameUniqueInFilesArray(pFilesA[i]["filename"], tFilesA) then
        add 1 to j
        put pFilesA[i]["filename"] into tFilesA[j]["filename"]

        if "source" is among the keys of pFilesA[i] then
          put resolveFilenameReference(pFilesA[i]["source"], pRootFolder) \
                into tFilesA[j]["source"]
        end if
        if "distribute" is among the keys of pFilesA[i] then
          put pFilesA[i]["distribute"] into tFilesA[j]["distribute"]
        end if
        if "encrypt" is among the keys of pFilesA[i] then
          put pFilesA[i]["encrypt"] into tFilesA[j]["encrypt"]
        end if
      end if
    end if
  end repeat

  return tFilesA
end expandMessagePathAssetsFileReferenceArray


private command addFolderToFilesArray pFolder, @xFilesA
  local tFolder, tFile, i

  put the number of elements of xFilesA into i

  repeat for each line tFile in fileListing(pFolder)
    if isFilenameUniqueInFilesArray(tFile, xFilesA) then
      add 1 to i
      put tFile into xFilesA[i]["filename"]
    end if
  end repeat

  repeat for each line tFolder in folderListing(pFolder)
    addFolderToFilesArray tFolder, xFilesA
  end repeat

  return empty for value
end addFolderToFilesArray


private function expandHelperAssetsFileReferenceArray pFilesA, pRootFolder
  local tFilesA, i, j

  replaceVariablesInPaths pFilesA

  repeat with i = 1 to the number of elements of pFilesA
    if pFilesA[i]["folder"] is not empty then
      put resolveFilenameReference(pFilesA[i]["folder"], pRootFolder) into pFilesA[i]["folder"]

      # expand the folder listing. Assume every folder is a helper to load.
      local tFile

      repeat for each line tFile in folderListing(pFilesA[i]["folder"])
        if isFilenameUniqueInFilesArray(tFile, tFilesA) then
          add 1 to j
          put tFile into tFilesA[j]["filename"]
          if "preload" is among the keys of pFilesA[i] then
            put pFilesA[i]["preload"] into tFilesA[j]["preload"]
          end if
        end if
      end repeat
    else if pFilesA[i]["filename"] is not empty then
      put resolveFilenameReference(pFilesA[i]["filename"], pRootFolder) \
            into pFilesA[i]["filename"]
      if isFilenameUniqueInFilesArray(pFilesA[i]["filename"], tFilesA) then
        add 1 to j
        put pFilesA[i] into tFilesA[j]
        if "preload" is among the keys of pFilesA[i] then
          put pFilesA[i]["preload"] into tFilesA[j]["preload"]
        end if
      end if
    end if
  end repeat

  return tFilesA
end expandHelperAssetsFileReferenceArray


private function expandComponentAssetsFileReferenceArray pFilesA, pRootFolder
  local tFilesA, i, j
  local tEncrypt

  replaceVariablesInPaths pFilesA

  repeat with i = 1 to the number of elements of pFilesA
    put empty into tEncrypt

    if pFilesA[i]["folder"] is not empty then
      put resolveFilenameReference(pFilesA[i]["folder"], pRootFolder) into pFilesA[i]["folder"]

      # expand the folder listing. Assume every folder is a component to load.
      local tFolder

      if "encrypt" is among the keys of pFilesA[i] then
        put pFilesA[i]["encrypt"] into tEncrypt
      end if

      repeat for each line tFolder in folderListing(pFilesA[i]["folder"])
        addComponentStacksToFilesArray tFolder, tFilesA, tEncrypt
      end repeat
      put the number of elements of tFilesA into j

    else if pFilesA[i]["filename"] is not empty then
      put resolveFilenameReference(pFilesA[i]["filename"], pRootFolder) \
            into pFilesA[i]["filename"]

      # If filename points to a folder then load up the entire folder
      # Otherwise the target is a single file within the component folder. Probably using different encryption setting.
      if there is a folder pFilesA[i]["filename"] then
        if "encrypt" is among the keys of pFilesA[i] then
          put pFilesA[i]["encrypt"] into tEncrypt
        end if
        addComponentStacksToFilesArray pFilesA[i]["filename"], tFilesA, tEncrypt
        put the number of elements of tFilesA into j
      else
        # points directly to a stack file
        put ensureStackNameIsPresent(pFilesA[i]) into pFilesA[i]

        if pFilesA[i]["name"] is not empty AND isFilenameUniqueInFilesArray(pFilesA[i]["filename"], tFilesA) then
          add 1 to j
          put pFilesA[i]["filename"] into tFilesA[j]["filename"]
          put pFilesA[i]["name"] into tFilesA[j]["name"]
          if "encrypt" is among the keys of pFilesA[i] then
            put pFilesA[i]["encrypt"] into tFilesA[j]["encrypt"]
          end if
        end if
      end if
    end if
  end repeat

  return tFilesA
end expandComponentAssetsFileReferenceArray


private command addComponentStacksToFilesArray pFolder, @xFilesA, pEncrypt
  local tError, tFiles, tFile, tFileA, i

  put the number of elements of xFilesA into i

  put fileListing(pFolder) into tFiles
  filter tFiles with regex pattern ".*\.livecode$|.*\.livecodescript$"

  repeat for each line tFile in tFiles
    if not isFilenameUniqueInFilesArray(tFile, xFilesA) then
      next repeat
    end if

    put empty into tFileA

    put tFile into tFileA["filename"]
    put ensureStackNameIsPresent(tFileA) into tFileA

    if tFileA["name"] is not empty then
      add 1 to i
      put tFileA into xFilesA[i]
      if pEncrypt is not empty then
        put pEncrypt into xFilesA[i]["encrypt"]
      end if
    end if
  end repeat

  return empty
end addComponentStacksToFilesArray


private command replaceVariablesInPaths @pFilesA
  local tUserExtensionsFolder, tFrameworkFolder
  local tKey, i

  put userExtensionsFolder() into tUserExtensionsFolder
  put levureFrameworkFolder() into tFrameworkFolder

  repeat with i = 1 to the number of elements of pFilesA
    repeat for each item tKey in "filename,folder,source"
      if tKey is among the keys of pFilesA[i] then
        replace "{{USER_EXTENSIONS}}" with tUserExtensionsFolder in pFilesA[i][tKey]

        if pFilesA[i][tKey] contains "{{FRAMEWORK}}" then
          replace "{{FRAMEWORK}}" with tFrameworkFolder in pFilesA[i][tKey]
          put true into pFilesA[i]["preload"] # framework files should be available to all app libraries, etc.
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


private function resolveFilenameReference pFilename, pRootFolder
  repeat while the last char of pFilename is "/"
    delete the last char of pFilename
  end repeat

  if isFilenameRelative(pFilename) then
    put normalizeRelativeFilename(pFilename) into pFilename

    if pFilename begins with "../" then
      return resolveRelativeFilenameReference(pFilename, pRootFolder) for value
    else
      return pRootFolder & "/" & pFilename
    end if
  else
    return pFilename
  end if
end resolveFilenameReference


private function isFilenameRelative pFilename
  set the itemDelimiter to "/"
  -- {{ is for variables
  return not ((the platform is "win32" and item 1 of pFilename contains ":") or pFilename begins with "/" or pFilename begins with "{{")
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


function yamlFileToArray pFilename
  local tError, tYaml

  put readFileContents(pFilename) into tYaml
  put the result into tError

  if tError is empty then
    return yamlToArray(textDecode(tYaml, "utf8")) for value
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


/**********************
Basic YAML support until an LCB extension is written.
***********************/
/**
Array-to-Yaml and Yaml-to-Array library
Mark Wieder 2016
wtf licenced : have fun

Public functions here:
arrayToYaml
yamlToArray
*/

-- allow 4 spaces per indentation in output yaml files
-- adjust as desired
constant kIndent = 4

/*
arrayToYaml

Convert a LiveCode array to yaml format

@pArray : the array to convert
@pIndentLevel : initially empty, recursion sets this
*/
private function arrayToYaml pArray, pIndentLevel
  local tYaml
  local tIndentLevel

  put pIndentLevel into tIndentLevel
  if tIndentLevel is empty then
    put kIndent into tIndentLevel
    put "ArrayName :" & cr into tYaml
  end if
  if pArray is an array then
    repeat for each key tKey in pArray
      if pArray[tKey] is an array then
        put indent(tIndentLevel) & tKey && ":" && pArray[tKey] & cr after tYaml
        add kIndent to tIndentLevel
        -- recurse to work through multidimensional arrays
        put arrayToYaml(pArray[tKey], tIndentLevel) after tYaml
        subtract kIndent from tIndentLevel
      else
        put indent(tIndentLevel) & tKey && ":" && pArray[tKey] & cr after tYaml
      end if
    end repeat
  else
    throw "not an array"
  end if
  return tYaml
end arrayToYaml

/*
indent

Used internally by arrayToYaml
*/
private function indent pIndentLevel
  local tIndentLevel

  -- return the proper number of spaces for indentation
  repeat pIndentLevel times
    put space after tIndentLevel
  end repeat
  return tIndentLevel
end indent

/*
indentationLevel

Return the indentation level of the supplied line
NOTE: changes the input line in situ to remove the indentation
Used internally by yamlToArray
*/
private function indentationLevel @pLine
  local tIndentationLevel
  local tKey, tValue

  put 0 into tIndentationLevel
  repeat while char 1 of pLine is space
    add 1 to tIndentationLevel
    delete char 1 of pLine
  end repeat
  return tIndentationLevel
end indentationLevel

/*
yamlToArray

Convert yaml format text to a LiveCode array
*/
private function yamlToArray pYaml
  local tArray, tDelOffset
  local tIndentation, tPrevIndent
  local tWorkingLine
  local tYamlHeading
  local tKey, tValue
  local tSpacesPerIndent

  repeat for each line tLine in pYaml
    put empty into tKey

    put tLine into tWorkingLine
    if word 1 to -1 of tWorkingLine is empty then next repeat

    # Support keys wrapped in quotes
    put offset(":", tWorkingLine) into tDelOffset
    if tDelOffset > 1 then
      local tStartQuoteCharOffset, tEndQuoteCharOffset

      put offset(quote, tWorkingLine) into tStartQuoteCharOffset
      if tStartQuoteCharOffset < tDelOffset then
        put offset(quote, tWorkingLine, tDelOffset) into tEndQuoteCharOffset
        if tEndQuoteCharOffset > 0 then
          add tDelOffset to tEndQuoteCharOffset
          put char 1 to tEndQuoteCharOffset of tWorkingLine into tKey
          delete the last char of tKey
          delete char tStartQuoteCharOffset of tKey
          put char tEndQuoteCharOffset + 1 to -1 of tWorkingLine into tValue
          repeat while char 1 of tValue is in ": "
            delete char 1 of tValue
          end repeat
          put word 1 to -1 of tValue into tValue
        end if
      end if
    end if

    if tKey is empty then
      set the itemdelimiter to ":"
      put item 1 of tWorkingLine into tKey
      repeat while char -1 of tKey is in ": "
        delete char -1 of tKey
      end repeat
      put word 1 to -1 of item 2 to -1 of tWorkingLine into tValue
    end if

    put indentationLevel(tKey) into tIndentation
    set the itemdelimiter to ","
    if tPrevIndent is empty then
      -- first time through
      put tIndentation into tPrevIndent
      put tKey into tYamlHeading
      put tValue into tArray[tYamlHeading]
    else
      -- When indentation decreases we need to guess how many levels down the user is going.
      -- Otherwise nested arrays won't work very well.
      if tSpacesPerIndent is empty AND tPrevIndent is 0 and tIndentation > 0 then
        put tIndentation into tSpacesPerIndent
      end if

      switch
        case tIndentation < tPrevIndent
          -- remove the array indexes depending on change in hierarchy
          repeat with i = (tPrevIndent/tSpacesPerIndent) down to (tIndentation/tSpacesPerIndent)
            RemoveLastIndexFrom tYamlHeading
          end repeat
          put tIndentation into tPrevIndent
          yamlAddToArray tArray, tYamlHeading, tKey, tValue
          put tKey into item (the number of items of tYamlHeading + 1) of tYamlHeading
          break
        case tIndentation is tPrevIndent
          RemoveLastIndexFrom tYamlHeading
          yamlAddToArray tArray, tYamlHeading, tKey, tValue
          put tKey into item (the number of items of tYamlHeading + 1) of tYamlHeading
          break
        case tIndentation > tPrevIndent
          -- add an array index
          yamlAddToArray tArray, tYamlHeading, tKey, tValue
          put tKey into item (the number of items of tYamlHeading + 1) of tYamlHeading
          put tIndentation into tPrevIndent
          break
      end switch
    end if
  end repeat
  return tArray
end yamlToArray

private command yamlAddToArray @xArray, pYamlHeading, pKey, pValue
  if pYamlHeading is empty then
    do "put pValue into xArray[" & quote & pKey & quote & "]"
  else
    do "put pValue into xArray" & yamlPathToArrayPath(pYamlHeading) & "[" & quote & pKey & quote & "]"
  end if
end yamlAddToArray

private command RemoveLastIndexFrom @pIndexString
  set the itemdelimiter to comma
  delete item -1 of pIndexString
end RemoveLastIndexFrom

private function yamlPathToArrayPath pYamlPath
  local tArrayPath

  set the itemdelimiter to comma
  repeat for each item tPath in pYamlPath
    put "[" & quote & tPath & quote & "]" after tArrayPath
  end repeat
  return tArrayPath
end yamlPathToArrayPath


private function _printArray pArray, pDimension, pFullData
  local tKeys, tKey, tText, tTempArray

  if pDimension is empty then put 0 into pDimension

  put the keys of pArray into tKeys
  sort tKeys numeric

  repeat for each line tKey in tKeys
    if pArray[tKey] is an array then
      put _printCharXTimes(space, pDimension * 3) & tKey & cr after tText
      put pArray[tKey] into tTempArray
      put _printArray(tTempArray, pDimension + 1, pFullData) after tText
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
