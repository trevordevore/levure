script "Levure Framework Application Packager"
local sStandaloneFilename

on libraryStack
  pass libraryStack
end libraryStack


on releaseStack
  pass releaseStack
end releaseStack


command levurePackageApplication pStandaloneStackFilename
  local tError, tLoaded
  
  put pStandaloneStackFilename into sStandaloneFilename
  
  if tError is empty then  
    put there is a stack sStandaloneFilename into tLoaded
    if not tLoaded then
      put "invalid standalone stack" into tError
    end if
  end if
  
  if tError is empty then
    start using stack sStandaloneFilename
    loadAppConfig
  end if
end levurePackageApplication


command levureBuildStandalones sStandaloneStackFilename, pBuildProfile
  local tError
  local buildForDistribution, tTempBuildFolder, tSourceFolder
  
  set the itemdelimiter to "/"
  
  put pBuildProfile is not "test" into buildForDistribution
  put levureBuildFolder() into tOutputFolder
  put the effective filename of stack sStandaloneStackFilename into tSourceFolder
  delete the last item of tSourceFolder  
  
  if tError is empty then
    if tOutputFolder is empty then
      put "not build folder has been set" into tError
    end if
    if levureAppGet("version") is empty then
      put "version has not been set" into tError
    end if
  end if
  
  if tError is empty then
    if buildForDistribution then
      put "/" & levureAppGet("version") & "(" & levureAppGet("build") & ")" after tOutputFolder
    else
      put "/test_executables" after tOutputFolder
    end if
    if there is a folder tOutputFolder then
      revDeleteFolder tOutputFolder
    end if
    create folder tOutputFolder
    put the result into tError
  end if
  
  if tError is empty then
    _updateStandaloneVersionInfo sStandaloneStackFilename
    put the result into tError
  end if
  
  if tError is empty then
    revIDESaveStack the long id of stack sStandaloneStackFilename
    put the result into tError
  end if
    
  if tError is empty then
    local tTempStandaloneStack
    
    put tSourceFolder & "/levureBuildStandaloneTemp_" && the milliseconds & ".livecode" into tTempStandaloneStack
    
    delete stack sStandaloneStackFilename
    revCopyFile sStandaloneStackFilename, tTempStandaloneStack
    put the result into tError
  end if
  
  if tError is empty then
    local tStackFiles, tLineNo
    
    put the stackfiles of stack tTempStandaloneStack into tStackFiles
    set the stackfiles of stack tTempStandaloneStack to empty
    
    put lineoffset("levureFramework", tStackFiles) into tLineNo
    if tLineNo is 0 then
      put "levureFramework is not assigned to the stackfiles of the standalone stack" into tError
    end if
  end if
  
  if tError is empty then
    local tAppPath, tFrameworkPath
    
    set the itemdelimiter to ","
    put item 2 to -1 of line tLineNo of tStackFiles into tFrameworkPath
    put resolveRelativeFilenameReference(tFrameworkPath, tSourceFolder) into tFrameworkPath
    put makeRelativePath(tFrameworkPath, tOutputFolder) into tFrameworkPath
    put levureAppFolder() into tAppPath
    put makeRelativePath(tAppPath, tOutputFolder) into tAppPath
    
    put generateStartupScript(tFrameworkPath, tAppPath, buildForDistribution) into tScript
    
    set the script of stack tTempStandaloneStack to tScript
    revIDESaveStack the long id of stack tTempStandaloneStack
    put the result into tError
  end if
  
  ## Now build standalones
  if tError is empty then
    local tStack
    
    put the short name of stack tTempStandaloneStack into tStack
    put specialFolderPath("temporary") into tTempBuildFolder
    put "/revstandalone" & the milliseconds after tTempBuildFolder
    try
      set the itemdelimiter to "."
      send "revSaveAsStandalone tStack, tTempBuildFolder" to stack "revSaveAsStandalone"
    catch e
      put e into tError
    end try
    
    set the stackfiles of stack sStandaloneStackFilename to tOrigStackFiles
  end if
  
  ## Finally, copy standalones to proper folder
  if tError is empty then
    _copyExecutablesAndSupportingFilesToFolder tTempBuildFolder, tOutputFolder
    put the result into tError
  end if
  
  if there is a folder tTempBuildFolder then
    revDeleteFolder tTempBuildFolder
  end if
  if there is a file tTempStandaloneStack then
    delete stack tTempStandaloneStack
    delete file tTempStandaloneStack
  end if
  
  # reload
  local isReloaded
  put there is a stack sStandaloneStackFilename into isReloaded
  
  if tError is not empty then
    answer "Error building standalones:" && tError & "."
  end if
