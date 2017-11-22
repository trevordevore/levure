script "Levure Framework Application Packager"
constant kStandaloneBuilderPlatforms = "MacOSX x86-32,MacOSX x86-64,Windows,Linux,Linux x64,Linux armv6-hf,iOS,Android,Emscripten"
constant kPlatformsThatCantTest = "iOS,Android,Emscripten"
local sAppA, sPassword, sBuildLogFile, sCallbackStacksA, sBuildStandaloneA

on libraryStack
  if the target is not me then pass libraryStack
end libraryStack


on releaseStack
  if the target is not me then pass releaseStack
end releaseStack


private command log pMsg
  local tError

  open file sBuildLogFile for "utf8" text append
  put the result into tError

  if tError is empty then
    write pMsg & cr to file sBuildLogFile
    put the result into tError
  end if

  close file sBuildLogFile

  return tError
end log


private command resetLogging
  put levureBuildFolder() & "/build.log" into sBuildLogFile
  delete file sBuildLogFile
end resetLogging


/**
Summary: Packages an application for configured platforms.

pStandaloneStackFilename: The filename of the standalone stack.
pBuildProfile: The build profile to use when packaging the application.

Returns: Empty

*/
command packagerPackageApplication pStandaloneStackFilename, pBuildProfile
  local tError, tBuildProfile, tBuildStandalone, tStandaloneBuilderPlatforms
  local tSubFolder, tOutputFolder, tAppFolder, tPlatformFilter

  levureLoadAppConfig pBuildProfile

  put levureAppGetConfig() into sAppA
  put pBuildProfile into tBuildProfile

  if pBuildProfile is "ios simulator" then
    put "release" into pBuildProfile
    put false into tBuildStandalone
    put "ios" into tStandaloneBuilderPlatforms
  else if pBuildProfile is "android simulator" then
    put "release" into pBuildProfile
    put false into tBuildStandalone
    put "android" into tStandaloneBuilderPlatforms
  else
    put true into tBuildStandalone
    put kStandaloneBuilderPlatforms into tStandaloneBuilderPlatforms
  end if

  put sAppA["build profiles"][pBuildProfile]["platform filter"] into tPlatformFilter

  _performPackagingPrechecks pStandaloneStackFilename, pBuildProfile
  put the result into tError

  resetLogging
  log "[" & the system date & "] Packaging app using profile" && pBuildProfile

  if tError is empty then
    local tExtensionsBuiltIntoStandalone, tTempFolder, tCopyFilesTempFolder

    put levureAppFolder() into tAppFolder

    put the temporary folder into tTempFolder
    put tTempFolder & "/levure-copy-files-" & the milliseconds into tCopyFilesTempFolder

    if tBuildStandalone then
      put levureAppGet("version") & "-" & levureAppGet("build") into tSubFolder
      put levureBuildFolder() & "/" & pBuildProfile & "/" & tSubFolder into tOutputFolder

      log "Output folder:" && tOutputFolder

      if there is a folder tOutputFolder then
        _deleteFolder tOutputFolder
        if the result is not empty then
          put "error deleting existing package folder:" && the result into tError
        end if
      end if
    else
      put tCopyFilesTempFolder into tOutputFolder
    end if
  end if

  if tError is empty then
    local tPlatform, tBuildPlatform
    local tAppA, tWorkingOutputFolder, tExecutableOutputFolder
    local tCertName

    put the cRevStandaloneSettings["extensions"] of stack pStandaloneStackFilename into tExtensionsBuiltIntoStandalone

    repeat for each item tBuildPlatform in tStandaloneBuilderPlatforms
      put _buildPlatformToLevurePlatform(tBuildPlatform) into tPlatform

      if not the cRevStandaloneSettings[tBuildPlatform] of stack pStandaloneStackFilename then next repeat
      if tPlatform is "macos" and the platform is not "macos" then next repeat
      if not _shouldBuildForPlatform(tPlatform, tPlatformFilter) then next repeat

      # Create folder for copy files
      log "packaging for platform:" && tPlatform

      _determineSigningCertificate pBuildProfile, tPlatform, sAppA

      # Create version of app array that will be modfiied and stored with package
      put sAppA into tAppA

      if tError is empty then
        packagerCreateAllFoldersInPath tCopyFilesTempFolder, tTempFolder
        put _errorMsg("creating copy files temp folder [" & tCopyFilesTempFolder & "] [" & tTempFolder & "]", the result) into tError
      end if

      # Send before filenames are made relative. Gives helpers a chance to modify
      # tAppA list of assets.
      if tError is empty then
        _dispatchFinalizePackagedAssets pBuildProfile, tPlatform, tAppA, tAppFolder
      end if

      # Copy over all files
      if tError is empty then
        _prepareAppFilesForStandaloneBuilding pStandaloneStackFilename, pBuildProfile, tPlatform, tAppA, tCopyFilesTempFolder
        put the result into tError
      end if

      # Process target specific instructions in "copy files"
      if tError is empty then
        _copyFiles pBuildProfile, tPlatform, tAppA, tAppFolder, tCopyFilesTempFolder
        put the result into tError
      end if

      # Process instructions for all platform
      if tError is empty then
        _copyFiles pBuildProfile, "all platforms", tAppA, tAppFolder, tCopyFilesTempFolder
        put the result into tError
      end if

      # Prune and move in app stack
      if tError is empty then
        local tSourceStackFilename, tTargetStackFilename, isReloaded

        _pruneAppArray tAppA, pBuildProfile, tPlatform

        log "tAppA:" && _printArray(tAppA,,true)

        set the itemdelimiter to "/"

        # Copy over framework file. Mobile standalone builder won't copy it. Desktop will.
        put levureFrameworkFilename() into tSourceStackFilename
        put tCopyFilesTempFolder & "/" & the last item of tSourceStackFilename into tTargetStackFilename
        _fileCopyFile tSourceStackFilename, tTargetStackFilename
        put _errorMsg("copying file [" & tSourceStackFilename & "] to [" & tTargetStackFilename & "]", the result) into tError

        if tError is empty then
          put levureAppStackFilename() into tSourceStackFilename
          put tCopyFilesTempFolder & "/" & the last item of tSourceStackFilename into tTargetStackFilename

          log "Source stack filename:" && tSourceStackFilename
          log "App stack filename:" && tTargetStackFilename

          _fileCopyFile tSourceStackFilename, tTargetStackFilename
          put _errorMsg("copying file [" & tSourceStackFilename & "] to [" & tTargetStackFilename & "]", the result) into tError
        end if

        if tError is empty then
          delete stack tSourceStackFilename

          set the scriptonly of stack tTargetStackFilename to false
          set the uAppA of stack tTargetStackFilename to tAppA
          _setPassword tTargetStackFilename, sPassword
          save stack tTargetStackFilename with newest format
          put _errorMsg("saving app stack", the result) into tError
          put the result into tError

          delete stack tTargetStackFilename
          put there is a stack tSourceStackFilename into isReloaded
        end if

        set the itemdelimiter to ","
      end if

      # Now build standalone for target platform
      if tError is empty then
        local tCopyFiles
        put _createCopyFilesListFromFolder(tCopyFilesTempFolder) into tCopyFiles

        log "Build: copy files list for platform" && tPlatform & ":" & cr & tCopyFiles

        if tBuildStandalone then
          packagerBuildStandalones pStandaloneStackFilename, tBuildPlatform, pBuildProfile, \
                tSubFolder, tCopyFiles, tAppA
          put the result into tError
        else
          set the cRevStandaloneSettings["files"] of stack pStandaloneStackFilename to tCopyFiles
        end if
      end if

      if tError is empty then
        # Refresh after having unloaded for standalone builder
        levureLoadAppConfig pBuildProfile

        _dispatchFinalizeBuildForPlatform pBuildProfile, tPlatform, sAppA, tAppFolder, tOutputFolder & "/" & tPlatform

        # dispatch and then sign macos bundle
        if tPlatform is "macos" then
          _signMacOSApplication pBuildProfile, sAppA, tOutputFolder & "/" & tPlatform
          put the result into tError
        end if

        if tPlatform is "macos" and pBuildProfile is "mac app store" then
          log "Packaging for Mac App Store"
          _packageForMAS sAppA, tOutputFolder & "/" & tPlatform
          put the result into tError
        end if
      end if

      # If not building standalone then leave folder in place. We are building for a simulator.
      if tBuildStandalone and there is a folder tCopyFilesTempFolder then
        _deleteFolder tCopyFilesTempFolder
      end if

      if tError is not empty then
        exit repeat
      end if
    end repeat
  end if

  # Process "package folder" key in "copy files"
  if tBuildStandalone then
    if tError is empty then
      _copyFiles pBuildProfile, "package folder", sAppA, tAppFolder, tOutputFolder
      put the result into tError
    end if

    if tError is empty then
      _dispatchPackagingComplete pBuildProfile, sAppA, tOutputFolder
    end if
  end if

  # Remove callback stacks from memory
  local tCallbackStacks

  repeat for each key tFilename in sCallbackStacksA
    if there is a stack tFilename then
      delete stack tFilename
    end if
  end repeat
  put empty into sCallbackStacksA

  if tError is not empty then
    log "Done packaging application with error:" && tError
    answer error tError
  else
    log "Done packaging application"
  end if

  send "packagerDidFinishPackagingApplication pStandaloneStackFilename, tBuildProfile" to stack pStandaloneStackFilename in 10 milliseconds
end packagerPackageApplication


private command _determineSigningCertificate pBuildProfile, pPlatform, @xAppA
  local tCertName

  put xAppA["build profiles"][pBuildProfile]["certificates"][pPlatform]["name"] into tCertName
  if tCertName is empty then
    put xAppA["build profiles"]["all profiles"]["certificates"][pPlatform]["name"] into tCertName
  end if

  if tCertName is not empty then
    if pBuildProfile is "mac app store" then
      put "3rd Party Mac Developer Application:" && tCertName into xAppA[pPlatform && "signing certificate"]
      put "3rd Party Mac Developer Installer:" && tCertName into xAppA[pPlatform && "installer signing certificate"]
    else if pBuildProfile is "mac app store development" then
      put "Mac Developer:" && tCertName into xAppA[pPlatform && "signing certificate"]
    else
      put "Developer ID Application:" && tCertName into xAppA[pPlatform && "signing certificate"]
    end if
  end if
end _determineSigningCertificate


private command _setPassword pStackName, pPassword
  if revLicenseType() is not "community" then
    if pPassword is not empty then
      log "  Encrypting stack" && pStackName
      set the password of stack pStackName to pPassword
    end if
  else
    log "  Skipping encryption in Community edition" && pStackName
  end if
  return empty
end _setPassword


private command _prepareAppFilesForStandaloneBuilding pStandaloneStackFilename, pBuildProfile, pPlatform, @xAppA, pOutputFolder
  local tError

  # Behaviors, Libraries, Frontscripts, Backscripts
  # Create single stack for each and move all as substacks of single stack.
  # For libraries, frontscripts, and backscripts store a custom property with order to load them in.
  if tError is empty then
    _packageAssetStacks pBuildProfile, xAppA, pOutputFolder
    put the result into tError
  end if

  # Extensions
  # Move straight across
  if tError is empty then
    _packageExtensions pBuildProfile, xAppA, pOutputFolder, the cRevStandaloneSettings["extensions"] of stack pStandaloneStackFilename
    put the result into tError
  end if

  # UI
  # Move straight across.
  # Convert script only stacks to regular stacks
  if tError is empty then
    _packageUI pBuildProfile, pPlatform, xAppA, pOutputFolder
    put the result into tError
  end if

  # Helpers
  # Move straight over
  # Convert any script only stacks to stacks
  # Remove helper.yml file.
  if tError is empty then
    _packageHelpers pBuildProfile, xAppA, pPlatform, pOutputFolder, pOutputFolder
    put the result into tError
  end if

  # Files
  # Move straight over
  if tError is empty then
    _packageFiles pBuildProfile, xAppA, pOutputFolder
    put the result into tError
  end if

  return tError for error
