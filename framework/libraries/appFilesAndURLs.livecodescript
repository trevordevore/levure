script "appFilesAndURLsFrontscript"
constant kAppStackName = "app"

local sURLsToProcessOnOpen
local sFilesToProcessOnOpen


function appGetURLsToProcessOnOpen
  return sURLsToProcessOnOpen
end appGetURLsToProcessOnOpen


function appGetFilesToProcessOnOpen
  return sFilesToProcessOnOpen
end appGetFilesToProcessOnOpen


on appleEvent pClass, pID, pSender
  ## Don't let user execute random scripts
  if the environment is not "development" and pClass & pID is among the items of "miscDOSC,miscEVAL" then exit appleEvent
  
  if pClass is "aevt" and pID is "odoc" then
    local tFiles
    
    request appleEvent data
    put it into tFiles
    
    if tFiles is not "not found" then
      put extractAppAssociatedFilesFromList(tFiles) into tFiles
      
      if tFiles is not empty then      
        if not hasAppLoaded() then
          if sFilesToProcessOnOpen is not empty then
            put sFilesToProcessOnOpen into line (the number of lines of tFiles + 1) of tFiles
          end if
          put tFiles into sFilesToProcessOnOpen
        else
          dispatch "ProcessFiles" to stack kAppStackName with tFiles
        end if
      else
        pass appleEvent
      end if
    else
      pass appleEvent
    end if
  else if pClass is "GURL" AND pID is "GURL" then
    ## application registered protocol
    request appleEvent data
    if not hasAppLoaded() then
      if sURLsToProcessOnOpen is not empty then
        put sURLsToProcessOnOpen into line (the number of lines of it + 1) of it
      end if
      put it into sURLsToProcessOnOpen
    else
      dispatch "ProcessURL" to stack kAppStackName with it
    end if
  else
    pass appleEvent
  end if
end appleEvent


/**
* This handler handles URLs and files. If '-url' appears in the params then the next param is considered
* a URL that needs to be processed. Otherwise all params are treated as files and any files with supported
* extensions are extracted and made available to the application for processing.
*/
command appProcessCommandLineParameters pParams
  local tLineNo
  
  set the wholeMatches to true
  
  put lineoffset("-url", pParams) into tLineNo
  if tLineNo > 0 then
    if not hasAppLoaded() then
      local tValue
      
      put line (tLineNo + 1) of pParams into tValue
      if sURLsToProcessOnOpen is not empty then
        put sURLsToProcessOnOpen into line (the number of lines of tValue + 1) of tValue
      end if
      put tValue into sURLsToProcessOnOpen
    else
      dispatch "ProcessURL" to stack kAppStackName with line (tLineNo + 1) of pParams
    end if
  else
    local tFiles
    
    put extractAppAssociatedFilesFromList(pParams) into tFiles
    if tFiles is not empty then
      if not hasAppLoaded() then
        if sFilesToProcessOnOpen is not empty then
          put sFilesToProcessOnOpen into line (the number of lines of tFiles + 1) of tFiles
        end if
        put tFiles into sFilesToProcessOnOpen
      else
        dispatch "ProcessFiles" to stack kAppStackName with tFiles
      end if
    end if
  end if
  
  return empty
end appProcessCommandLineParameters


function appSupportedFileExtensionsList pNames
  local tName, tExtensionsA, tExtensions
  
  put getFileExtensionsArray() into tExtensionsA
  
  if pNames is not empty then      
    repeat for each item tName in pNames
      if tExtensionsA[tName] is not empty then
        put tExtensionsA[tName] & cr after tExtensions
      end if
    end repeat
  else
    repeat for each key tName in tExtensionsA
      put tExtensionsA[tName] & cr after tExtensions
    end repeat
  end if
  delete the last char of tExtensions
  replace comma with cr in tExtensions
  sort lines of tExtensions ascending
  
  return tExtensions
end appSupportedFileExtensionsList


/**
* Returns a file type filter string suitable for use with 'ask file with type'.
*
* 'ask file with type' filters the available files that a user can select in the dialog using a specially \
      * formatted string. This function will generate that string based on the file extensions that have \
      * been defined for a File Type Filter object. The \
      * string will look something similar to this:
*/
function appFileDialogTypeFilterFromGroup pFileExtGroupName
  local tFileExtGroupsA, tGroupA
  local tFilter
  
  put getFileExtensionsGroupsArray() into tFileExtGroupsA
  put tFileExtGroupsA[pFileExtGroupName] into tGroupA
  
  if tGroupA is an array then
    local i
    local tFileTypes # not used
    
    repeat with i = 1 to the number of elements of tGroupA      
      if tGroupA[i]["extensions"] is not empty then
        put tGroupA[i]["name"] & "|" & tGroupA[i]["extensions"] & "|" & tFileTypes & cr after tFilter
      end if
    end repeat
    delete the last char of tFilter
  end if
  
  return tFilter
end appFileDialogTypeFilterFromGroup