end levureBuildStandalones


private command _copyExecutablesAndSupportingFilesToFolder pBuildFolder, pOutputFolder
  local tError
  local tFolderContainingPlatformBuilds, tPlatformFolders, tPlatformFolder
  local tWindowsFolder, tLinuxFolder, tMacOSXBundle
  local tFiles, tFile
  
  put folderListing(pBuildFolder) into tFolderContainingPlatformBuilds
  put folderListing(tFolderContainingPlatformBuilds) into tPlatformFolders
  
  set the itemdelimiter to "/"
  
  repeat for each line tPlatformFolder in tPlatformFolders
    if the last item of tPlatformFolder begins with "Windows" then
      put tPlatformFolder into tWindowsFolder
    else if the last item of tPlatformFolder begins with "MacOSX" then
      put folderListing(tPlatformFolder) into tMacOSXBundle
    else if the last item of tPlatformFolder begins with "Linux" then
      put tPlatformFolder into tLinuxFolder
    else if tPlatformFolder ends with ".app" then
      ## OS X application
      put tPlatformFolder into tMacOSXBundle
    end if
  end repeat
  
  ## No folders/mac app found? Only built for one platform so copy everything over
  if tWindowsFolder is empty and tMacOSXBundle is empty and tLinuxFolder is empty then
    put fileListing(tFolderContainingPlatformBuilds) into tFiles
    if tFiles is not empty then
      repeat for each line tFile in tFiles
        if tFile ends with ".exe" then
          put tFolderContainingPlatformBuilds into tWindowsFolder
        else
          put tFolderContainingPlatformBuilds into tLinuxFolder
        end if
      end repeat
    end if
  end if
  
  # Clear out externals folder
  if tError is empty then
    if there is a folder (pOutputFolder & "/Externals") then
      revDeleteFolder (pOutputFolder & "/Externals")
    end if
    
    if there is a folder (tWindowsFolder & "/Externals") or there is a folder (tLinuxFolder & "/Externals") then
      create folder (pOutputFolder & "/Externals")
      put the result into tError
    end if
  end if
  
  if tError is empty then
    if tWindowsFolder is not empty then
      repeat for each line tFile in fileListing(tWindowsFolder)
        if there is a file (pOutputFolder & "/" & the last item of tFile) then
          delete file (pOutputFolder & "/" & the last item of tFile)
        end if
        
        rename file tFile to (pOutputFolder & "/" & the last item of tFile)
        put the result into tError
        
        if tError is not empty then exit repeat
      end repeat
      
      if tError is empty then
        if there is a folder (tWindowsFolder & "/Externals") then
          moveFilesAndFolders tWindowsFolder & "/Externals", pOutputFolder & "/Externals"
          put the result into tError
        end if
      end if
    end if
  end if
  
  if tError is not empty then
    if tLinuxFolder is not empty then
      repeat for each line tFile in fileListing(tLinuxFolder)
        if there is a file (pOutputFolder & "/" & last item of tFile) then
          delete file (pOutputFolder & "/" & last item of tFile)
        end if
        
        rename file tFile to (pOutputFolder & "/" & the last item of tFile)
        put the result into tError
        
        if tError is not empty then exit repeat
      end repeat
      
      if tError is empty then
        if there is a folder (tLinuxFolder & "/Externals") then
          moveFilesAndFolders tLinuxFolder & "/Externals", pOutputFolder & "/Externals"
          put the result into tError
        end if
      end if
    end if
  end if
  
  if tError is empty then
    if tMacOSXBundle is not empty then
      if there is a folder (pOutputFolder & "/" & the last item of tMacOSXBundle) then
        revDeleteFolder (pOutputFolder & "/" & the last item of tMacOSXBundle)
      end if
      rename folder tMacOSXBundle to (pOutputFolder & "/" & the last item of tMacOSXBundle)
    end if
  end if
  
  return tError for error
end _copyExecutablesAndSupportingFilesToFolder