end _prepareAppFilesForStandaloneBuilding



private function _createCopyFilesListFromFolder pFolder
  local tFiles, tFolders

  put _fileListing(pFolder) into tFiles
  if tFiles is not empty then put cr after tFiles
  put _folderListing(pFolder) into tFolders
  repeat for each line tFolder in tFolders
    put tFolder & "/*" & cr after tFiles
  end repeat
  delete the last char of tFiles
  return tFiles
end _createCopyFilesListFromFolder


private command _pruneAppArray @xAppA, pBuildProfile, pPlatform
  local tKeysToDelete
  local tFilename
  local tCallbackStacks

  delete local xAppA["password"]
  delete local xAppA["build folder"]
  delete local xAppA["encrypt stacks"]
  delete local xAppA["build profiles"]
  delete local xAppA["creator code"]
  delete local xAppA["externals packages to verify"]
  delete local xAppA["externals to load"]
  delete local xAppA["packager callbacks stackfiles"]

  switch pPlatform
    case "windows"
      put "macos,linux,ios,android" into tKeysToDelete
      break
    case "macos"
      put "windows,linux,ios,android" into tKeysToDelete
      break
    case "linux"
      put "windows,macos,ios,android" into tKeysToDelete
      break
    case "android"
      put "linux,windows,macos,ios" into tKeysToDelete
      break
    case "ios"
      put "linux,windows,macos,android" into tKeysToDelete
      break
  end switch

  repeat for each item tKey in tKeysToDelete
    delete local xAppA["preferences filename"]["user"][tKey]
    delete local xAppA["preferences filename"]["shared"][tKey]
  end repeat

  return empty for error
end _pruneAppArray


private function _toArray
  local i, tA
  repeat with i = 1 to the paramcount
    put param(i+1) into tA[param(i)]
    add 1 to i
  end repeat
  return tA
end _toArray


private function _packagerCallbackStacks pAppA, pBuildProfile
  local tCallbackStacks

  put sAppA["packager callbacks stackfiles"] into tCallbackStacks
  if _packagerCallbacksStackFile(pAppA, pBuildProfile) is not empty then
    put _packagerCallbacksStackFile(pAppA, pBuildProfile) into line (the number of lines of tCallbackStacks + 1) of tCallbackStacks
  end if

  return tCallbackStacks
end _packagerCallbackStacks


private command _dispatchFinalizeBuildForPlatform pBuildProfile, pPlatform, pAppA, pAppFolder, pOutputFolder
  local tCallbackStacks, tFilename

  # Send callbacks
  put _packagerCallbackStacks(pAppA, pBuildProfile) into tCallbackStacks
  repeat for each line tFilename in tCallbackStacks
    log "Dispatching finalizePackageForPlatform to stack" && tFilename

    dispatch "finalizePackageForPlatform" to stack tFilename with pBuildProfile, pPlatform, pAppFolder, pOutputFolder
    put "" into sCallbackStacksA[ tFilename ]
  end repeat
end _dispatchFinalizeBuildForPlatform


private command _dispatchFinalizePackagedAssets pBuildProfile, pPlatform, @xAppA, pAppFolder
  local tCallbackStacks, tFilename

  # Send callbacks
  put _packagerCallbackStacks(xAppA, pBuildProfile) into tCallbackStacks
  repeat for each line tFilename in tCallbackStacks
    log "Dispatching finalizePackagedAssets to stack" && tFilename

    dispatch "finalizePackagedAssets" to stack tFilename with pBuildProfile, pPlatform, xAppA, pAppFolder
    put "" into sCallbackStacksA[ tFilename ]
  end repeat
end _dispatchFinalizePackagedAssets


private command _dispatchPackagingComplete pBuildProfile, pAppA, pOutputFolder
  local tCallbackStacks, tFilename

  # Send callbacks
  put _packagerCallbackStacks(pAppA, pBuildProfile) into tCallbackStacks
  repeat for each line tFilename in tCallbackStacks
    log "Dispatching packagingComplete to stack" && tFilename

    dispatch "packagingComplete" to stack tFilename with pBuildProfile, pOutputFolder
  end repeat
end _dispatchPackagingComplete


command packagerBuildStandaloneForTesting pStandaloneStackFilename
  local tError, tOutputFolder
  local tBuildProfile = "test"

  resetLogging
  log "[" & the system date & "] Packaging app using profile test"

  put levureBuildFolder() & "/" & tBuildProfile into tOutputFolder
  log "Output folder:" && tOutputFolder

  if there is a folder tOutputFolder then
    _deleteFolder tOutputFolder
    if the result is not empty then
      put "unable to delete output folder for standalone testing:" && the result into tError
    end if
  end if

  if tError is empty then
    repeat for each item tBuildPlatform in kStandaloneBuilderPlatforms
      if tBuildPlatform is among the items of kPlatformsThatCantTest \
            OR not the cRevStandaloneSettings[tBuildPlatform] of stack pStandaloneStackFilename then next repeat

      packagerBuildStandalones pStandaloneStackFilename, tBuildPlatform, tBuildProfile, empty, sAppA
      put the result into tError

      if tError is empty then
        # Refresh after having unloaded for standalone builder
        levureLoadAppConfig
      end if

      if tError is not empty then
        exit repeat
      end if
    end repeat
  end if

  if tError is not empty then
    log "Done building standalone for testing with error:" && tError
    answer error tError
  else
    log "Done building standalone for testing"
  end if

  send "packagerDidFinishBuildingStandaloneForTesting" to stack pStandaloneStackFilename in 10 milliseconds
end packagerBuildStandaloneForTesting


command packagerBuildStandalones pStandaloneStackFilename, pBuildForPlatform, pBuildProfile, pSubfolder, pCopyFiles, pPrunedAppA
  local tError
  local buildForDistribution, tTempBuildFolder, tSourceFolder, tOutputFolder

  if the keys of sAppA is empty then
    put levureAppGetConfig() into sAppA
  end if
  put levureAppFolder() into sBuildStandaloneA["app folder"]
  put pBuildProfile into sBuildStandaloneA["build profile"]
  put _buildPlatformToLevurePlatform(pBuildForPlatform) into sBuildStandaloneA["target platform"]
  put _packagerCallbackStacks(sAppA, pBuildProfile) into sBuildStandaloneA["callback stacks"]
  put pPrunedAppA into sBuildStandaloneA["app array"]

  put tolower(pBuildProfile) into pBuildProfile

  _validateBuildProfile pBuildProfile
  put the result into tError

  log "Build: Building standalones for profile:" && pBuildProfile

  put word 1 to -1 of line 1 of pSubfolder into pSubfolder

  set the itemdelimiter to "/"

  put pBuildProfile is not "test" into buildForDistribution
  put levureBuildFolder() into tOutputFolder

  local tAppPath, tStandaloneFolder

  put levureAppFolder() into tAppPath
  put levureStandaloneFolder() into tStandaloneFolder

  # tFrameworkFilename is to work around issue where framework isn't being hooked
  # up as the behavior at the end of handler when reloading standalone stack and putting
  # it in use. See code at end of handler that uses tFrameworkFilename.
  local tFrameworkFilename
  put the filename of stack "levureFramework" into tFrameworkFilename

  put the effective filename of stack pStandaloneStackFilename into tSourceFolder
  delete the last item of tSourceFolder

  if tError is empty then
    if tOutputFolder is empty then
      put "no build folder has been set" into tError
    end if
    if buildForDistribution and pSubfolder is empty then
      put "subfolder cannot be empty" into tError
    end if
    if levureAppGet("version") is empty then
      put "version has not been set" into tError
    end if
  end if

  if tError is empty then
    if there is not a folder tOutputFolder then
      create folder tOutputFolder
      put _errorMsg("creating folder [" & tOutputFolder & "]", the result) into tError
    end if
  end if

  if tError is empty then
    if buildForDistribution then
      put "/" & pBuildProfile after tOutputFolder
      put "/" & pSubfolder after tOutputFolder
    else
      put "/" & pBuildProfile after tOutputFolder
    end if

    if there is not a folder tOutputFolder then
      packagerCreateAllFoldersInPath tOutputFolder, levureBuildFolder()
      put _errorMsg("creating folder [" & tOutputFolder & "]", the result) into tError
    end if

    log "Build: Output folder:" && tOutputFolder
  end if

  if tError is empty then
    log "Build: Update standalone version info"

    _updateStandaloneVersionInfo pStandaloneStackFilename
    put the result into tError
  end if

  if tError is empty then
    log "Build: Saving stack using IDE call"

    revIDESaveStack the long id of stack pStandaloneStackFilename
    put _errorMsg("calling revIDESaveStack [" & pStandaloneStackFilename & "]", the result) into tError
  end if

  # Build startup script before unloading framework stack
  if tError is empty then
    local tStackFiles, tLineNo

    set the itemdelimiter to ","

    put the stackfiles of stack pStandaloneStackFilename into tStackFiles
    put lineoffset("levureFramework", tStackFiles) into tLineNo
    if tLineNo is 0 then
      put "levureFramework is not assigned to the stackfiles of the standalone stack" into tError
    end if
  end if

  if tError is empty then
    local tFrameworkPath, tScript

    put item 2 to -1 of line tLineNo of tStackFiles into tFrameworkPath
    put _resolveRelativeFilenameReference(tFrameworkPath, tSourceFolder) into tFrameworkPath
    put _makeRelativePath(tFrameworkPath, tOutputFolder) into tFrameworkPath
    put levureAppFolder() into tAppPath

    if buildForDistribution then
      replace tStandaloneFolder with empty in tAppPath
      if tAppPath begins with "/" then
        delete char 1 of tAppPath
      end if
    else
      put _makeRelativePath(tAppPath, tOutputFolder) into tAppPath
    end if

    put _generateStartupScript(tFrameworkPath, tAppPath, buildForDistribution) into tScript
    if the script of stack pStandaloneStackFilename is not empty then
      put cr & cr & the script of stack pStandaloneStackFilename after tScript
    end if

    log "Build: Startup script:" && tScript
  end if

  # Create new stack to build standalone with
  if tError is empty then
    local tTempStandaloneStack

    put tSourceFolder & "/levureBuildStandaloneTemp_" & the milliseconds & ".livecode" into tTempStandaloneStack

    log "Build: Temp stack:" && tTempStandaloneStack

    # Stop using first. See: http://quality.livecode.com/show_bug.cgi?id=19246
    stop using stack pStandaloneStackFilename
    _unloadStackAndStackFiles pStandaloneStackFilename

    _fileCopyFile pStandaloneStackFilename, tTempStandaloneStack
    put the result into tError
  end if

  if tError is empty then
    if not buildForDistribution then
      set the stackfiles of stack tTempStandaloneStack to empty
      set the behavior of stack tTempStandaloneStack to empty
    end if
  end if

  if tError is empty then
    set the uBuildProfile of stack tTempStandaloneStack to pBuildProfile
    set the script of stack tTempStandaloneStack to tScript

    if pBuildProfile is "test" then
      local tScriptLibraries

      set the wholematches to true

      put the cRevStandaloneSettings["scriptLibraries"] of stack tTempStandaloneStack into tScriptLibraries
      if "Remote Debugger" is not among the lines of tScriptLibraries then
        put "Remote Debugger" into line (the number of lines of tScriptLibraries + 1) of tScriptLibraries
        set the cRevStandaloneSettings["scriptLibraries"] of stack tTempStandaloneStack to tScriptLibraries
      end if
    end if

    # Only build for target platform
    repeat for each item tPlatform in kStandaloneBuilderPlatforms
      set the cRevStandaloneSettings[tPlatform] of stack tTempStandaloneStack to tPlatform is pBuildForPlatform
    end repeat

    set the cRevStandaloneSettings["files"] of stack tTempStandaloneStack to pCopyFiles

    log "Build: Saving temporary stack with IDE call"

    revIDESaveStack the long id of stack tTempStandaloneStack
    put the result into tError
  end if

  ## Now build standalones
  if tError is empty then
    local tStack

    put the short name of stack tTempStandaloneStack into tStack
    put specialFolderPath("temporary") into tTempBuildFolder
    put "/revstandalone" & the milliseconds after tTempBuildFolder
    # Assign defaultBuildFolder so that IDE doesn't ask you to save stack
    set the cRevStandaloneSettings["defaultBuildFolder"] of stack tTempStandaloneStack to tTempBuildFolder
    try
      log "Build: revSaveAsStandalone"

      revSetTestEnvironment true

      # Intercept standaloneSaved and dispatch custom message.
      local tFrontScriptFilename

      put the filename of me into tFrontScriptFilename
      set the itemDelimiter to "/"
      put "packager_frontscript.livecodescript" into the last item of tFrontScriptFilename
      insert script of stack tFrontScriptFilename into front

      # This will trigger a "purge stack" error for the levureFramework stack. The stack in question resides
      # in the tmp stack where LiveCode builds the standalone. My guess is that the
      # revSaveAsStandalone handler is not unloading the stackfiles stacks that the engine automatically loads
      # when loading a stack. See _unloadStackAndStackFiles in packager.livecodescript and look at adding same logic
      # to the LiveCode revSaveAsStandalone handler.
      dispatch "revSaveAsStandalone" to stack "revSaveAsStandalone" with tStack, tTempBuildFolder,, true
      put the result into tError
    catch e
      put e into tError
    finally
      revSetTestEnvironment false
      remove script of stack tFrontScriptFilename from front
      put empty into sBuildStandaloneA
    end try
  end if

  ## Finally, copy standalones to proper folder
  if tError is empty then
    log "Build: copy standalones to proper folder"

    _copyExecutablesAndSupportingFilesToFolder _buildPlatformToLevurePlatform(pBuildForPlatform), buildForDistribution, tTempBuildFolder, tOutputFolder
    put the result into tError
  end if

  if there is a folder tTempBuildFolder then
    _deleteFolder tTempBuildFolder
  end if
  if there is a file tTempStandaloneStack then
    stop using stack tTempStandaloneStack
    _unloadStackAndStackFiles tTempStandaloneStack
    delete file tTempStandaloneStack
  end if

  # reload
  # framework stack may be the tmp folder version. Just unload as it will be reloaded
  # when loading the original standalone stack back into memory. Once LiveCode uploads
  # standalone builder with update that unloads stackFiles during standalone builder then
  # this code can be removed.
  if there is a stack "levureFramework" then
    delete stack "levureFramework"
  end if

  # Problem: Reopening this stack isn't loading the behavior of the stack (levureFramework).
  # back into memory. Why? Outside of this handler the engine always loads the behavior script.
  # Workaround: Grab the filename of stack at beginning of handler. Specifically reassign the
  # behavior before putting the standalone stack back in use.
  go stack pStandaloneStackFilename
  set the behavior of stack pStandaloneStackFilename to empty
  set the behavior of stack pStandaloneStackFilename to the long id of stack tFrameworkFilename
  start using stack pStandaloneStackFilename

  return tError
