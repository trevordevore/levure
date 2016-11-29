script "levureFramework"
##########
## This script must be assigned to a behavior of a stack that will be built as a standalone.
##########
constant kVersion = "0.0.1.0"
constant kAppStackName = "app"
constant kApplicationExternals = "levureAppExternals"

local sRootFolder             # Folder where standalone resides
local sAppFolder              # Folder where the `app` stack resides
local sAppA
local sRuntimePropertiesA

on mouseDown pBtnNum
  # Load app if user clicks on button in standalone stack
  if sRuntimePropertiesA["state"] is empty then
    if word 1 of the target is "button" and the owner of the owner of the target is me then
      startup
    end if
  end if
end mouseDown


after startup
  put "loading" into sRuntimePropertiesA["state"]
  set visible of me to false
  set the loc of me to the screenloc
  start using me
  levureInitializeAndRunApplication
end startup


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


command levureBuildTestStandalones
  local tError, tStackFilename
  
  if the environment is not "development" then return "can only be run in development environment"
  
  if sAppA is not an array then
    start using me

    loadAppConfig
    put the result into tError
  end if
  
  if tError is empty then
    set the itemdelimiter to "/"
    
    put levureFrameworkFolder() into tStackFilename
    put "packager/packager.livecodescript" into the last item of tStackFilename
  end if
  
  if tError is empty then
    put the effective filename of me into tStandaloneStack
    put "test" into tBuildProfile
    send "levureBuildStandalones tStandaloneStack, tBuildProfile" to stack tStackFilename in 10 milliseconds
  end if
