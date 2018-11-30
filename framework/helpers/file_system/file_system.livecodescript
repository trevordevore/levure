script "File System Library"
constant kAppStackName = "app"

local sURLsToProcessOnOpen
local sFilesToProcessOnOpen
local sMaxRecentFiles = "15"


on libraryStack
  if the target is not me then pass libraryStack

  local tListA, tProtocol

  if levureAppHasProperty("url protocols") then
    put levureAppGet("url protocols") into tListA
    repeat for each key tProtocol in tListA
      if word 1 to -1 of line 1 of tProtocol is not empty and word 1 to -1 of line 1 of tListA[tProtocol] is not empty then
        fileSystemRegisterURLProtocol tProtocol, tListA[tProtocol]
      end if
    end repeat
  end if
end libraryStack


on releaseStack
  if the target is not me then pass releaseStack
end releaseStack


/**
Summary: Returns a list of URLs that the operating system passed to your application at launch.

Returns: CR-delimited list
*/
function fileSystemURLsToProcessOnOpen
  return sURLsToProcessOnOpen
end fileSystemURLsToProcessOnOpen


/**
Summary: Returns a list of files that the operating system passed to your application at launch.

Returns: CR-delimited list

Description:
The helper will look at files passed to the application at launch and create a list of files
that are supported. A file is supported if the file extension is listed in the `file extensions` key
in the `app.yml` file.
*/
function fileSystemFilesToProcessOnOpen
  return sFilesToProcessOnOpen
end fileSystemFilesToProcessOnOpen


/**
Summary: Process the file/url so that levure handlers can be used for processing the request.

Parameters:
pUrl: If this is a file then it starts with file://

Description:
If a url caused the OS to open the app then this is called before levure app finishes loading.
It can be handled like other events triggered by file/url open requests.
*/
on urlWakeUp pUrl
  if pURL begins with "file://" then
    delete char 1 to 7 of pUrl
  end if
  ProcessCommandLineParameters pUrl
end urlWakeUp


/**
Summary: Processes files and urls that are sent to the application via appleEvents on macOS.

Description:
On macOS appleEvents are sent when an application should open a file or url. URLs and supported files
will be extracted from the message. If the application is running then `ProcessFiles` or `ProcessURL`
will be sent to the `app` stack. If the application is still loading then the files and urls will
be accessible using the `fileSystemFilesToProcessOnOpen()` and `fileSystemURLsToProcessOnOpen()` functions.
*/
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
Summary: Process parameters passed to the application on the command line.

Returns: empty

Description:
The `ProcessCommandLineParameters` message is sent from the framework when an application is loading up.
This handler processes URLs and files passed in on the command line. If '-url' appears in the params then the next param is considered
a URL that needs to be processed. Otherwise all params are treated as files and any files with supported
extensions are extracted and made available to the application for processing.

If the application is running then `ProcessFiles` or `ProcessURL`
will be sent to the `app` stack. If the application is still loading then the files and urls will
be accessible using the `fileSystemFilesToProcessOnOpen()` and `fileSystemURLsToProcessOnOpen()` functions.
*/
command ProcessCommandLineParameters pParams
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
end ProcessCommandLineParameters


/**
Summary: Registers the application to process a particular URL handler on Windows.

pProtocol The protocol to register (i.e. x-myapplication).
pDescription Description of the protocol.

Returns:  Error

Description:
Calling this handler on platforms other than Windows does nothing.
http://msdn.microsoft.com/en-us/library/aa767914(v=vs.85).aspx
*/
command fileSystemRegisterURLProtocol pProtocol, pDescription
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
end fileSystemRegisterURLProtocol