end packagerBuildStandalones


command packagerStandaloneSaved pFolderSavedIn
  local tStack, tError

  if the last char of pFolderSavedIn is "/" then delete the last char of pFolderSavedIn

  if sBuildStandaloneA["target platform"] is "macos" then
    local tAppBundle

    # Use .app bundle path
    put folders(pFolderSavedIn) into tAppBundle
    filter tAppBundle with "*.app"
    put pFolderSavedIn & "/" & tAppBundle into pFolderSavedIn

    _copyFiles sBuildStandaloneA["build profile"], "macos resources", sAppA, \
          sBuildStandaloneA["app folder"], pFolderSavedIn & "/Contents/Resources"
    put the result into tError
  end if

  if tError is empty then
    repeat for each line tStack in sBuildStandaloneA["callback stacks"]
      dispatch "finalizeStandaloneForPlatform" to stack tStack \
            with sBuildStandaloneA["build profile"], sBuildStandaloneA["target platform"], \
            sBuildStandaloneA["app array"], sBuildStandaloneA["app folder"], pFolderSavedIn
    end repeat
  end if

  if tError is not empty then
    answer error "Unable to copy `macos resources` files:" && tError & "."
  end if
end packagerStandaloneSaved


command packagerMobileStandaloneSaved pTargetType, pAppBundle
  local tStack, tError

  if the last char of pAppBundle is "/" then delete the last char of pAppBundle

  if sBuildStandaloneA["target platform"] is "macos" then
    _copyFiles sBuildStandaloneA["build profile"], "macos resources", sAppA, \
          sBuildStandaloneA["app folder"], pAppBundle & "/Contents/Resources"
    put the result into tError
  end if

  if tError is empty then
    repeat for each line tStack in sBuildStandaloneA["callback stacks"]
      dispatch "finalizeStandaloneForPlatform" to stack tStack \
            with sBuildStandaloneA["build profile"], sBuildStandaloneA["target platform"], \
            sBuildStandaloneA["app array"], sBuildStandaloneA["app folder"], pAppBundle
    end repeat
  end if

  if tError is not empty then
    answer error "Unable to copy `macos resources` files:" && tError & "."
  end if
end packagerMobileStandaloneSaved


private function _packagerCallbacksStackFile pAppA, pBuildProfile
  local tFilename

  put pAppA["build profiles"][pBuildProfile]["packager callbacks stackfile"] into tFilename
  if tFilename is empty then
    put pAppA["build profiles"]["all profiles"]["packager callbacks stackfile"] into tFilename
  end if

  if tFilename is not empty then
    put _resolveRelativeFilenameReference(tFilename, levureAppFolder()) into tFilename
    return tFilename for value
  else
    return empty for value
  end if
end _packagerCallbacksStackFile


private function _buildPlatformToLevurePlatform pBuildPlatform
  switch pBuildPlatform
  case "Windows"
    return "windows"
  case "MacOSX x86-32"
  case "MacOSX x86-64"
    return "macos"
  case "Linux"
  case "Linux x64"
  case "Linux armv6-hf"
    return "linux"
  case "iOS"
    return "ios"
  case "Android"
    return "android"
  case "Emscripten"
    return "emscripten"
  default
    throw param(0) && "invalid build platform:" && pBuildPlatform
  end switch
end _buildPlatformToLevurePlatform


private function _errorMsg pPrefix, pError
  if pError is not empty then
    if pError is not empty AND pError is not "cancel" AND pError is not "cancelled" then
        return pPrefix && "(" & pError & ")"
    end if
  end if
  return empty
end _errorMsg


/**
Summary: Process the "copy files" section of the application configuration.

pBuildProfile: The target build profile.
pTargetPlatform: The platform to target when copying files.
pAppA: The app config array to process.
pRootFolder: Root folder to use for resolving relative paths.
pDestinationFolder: Location where files are being copied to.

Returns: Error message
*/
private command _copyFiles pBuildProfile, pTargetPlatform, pAppA, pRootFolder, pDestinationFolder
  local tError
  local i, tProfile, tFilename, tFiledata, tFoldersA

  if pTargetPlatform is not among the items of "package folder,all platforms,macos,macos resources,windows,linux,ios,ios resources,android,emscripten" then \
        throw "invalid target platform for copy files action:" && pTargetPlatform

  put tolower(pBuildProfile) into pBuildProfile

  set the itemdelimiter to "/"

  if tError is empty then
    local tDestination, tFilesA, tKey, tIndex, tMaintainFilenameFolderStructure

    log "Copying files for" && pTargetPlatform

    repeat for each item tProfile in "all profiles/" & pBuildProfile
      # Build list of files to copy over. Start with known files for target platform.
      put pAppA["build profiles"][tProfile]["copy files"][pTargetPlatform] into tFilesA
      put the number of elements of tFilesA into tIndex

      # Now add in any "copy files" registered components that target this platform
      repeat for each key tKey in pAppA["registered components"]["copy files"]
        if pAppA["registered components"]["copy files"][tKey]["target platform"] is pTargetPlatform then
          repeat with i = 1 to the number of elements of pAppA["build profiles"][tProfile]["copy files"][tKey]
            add 1 to tIndex
            put pAppA["build profiles"][tProfile]["copy files"][tKey][i] into tFilesA[tIndex]
            put pAppA["registered components"]["copy files"][tKey]["callback stackfile"] into tFilesA[tIndex]["callback stackfile"]
            put pAppA["registered components"]["copy files"][tKey]["destination"] into tFilesA[tIndex]["destination"]
          end repeat
        end if
      end repeat

      repeat with i = 1 to the number of elements of tFilesA
        # Don't process an empty entry
        if tFilesA[i]["filename"] is empty then next repeat
        if not _doesStringPassFilter(pBuildProfile, tFilesA[i]["build profiles filter"]) then next repeat

        put not (tFilesA[i]["filename"] begins with "../") into tMaintainFilenameFolderStructure

        # Figure out destination
        put tFilesA[i]["destination"] into tDestination

        if tDestination is empty then
          # If filename is not relative and contains a folder reference then use same folder structure when moving to destination.
          if tMaintainFilenameFolderStructure and the number of items of tFilesA[i]["filename"] > 1 then
            put pDestinationFolder & "/" & item 1 to -2 of tFilesA[i]["filename"] into tDestination
          else
            put pDestinationFolder into tDestination
          end if
        else
          put pDestinationFolder & "/" & _normalizeRelativeFilename(tDestination) into tDestination
          # tDestination may have been `./` or `/`.
          if the last char of tDestination is "/" then
            delete the last char of tDestination
          end if
        end if

        packagerCreateAllFoldersInPath tDestination, pDestinationFolder
        put _errorMsg("creating folder" && tDestination, the result) into tError

        # Copy file or folder
        if tError is empty then
          put _resolveRelativeFilenameReference(tFilesA[i]["filename"], pRootFolder) into tFilename

          if there is a file tFilename then
            log "  Copying file" && tFilename && "to" && tDestination

            put URL("binfile:" & tFilename) into tFiledata

            # Send callbacks
            if tFilesA[i]["callback stackfile"] is not empty then
              log "Dispatching processCopyFilesFile to stack" && tFilesA[i]["callback stackfile"]

              dispatch "processCopyFilesFile" to stack tFilesA[i]["callback stackfile"] \
                    with pBuildProfile, tFiledata, tDestination, the last item of tFilename, tFilesA[i]

              # Store for unloading at end of packaging
              put "" into sCallbackStacksA[ tFilesA[i]["callback stackfile"] ]
            end if

            put tFiledata into URL("binfile:" & tDestination & "/" & the last item of tFilename)
            put _errorMsg("storing file" && tDestination & "/" & the last item of tFilename, the result) into tError
          else if there is a folder tFilename then
            local tTargetFolder

            put tDestination & "/" & the last item of tFilename into tTargetFolder

            if there is a folder tTargetFolder then
              _copyFilesAndFolders tFilename, tTargetFolder
              put _errorMsg("copying file" && tFilename && "to" && tTargetFolder, the result) into tError
            else
              _fileCopyFolder tFilename, tTargetFolder
              put _errorMsg("copying file" && tFilename && "to" && tTargetFolder, the result) into tError
            end if
          else
            put "unable to locate file [" & tFilename & "]" into tError
          end if
        end if

        if tError is not empty then exit repeat
      end repeat

      if tError is not empty then exit repeat
    end repeat
  end if

  return tError for error