private command moveFilesAndFolders pSourceFolder, pDestinationFolder
  local tError, tFile

  set the itemdelimiter to "/"
  
  if tError is empty then  
    repeat for each line tFile in fileListing(pSourceFolder)
      rename file tFile to (pDestinationFolder & "/" & the last item of tFile)
      put the result into tError
    
      if tError is not empty then exit repeat
    end repeat
  end if
  
  if tError is empty then
    repeat for each line tFile in folderListing(pSourceFolder)
      rename folder tFile to (pDestinationFolder & "/" & the last item of tFile)
      put the result into tError
    
      if tError is not empty then exit repeat
    end repeat
  end if
  
  return tError
end moveFilesAndFolders


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
  
  ## -- OS X
  if the cRevStandaloneSettings["OSX,plist"] of stack pStackFilename is not empty then
    local tPlist
    
    put the filename of stack pStackFilename into tPlist
    set the itemdelimiter to slash
    put the cRevStandaloneSettings["OSX,plist"] of stack pStackFilename into the last item of tPlist
    if there is a file tPlist then
      local tData
      
      ## Developer is doing this the proper way. Update plist
      put URL("binfile:" & tPlist) into tData
      
      _updatePlistInfo tData
      
      put tData into URL("binfile:" & tPlist)
      put the result into tError
      if tError is not empty then
        put "error writing plist info: " & tError into tError
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
  
  return tError for error
end _updateStandaloneVersionInfo


private command _updatePlistInfo @xData, pVersionA
  local tRangeA, tVersion, tBuild, tString
  
  put levureAppGet("version") into tVersion
  put levureAppGet("build") into tBuild
  
  put _findRangeForPlistEntry(xData, "CFBundleGetInfoString") into tRangeA
  if tRangeA["start"] > 0 then
    put char tRangeA["start"] to tRangeA["end"] of xData into tString
    
    put tVersion && "build" && levureAppGet("build") into tVersion
    put tVersion into item 1 of tString
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


private command revSBListWidgetsOfStack pStack, @xWidgetKindsA
  local tNumCards, tNumWidgets, tKind
  put the number of cards of pStack into tNumCards
  repeat with tCard = 1 to tNumCards
    put the number of widgets of card tCard of pStack into tNumWidgets
    repeat with tWidget = 1 to tNumWidgets
      put the kind of widget tWidget of card tCard of pStack into tKind
      put "" into xWidgetKindsA[tKind]
    end repeat
  end repeat
end revSBListWidgetsOfStack


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


private function generateStartupScript pRelativeFrameworkPath, pRelativeAppPath, pBuildForDistribution
  local tScript, tFunction
  
  if pBuildForDistribution then
    
  else
    put "appFolder()" into tFunction
  end if
  
  put "on startup" & cr & \
        qstr("put resolvePath(`" & pRelativeFrameworkPath & "`, " & tFunction & ") into tStackfile") & cr & \
        "set the behavior of me to the long id of stack tStackfile" & cr & \
        "end startup" into tScript
        
  put cr & cr & \
      "function levureTestingStandaloneAppFolder" & cr & \
      qstr("put resolvePath(`" & pRelativeAppPath & "`, " & tFunction & ") into tStackfile") & cr & \
      "return tStackfile for value" & cr & \
      "end levureTestingStandaloneAppFolder" after tScript
  
  put cr & cr & \
        "private function resolvePath pFilename, pRootFolder" & cr & \
        qstr("set the itemDelimiter to `/`") & cr & \
        qstr("repeat while pFilename begins with `../`") & cr & \
        "if pRootFolder is empty then" & cr & \
        qstr("return `relative path is too deep for root folder` for error") & cr & \
        "else" & cr & \
        "delete the last item of pRootFolder" & cr & \
        "delete char 1 to 3 of pFilename" & cr & \
        "end if" & cr & \
        "end repeat" & cr & \
        qstr("return pRootFolder & `/` & pFilename for value") & cr & \
        "end resolvePath" after tScript
  
  put cr & cr & \
        "private function appFolder" & cr & \
        "set the itemdelimiter to slash" & cr & \
        "put the effective filename of me into tFilename" & cr & \
        "delete the last item of tFilename" & cr & \
        qstr("if the platform is `macos` and tFilename contains `.app/Contents/MacOS` then") & cr & \
        "delete item -3 to -1 of tFilename" & cr & \
        "end if" & cr & \
        "return tFilename" & cr & \
        "end appFolder" after tScript
  
  return tScript for value
end generateStartupScript


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


private function makeRelativePath pFilename, pRootFolder
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
end makeRelativePath


private function qstr pStr
  replace "`" with quote in pStr
  return pStr
end qstr