/**
Summary: Returns a CR delimited list of extensions associated with a given type.

Returns: CR-delimited list of extensions

Description:
Assume the following configuration in the `app.yml` file:

```
file extensions:
  JPEG File: jpeg,jpg
  PNG File: png
  BMP file: bmp
  GIF file: gif
```

You can get a list of JPEG extensions using the following code:

```
put fileSystemFileExtensionsForTypes("jpeg file") into tExtensions
```

`tExtensions` now contains the following value:

```
jpeg
jpg
```
*/
function fileSystemFileExtensionsForTypes pTypes
  local tType, tExtensionsA, tExtensions

  put getFileExtensionsArray() into tExtensionsA

  if pTypes is not empty then
    repeat for each item tType in pTypes
      if tExtensionsA[tType] is not empty then
        put tExtensionsA[tType] & cr after tExtensions
      end if
    end repeat
  else
    repeat for each key tType in tExtensionsA
      put tExtensionsA[tType] & cr after tExtensions
    end repeat
  end if
  delete the last char of tExtensions
  replace comma with cr in tExtensions
  sort lines of tExtensions ascending

  return tExtensions
end fileSystemFileExtensionsForTypes


/**
Summary: Creates a file type filter string from an extension that is suitable for use with `ask file with type`.

pExtensionName: A file extension name that has been defined in the `file extensions` key of the `app.yml` file.

Returns: filter type string

Description:
`ask file with type` filters the available files that a user can select in the dialog using a specially
formatted string. This function will generate that string based on file extensions that you have defined
in your application using the `file extensions` key of the `app.yml` file. The string will look something similar to this:

```
JPEG file|jpg|JPEG
```

Example:
# app.yml
file extensions:
  JPEG File: jpeg,jpg

#
put fileSystemFileDialogTypeFilterFromExtension("JPEG File") into theTypeFilter
ask files "Select JPEG Files" with theTypeFilter
*/
function fileSystemFileDialogTypeFilterFromExtension pExtensionName
  local tFilter, tExtensionsA

  put getFileExtensionsArray() into tExtensionsA

  if tExtensionsA[pExtensionName] is not empty then
    local tExtensions, tFileTypes

    _splitExtensionsIntoTypeFilter tExtensionsA[pExtensionName], tExtensions, tFileTypes
    put pExtensionName & "|" & tExtensions & "|" & tFileTypes into tFilter
  end if

  return tFilter
end fileSystemFileDialogTypeFilterFromExtension


private command _splitExtensionsIntoTypeFilter pExtensionStr, @rExtensions, @rFileTypes
  put empty into rExtensions
  put empty into rFileTypes

  repeat for each item tStr in pExtensionStr
    set the itemDelimiter to "|"
    if item 1 of tStr is not empty then
      put item 1 of tStr & "," after rExtensions
    end if
    if item 2 of tStr is not empty then
      put item 2 of tStr & "," after rFileTypes
    end if
    set the itemDelimiter to ","
  end repeat
  delete the last char of rExtensions
  delete the last char of rFileTypes
  return empty
end _splitExtensionsIntoTypeFilter


/**
Summary: Creates a file type filter string from a file extension group that is suitable for use with `ask file with type`.

pFileExtGroupName: A file extension group name that has been defined in the `file extension groups` key of the `app.yml` file.

Returns: filter type string

Description:
`ask file with type` filters the available files that a user can select in the dialog using a specially
formatted string. This function will generate that string based on the file extensions that have
been defined in the `file extension groups` key of the `app.yml` file. The string will look something similar to this:

```
JPEG file|jpg|JPEG
PNG file|png|PNG
GIF file|gif|GIF
```

Example:

# app.yml
file extension groups:
  Media Files:
    - name: All Files
      extensions: jpg,jpeg,png,bmp,gif

# Code
put fileSystemFileDialogTypeFilterFromGroup("Media Files") into theTypeFilter
answer files "Select media files:" with type theTypeFilter

*/
function fileSystemFileDialogTypeFilterFromGroup pFileExtGroupName
  local tFileExtGroupsA, tGroupA
  local tFilter

  put getFileExtensionsGroupsArray() into tFileExtGroupsA
  put tFileExtGroupsA[pFileExtGroupName] into tGroupA

  if tGroupA is an array then
    local i
    local tExtensions, tFileTypes

    repeat with i = 1 to the number of elements of tGroupA
      if tGroupA[i]["extensions"] is not empty then
        _splitExtensionsIntoTypeFilter tGroupA[i]["extensions"], tExtensions, tFileTypes
        put tGroupA[i]["name"] & "|" & tExtensions & "|" & tFileTypes & cr after tFilter
      end if
    end repeat
    delete the last char of tFilter
  end if

  return tFilter