end _copyFiles


private command _packageHelpers pBuildProfile, @xAppA, pPlatform, pOutputFolder, pExecutableOutputFolder
  local tError, i, tIndex, tHelpersA
  local tPlatformKey, tRootFolder

  if the number of elements of xAppA["helpers"] > 0 then
    if pPlatform is "win32" then put "windows" into tPlatformKey
    else put tolower(pPlatform) into tPlatformKey

    log "Packaging Helpers for platform" && pPlatform

    repeat with i = 1 to the number of elements of xAppA["helpers"]
      if not _shouldAssetBeDistributed(xAppA["helpers"][i], pBuildProfile) then
        log "  Skipping helper:" && xAppA["helpers"][i]["filename"]
        next repeat
      end if

      if there is not a folder xAppA["helpers"][i]["filename"] then
        put "helper folder not found:" && xAppA["helpers"][i]["filename"] into tError
      end if

      if tError is empty then
        _packageHelper pBuildProfile, xAppA["helpers"][i], pOutputFolder, pExecutableOutputFolder, tPlatformKey
        put the result into tError
      end if

      # Create new array with excluded elements removed
      if tError is empty then
        add 1 to tIndex
        put xAppA["helpers"][i] into tHelpersA[tIndex]
      end if

      if tError is not empty then exit repeat
    end repeat

    # Store reindexed version of array
    put tHelpersA into xAppA["helpers"]
  end if

  return tError for error
end _packageHelpers


private command _packageHelper pBuildProfile, @xHelperA, pOutputFolder, pExecutableOutputFolder, pPlatform
  local tError, tExclusions, tDestFolder, tExecutableDestFolder, tFolder
  local tKey, i
  local tRootFolder
  local tIndex, tHelpersA

  set the itemdelimiter to "/"

  put pOutputFolder & "/helpers/" & the last item of xHelperA["filename"] into tDestFolder
  put pExecutableOutputFolder & "/helpers/" & the last item of xHelperA["filename"] into tExecutableDestFolder

  # When creating all folders make sure we work from a common root folder
  if pExecutableOutputFolder ends with ".app/Contents/MacOS" then
    put item 1 to -3 of pOutputFolder into tRootFolder
  else
    put pOutputFolder into tRootFolder
  end if

  log "  Adding helper:" && xHelperA["filename"]

  packagerCreateAllFoldersInPath tDestFolder, tRootFolder
  put the result into tError

  if tError is empty then

    # ui, libraries, frontscripts, backscripts, and behaviors
    repeat for each item tKey in "ui/libraries/frontscripts/backscripts/behaviors"
      put empty into tHelpersA
      put 0 into tIndex

      repeat with i = 1 to the number of elements of xHelperA[tKey]
        if not _shouldAssetBeDistributed(xHelperA[tKey][i], pBuildProfile) then
          log "  Skipping helper" && tKey && ":" && xHelperA[tKey]["filename"]
          next repeat
        end if

        log "  Adding" && tKey && "helper file:" && xHelperA[tKey][i]["filename"]
        log "    to folder:" && tDestFolder

        _fileCopyFile xHelperA[tKey][i]["filename"], tDestFolder
        put the result into tError

        if tError is empty then
          if xHelperA["encrypt"] is false OR xHelperA[tKey][i]["encrypt"] is false then
            put tDestFolder & "/" & the last item of xHelperA[tKey][i]["filename"] & cr after tExclusions
          end if

          replace (xHelperA["filename"] & "/") with empty in xHelperA[tKey][i]["filename"]

          # Create new array with excluded elements removed
          add 1 to tIndex
          put xHelperA[tKey][i] into tHelpersA[tIndex]
        end if

        if tError is not empty then exit repeat
      end repeat

      # Store reindexed version of array
      if tError is empty then
        put tHelpersA into xHelperA[tKey]
      end if

      if tError is not empty then exit repeat
    end repeat

    # externals
    repeat for each key tKey in xHelperA["externals"]
      if tKey is not pPlatform then
        log "  Skipping helper external platform" && tKey & ", target platform:" && pPlatform
        delete local xHelperA["externals"][tKey]
      else
        put empty into tHelpersA
        put 0 into tIndex

        repeat with i = 1 to the number of elements of xHelperA["externals"][pPlatform]
          if not _shouldAssetBeDistributed(xHelperA["externals"][pPlatform][i], pBuildProfile) then
            log "  Skipping helper external:" && xHelperA["externals"][pPlatform][i]["filename"]
            next repeat
          end if

          log "  Adding external helper file:" && xHelperA["externals"][pPlatform][i]["filename"]
          log "    to folder:" && tExecutableDestFolder

          packagerCreateAllFoldersInPath tExecutableDestFolder, tRootFolder
          put the result into tError

          if tError is empty then
            if there is a file xHelperA["externals"][pPlatform][i]["filename"] then
              _fileCopyFile xHelperA["externals"][pPlatform][i]["filename"], tExecutableDestFolder
            else
              _fileCopyFolder xHelperA["externals"][pPlatform][i]["filename"], \
                  tExecutableDestFolder & "/" & the last item of xHelperA["externals"][pPlatform][i]["filename"]
            end if
            put the result into tError
          end if

          if tError is empty then
            replace (xHelperA["filename"] & "/") with empty in xHelperA["externals"][pPlatform][i]["filename"]

            # Create new array with excluded elements removed
            add 1 to tIndex
            put xHelperA["externals"][pPlatform][i] into tHelpersA[tIndex]
          end if

          if tError is not empty then exit repeat
        end repeat

        # Store reindexed version of array
        if tError is empty then
          put tHelpersA into xHelperA["externals"][pPlatform]
        end if
      end if

      if tError is not empty then exit repeat
    end repeat

    # extensions
    if tError is empty then
      put empty into tHelpersA
      put 0 into tIndex

      repeat with i = 1 to the number of elements of xHelperA["extensions"]
        if not _shouldAssetBeDistributed(xHelperA["extensions"][i], pBuildProfile) then
          log "  Skipping helper extension:" && xHelperA["extensions"][i]["filename"]
          next repeat
        end if

        log "  Adding extension helper file:" && xHelperA["extensions"][i]["filename"]
        log "    to folder:" && tExecutableDestFolder

        packagerCreateAllFoldersInPath tExecutableDestFolder, tRootFolder
        put the result into tError

        if tError is empty then
          _fileCopyFile xHelperA["extensions"][i]["filename"], tExecutableDestFolder
          put the result into tError
        end if

        if tError is empty then
          if xHelperA["extensions"][i]["resource folder"] is not empty then
            log "  Adding extension helper resource folder:" && xHelperA["extensions"][i]["resource folder"]
            log "    to folder:" && tDestFolder

            _fileCopyFolder xHelperA["extensions"][i]["resource folder"], tDestFolder
            put the result into tError

            if tError is empty then
              replace (xHelperA["filename"] & "/") with empty in xHelperA["extensions"][i]["resource folder"]
            end if
          end if
        end if

        if tError is empty then
          replace (xHelperA["filename"] & "/") with empty in xHelperA["extensions"][i]["filename"]

          # Create new array with excluded elements removed
          add 1 to tIndex
          put xHelperA["extensions"][i] into tHelpersA[tIndex]
        end if

        if tError is not empty then exit repeat
      end repeat

      # Store reindexed version of array
      if tError is empty then
        put tHelpersA into xHelperA["extensions"]
      end if
    end if

    # Move over any other folders
    repeat for each line tFolder in _folderListing(xHelperA["filename"])
      if not (the last item of tFolder begins with ".") AND not (tFolder ends with ".bundle") AND there is not a folder (tDestFolder & "/" & the last item of tFolder) then
        log "  Adding helper additional folder:" && tFolder
        log "    to folder:" && tDestFolder & "/" & the last item of tFolder

        _fileCopyFolder tFolder, tDestFolder & "/" & the last item of tFolder
        put the result into tError
      end if

      if tError is not empty then exit repeat
    end repeat

    if tError is empty then
      _processStacksInFolder tDestFolder, sPassword, tExclusions
      put the result into tError
    end if
  end if

  put "helpers/" & the last item of xHelperA["filename"] into xHelperA["filename"]

  return tError
end _packageHelper


private command _packageUI pBuildProfile,pPlatform,  @xAppA, pOutputFolder
  local tError
  local tCompsA, tIndex, tKey, i
  local tComponentFolder

  set the itemdelimiter to "/"

  repeat for each key tKey in xAppA["registered components"]["ui"]
    put empty into tCompsA
    put 0 into tIndex

    if the number of elements of xAppA[tKey] > 0 then
      log "Packaging" && tKey

      create folder (pOutputFolder & "/" & tKey)
      put _errorMsg("creating folder" && pOutputFolder & "/" & tKey, the result) into tError

      if tError is empty then
        local tDestFolder, tExclusions

        repeat with i = 1 to the number of elements of xAppA[tKey]
          if not _shouldAssetBeDistributed(xAppA[tKey][i], pBuildProfile) then
            log "  Skipping ui asset" && tKey && ":" && xAppA[tKey][i]["filename"]
            next repeat
          end if

          put empty into tExclusions
          put item 1 to -2 of xAppA[tKey][i]["filename"] into tComponentFolder

          log "  Adding component:" && xAppA[tKey][i]["filename"]

          put pOutputFolder & "/" & tKey & "/" & the last item of tComponentFolder into tDestFolder

          # If two entries in array are in same folder only copy and process the folder once.
          if there is not a folder tDestFolder then
            _fileCopyFolder tComponentFolder, tDestFolder
            put _errorMsg("copying folder" && tComponentFolder && "to" && tDestFolder, the result) into tError

            if tError is empty then
              if xAppA[tKey][i]["encrypt"] is false then
                put tDestFolder & "/" & the last item of xAppA[tKey][i]["filename"] into tExclusions
              end if

              _processStacksInFolder tDestFolder, sPassword, tExclusions
              put the result into tError
            end if

            # Send callbacks
            if tError is empty then
              if xAppA["registered components"]["ui"][tKey]["callback stackfile"] is not empty then
                log "Dispatching finalizePackagedUIAsset to stack" && xAppA["registered components"]["ui"][tKey]["callback stackfile"]

                dispatch "finalizePackagedUIAsset" to stack xAppA["registered components"]["ui"][tKey]["callback stackfile"] \
                      with pBuildProfile, pPlatform, tDestFolder

                # Store for unloading at end of packaging
                put "" into sCallbackStacksA[ xAppA["registered components"]["ui"][tKey]["callback stackfile"] ]
              end if
            end if
          else
            beep
          end if

          add 1 to tIndex
          put tKey & "/" & the last item of tComponentFolder & "/" & the last item of xAppA[tKey][i]["filename"] into tCompsA[tIndex]["filename"]
          put xAppA[tKey][i]["name"] into tCompsA[tIndex]["name"]
          put xAppA[tKey][i]["autoload"] into tCompsA[tIndex]["autoload"]

          if tError is not empty then exit repeat
        end repeat
      end if

      if tError is empty then
        put tCompsA into xAppA[tKey]
      end if
    end if
  end repeat

  return tError
end _packageUI


