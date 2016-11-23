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


after mouseDown pBtnNum
  # Load app if user clicks on button in standalone stack
  if word 1 of the target is "button" then
    if sRuntimePropertiesA["state"] is empty then
      start using me
      startup
    end if
  end if
end mouseDown


on startup
  put "loading" into sRuntimePropertiesA["state"]
  set visible of me to false
  set the loc of me to the screenloc
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
  local tError, tStacksInApp

  if the long id of me is the long id of this me OR word 1 of the long id of me is not "stack" then
    put "the framework is not assigned to a stack as a behavior" into tError
  end if

  if tError is empty then
    if pRootFolder is not empty then
      put normalizeFolderPath(pRootFolder) into sRootFolder
    else
      put levureStandaloneFolder() into sRootFolder
    end if
  end if

  if tError is empty then
    loadAppConfig
    put the result into tError
  end if

  if tError is empty then
    loadCommandLineArguments

    loadAppStack
    put the result into tError
  end if

  if tError is empty then
    loadHelpers tStacksInApp
    put the result into tError
  end if

  if tError is empty then
    set the stackFiles of stack kAppStackName to tStacksInApp
  end if

  return tError for error
end levureInitializeFramework


command levureRunApplication
  local tError, tStacksInApp
  
  if tError is empty then
    put the stackFiles of stack kAppStackName into tStacksInApp
    loadAppAssets tStacksInApp
  end if
  
  # Add lookup for all stacks in app. They will be loaded into memory as needed
  # when referenced by name.
  if tError is empty then
    set the stackFiles of stack kAppStackName to tStacksInApp
    
    dispatch "InitializeApplication" to stack kAppStackName
    if it is "handled" and the result is false then
      ## user can quit app if they want
      if lockMessages is true then unlock messages
      unloadApp
      
      ## Only quit if not in development. This allows developer to troubleshoot.
      if the environment is not "development" then
        quit
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
        return normalizeFolderPath(specialFolderPath("support") & "/" & sAppA["application data folder"])
      case "linux"
        return normalizeFolderPath(specialFolderPath("home") & "/." & sAppA["application data folder"])
      default
        return empty
    end switch
  else
    switch the platform
      case "macos"
        return normalizeFolderPath(specialFolderPath("asup") & "/" & sAppA["application data folder"])
      case "win32"
        return normalizeFolderPath(specialFolderPath("35") & "/" & sAppA["application data folder"])
      case "linux"
        return normalizeFolderPath("/opt/." & sAppA["application data folder"])
      default
        return empty
    end switch
  end if
end levureApplicationDataFolder


function levureApplicationState
  return sRuntimePropertiesA["state"]
end levureApplicationState


function levureAppGet pProp
  if pProp is an array or pProp is among the keys of pProp then
    return sAppA[pProp]
  else
    throw "invalid levure app property:" && pProp
  end if
end levureAppGet


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
    remove stack sAppA["frontscripts"][i]["filename"] from front
  end repeat
  repeat with i = 1 to the number of elements of sAppA["backscripts"]
    remove stack sAppA["backscripts"][i]["filename"] from back
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
    
    put yamlFileToArray(sAppFolder & "/app.yml") into sAppA
    put the result into tError
    
    if tError is empty then
      normalizeAppArray
    end if
    
    # If not explicitly configured, load any libraries, frontscripts, or backscripts
    if tError is empty then
      local i, j
      local tFilesA
      
      ##########
      # Libaries, Backscripts, Frontscripts
      ##########
      local tSource
      
      repeat for each item tSource in "libraries,backscripts,frontscripts,behaviors"
        put empty into tFilesA
        put 0 into j
      
        if there is a folder (levureFrameworkFolder() & "/" & tSource) then
          add 1 to j
          put levureFrameworkFolder() & "/" & tSource into tFilesA[j]["folder"]
        end if
      
        if the number of elements of sAppA[tSource] > 1 then        
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
      
      if the number of elements of sAppA["components"] > 1 then        
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
        add 1 to j
        put levureFrameworkFolder() & "/helpers" into tFilesA[j]["folder"]
      end if
      
      if the number of elements of sAppA["helpers"] > 1 then        
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
      end if
    end if
  end if
  
  if sAppA is not an array then
    put "invalid app.yml file" into tError
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


private command loadAppAssets @xStacks
  local tError
  
  if tError is empty then
    local i
    
    repeat with i = 1 to the number of elements of sAppA["components"]      
      put sAppA["components"][i]["name"] & "," & \
            sAppA["components"][i]["filename"] & cr after xStacks
    end repeat
    if the number of elements of sAppA["components"] > 0 then
      delete the last char of xStacks
    end if
  end if
  
  if tError is empty then
    loadMessagePathAssets sAppA
  end if
  
  return tError
end loadAppAssets


private command loadMessagePathAssets pArrayA
  local tFileIsLoaded
  
  repeat with i = 1 to the number of elements of pArrayA["behaviors"]
    put there is a stack pArrayA["behaviors"][i]["filename"] into tFileIsLoaded
    if tFileIsLoaded then
      # Enable a script only behavior stack to set its own behavior
      dispatch "LoadBehavior" to stack tFileIsLoaded
    end if
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