end fileSystemFileDialogTypeFilterFromGroup


/**
Summary: Returns a list of file extensions for a File Type Filter Group.

pFileExtGroupName: A file extension group name that has been defined in the `file extension groups` key of the `app.yml` file.

Returns:  CR-delimited list

Example:
put fileSystemFileExtensionGroupExtensions("Select Image", "Image Files") into theExtensions
jpeg
jpg
png
bmp
gif
*/
function fileSystemFileExtensionGroupExtensions pFileExtGroupName
  local tExtGroupsA, tExtensions

  put getFileExtensionsGroupsArray() into tExtGroupsA

  if tExtGroupsA[pFileExtGroupName] is an array then
    local i

    repeat with i = 1 to the number of elements of tExtGroupsA[pFileExtGroupName]
      if tExtGroupsA[pFileExtGroupName][i]["extensions"] is not empty then
        put tExtGroupsA[pFileExtGroupName][i]["extensions"] & "," after tExtensions
      end if
    end repeat
  end if
  delete the last char of tExtensions
  replace "," with cr in tExtensions
  return tExtensions
end fileSystemFileExtensionGroupExtensions


/**
Summary: Returns a list of extensions for a specific category within a file extension group.

pFileExtGroupName: A file extension group name that has been defined in the `file extension groups` key of the `app.yml` file.
pCategoryName: A category of file extensions within pFileExtGroupName.

Returns: A CR-delimited list of file extensions

Example:
# app.yml
file extension groups:
  Media Files:
    - name: All Files
      extensions: jpg,jpeg,png,bmp,gif,svg,ai
    - name: Vector Files
      extensions: svg,ai
    - name: Bitmap Files
      extensions: jpg,jpeg,png,bmp,gif

# code
put fileSystemFileExtensionGroupExtensionsForCategory("Media Files", "Vector Files") into

*/
function fileSystemFileExtensionGroupExtensionsForCategory pFileExtGroupName, pCategoryName
  local tExtGroupsA, tExtensions

  put getFileExtensionsGroupsArray() into tExtGroupsA

  if tExtGroupsA[pFileExtGroupName] is an array then
    local i

    repeat with i = 1 to the number of elements of tExtGroupsA[pFileExtGroupName]
      if tExtGroupsA[pFileExtGroupName][i]["name"] is pCategoryName then
        put tExtGroupsA[pFileExtGroupName][i]["extensions"] into tExtensions
        exit repeat
      end if
    end repeat
  end if
  replace "," with cr in tExtensions
  return tExtensions
end fileSystemFileExtensionGroupExtensionsForCategory


private function getFileExtensionsArray
  return levureAppGet("file extensions")
end getFileExtensionsArray


private function getFileExtensionsGroupsArray
  return levureAppGet("file extension groups")
end getFileExtensionsGroupsArray


/**
Summary: Given a list of files this function will extract all files that have extensions that are supported by an application.

pFiles CR-delimited list of files to search in.

Returns:  CR-delimited list
*/
private function extractAppAssociatedFilesFromList pFiles
  local tExtensions, tSupportedFiles
  local tFile, tCorrectedFilepath
  local tFileName, tExtension, tLineNo

  set the wholeMatches to true

  put fileSystemFileExtensionsForTypes(empty) into tExtensions

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
  return levureApplicationState() is "running"
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


private function _encodeTextForMenu pString
  replace slash with slash & slash in pString
  replace "(" with "((" in pString
  replace "&" with "&&" in pString
  replace "\" with "\\" in pString
  return pString
end _encodeTextForMenu


private function _decodeMenuText pString
  replace slash & slash with slash in pString
  replace "((" with "(" in pString
  replace "&&" with "&" in pString
  replace "\\" with "\" in pString
  return pString