private command _packageFiles pBuildProfile, @xAppA, pOutputFolder
  local tError
  local tCompsA, tKey, tProp, i
  local tComponentFolder

  set the itemdelimiter to "/"

  repeat for each key tKey in xAppA["registered components"]["files"]
    put empty into tCompsA

    if _shouldAssetBeDistributed(xAppA["registered components"]["files"][tKey], pBuildProfile) and the number of elements of xAppA[tKey] > 0 then
      log "Packaging" && tKey

      if tError is empty then
        local tFilename

        repeat with i = 1 to the number of elements of xAppA[tKey]
          if not _shouldAssetBeDistributed(xAppA[tKey][i], pBuildProfile) then
            log "  Skipping file asset" && tKey && ":" && xAppA[tKey][i]["filename"]
            next repeat
          end if

          put xAppA[tKey][i]["filename"] into tFilename
          replace levureAppFolder() with pOutputFolder in tFilename

          packagerCreateAllFoldersInPath item 1 to -2 of tFilename, pOutputFolder
          put _errorMsg("creating folder" && item 1 to -2 of xAppA[tKey][i]["filename"], the result) into tError

          if tError is empty then
            _fileCopyFile xAppA[tKey][i]["filename"], tFilename
            put _errorMsg("copying file" && xAppA[tKey][i]["filename"] && "to" && \
                  tFilename, the result) into tError
          end if

          if tError is empty then
            put _makeRelativePath(xAppA[tKey][i]["filename"], levureAppFolder()) into tCompsA[i]["filename"]
            repeat for each key tProp in xAppA[tKey][i]
              if tProp is "filename" then next repeat

              put xAppA[tKey][i][tProp] into tCompsA[i][tProp]
            end repeat
          end if

          if tError is not empty then exit repeat
        end repeat
      end if

      if tError is empty then
        put tCompsA into xAppA[tKey]
      end if
    end if
  end repeat

  return tError
end _packageFiles


private function _shouldAssetBeDistributed pAssetA, pBuildProfile
  if pAssetA["distribute"] is false then return false
  else return true
end _shouldAssetBeDistributed


private function _shouldBuildForPlatform pPlatform, pFilter
  return _doesStringPassFilter(pPlatform, pFilter)
end _shouldBuildForPlatform


/**
Summary: Returns true if pString passes pFilter
*/
private function _doesStringPassFilter pString, pFilter
  if pFilter is empty then return true

  local tFilter
  local tPerformedAPositiveMatchCheck = "false"

  repeat for each item tFilter in pFilter
    if char 1 of tFilter is "!" then
      # Match means false
      if pString is char 2 to -1 of tFilter then
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
    return false
  else
    return true
  end if
end _doesStringPassFilter


private command _processStacksInFolder pFolder, pPassword, pExclusions
  local tError
  local tFolders, tFolder, tFiles, tFile

  log "Processing stacks in folder:" && pFolder
  log "  Stacks excluded from encryption:" && pExclusions

  set the wholematches to true

  lock messages

  put _fileListing(pFolder) into tFiles
  repeat for each line tFile in tFiles
    if there is a stack tFile then
      if the scriptonly of stack tFile then
        set the scriptonly of stack tFile to false
        if pPassword is not empty AND tFile is not among the lines of pExclusions then
          _setPassword tFile, pPassword
        end if
        save stack tFile as tFile with newest format
        put the result into tError
      else
        if pPassword is not empty AND tFile is not among the lines of pExclusions \
              AND the password of stack tFile is empty then
          _setPassword tFile, pPassword
          save stack tFile as tFile with newest format
          put the result into tError
        end if
      end if

      # When loading a stack into memory the stackfiles may be loaded into memory
      _unloadStackAndStackFiles tFile
    end if

    if tError is not empty then exit repeat
  end repeat

  if tError is empty then
    put _folderListing(pFolder) into tFolders
    repeat for each line tFolder in tFolders
      _processStacksInFolder tFolder, pPassword
      put the result into tError

      if tError is not empty then exit repeat
    end repeat
  end if

  unlock messages

  return tError
end _processStacksInFolder


private command _unloadStackAndStackFiles pStack
  local tStackEntry, tStack

  repeat for each line tStackEntry in the stackfiles of stack pStack
    put item 1 of tStackEntry into tStack
    if tStack is not empty AND there is a stack tStack then
      delete stack tStack
    end if
  end repeat

  delete stack pStack

  return empty
end _unloadStackAndStackFiles


private command _packageExtensions pBuildProfile, @xAppA, pOutputFolder, pExtensionsBuiltIntoStandalone
  local tError
  local tExtsA, tIndex, i

  set the itemdelimiter to "/"
  set the wholematches to true

  if the number of elements of xAppA["extensions"] > 0 then
    log "Packaging extensions"

    repeat with i = 1 to the number of elements of xAppA["extensions"]
      # We don't need to add extensions that are being built with the standalone
      if _getKindFromExtensionFile(xAppA["extensions"][i]["filename"]) is not among the lines of pExtensionsBuiltIntoStandalone \
            and _shouldAssetBeDistributed(xAppA["extensions"][i], pBuildProfile) then
        if there is not a folder (pOutputFolder & "/extensions") then
          create folder (pOutputFolder & "/extensions")
          put _errorMsg("creating the extensions folder [" & pOutputFolder & "/extensions" & "]", the result) into tError
          if tError is not empty then
            exit repeat
          end if
        end if

        log "  Adding extension:" && xAppA["extensions"][i]["filename"]

        _fileCopyFile xAppA["extensions"][i]["filename"], pOutputFolder & "/extensions/" & the last item of xAppA["extensions"][i]["filename"]
        put _errorMsg("copying file [" & xAppA["extensions"][i]["filename"] & "] to [" & pOutputFolder & "/extensions/" & the last item of xAppA["extensions"][i]["filename"] & "]", the result) into tError

        if tError is empty then
          add 1 to tIndex
          put "extensions/" & the last item of xAppA["extensions"][i]["filename"] into tExtsA[tIndex]["filename"]

          if xAppA["extensions"][i]["resource folder"] is not empty then
            # TODO: need to copy the resource folder and make sure it has a unique name
          end if
        end if
      end if

      if tError is not empty then exit repeat
    end repeat

    if tError is empty then
      put tExtsA into xAppA["extensions"]
    end if
  end if

  return tError for error
end _packageExtensions


private function _getKindFromExtensionFile pFilename
  local tError, tKind, it, i

  open file pFilename for binary read
  put the result into tError

  if tError is empty then
    seek to 6 in file pFilename
    put the result into tError

    if tError is empty then
      repeat forever
        add 1 to i
        read from file pFilename for 1 byte
        put the result into tError

        if tError is empty then
          if byteToNum(it) < 46 then # Identifier: [A-Za-z][A-Za-z0-9.]* (46 is ".")
            exit repeat
          else
            put it after tKind
          end if
        end if

        if tError is not empty then exit repeat
      end repeat

      close file pFilename
    end if
  end if

  if tError is empty then
    return tKind for value
  else
    return tError for error
  end if
end _getKindFromExtensionFile


private command _packageAssetStacks pBuildProfile, @xAppA, pOutputFolder
  local tError, i
  local tStacksToLoad
  local tStackName, tFilename

  lock messages

  # behaviors
  if tError is empty then
    if the number of elements of xAppA["behaviors"] > 0 then
      log "Packaging behaviors"

      put "Levure Application Behaviors" into tStackName
      create invisible stack tStackName

      if sPassword is not empty then
        _setPassword tStackName, sPassword
      end if

      repeat with i = 1 to the number of elements of xAppA["behaviors"]
        if not _shouldAssetBeDistributed(xAppA["behaviors"][i], pBuildProfile) then next repeat

        if xAppA["behaviors"][i]["encrypt"] is not false and sPassword is not empty then
          # Just in case there are duplicate entries in array
          if the password of stack xAppA["behaviors"][i]["filename"] is empty then
            set the scriptOnly of stack xAppA["behaviors"][i]["filename"] to false
            _setPassword xAppA["behaviors"][i]["filename"], sPassword
          end if
        end if

        log "  Adding behavior stack:" && xAppA["behaviors"][i]["filename"]
        set the mainstack of stack xAppA["behaviors"][i]["filename"] to tStackName
      end repeat

      log "Saving behavior stack:" && pOutputFolder & "/behaviors.livecode"

      save stack tStackName as (pOutputFolder & "/behaviors.livecode") with newest format
      put the result into tError
      delete stack tStackName

      if tError is empty then
        put empty into xAppA["behaviors"]
        put "behaviors.livecode" into xAppA["behaviors"][1]["filename"]
      end if
    end if
  end if

  # libraries, frontscripts, backscript
  if tError is empty then
    local tProp

    repeat for each item tAssetType in "frontscripts,backscripts,libraries"
      put empty into tStacksToLoad

      if the number of elements of xAppA[tAssetType] is 0 then next repeat

      put "Levure Application" && toupper(char 1 of tAssetType) & char 2 to -1 of tAssetType into tStackName
      create invisible stack tStackName

      if sPassword is not empty then
        _setPassword tStackName, sPassword
      end if

      repeat with i = 1 to the number of elements of xAppA[tAssetType]
        if not _shouldAssetBeDistributed(xAppA[tAssetType][i], pBuildProfile) then next repeat

        if xAppA[tAssetType][i]["encrypt"] is not false and sPassword is not empty then
          # Just in case there are duplicate entries in array
          if the password of stack xAppA[tAssetType][i]["filename"] is empty then
            set the scriptOnly of stack xAppA[tAssetType][i]["filename"] to false
            _setPassword xAppA[tAssetType][i]["filename"], sPassword
          end if
        end if

        log "  Adding" && tAssetType && "stack:" && xAppA[tAssetType][i]["filename"]
        set the mainstack of stack xAppA[tAssetType][i]["filename"] to tStackName

        repeat for each key tProp in xAppA[tAssetType][i]
          if tProp is "filename" then
            put the short name of stack xAppA[tAssetType][i]["filename"] into tStacksToLoad[i]["name"]
          else
            put xAppA[tAssetType][i][tProp] into tStacksToLoad[i][tProp]
          end if
        end repeat
      end repeat

      set the uStacksToLoad of stack tStackName to tStacksToLoad

      log "Saving" && tAssetType && "stack:" && pOutputFolder & "/" & tAssetType & ".livecode"
      save stack tStackName as (pOutputFolder & "/" & tAssetType & ".livecode") with newest format
      put _errorMsg("saving" && tAssetType && "stack [" & pOutputFolder & "/" & tAssetType & ".livecode" & "]", the result) into tError
      delete stack tStackName

      if tError is empty then
        put empty into xAppA[tAssetType]
        put tAssetType & ".livecode" into xAppA[tAssetType][1]["filename"]
      end if
    end repeat
  end if

  unlock messages

  return tError
end _packageAssetStacks


private command _copyExecutablesAndSupportingFilesToFolder pBuildForPlatform, pBuildForDistribution, pBuildFolder, pOutputFolder
  local tError
  local tFolderContainingBuild
  local tFiles, tFile

  put _folderListing(pBuildFolder) into tFolderContainingBuild

  set the itemdelimiter to "/"

  if pBuildForDistribution then
    _moveFolder tFolderContainingBuild, pOutputFolder
    put _errorMsg("moving folder [" & tFolderContainingBuild & "] to [" & pOutputFolder & "]", the result) into tError

    if tError is empty then
      rename folder (pOutputFolder & "/" & the last item of tFolderContainingBuild) to pOutputFolder & "/" & pBuildForPlatform
      put _errorMsg("renaming folder [" & tFolderContainingBuild & "] to [" & pOutputFolder & "/" & pBuildForPlatform & "]", the result) into tError
    end if
  else
    _moveFilesAndFolders tFolderContainingBuild, pOutputFolder
    put the result into tError
  end if

  return tError for error