private command loadHelpers @xStacks
  local tError, i
  local tConfigA
  
  repeat with i = 1 to the number of elements of sAppA["helpers"]
    if there is a file (sAppA["helpers"][i]["filename"] & "/helper.yml") then
      put yamlFileToArray(sAppA["helpers"][i]["filename"] & "/helper.yml") into tConfigA
      put the result into tError
    else
      # Load up any stacks
      local tFile, tIsAStack, j
      
      set the itemDelimiter to "/"
      
      repeat for each line tFile in fileListing(sAppA["helpers"][i]["filename"])
        put there is a stack tFile into tIsAStack
        if tIsAStack then
          add 1 to j
          
          put the short name of stack tFile into tConfigA["stacks"][j]["name"]
          put the last item of tFile into tConfigA["stacks"][j]["filename"]
          delete stack tFile
        end if
      end repeat
      
      set the itemDelimiter to ","
    end if
    
    if tError is empty then
      local tExternals, tKey
      local tExternalPackagesInMemory, tExternalsToVerify, tExternalPackageName
      
      repeat with j = 1 to the number of elements of tConfigA["stacks"]
        put tConfigA["stacks"][j]["name"] & "," & \
              sAppA["helpers"][i]["filename"] & "/" & normalizeRelativeFilename(tConfigA["stacks"][j]["filename"]) & cr after xStacks
      end repeat
      if the number of elements of tConfigA["stacks"] > 0 then
        delete the last char of xStacks
      end if
      
      if the platform is "win32" then put "win" into tKey
      else put the platform into tKey
      
      put levureExternalsLoadedInMemory() into tExternalPackagesInMemory
      set the wholematches to true
      
      repeat with j = 1 to the number of elements of tConfigA["externals"][tKey]
        if tConfigA["externals"][tKey][j]["name"] is not empty \
              and tConfigA["externals"][tKey][j]["name"] is not among the lines of tExternalPackagesInMemory then
          put sAppA["helpers"][i]["filename"] & "/" & normalizeRelativeFilename(tConfigA["externals"][tKey][j]["filename"]) & cr after tExternals
          put tConfigA["externals"][tKey][j]["name"] & cr after tExternalsToVerify
        end if
      end repeat
      # We may not have added any externals to the list
      if the last char of tExternals is cr then
        delete the last char of tExternals
        delete the last char of tExternalsToVerify
      end if
      
      repeat with j = 1 to the number of elements of tConfigA["behaviors"]
        put sAppA["helpers"][i]["filename"] & "/" before tConfigA["behaviors"][j]["filename"]
      end repeat
      
      repeat with j = 1 to the number of elements of tConfigA["libraries"]
        put sAppA["helpers"][i]["filename"] & "/" before tConfigA["libraries"][j]["filename"]
      end repeat
      
      repeat with j = 1 to the number of elements of tConfigA["backscripts"]
        put sAppA["helpers"][i]["filename"] & "/" before tConfigA["backscripts"][j]["filename"]
      end repeat
      
      repeat with j = 1 to the number of elements of tConfigA["frontscripts"]
        put sAppA["helpers"][i]["filename"] & "/" before tConfigA["frontscripts"][j]["filename"]
      end repeat
      
      loadExternals tExternals
      loadMessagePathAssets tConfigA
      
      put levureExternalsLoadedInMemory() into tExternalPackagesInMemory
      repeat for each line tExternalPackageName in tExternalsToVerify
        if tExternalPackageName is not among the lines of tExternalPackagesInMemory then
          put "unable to load external" && tExternalPackageName & cr after tError
        end if
      end repeat
      delete the last char of tError
    end if
    
    if tError is not empty then exit repeat
  end repeat
  
  return tError for error
end loadHelpers


private command loadExternals pFilenames
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
  
  put the effective filename of this stack into tFolder
  set the itemDelimiter to "/"
  delete the last item of tFolder
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
      end if
    end if
  end repeat
  
  replaceVariablesInPaths tFilesA
  
  return tFilesA
end expandMessagePathAssetsFileReferenceArray


private command addFolderToFilesArray pFolder, @xFilesA
  local tFolder, tFile, i
  
  repeat for each line tFolder in folderListing(pFolder)
    addFolderToFilesArray tFolder, @xFilesA
  end repeat
  
  put the number of elements of xFilesA into i
  
  repeat for each line tFile in fileListing(pFolder)
    if isFilenameUniqueInFilesArray(tFile, xFilesA) then
      add 1 to i
      put tFile into xFilesA[i]["filename"]
    end if
  end repeat
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
    local tStackIsLoaded
    
    put there is a stack pFileA["filename"] into tStackIsLoaded
    if tStackIsLoaded then
      put the short name of stack pFileA["filename"] into pFileA["name"]
      delete stack pFileA["filename"]
    end if
  end if
  
  return pFileA
end ensureStackNameIsPresent


private function resolveFilenameReference pFilename, pRootFolder
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
  return not ((the platform is "win32" and item 1 of pFilename contains ":") or pFilename begins with "/")
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