end _decodeMenuText


private function _recentlyOpenedFiles pCategory
  local tFilesA

  put prefsGetPref("recently opened:" && pCategory) into tFilesA
  if tFilesA is not an array then ## old behavior was just a list of files
    put tFilesA into tFilesA["files"]
    put tFilesA["files"] into tFilesA["tags"]
  end if

  return tFilesA
end _recentlyOpenedFiles


/**
Summary: Sets the maximum number of files that will be stored in the recent files list.

pMax: The maximum number of files to store in the list.

Returns: empty

Description:
Once the threshold is met the last file in the list will be removed when another file is added.
*/
command fileSystemSetMaxRecentFiles pMax
  if pMax is an integer AND pMax > 0 then
    put pMax into sMaxRecentFiles
  end if
  return empty for value
end fileSystemSetMaxRecentFiles


/**
Summary: Adds a file to the list of recently opened files for a specific category.

pCategory: The category to add the file to. This is simply a string that helps you organize multiple lists of recent files.
pFile: The full path to the file to add to the recent file list.
pTag: This will be used as the tag in the menu that is generated by fileSystemRecentlyOpenedMenuText. If empty then pFile is used. A tag can be useful if you are opening something other than a file. For example, perhaps it is a database record and you want to store the record id.
pSecurityBookmark: Pass in any security related bookmark data. Security bookmarks are required when opening a file in a sandboxed environment on macos. This will be stored with the entry as it may be needed to open the file.

Description:
If adding the file will exceed the maximum number of recent files that can be stored then
a numerically indexed array will be returned. The array representes the files that were
removed from the recently opened list. Each value is an array with "file" and "tag"
keys.

Calling this handler will save preferences.

Returns:
the result: Error message
it: Numerically indexed array
*/
command fileSystemAddToRecentlyOpened pCategory, pFile, pTag, pSecurityBookmark
  local tError, tFilesA, tPurgedFilesA
  local tLineOffset, i, j

  set the wholeMatches to true

  put word 1 to -1 of (line 1 of pFile) into pFile

  if pTag is empty then put pFile into pTag

  put _recentlyOpenedFiles(pCategory) into tFilesA

  put lineOffset(pFile, tFilesA["files"]) into tLineOffset	# look for exact matches
  if tLineOffset > 0 then
    delete line tLineOffset of tFilesA["files"]
    delete line tLineOffset of tFilesA["tags"]
  end if

  # Do this before adding cr to pTag
  put pSecurityBookmark into tFilesA["security bookmarks"][pTag]

  if tFilesA["files"] is not empty then
    put cr after pFile
    put cr after pTag
  end if
  put pFile before tFilesA["files"]
  put pTag before tFilesA["tags"]

  if the number of lines of tFilesA["files"] > sMaxRecentFiles then
    repeat with i = (sMaxRecentFiles+1) to the number of lines of tFilesA["tags"]
      delete local tFilesA["security bookmarks"][line i of tFilesA["tags"]]

      add 1 to j
      put line i of tFilesA["files"] into tPurgedFilesA[j]["file"]
      put line i of tFilesA["tags"] into tPurgedFilesA[j]["tag"]
    end repeat
    delete line (sMaxRecentFiles+1) to -1 of tFilesA["files"]
    delete line (sMaxRecentFiles+1) to -1 of tFilesA["tags"]
  end if

  prefsSetPref "recently opened:" && pCategory, tFilesA
  prefsSave
  put the result into tError

  if tError is not empty then
    return tError for error
  else
    return tPurgedFilesA for value
  end if
end fileSystemAddToRecentlyOpened