end _copyExecutablesAndSupportingFilesToFolder


private function _generateStartupScript pRelativeFrameworkPath, pRelativeAppPath, pBuildForDistribution
  local tScript, tFunction

  if pBuildForDistribution then
    # load app stack into memory on startup
    local tFrameworkFilename, tAppStackFilename

    set the itemdelimiter to "/"
    put pRelativeAppPath into tFrameworkFilename # Framework and app stack will be alongside each other when packaged
    put pRelativeAppPath into tAppStackFilename
    put the last item of levureFrameworkFilename() into item (the number of items of tFrameworkFilename + 1) of tFrameworkFilename
    put the last item of levureAppStackFilename() into item (the number of items of tAppStackFilename + 1) of tAppStackFilename

    put "on startup" & cr & \
          _qstr("set the itemDelimiter to `/`") & cr & \
          _qstr("if the platform is `macos` then") & cr & \
          _qstr("put resolvePath(`" & tAppStackFilename & "`, item 1 to -2 of the engine folder & `/Resources/_MacOS`) into tAppStackFilename") & cr & \
          _qstr("put resolvePath(`" & tFrameworkFilename & "`, item 1 to -2 of the engine folder & `/Resources/_MacOS`) into tFrameworkFilename") & cr & \
          "else" & cr & \
          _qstr("put resolvePath(`" & tAppStackFilename & "`, the engine folder) into tAppStackFilename") & cr & \
          _qstr("put resolvePath(`" & tFrameworkFilename & "`, the engine folder) into tFrameworkFilename") & cr & \
          "end if" & cr & \
          "put there is a stack tFrameworkFilename into tLoaded" & cr & \
          "if tLoaded then" & cr & \
          _qstr("set the behavior of me to the long id of stack tFrameworkFilename") & cr & \
          "else" & cr & \
          _qstr("answer `Could not locate app stack: ` & tFrameworkFilename") & cr & \
          "quit" & cr & \
          "end if" & cr & \
          "put there is a stack tAppStackFilename into tLoaded" & cr & \
          "if not tLoaded then" & cr & \
          _qstr("answer `Could not locate app stack: ` & tAppStackFilename") & cr & \
          "quit" & cr & \
          "end if" & cr & \
          "end startup" into tScript
  else
    # Add code to locate framework and app files
    put "appFolder()" into tFunction

    put "on startup" & cr & \
      _qstr("put resolvePath(`" & pRelativeFrameworkPath & "`, " & tFunction & ") into tStackfile") & cr & \
      "set the behavior of me to the long id of stack tStackfile" & cr & \
      "end startup" into tScript

    put cr & cr & \
      "function levureTestingStandaloneAppFolder" & cr & \
      _qstr("put resolvePath(`" & pRelativeAppPath & "`, " & tFunction & ") into tStackfile") & cr & \
      "return tStackfile for value" & cr & \
      "end levureTestingStandaloneAppFolder" after tScript

    put cr & cr & \
      "function levureTestingRevCustomizationFolder" & cr & \
      _qstr("return `" & revEnvironmentCustomizationPath() & "` for value") & cr & \
      "end levureTestingRevCustomizationFolder" after tScript

    put cr & cr & \
      "function levureTestingStandaloneFrameworkPath" & cr & \
      _qstr("return resolvePath(`" & pRelativeFrameworkPath & "`, " & tFunction & ")") & cr & \
      "end levureTestingStandaloneFrameworkPath" after tScript

    put cr & cr & \
          "private function appFolder" & cr & \
          "set the itemdelimiter to slash" & cr & \
          "put the effective filename of me into tFilename" & cr & \
          "delete the last item of tFilename" & cr & \
          _qstr("if the platform is `macos` and tFilename contains `.app/Contents/MacOS` then") & cr & \
          "delete item -3 to -1 of tFilename" & cr & \
          "end if" & cr & \
          "return tFilename" & cr & \
          "end appFolder" after tScript
  end if

  put cr & cr & \
        "private function resolvePath pFilename, pRootFolder" & cr & \
        _qstr("set the itemDelimiter to `/`") & cr & \
        _qstr("repeat while pFilename begins with `../`") & cr & \
        "if pRootFolder is empty then" & cr & \
        _qstr("return `relative path is too deep for root folder` for error") & cr & \
        "else" & cr & \
        "delete the last item of pRootFolder" & cr & \
        "delete char 1 to 3 of pFilename" & cr & \
        "end if" & cr & \
        "end repeat" & cr & \
        _qstr("return pRootFolder & `/` & pFilename for value") & cr & \
        "end resolvePath" after tScript

  return tScript for value
end _generateStartupScript


private command _validateBuildProfile pBuildProfile
  local tError

  put word 1 to -1 of line 1 of pBuildProfile into pBuildProfile
  if pBuildProfile is empty then put "invalid build profile" into tError

  if tError is empty then
    if pBuildProfile is not "test" and pBuildProfile is not among the keys of sAppA["build profiles"] then
      put "invalid build profile" into tError
    end if
  end if

  return tError for error
end _validateBuildProfile


private command _performPackagingPrechecks pStandaloneStackFilename, @xBuildProfile
  local tError, tLoaded

  put empty into sPassword
  put tolower(xBuildProfile) into xBuildProfile

  _validateBuildProfile xBuildProfile
  put the result into tError

  if tError is empty then
    put there is a stack pStandaloneStackFilename into tLoaded
    if not tLoaded then
      put "invalid standalone stack" into tError
    end if
  end if

  # Check if encryption is supposed to happen but password is missing
  if tError is empty then
    if xBuildProfile is not "test" AND levureAppGet("encrypt stacks") then
      put levureAppGet("password") into sPassword

      if sPassword is empty then
        local tEnvA

        put levureAppGetENV() into tEnvA
        put tEnvA["PASSWORD"] into sPassword
      end if

      if sPassword is empty then
        put "no password was provided to encrypt stacks" into tError
      end if
    end if
  end if

  if tError is empty then
    if not (levureAppFolder() begins with levureStandaloneFolder()) then
      put "the app.yml file must be in the same directory or a subdirectory of the standalone stack" into tError
    end if
  end if

  return tError for error
end _performPackagingPrechecks


private command _moveFilesAndFolders pSourceFolder, pDestinationFolder
  local tError, tFile

  set the itemdelimiter to "/"

  if tError is empty then
    repeat for each line tFile in _fileListing(pSourceFolder)
      rename file tFile to (pDestinationFolder & "/" & the last item of tFile)
      put the result into tError

      if tError is not empty then exit repeat
    end repeat
  end if

  if tError is empty then
    repeat for each line tFile in _folderListing(pSourceFolder)
      rename folder tFile to (pDestinationFolder & "/" & the last item of tFile)
      put the result into tError

      if tError is not empty then exit repeat
    end repeat
  end if

  return tError
end _moveFilesAndFolders


private command _copyFilesAndFolders pSourceFolder, pDestinationFolder
  local tError, tFile

  set the itemdelimiter to "/"

  if tError is empty then
    repeat for each line tFile in _fileListing(pSourceFolder)
      _fileCopyFile tFile, pDestinationFolder & "/" & the last item of tFile
      put the result into tError

      if tError is not empty then exit repeat
    end repeat
  end if

  if tError is empty then
    repeat for each line tFile in _folderListing(pSourceFolder)
      _fileCopyFolder tFile, pDestinationFolder & "/" & the last item of tFile
      put the result into tError

      if tError is not empty then exit repeat
    end repeat
  end if

  return tError
end _copyFilesAndFolders


private command _updateStandaloneVersionInfo pStackFilename
  local tError
  local tVersion, tMajor, tMinor, tRevision, tBuild

  put levureAppGet("version") into tVersion
  put levureAppGet("build") into tBuild

  set the itemdelimiter to "."
  put item 1 of tVersion into tMajor
  put item 2 of tVersion into tMinor
  put item 3 of tVersion into tRevision

  ## -- Windows
  set the cRevStandaloneSettings["Windows,fileversion1"] of stack pStackFilename to tMajor
  set the cRevStandaloneSettings["Windows,fileversion2"] of stack pStackFilename to tMinor
  set the cRevStandaloneSettings["Windows,fileversion3"] of stack pStackFilename to tRevision
  set the cRevStandaloneSettings["Windows,fileversion4"] of stack pStackFilename to tBuild

  set the cRevStandaloneSettings["Windows,productversion1"] of stack pStackFilename to tMajor
  set the cRevStandaloneSettings["Windows,productversion2"] of stack pStackFilename to tMinor
  set the cRevStandaloneSettings["Windows,productversion3"] of stack pStackFilename to tRevision
  set the cRevStandaloneSettings["Windows,productversion4"] of stack pStackFilename to tBuild

  ## -- macOS
  if the cRevStandaloneSettings["OSX,plist"] of stack pStackFilename is not empty then
    local tPlist

    put the filename of stack pStackFilename into tPlist
    set the itemdelimiter to slash
    put the cRevStandaloneSettings["OSX,plist"] of stack pStackFilename into the last item of tPlist
    if there is a file tPlist then
      local tData

      ## Developer is doing this the proper way. Update plist
      put URL("binfile:" & tPlist) into tData
      put _errorMsg("opening plist file [" & tPlist & "]", the result) into tError

      if tError is empty then
        _updatePlistInfo tData

        put tData into URL("binfile:" & tPlist)
        put the result into tError
        if tError is not empty then
          put "error writing plist info: " & tError into tError
        end if
      end if
    else
      put "could not find plist file" && quote & tPlist & quote into tError
    end if
  else
    ## update standalone settings
    set the cRevStandaloneSettings["OSX,shortversion"] of stack pStackFilename \
          to format("%u.%u.%u", tMajor, tMinor, tRevision)
    set the cRevStandaloneSettings["OSX,longVersion"] of stack pStackFilename \
          to format("%u.%u.%u (%u)", tMajor, tMinor, tRevision, tBuild)
  end if

  ## -- iOS
  set the cRevStandaloneSettings["ios,bundle version"] of stack pStackFilename to format("%u.%u.%u", tMajor, tMinor, tRevision)
  set the cRevStandaloneSettings["ios,bundle build"] of stack pStackFilename to tBuild

  ## -- Android
  set the cRevStandaloneSettings["android,version name"] of stack pStackFilename to format("%u.%u.%u", tMajor, tMinor, tRevision)
  set the cRevStandaloneSettings["android,version code"] of stack pStackFilename to tBuild

  return tError for error
end _updateStandaloneVersionInfo


private command _updatePlistInfo @xData, pVersionA
  local tRangeA, tVersion, tBuild, tString

  put levureAppGet("version") into tVersion
  put levureAppGet("build") into tBuild

  put _findRangeForPlistEntry(xData, "CFBundleGetInfoString") into tRangeA
  if tRangeA["start"] > 0 then
    put char tRangeA["start"] to tRangeA["end"] of xData into tString
    put tVersion && "build" && tBuild into item 1 of tString
    put tString into char tRangeA["start"] to tRangeA["end"] of xData
  end if

  put _findRangeForPlistEntry(xData, "CFBundleShortVersionString") into tRangeA
  if tRangeA["start"] > 0 then
    put tVersion into char tRangeA["start"] to tRangeA["end"] of xData
  end if

  put _findRangeForPlistEntry(xData, "CFBundleVersion") into tRangeA
  if tRangeA["start"] > 0 then
    put tBuild into char tRangeA["start"] to tRangeA["end"] of xData
  end if

  put _findRangeForPlistEntry(xData, "CFBundleLongVersionString") into tRangeA
  if tRangeA["start"] > 0 then
    put tVersion & "." & tBuild into char tRangeA["start"] to tRangeA["end"] of xData
  end if
end _updatePlistInfo