end levureBuildTestStandalones


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
    loadAppConfig
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
    
    set the itemDelimiter to "."
    repeat with i = 1 to ($# - 1)
      put value("$" & i) into tValue
      put tValue & cr after tParams
    end repeat
    
    if tParams is not empty then
      appProcessCommandLineParameters tParams
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
  if pUserOrShared is not "shared" then
    switch the platform
      case "win32"
      case "macos"
        return specialFolderPath("support") & "/" & sAppA["application data folder"]
      case "linux"
        return specialFolderPath("home") & "/." & sAppA["application data folder"]
      default
        return empty
    end switch
  else
    switch the platform
      case "macos"
        return specialFolderPath("asup") & "/" & sAppA["application data folder"]
      case "win32"
        return specialFolderPath("35") & "/" & sAppA["application data folder"]
      case "linux"
        return "/opt/." & sAppA["application data folder"]
      default
        return empty
    end switch
  end if
end levureApplicationDataFolder


function levureApplicationState
  return sRuntimePropertiesA["state"]
end levureApplicationState


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
    return sAppA["active build profile"] # Created at build time
  end if
end levureBuildProfile


private command normalizeAppArray
  put sAppA["multiple instances"] is true into sAppA["multiple instances"]
  put sAppA["relaunch in background"] is true into sAppA["relaunch in background"]
  
  put normalizeFolderPath(sAppA["application data folder"]) into sAppA["application data folder"]
  repeat while char 1 of sAppA["application data folder"] is "/"
    delete char 1 of sAppA["application data folder"]
  end repeat
  
  repeat for each item tKey in "password,file extensions,file extension groups"
    if tKey is not among the keys of sAppA then
      put empty into sAppA[tKey]
    end if
  end repeat
  
  return empty for value
end normalizeAppArray


private command unloadApp
  # TODO: This isn't complete. Helpers can have scripts as well.
  repeat with i = 1 to the number of elements of sAppA["frontscripts"]
    remove the script of stack sAppA["frontscripts"][i]["filename"] from front
  end repeat
  repeat with i = 1 to the number of elements of sAppA["backscripts"]
    remove the script of stack sAppA["backscripts"][i]["filename"] from back
  end repeat
  repeat with i = 1 to the number of elements of sAppA["libraries"]
    stop using stack sAppA["libraries"][i]["filename"]
  end repeat
  unloadExternals
end unloadApp


/**
* \brief Cleans up and shuts down the application. Dispatches glxapp_cleanupApplication.
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
    repeat for each line tStack in the openStacks
      if tStack is empty then next repeat
      if windowIsManaged(tStack) then
         windowSaveWindowPosition tStack
      end if
   end repeat
 
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


private command loadAppConfig
  local tError
  
  put levureStandaloneFolder() into sRootFolder
  
  if the environment is not "development" and sAppA is an array then
    # Packaged application. 
    # - 'app' stack should be in memory
    # - sAppA should have configuration info
    
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
    
    # Execution errors should be available as early as possible.
    # Preferences needs to be available for the PreloadApplication message so load now.
    if tError is empty then
      loadFrameworkHelper "execution_error_dialog,preferences"
      put the result into tError
    end if
    
    # Load the preference external. Remove once we move it to a module.
    if tError is empty then
      loadExternals sAppA["externals to load"]
      put the result into tError
    end if
    
    # If not explicitly configured, load any extensions, libraries, frontscripts, or backscripts
    if tError is empty then
      local i, j
      local tFilesA
      
      ##########
      # Extensions, Libaries, Backscripts, Frontscripts, and Behaviors
      ##########
      local tSource
      
      repeat for each item tSource in "extensions,libraries,backscripts,frontscripts,behaviors"
        put empty into tFilesA
        put 0 into j
        
        if there is a folder (levureFrameworkFolder() & "/" & tSource) then
          add 1 to j
          put levureFrameworkFolder() & "/" & tSource into tFilesA[j]["folder"]
        end if
        
        if the number of elements of sAppA[tSource] > 0 then        
          repeat with i = 1 to the number of elements of sAppA[tSource]
            add 1 to j
            put sAppA[tSource][i] into tFilesA[j]
          end repeat
        else if sAppFolder is not levureFrameworkFolder() AND there is a folder (sAppFolder & "/" & tSource) then
          add 1 to j
          put sAppFolder & "/" & tSource into tFilesA[j]["folder"]
        end if
        
        if the number of elements of tFilesA > 0 then
          put expandMessagePathAssetsFileReferenceArray(tFilesA, sAppFolder) into sAppA[tSource]
        end if
      end repeat
      
      ##########
      # Components
      ##########      
      put empty into tFilesA
      put 0 into j
      
      if there is a folder (levureFrameworkFolder() & "/components") then
        add 1 to j
        put levureFrameworkFolder() & "/components" into tFilesA[j]["folder"]
      end if
      
      if the number of elements of sAppA["components"] > 0 then        
        repeat with i = 1 to the number of elements of sAppA["components"]
          add 1 to j
          put sAppA["components"][i] into tFilesA[j]
        end repeat
      else if sAppFolder is not levureFrameworkFolder() AND there is a folder (sAppFolder & "/components") then
        add 1 to j
        put sAppFolder & "/components" into tFilesA[j]["folder"]
      end if
      
      if the number of elements of tFilesA > 0 then
        put expandComponentAssetsFileReferenceArray(tFilesA, sAppFolder) into sAppA["components"]
      end if
      
      ##########
      # Helpers
      ##########
      put empty into tFilesA
      put 0 into j
      
      if there is a folder (levureFrameworkFolder() & "/helpers") then
        local tHelperFolders, tHelperFolder
        
        set the itemdelimiter to "/"
        put folderListing(levureFrameworkFolder() & "/helpers") into tHelperFolders
        repeat for each line tHelperFolder in tHelperFolders
          if the last item of tHelperFolder is "execution_error_dialog" then # preloaded
            next repeat
          else
            add 1 to j
            put tHelperFolder into tFilesA[j]["filename"]
          end if
        end repeat
      end if
      
      if the number of elements of sAppA["helpers"] > 0 then        
        repeat with i = 1 to the number of elements of sAppA["helpers"]
          add 1 to j
          put sAppA["helpers"][i] into tFilesA[j]
        end repeat
      else if sAppFolder is not levureFrameworkFolder() AND there is a folder (sAppFolder & "/helpers") then
        add 1 to j
        put sAppFolder & "/helpers" into tFilesA[j]["folder"]
      end if
      
      if the number of elements of tFilesA > 0 then
        put expandHelperAssetsFileReferenceArray(tFilesA, sAppFolder) into sAppA["helpers"]
        expandHelperAssets
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
end loadAppConfig


private command loadAppStack
  # app stack will already be in memory if this is a packaged app
  if there is not a stack kAppStackName then
    if there is not a stack (sAppFolder & "/app.livecodescript") \
      AND there is not a stack (sAppFolder & "/app.livecode") then
      return "app stack not found" for error
    end if
  end if
  
  start using stack kAppStackName

  return empty for value
end loadAppStack


private command loadAppAssets
  local tError
  local tRenameAnswerDialog = "false"
  local tRenameAskDialog = "false"
  
  if tError is empty then
    local tExternalPackagesInMemory, tExternalPackageName
    
    loadExternals sAppA["externals to load"]
    put the result into tError
  end if
  
  if tError is empty then
    local i, tStackFiles
    
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
    delete the last char of tStackFiles
  end if
  
  if tError is empty then
    loadExtensions sAppA
    put the result into tError
  end if
  
  if tError is empty then
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
        delete stack "Answer Dialog"
      end if
    end if
    set the stackFiles of stack kAppStackName to tStackFiles
  end if
  
  return tError
end loadAppAssets


private command loadMessagePathAssets pArrayA
  local tFileIsLoaded, i
  
  repeat with i = 1 to the number of elements of pArrayA["behaviors"]
    put there is a stack pArrayA["behaviors"][i]["filename"] into tFileIsLoaded
  end repeat
  
  # Now that all behaviors are in memory enable a script only 
  # behavior stack to set its own behavior
  repeat with i = 1 to the number of elements of pArrayA["behaviors"]
    dispatch "LoadBehavior" to stack pArrayA["behaviors"][i]["filename"]
  end repeat
  
  repeat with i = 1 to the number of elements of pArrayA["libraries"]
    start using stack pArrayA["libraries"][i]["filename"]
  end repeat
  
  repeat with i = 1 to the number of elements of pArrayA["backscripts"]
    insert script of stack pArrayA["backscripts"][i]["filename"] into back
  end repeat
  
  repeat with i = 1 to the number of elements of pArrayA["frontscripts"]
    insert script of stack pArrayA["frontscripts"][i]["filename"] into front
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
    
    loadAppConfig
    put the result into tError
  end if
  
  if tError is empty then
    buildExtensions sAppA["extensions"]
    put the result into tError
  end if
  
  return tError as error
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


private command expandHelperAssets
  local tError, tConfigA, i
  local tExternalPackagesInMemory, tStackFiles
  
  put levureExternalsLoadedInMemory() into tExternalPackagesInMemory
  put the stackFiles of stack kAppStackName into tStackFiles
  
  if tStackFiles is not empty then put cr after tStackFiles
  
  repeat with i = 1 to the number of elements of sAppA["helpers"]
    loadHelperFolderAssets sAppA["helpers"][i]["filename"], tExternalPackagesInMemory, sAppA, tStackFiles
    put the result into tError
    
    if tError is not empty then exit repeat
  end repeat
  
  if tError is empty then
    if the last char of tStackFiles is cr then delete the last char of tStackFiles
    
    set the stackfiles of stack kAppStackName to tStackFiles
  end if  

  return tError for error
end expandHelperAssets


# Special case as we want to load very early
private command loadFrameworkHelper pHelperFolders
  local tError, tHelperFolder
  
  local tAssetsA, tStackFiles
  
  repeat for each item tHelperFolder in pHelperFolders
    if there is a folder (levureFrameworkFolder() & "/helpers/" & tHelperFolder) then
    
      loadHelperFolderAssets levureFrameworkFolder() & "/helpers/" & tHelperFolder, empty, tAssetsA, tStackFiles
      put the result into tError

      if tError is empty then
        if the last char of tStackFiles is cr then delete the last char of tStackFiles
      
        # Add to sAppA so that the helper is not loaded again.
        put levureFrameworkFolder() & "/helpers/" & tHelperFolder into sAppA["helpers"][ the number of elements of sAppA["helpers"] + 1 ]["filename"]
        
        loadExtensions tAssetsA
        put the result into tError
      end if
      
      if tError is empty then
        loadMessagePathAssets tAssetsA
      
        # Add to sAppA so we have a complete list of helper assets that were loaded.
        repeat with i = 1 to the number of elements of tAssetsA["behaviors"]
          put tAssetsA["behaviors"][i]["filename"] into sAppA["behaviors"][ the number of elements of sAppA["behaviors"] + 1 ]["filename"]
        end repeat
        repeat with i = 1 to the number of elements of tAssetsA["libraries"]
          put tAssetsA["libraries"][i]["filename"] into sAppA["libraries"][ the number of elements of sAppA["libraries"] + 1 ]["filename"]
        end repeat
        repeat with i = 1 to the number of elements of tAssetsA["backscripts"]
          put tAssetsA["backscripts"][i]["filename"] into sAppA["backscripts"][ the number of elements of sAppA["backscripts"] + 1 ]["filename"]
        end repeat
        repeat with i = 1 to the number of elements of tAssetsA["frontscripts"]
          put tAssetsA["frontscripts"][i]["filename"] into sAppA["frontscripts"][ the number of elements of sAppA["frontscripts"] + 1 ]["filename"]
        end repeat
        
        set the stackfiles of stack kAppStackName to tStackFiles
      end if
    end if
  
    if tError is not empty then exit repeat
  end repeat
  
  return tError for value
end loadFrameworkHelper


private command loadHelperFolderAssets pFolder, pExternalPackagesInMemory, @xAssetsA, @xStackFiles
  local tError
  local tConfigA
  local tExtensionIndex, tBehaviorIndex, tLibraryIndex, tBackscriptIndex, tFrontscriptIndex
  
  put the number of elements of xAssetsA["extensions"] into tExtensionIndex
  put the number of elements of xAssetsA["behaviors"] into tBehaviorIndex
  put the number of elements of xAssetsA["libraries"] into tLibraryIndex
  put the number of elements of xAssetsA["backscripts"] into tBackscriptIndex
  put the number of elements of xAssetsA["frontscripts"] into tFrontscriptIndex
  
  if there is a file (pFolder & "/helper.yml") then
    put yamlFileToArray(pFolder & "/helper.yml") into tConfigA
    put the result into tError
  else
    # Load up any stacks
    local tFile, tIsAStack, j
  
    put 0 into j
    put empty into tConfigA
    set the itemDelimiter to "/"
  
    repeat for each line tFile in fileListing(pFolder)
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

  if tError is empty then    
    local tKey
  
    # stack files
    repeat with j = 1 to the number of elements of tConfigA["stacks"]
      put pFolder & "/" & normalizeRelativeFilename(tConfigA["stacks"][j]["filename"]) into tConfigA["stacks"][j]["filename"]
      put ensureStackNameIsPresent(tConfigA["stacks"][j]) into tConfigA["stacks"][j]
    
      put tConfigA["stacks"][j]["name"] & "," & tConfigA["stacks"][j]["filename"] & cr after xStackFiles
    end repeat
  
    if the platform is "win32" then put "win" into tKey
    else put the platform into tKey
  
    set the wholematches to true
  
    # externals
    repeat with j = 1 to the number of elements of tConfigA["externals"][tKey]
      if tConfigA["externals"][tKey][j]["name"] is not empty \
            and tConfigA["externals"][tKey][j]["name"] is not among the lines of pExternalPackagesInMemory then
        put pFolder & "/" & normalizeRelativeFilename(tConfigA["externals"][tKey][j]["filename"]) into \
            line (the number of lines of sAppA["externals to load"] + 1) of sAppA["externals to load"]
        put tConfigA["externals"][tKey][j]["name"] into \
            line (the number of lines of sAppA["externals packages to verify"] + 1) of sAppA["externals packages to verify"]
      end if
    end repeat
  
    # extensions
    repeat with j = 1 to the number of elements of tConfigA["extensions"]
      add 1 to tExtensionIndex
      put pFolder & "/" & tConfigA["extensions"][j]["filename"] into xAssetsA["extensions"][tExtensionIndex]["filename"]
    
      if tConfigA["extensions"][j]["resource folder"] is not empty then
        put pFolder & "/" & tConfigA["extensions"][j]["resource folder"] into xAssetsA["extensions"][tExtensionIndex]["resource folder"]
      end if
    
      if tConfigA["extensions"][j]["source"] is not empty then
        put resolveRelativeFilenameReference(tConfigA["extensions"][j]["source"], pFolder) into xAssetsA["extensions"][j]["source"]
      end if
    end repeat
  
    # behaviors, libraries, frontscripts, backscripts
    repeat with j = 1 to the number of elements of tConfigA["behaviors"]
      add 1 to tBehaviorIndex
      put pFolder & "/" & tConfigA["behaviors"][j]["filename"] into xAssetsA["behaviors"][tBehaviorIndex]["filename"]
    end repeat
  
    repeat with j = 1 to the number of elements of tConfigA["libraries"]
      add 1 to tLibraryIndex
      put pFolder & "/" & tConfigA["libraries"][j]["filename"] into xAssetsA["libraries"][tLibraryIndex]["filename"]
    end repeat
  
    repeat with j = 1 to the number of elements of tConfigA["backscripts"]
      add 1 to tBackscriptIndex
      put pFolder & "/" & tConfigA["backscripts"][j]["filename"] into xAssetsA["backscripts"][tBackscriptIndex]["filename"]
    end repeat
  
    repeat with j = 1 to the number of elements of tConfigA["frontscripts"]
      add 1 to tFrontscriptIndex
      put pFolder & "/" & tConfigA["frontscripts"][j]["filename"] into xAssetsA["frontscripts"][tFrontscriptIndex]["filename"]
    end repeat
  end if
  
  return tError for error
end loadHelperFolderAssets


private command loadExternals pFilenames
  local tError
  
  if pFilenames is empty then return empty for value
  
  if there is a stack kApplicationExternals then
    delete stack kApplicationExternals
  end if
  
  /*dispatch "PreloadExternals" to stack kAppStackName with pFilenames
  if it is "handled" then
    put the result into pFilenames
  end if*/
  
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
  return levureStandaloneFolder() & "/" & tFilename
end levureStandaloneFilename


function levureBuildFolder
  return resolveFilenameReference(sAppA["build folder"], levureAppFolder())
end levureBuildFolder


function levureFrameworkFolder
  put the filename of (the long id this me) into tFolder
  set the itemDelimiter to "/"
  delete the last item of tFolder
  return tFolder for value
end levureFrameworkFolder


private function expandMessagePathAssetsFileReferenceArray pFilesA, pRootFolder
  local tFilesA, i, j
  
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
        
        if "source" is among the keys of pFilesA[j] then
          put resolveFilenameReference(pFilesA[i]["source"], pRootFolder) \
                into tFilesA[j]["source"]
        end if
      end if
    end if
  end repeat
  
  replaceVariablesInPaths tFilesA
  
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
  
  repeat with i = 1 to the number of elements of pFilesA      
    if pFilesA[i]["folder"] is not empty then
      put resolveFilenameReference(pFilesA[i]["folder"], pRootFolder) into pFilesA[i]["folder"]
      
      # expand the folder listing. Assume every folder is a helper to load.
      local tFile
      
      repeat for each line tFile in folderListing(pFilesA[i]["folder"])
        if isFilenameUniqueInFilesArray(tFile, tFilesA) then
          add 1 to j
          put tFile into tFilesA[j]["filename"]
        end if
      end repeat
    else if pFilesA[i]["filename"] is not empty then
      put resolveFilenameReference(pFilesA[i]["filename"], pRootFolder) \
        into pFilesA[i]["filename"]
      if isFilenameUniqueInFilesArray(pFilesA[i]["filename"], tFilesA) then
        add 1 to j
        put pFilesA[i]["filename"] into tFilesA[j]["filename"]
      end if
    end if
  end repeat
  
  replaceVariablesInPaths tFilesA
  
  return tFilesA
end expandHelperAssetsFileReferenceArray


private function expandComponentAssetsFileReferenceArray pFilesA, pRootFolder
  local tFilesA, i, j
    
  repeat with i = 1 to the number of elements of pFilesA      
    if pFilesA[i]["folder"] is not empty then
      put resolveFilenameReference(pFilesA[i]["folder"], pRootFolder) into pFilesA[i]["folder"]
      
      # expand the folder listing. Assume every folder is a component to load.
      local tError, tFolder, tFiles, tFile, tFileA
      
      repeat for each line tFolder in folderListing(pFilesA[i]["folder"])
        put empty into tError
        put empty into tFileA
        
        put fileListing(tFolder) into tFiles
        filter tFiles with regex pattern ".*\.livecode$|.*\.livecodescript$"
        
        if tFiles is not empty then
          # Has any file in this folder been loaded already?
          repeat for each line tFile in tFiles
            if not isFilenameUniqueInFilesArray(tFile, tFilesA) then
              put "already loaded" into tError
              exit repeat
            end if
          end repeat
        
          if tError is empty then
            put line 1 of tFiles into tFileA["filename"]
            put ensureStackNameIsPresent(tFileA) into tFileA
          
            if tFileA["name"] is not empty then
              add 1 to j
              put tFileA into tFilesA[j]
            end if
          end if
        end if
      end repeat
      
    else if pFilesA[i]["filename"] is not empty then
      put resolveFilenameReference(pFilesA[i]["filename"], pRootFolder) \
        into pFilesA[i]["filename"]
        
      put ensureStackNameIsPresent(pFilesA[i]) into pFilesA[i]
      
      if pFilesA[i]["name"] is not empty AND isFilenameUniqueInFilesArray(pFilesA[i]["filename"], tFilesA) then
        add 1 to j
        put pFilesA[i]["filename"] into tFilesA[j]["filename"]
        put pFilesA[i]["name"] into tFilesA[j]["name"]
      end if
    end if
  end repeat
  
  replaceVariablesInPaths tFilesA
  
  return tFilesA
end expandComponentAssetsFileReferenceArray


private command replaceVariablesInPaths @pFilesA
  if the environment is "development" then
    local tUserExtensionsFolder, i
    
    put revEnvironmentCustomizationPath() into tUserExtensionsFolder
    
    repeat with i = 1 to the number of elements of pFilesA
      replace "{{USER_EXTENSIONS}}" with tUserExtensionsFolder in pFilesA[i]["filename"]
      if "source" is among the keys of pFilesA[i] then
        replace "{{USER_EXTENSIONS}}" with tUserExtensionsFolder in pFilesA[i]["source"]
      end if
    end repeat
  end if
  
  return empty for value
end replaceVariablesInPaths


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
  set the itemdelimiter to "/"
  put the last item of pFilename into tExt
  set the itemdelimiter to "."
  if the number of items of tExt > 1 then
    return the last item of tExt
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
  local tError
  
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
      put word 1 to -1 of item 2 of tWorkingLine into tValue
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