/**
Summary: Removes a file from the list of recently opened files for a specific category.

pCategory: The category to remove the file from. This is simply a string that helps you organize multiple lists of recent files.
pFile: The full path to the file to remove from the recent file list.

Returns: Error message

Description:
Calling this handler will save preferences.
*/
command fileSystemRemoveFromRecentlyOpened pCategory, pFile
  local tError,tFilesA,tLineOffset

  set the wholeMatches to true

  put _recentlyOpenedFiles(pCategory) into tFilesA

  put lineOffset(pFile, tFilesA["files"]) into tLineOffset # look for exact matches
  if tLineOffset > 0 then
    if line tLineOffset of tFilesA["tags"] is not empty then
      delete local tFilesA["security bookmarks"][line tLineOffset of tFilesA["tags"]]
    end if
    delete line tLineOffset of tFilesA["files"]
    delete line tLineOffset of tFilesA["tags"]
  end if

  prefsSetPref "recently opened:" && pCategory, tFilesA
  prefsSave
  put the result into tError

  return tError
end fileSystemRemoveFromRecentlyOpened


/**
Summary: Returns a list of recently opened files for a particular category.

pCategory: The category to retrieve the list of recently opened files for.
pShortVersion: Pass in true if you would like the file paths truncated to their shortest unique length. Default is full file path.

Returns: CR-delimited list
*/
function fileSystemRecentlyOpened pCategory, pShortVersion
  local tFile,tFileKeysA,tFilesA,tFileList,tFiles
  local tIndex,tItemCount,tKey

  put _recentlyOpenedFiles(pCategory) into tFilesA

  if pShortVersion then
    set the itemdelimiter to slash
    repeat for each line tFile in tFilesA["tags"]
      put -1 into tIndex
      put item tIndex of tFile into tKey
      put the number of items of tFile into tItemCount
      repeat until tFileKeysA[tKey] is empty or abs(tIndex) = tItemCount
        subtract 1 from tIndex
        put item tIndex to -1 of tFile into tKey
      end REPEAT
      put 1 into tFileKeysA[tKey]

      if char 1 of tKey is "/" then put ".." before tKey
      if the platform is "win32" then replace "/" with "\" in tKey
      put tKey & cr after tFileList
    end repeat
    delete the last char of tFileList
    return tFileList
  else
    return tFilesA["tags"]
  end if
end fileSystemRecentlyOpened


/**
Summary: Returns a list of recently opened files for a particular category which has been encoded for display in a menu.

pCategory: The category to retrieve the list of recently opened files for.

Returns: CR-delimited list

Description:
Each line of the returned list will be prefixed with a tab and will have special characters escaped
for display in a menu. The filename will be urlencoded so make sure to urldecode it in your `menuPick`
handler.
*/
function fileSystemRecentlyOpenedMenuText pCategory
  local tFile,tFileKeysA,tFilesA,tFileList,tFiles
  local tIndex,tItemCount,tKey
  local tLineNo

  put _recentlyOpenedFiles(pCategory) into tFilesA

  set the itemDelimiter to slash
  repeat for each line tFile in tFilesA["files"]
    add 1 to tLineNo
    put -1 into tIndex
    put item tIndex of tFile into tKey
    put the number of items of tFile into tItemCount
    repeat until tFileKeysA[tKey] is empty or abs(tIndex) = tItemCount
      subtract 1 from tIndex
      put item tIndex to -1 of tFile into tKey
    end repeat
    put 1 into tFileKeysA[tKey]

    if char 1 of tKey is "/" then put ".." before tKey
    if the platform is "win32" then replace "/" with "\" in tKey
    put tab & _encodeTextForMenu(tKey) & "/|" & urlencode(line tLineNo of tFilesA["tags"]) & cr after tFileList
  end repeat
  delete the last char of tFileList
  return tFileList
end fileSystemRecentlyOpenedMenuText


/**
Summary: Returns the security scoped bookmark data for a file.

pCategory: The category to retrieve the list of recently opened files for.
pTag: The tag assigned to the recently opened file. Unless you explicitly set a tag this will be the filename.

Returns: bookmark data
*/
function fileSystemSecurityBookmarkForRecentlyOpenedFile pCategory, pTag
  local tFilesA

  put _recentlyOpenedFiles(pCategory) into tFilesA

  return tFilesA["security bookmarks"][pTag]
end fileSystemSecurityBookmarkForRecentlyOpenedFile