/** 
* \brief Registers the application to process a particular URL handler on Windows.
*
* \param pProtocol The protocol to register (i.e. x-myapplication).
* \param pDescription Description of the protocol.
*
* Calling this handler on platforms other than Windows does nothing.
* http://msdn.microsoft.com/en-us/library/aa767914(v=vs.85).aspx
*
* \return Error
*/
command appRegisterURLProtocol pProtocol, pDescription
  local tError
  
  if pDescription is empty then put pProtocol && "Protocol" into pDescription
  
  switch the platform
    case "win32"
      local tFilename, wasSuccessful
      
      put levureStandaloneFilename() into tFilename
      replace "/" with "\" in tFilename
      put setRegistry("HKEY_CURRENT_USER\Software\Classes\" & pProtocol & "\", "URL:" & pDescription) into wasSuccessful ## default value
      put setRegistry("HKEY_CURRENT_USER\Software\Classes\" & pProtocol & "\URL Protocol", " ") into wasSuccessful
      put setRegistry("HKEY_CURRENT_USER\Software\Classes\" & pProtocol & "\Default Icon\", tFilename & ",1") into wasSuccessful ## default value
      put setRegistry("HKEY_CURRENT_USER\Software\Classes\" & pProtocol & "\shell\open\command\", \
            quote & tFilename & quote && "-url" && quote & "%1" & quote) into wasSuccessful ## default value
      put setRegistry("HKEY_CURRENT_USER\Software\Classes\" & pProtocol & "\UseOriginalUrlEncoding", "1") into wasSuccessful # IE9 recognizes this and won't decode URL prior to passing to app
      break
  end switch
  
  return tError
end appRegisterURLProtocol


/**
* Returns a file type filter string suitable for use with 'ask file with type'.
*
* 'ask file with type' filters the available files that a user can select in the dialog using a specially \
      * formatted string. This function will generate that string based on a file extension that you have defined \
      * in your application. The string will look something similar to this:
*
* <pre>JPEG file|jpg|JPEG</pre>
*/
function appFileDialogTypeFilterFromExtension pExtensionName
  local tFilter, tExtensionsA
  
  put getFileExtensionsArray() into tExtensionsA
  
  if pExtensionName[pExtensionName] is an array then
    put pExtensionName & "|" & pExtensionName[pExtensionName] & "|" & empty into tFilter
  end if
  
  return tFilter
end appFileDialogTypeFilterFromExtension


/**
* \brief Returns a list of file extensions for a File Type Filter Group. 
* \param pFileFilterName Name of File Type Filter object to locate group in.
* \param pGroupName Name of group to return extensions for.
*
* Example:
* <pre>put glxapp_fileTypeFilterGroupExtensionsString("Select Image", "Image Files") into theExtensions
* jpeg
* jpg
* png
* bmp
* gif</pre>
*
* \package Files
*
* \return CR delimited list
*/
function appFileExtensionGroupExtensions pGroupName
  local tExtGroupsA, tExtensions
  
  put getFileExtensionsGroupsArray() into tExtGroupsA
  
  if tExtGroupsA[pGroupName] is an array then
    local i
    
    repeat with i = 1 to the number of elements of tExtGroupsA[pGroupName]
      if tExtGroupsA[pGroupName][i]["extensions"] is not empty then
        put tExtGroupsA[pGroupName][i]["extensions"] & "," after tExtensions
      end if
    end repeat
  end if
  delete the last char of tExtensions
  replace "," with cr in tExtensions
  return tExtensions
end appFileExtensionGroupExtensions


function appFileExtensionGroupExtensionsForCategory pGroupName, pCategoryName
  local tExtGroupsA, tExtensions
  
  put getFileExtensionsGroupsArray() into tExtGroupsA
  
  if tExtGroupsA[pGroupName] is an array then
    local i
    
    repeat with i = 1 to the number of elements of tExtGroupsA[pGroupName]
      if tExtGroupsA[pGroupName][i]["name"] is pCategoryName then
        put tExtGroupsA[pGroupName][i]["extensions"] into tExtensions
        exit repeat
      end if
    end repeat
  end if
  replace "," with cr in tExtensions
  return tExtensions
end appFileExtensionGroupExtensionsForCategory


private function getFileExtensionsArray
  return levureAppGet("file extensions")
end getFileExtensionsArray


private function getFileExtensionsGroupsArray
  return levureAppGet("file extension groups")
end getFileExtensionsGroupsArray


/**
* \brief Given a list of files this function will extract all files that have extensions that are supported by your application. 
* \param pFiles CR delimited list of files to search in.
*
* \package Files
*
* \return CR delimited list
*/
private function extractAppAssociatedFilesFromList pFiles
  local tExtensions, tSupportedFiles
  local tFile, tCorrectedFilepath
  local tFileName, tExtension, tLineNo
  
  set the wholeMatches to true
  
  put appSupportedFileExtensionsList(empty) into tExtensions
   
  repeat for each line tFile in pFiles
    put _longFilePath(tFile) into tCorrectedFilepath
    
    set the itemDelimiter to slash
    put item -1 of tCorrectedFilepath into tFileName
    set the itemDelimiter to "."
    if the number of items of tFileName > 1 then
      put item -1 of tFileName into tExtension
      put lineOffset(tExtension, tExtensions) into tLineNo
      if tLineNo > 0 then
        put tCorrectedFilepath & cr after tSupportedFiles
      end if
    else
      # TODO: Check creator types on mac os (2016-11-12: is this relevant any longer?)
      if the platform is "MacOS" then
        
      end if
    end if
  end repeat
  
  delete the last char of tSupportedFiles
  return tSupportedFiles
end extractAppAssociatedFilesFromList


private function hasAppLoaded
  return levureApplicationHasLoaded()
end hasAppLoaded


private function _longFilePath pPath
  if pPath is empty then return empty
  
  if the platform is "win32" then
    local tLongPath
    
    # http://quality.runrev.com/show_bug.cgi?id=14453
    put the longFilePath of pPath into tLongPath
    if tLongPath is empty then
      return pPath
    else
      return tLongPath
    end if
  else
    return pPath
  end if
end _longFilePath