private function _findRangeForPlistEntry pData, pEntry
  local tRangeA, tFirstCharNo, tStartCharNo, tEndCharNo

  put 0 into tRangeA["start"]
  put 0 into tRangeA["end"]

  put offset("<key>" & pEntry & "</key>", pData) into tFirstCharNo
  if tFirstCharNo > 0 then
    put offset("<string>", pData, tFirstCharNo) into tStartCharNo
    if tStartCharNo > 0 then
      put offset("</string>", pData, tFirstCharNo) into tEndCharNo
      if tEndCharNo > 0 then
        add tFirstCharNo to tStartCharNo
        add tFirstCharNo to tEndCharNo
        put tStartCharNo + 8 into tRangeA["start"]
        put tEndCharNo - 1 into tRangeA["end"]
      end if
    end if
  end if

  return tRangeA
end _findRangeForPlistEntry


private command _packageForMAS pAppA, pFolderWithMacApp
  local tAppBundle
  local tPackage, tCmd, tResult

  set the itemdelimiter to "/"

  put pFolderWithMacApp & "/" & the last item of levureStandaloneFilename() into tAppBundle
  if there is not a folder tAppBundle then return empty

  set the itemdelimiter to "."
  put tAppBundle into tPackage
  put "pkg" into item -1 of tPackage

  put format("productbuild --component \"%s\" /Applications --sign \"%s\" \"%s\"", tAppBundle, pAppA["macos installer signing certificate"], tPackage) into tCmd
  put shell(tCmd) into tResult
  if the result > 0 then
    return tResult for error
  else
    return empty for value
  end if
end _packageForMAS


private command _signMacOSApplication pBuildProfile, pAppA, pFolderWithMacApp
  local tError, tAppBundle

  set the itemdelimiter to "/"

  put pFolderWithMacApp & "/" & the last item of levureStandaloneFilename() into tAppBundle
  if there is a folder tAppBundle then

    if pAppA["macos signing certificate"] is not empty then

      log "Signing application for OS X using cert:" && pAppA["macos signing certificate"]

      local tCmd

      # Sierra on up needs extended attributes stripped out
      if tError is empty then
         put format("chmod -R u+rw \"%s\"", tAppBundle) into tCmd
         get shell(tCmd)
         if the result > 0 then
          put it into tError
        end if
      end if

      if tError is empty then
         put format("xattr -rc \"%s\"", tAppBundle) into tCmd
         get shell(tCmd)
         if the result > 0 then
          put it into tError
        end if
      end if

      if tError is empty then
        _signAndStrip tAppBundle, pAppA["macos signing certificate"]
        put the result into tError
      end if

      if tError is empty then
        put format("codesign -dvvv \"%s\"", tAppBundle) into tCmd
        get shell(tCmd)
        if the result > 0 then
          put it into tError
        end if
      end if

      if tError is empty then
        if pAppA["macos signing certificate"] begins with "3rd Party Mac Developer Application" then
          put format("spctl --assess --verbose --ignore-cache --type execute -v \"%s\"", tAppBundle) into tCmd
          get shell(tCmd)
          if the result > 0 then
            # Don't stop because of this
            put "spctl error:" && it into tError
          end if
        end if
      end if

    end if
  end if

  return tError for error
end _signMacOSApplication


## Monte Goulding with modifications by Trevor DeVore
command _signAndStrip pBundle, pCertificate, pSignFile
  local tError
  local tRootFolder

  # recursively parse any frameworks
  if tError is empty then
    put pBundle & "/Contents/Frameworks" into tRootFolder
    if there is a folder tRootFolder then
      _findBundlesAndStripExecutables tRootFolder, pCertificate, pSignFile
      put the result into tError
    end if
  end if

  # recursively parse the MacOS folder
  if tError is empty then
    put pBundle & "/Contents/MacOS" into tRootFolder
    if there is a folder tRootFolder then
      _findBundlesAndStripExecutables tRootFolder, pCertificate, pSignFile
      put the result into tError
    end if
  end if

  if tError is empty then
    _signFile pBundle, pCertificate
    put the result into tError
  end if

  return tError
end _signAndStrip


# Signs a file or folder
private command _signFile pFilename, pCertificate
  local tEntitlementsFile, tCmd, tError, tResult

  if tError is empty then
    put _bundleEntitlementFile(pFilename) into tEntitlementsFile

    if tEntitlementsFile is not empty then
      put format("codesign --verbose --force -s \"%s\" --entitlements \"%s\" \"%s\"", pCertificate, tEntitlementsFile, pFilename) into tCmd
    else
      put format("codesign --verbose --force -s \"%s\" \"%s\"", pCertificate, pFilename) into tCmd
    end if

    get shell(tCmd)
    if the result > 0 then
      put the result into tError
      if tError is 1 then
        put "codesign process failed:" && it into tError
      else if tError is 2 then
        put "invalid arguments passed to codesign:" && it into tError
      else if tError is 3 then
        put "requirements not met for -R flag in codesign:" && it into tError
      else
        put it into tError
      end if
    end if
  end if

  return tError for error
end _signFile


private function _bundleEntitlementFile pBundle
  local tFiles, tBundleName

  # Look for an entitlement file that matches the bundle name
  set the itemdelimiter to "/"
  put the last item of pBundle into tBundleName
  set the itemDelimiter to "."
  put item 1 to -2 of tBundleName into tBundleName

  put _fileListing(pBundle & "/Contents/Resources", true) into tFiles
  filter tFiles with "*/" & tBundleName & ".entitlements"
  if tFiles is empty then
    put _fileListing(pBundle & "/Contents", true) into tFiles
    filter tFiles with "*/" & tBundleName & ".entitlements"
  end if

  return tFiles
end _bundleEntitlementFile


private function _isMacOSExecutable pFilepath
  return pFilepath ends with ".bundle" \
        OR pFilepath ends with ".dylib" \
        OR pFilepath ends with ".framework" \
        OR pFilepath ends with ".app"
end _isMacOSExecutable


## Monte Goulding with modifications by Trevor DeVore
private command _findBundlesAndStripExecutables pFolder, pCertificate, pSignFiles
  local tError, tOldDefaultFolder, tFolders, tFilesInfo, tFiles, tResult

  put pSignFiles is not false into pSignFiles

  # Get list of folders and reset. Can't wait until end as it messes up recursive calls.
  put the defaultFolder into tOldDefaultFolder
  set the defaultFolder to pFolder
  put the folders into tFolders
  put the detailed files into tFilesInfo
  put the files into tFiles
  set the defaultFolder to tOldDefaultFolder

  repeat for each line tFolder in line 2 to -1 of tFolders
    if _isMacOSExecutable(tFolder) then
      _signAndStrip  pFolder & "/" & tFolder, pCertificate, false # don't sign any files within bundle
      put the result into tError
    else if tFolder ends with ".app" OR tFolder ends with ".framework" then
      _signAndStrip  pFolder & "/" & tFolder, pCertificate, true # sign files within the app
      put the result into tError
    else
      _findBundlesAndStripExecutables pFolder & "/" & tFolder, pCertificate, pSignFiles # inherit behavior
      put the result into tError
    end if

    if tError is not empty then exit repeat
  end repeat

  # On Mavericks and above additional signing is required. Anything that can contain code (or that OS X thinks can contain code)
  if tError is empty then
    if pSignFiles then # don't sign if part of a bundle
      local tFilesWOExt, tCmd

      set the itemdelimiter to "."

      # sign things like .dylib before others. Otherwise codesign will try to sign app and complain that .dylib isn't signed.
      put tFiles into tFilesWOExt
      filter tFilesWOExt without "*.*"
      filter tFiles with "*.*"
      if tFilesWOExt is not empty then
        put tFilesWOExt into line (the number of lines of tFiles + 1) of tFiles
      end if

      repeat for each line tFile in tFiles
        if the platform is "macos" AND \
              (item 1 of the itemDelimiter > 10 OR item 1 of the systemVersion = 10 AND item 2 of the systemVersion >= 9) then

          # If file has already been codesigned then don't sign again. Some binaries may need to be signed by the developer
          # using an entitlement file. If the file is signed again the entitlements won't be applied. If for any reason this code
          # returns a false positive in the future a comparison could be done between pCertificate and the following line of output
          # from the `codesign` call:
          # Authority=3rd Party Mac Developer Application: CERT_NAME (TEAM_ID)
          # pCertificate should match `3rd Party Mac Developer Application: CERT_NAME`.
          put format("codesign -dv --verbose=4 \"%s\"", pFolder & "/" & tFile) into tCmd
          put shell(tCmd) into tResult
          if the result < 1 then
            log "skipping file which is already signed:" && pFolder & "/" & tFile
            next repeat
          end if

          _signFile pFolder & "/" & tFile, pCertificate
          put the result into tError
        end if

        if tError is not empty then exit repeat
      end repeat
    end if
  end if

  # strip
  if tError is empty then
    set the itemDelimiter to ","

    repeat for each line tFile in tFilesInfo
      # If executable bit is set then lipo it.
      # Prior to 2014-05-27 we assumed 755. Now we just check for a 7 in the first char.
      # TODO: error reporting
      if char 1 of item 10 of tFile = "7" then
        log "lipo -remove ppc" && pFolder & "/" & URLDecode(item 1 of tFile) && tResult
        get shell(format("lipo -remove ppc \"%s\" -output \"%s\"", pFolder & "/" & URLDecode(item 1 of tFile), pFolder & "/" & URLDecode(item 1 of tFile)))
        if the result > 0 then
          log "lipo ppc7400" && pFolder & "/" & URLDecode(item 1 of tFile) && tResult
          get shell(format("lipo -remove ppc7400 \"%s\" -output \"%s\"", pFolder & "/" & URLDecode(item 1 of tFile), pFolder & "/" & URLDecode(item 1 of tFile)))
        end if
      end if
    end repeat
  end if

  return tError for error
end _findBundlesAndStripExecutables


private function _folderListing pFilename
  local tFolders, tFolder, tFullPathFolders

  put folders(pFilename) into tFolders
  if line 1 of tFolders is ".." then delete line 1 of tFolders

  repeat for each line tFolder in tFolders
    put pFilename & "/" & tFolder & cr after tFullPathFolders
  end repeat
  delete the last char of tFullPathFolders

  return tFullPathFolders for value
end _folderListing


private function _fileListing pFilename
  local tFiles, tFile, tFullPathFiles

  put files(pFilename) into tFiles

  repeat for each line tFile in tFiles
    put pFilename & "/" & tFile & cr after tFullPathFiles
  end repeat
  delete the last char of tFullPathFiles

  return tFullPathFiles for value
end _fileListing


private function _resolveRelativeFilenameReference pFilename, pRootFolder
  set the itemDelimiter to "/"

  put _normalizeRelativeFilename(pFilename) into pFilename

  repeat while pFilename begins with "../"
    if pRootFolder is empty then
      return "relative path is too deep for root folder" for error
    else
      delete the last item of pRootFolder
      delete char 1 to 3 of pFilename
    end if
  end repeat

  if pFilename is empty then
    return pRootFolder for value
  else
    return pRootFolder & "/" & pFilename for value
  end if
end _resolveRelativeFilenameReference


private function _normalizeRelativeFilename pFilename
  if char 1 of pFilename is "/" then
    delete char 1 of pFilename
  else if char 1 to 2 of pFilename is "./" then
    delete char 1 to 2 of pFilename
  end if
  return pFilename for value
end _normalizeRelativeFilename


private function _makeRelativePath pFilename, pRootFolder
  local tIndex
  local tMatchCount = 0
  local tNonMatchCount =0

  ## NORMALIZE
  if char 1 of pFilename is slash then delete char 1 of pFilename
  if char 1 of pRootFolder is slash then delete char 1 of pRootFolder
  if the last char of pFilename is slash then delete the last char of pFilename
  if the last char of pRootFolder is slash then delete the last char of pRootFolder
  set the itemDelimiter to slash

  if pFilename is empty then return empty
  if pRootFolder is empty then return empty

  ## IS pFilename A CHILD DIRECTORY OF pRootFolder?
  if pRootFolder is item 1 to (the number of items of pRootFolder) of pFilename then
    delete char 1 to length(pRootFolder) + 1 of pFilename
    put "./" before pFilename
  else if pFilename is char 1 to length(pFilename) of pRootFolder then
    delete char 1 to length(pFilename) + 1 of pRootFolder
    put empty into pFilename
    repeat with tIndex = 1 to the number of items of pRootFolder
      put "../" after pFilename
    end repeat
  else
    ## DETERMINE WHERE PATHS DIVERGE
    repeat with tIndex = 1 to the number of items of pFilename
      if item tIndex of pFilename is not item tIndex of pRootFolder then
        put tIndex - 1 into tMatchCount
        put the number of items of pRootFolder - tIndex + 1 into tNonMatchCount
        exit repeat
      end if
    end repeat

    if tMatchCount > 0 then
      delete item 1 to tMatchCount of pFilename
    end if

    repeat with tIndex = 1 to tNonMatchCount
      put "../" before pFilename
    end repeat
  end if

  return pFilename
end _makeRelativePath


private function _qstr pStr
  replace "`" with quote in pStr
  return pStr
end _qstr


private command _fileCopyFile pSrcFile, pDestFile
  local tShellError, tTouchResult
  local tError, tResult

  if the platform is "MacOS" then
    put _escapeForShell(pSrcFile) into pSrcFile
    put _escapeForShell(pDestFile) into pDestFile
    put shell ("cp -f" && pSrcFile && pDestFile) into tResult ## removed -p as it had problems with servers
    put the result into tShellError

    if tShellError is empty then
      ## Copying to USB (10.5.2) wouldn't return file mod time when queried with detailed files
      ## This fixes it
      put shell ("touch -c -a" && pDestFile) into tTouchResult
    end if
  else if the platform is "Win32" then
    put _escapeForShell(pSrcFile) into pSrcFile
    put _escapeForShell(pDestFile) into pDestFile
    put shell ("copy /Y /V" && pSrcFile && pDestFile) into tResult ## dies on long filenames
    put the result into tShellError
  else
    put _escapeForShell(pSrcFile) into pSrcFile
    put _escapeForShell(pDestFile) into pDestFile
    put shell ("cp -f" && pSrcFile && pDestFile) into tResult
    put the result into tShellError
  end if

  if tShellError is not empty then
    if tResult is not empty then
      put line 1 to 3 of tResult into tError
    else
      put tShellError into tError
    end if
  end if

  return tError
end _fileCopyFile


private command _fileCopyFolder pSrcFolder, pDestFolder
  local tError, tLastItemofSrcFolder, tResult

  if the platform is "MacOS" then
    ## ditto copies contents of pSrcFolder to pDestFolder if pDestFolder exists
    ## What we want is for pSrcFolder to exist within pDestFolder
    if there is a directory pDestFolder then
      set the itemdel to "/"
      if char -1 of pDestFolder is "/" then delete char -1 of pDestFolder
      put item -1 of pSrcFolder into tLastItemofSrcFolder
      put "/" & tLastItemofSrcFolder after pDestFolder
      create directory pDestFolder
    end if

    put _escapeForShell(pSrcFolder) into pSrcFolder
    put _escapeForShell(pDestFolder) into pDestFolder
    put shell ("ditto" && pSrcFolder && pDestFolder) into tResult
    if tResult contains "operation not permitted" then
      # OS X sandbox may not let us copy some metadata.
      # Don't know why but it happens. Saw it when copying from temp folder to temp folder.
      put shell ("ditto --norsrc" && pSrcFolder && pDestFolder) into tResult
    end if

  else if the platform is "Win32" then
    if there is a directory pDestFolder then
      set the itemdel to "/"
      if char -1 of pDestFolder is "/" then delete char -1 of pDestFolder
      put item -1 of pSrcFolder into tLastItemofSrcFolder
      put "/" & tLastItemofSrcFolder after pDestFolder
      create directory pDestFolder
    end if

    put _escapeForShell(pSrcFolder) into pSrcFolder
    put _escapeForShell(pDestFolder) into pDestFolder

    put shell ("robocopy" && pSrcFolder && pDestFolder && "/E /NFL /NDL /NS /NC /NJH /NJS") into tResult
  else
    put _escapeForShell(pSrcFolder) into pSrcFolder
    put _escapeForShell(pDestFolder) into pDestFolder
    put shell ("cp -rf" && pSrcFolder && pDestFolder) into tResult
  end if

  if the result is not empty then
    put line 1 of tResult into tError
  end if

  return tError
end _fileCopyFolder


command packagerCreateAllFoldersInPath pPath, pRootPath
  local tCheck, tError, tPathSegment

  ## Watch for double slashes /Folder/To//Something//
  ## You will not enter a never ending loop if you aren't careful.
  _stripDoubleSlash pPath
  _stripDoubleSlash pRootPath

  ## Get rid of trailing slashes
  ## We can safely ignore UNC paths starting with "//"
  ## Neither pPath or pRootPath with values of just "//" would be valid
  repeat until the last char of pPath is not slash
    delete the last char of pPath
  end repeat
  if the number of chars of pRootPath > 1 and the last char of pRootPath is slash then
    repeat forever
      delete the last char of pRootPath
      if the last char of pRootPath is not slash or the number of chars of pRootPath is 1 then
        exit repeat
      end if
    end repeat
  end if

  set the itemDelimiter to slash

  if pPath is empty or the number of items of pPath is 1 then
    put "cannot create folder (invalid path)" into tError
  end if

  ## VALIDATE pRootPath
  if tError is empty then
    if pRootPath is empty then
      put item 1 to 2 of pPath into pRootPath ## "/NODE"
    end if

    if tError is empty then
      if last char of pRootPath is not slash then put slash after pRootPath ## Makes it easier to deal with "/" path

      if not _fileIsFolder(pRootPath) then
        put "root path does not exist [root:" && pRootPath & "]" into tError
      end if
    end if
  end if

  ## VALIDATE ANCESTORY OF PATH
  if tError is empty then
    put char 1 to -2 of pRootPath into tCheck ## -2 gets rid of trailing slash
    if char 1 to (number of chars of tCheck) of pPath is not tCheck then
      put "path is not a child of root path" & cr & "[path:" && pPath & "]" & cr & "[root:" && pRootPath & "]" into tError
      put the executioncontexts
    end if
  end if

  ## CREATE FOLDERS
  if tError is empty then
    if number of items of pPath > number of items of pRootPath then
      put pRootPath & item (number of items of pRootPath + 1) of pPath into tPathSegment

      if not _fileIsFolder(tPathSegment) then
        create folder tPathSegment
        if the result is not empty then
          put "error creating folder (" & the result & ") [folder:" && tPathSegment & "]" into tError
        end if
      end if

      if tError is empty then
        packagerCreateAllFoldersInPath pPath, tPathSegment
        put the result into tError
      end if
    end if
  end if

  return tError
end packagerCreateAllFoldersInPath


private function _fileIsFolder pPath
  local tFolder, isAFolder

  put the defaultFolder into tFolder
  set the defaultfolder to pPath
  put the result is empty into isAFolder
  set the defaultFolder to tFolder
  return isAFolder
end _fileIsFolder


private command _stripDoubleSlash @pVariable
  local tCharNo, tPrefix

  # Don't wipe out UNC prefixes
  if char 1 to 2 of pVariable is "//" then
    put "//" into tPrefix
    delete char 1 to 2 of pVariable
  end if

  repeat forever
    put offset("//", pVariable) into tCharNo
    if tCharNo > 0 then
      replace "//" with slash in pVariable
    else
      exit repeat
    end if
  end repeat

  if tPrefix is not empty then
    put tPrefix before pVariable
  end if

  return empty
end _stripDoubleSlash


private function _escapeForShell pStr
  local tChar, tSpecialChars

  if the platform is "win32" then
    replace "/" with "\" in pStr
    put quote & pStr & quote into pStr
  else
    put "\" & space & quote & "'`<>!;()[]?#$^&*=|" into tSpecialChars
    repeat for each char tChar in tSpecialChars
      replace tChar with ("\" & tChar) in pStr
    end repeat
  end if

  return pStr
end _escapeForShell


on _moveFolder pSrcFolder, pDestFolder
  local tError,tResult, tExitCode

  if the platform is "MacOS" then
    put _escapeForShell(pSrcFolder) into pSrcFolder
    put _escapeForShell(pDestFolder) into pDestFolder
    put shell ("mv -f" && pSrcFolder && pDestFolder) into tResult
    put the result into tExitCode

  else if the platform is "Win32" then
    if the last char of pSrcFolder is "/" then delete the last char of pSrcFolder
    if the last char of pDestFolder is "/" then delete the last char of pDestFolder
    set the itemDelimiter to slash
    put "/" & the last item of pSrcFolder after pDestFolder

    put _escapeForShell(pSrcFolder) into pSrcFolder
    put _escapeForShell(pDestFolder) into pDestFolder

    # Note: `move` fails on networks paths like \\mypath\file.
    # Use `robocopy` or `xcopy` instead.
    if _isWindowsVistaOrNewer() then
      ## VISTA INTRODUCED ROBOCOPY. XCOPY WAS FAILING WITH COPIES TO PARALLELS NETWORK SHARE
      put shell ("robocopy" && pSrcFolder && pDestFolder && "/e /nfl /ndl /ns /nc /njh /njs") into tResult
    else
      put shell ("xcopy" && pSrcFolder && pDestFolder && "/y /v /i /e /r /h") into tResult
    end if
    put the result into tExitCode

    if tExitCode is empty then ## exit code is number of affected files
      revDeleteFolder pSrcFolder
    end if

  else -- linux
    put _escapeForShell(pSrcFolder) into pSrcFolder
    put _escapeForShell(pDestFolder) into pDestFolder
    put shell ("mv -f" && pSrcFolder && pDestFolder) into tResult
    put the result into tExitCode
  end if

  if tExitCode is not empty then
    put line 1 of tResult into tError
  end if

  return tError
end _moveFolder


## Like revDeleteFolder but returns valid error message.
on _deleteFolder pSrcFolder
  if the platform is "MacOS" and char 1 of the systemVersion is not "1" then
    if "applescript" is in the alternateLanguages then
      # OK-2009-02-11 : Removed unquoted literal pDestFolder
      --do revAppleScriptFull("deleteFolder",pSrcFolder,pDestFolder) as applescript
      do revAppleScriptFull("deleteFolder", pSrcFolder) as "applescript"
      return the result
    else return "Error: AppleScript not installed"
  else if the platform is "Win32" then
    revSetWindowsShellCommand
    if _isWindowsVistaOrNewer() then
      get shell ("rmdir /s /q" && revWindowsFromUnixPath(quote&pSrcFolder&quote))
    else
      get shell ("deltree /Y" && revWindowsFromUnixPath(quote&pSrcFolder&quote))
    end if
  else
    get shell ("rm -rf" && quote&pSrcFolder&quote)
  end if

  ## Only applies to Win/Linux
  if the result is not empty then return it
  else return empty
end _deleteFolder


private function _isWindowsVistaOrNewer
  return word 1 of the systemVersion is "NT" and word 2 of the systemVersion >= 6.0
end _isWindowsVistaOrNewer


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
