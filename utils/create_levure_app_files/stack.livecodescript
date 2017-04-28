local sSettingsA


command uiCreateLevureApp
  local tOutputFolder

  answer folder "Select your application folder"
  put it into tOutputFolder

  if tOutputFolder is not empty then
    CreateLevureApp tOutputFolder
  end if
end uiCreateLevureApp


command CreateLevureApp pFolder
  local tError

  put empty into sSettingsA

  put word 1 to -1 of the text of field "GitPath" into sSettingsA["git folder"]
  replace "\" with "/" in sSettingsA["git folder"]
  if sSettingsA["git folder"] is not empty then
    if the last char of sSettingsA["git folder"] is not "/" then
      put "/" after sSettingsA["git folder"]
    end if
  end if

  put pFolder into sSettingsA["target folder"]

  if the hilite of button "UseGit" then
    CreateApplicationFilesAndFolders
    put the result into tError

    if tError is empty then
      SetupGitInFolder
      put the result into tError
    end if

    if tError is empty then
      CreateStandaloneStackfile
      put the result into tError
    end if

    if tError is empty then
      AddFilesToGit
      put the result into tError
    end if

    if tError is empty then
      AppProjectCompleted
    end if
  else
    # download latest version
    load url "http://github.com/trevordevore/levure/archive/master.zip" with callback "LevureZipDownloadComplete"
    put the result into tError
  end if

  AnswerError "starting Levure zip archive download", tError
end CreateLevureApp


command LevureZipDownloadComplete pUrl, pUrlStatus
  local tError

  if pUrlStatus is "cached" then
    local tFilename

    put sSettingsA["target folder"] & "/levure-master.zip" into tFilename
    put url pUrl into URL ("binfile:" & tFilename)
    UnzipLevureFiles tFilename
    put the result into tError

    unload url pUrl
    delete file tFilename

    if tError is empty then
      delete char -4 to -1 of tFilename
      rename folder tFilename to sSettingsA["target folder"] & "/levure"
      put the result into tError
    end if

    if tError is empty then
      CreateApplicationFilesAndFolders
      put the result into tError
    end if

    if tError is empty then
      CreateStandaloneStackfile
      put the result into tError
    end if

    if tError is empty then
      AppProjectCompleted
    end if
  else if pUrlStatus is not "cancelled" then
    if pUrlStatus is "error" then
      put libURLErrorData(pUrl) into tError
    else
      put pUrlStatus into tError
    end if
  end if

  AnswerError "downloading Levure zip archive", tError
end LevureZipDownloadComplete


command CreateApplicationFilesAndFolders
  local tError

  if tError is empty then
    local tFolder

    put sSettingsA["target folder"] & "/app" into tFolder
    fileCreateAllFoldersInPath tFolder, sSettingsA["target folder"]
    put the result into tError
  end if

  if tError is empty then
    create folder sSettingsA["target folder"] & "/builds"
    create folder tFolder & "/backscripts"
    create folder tFolder & "/behaviors"
    create folder tFolder & "/frontscripts"
    create folder tFolder & "/helpers"
    create folder tFolder & "/libraries"
    create folder tFolder & "/ui"
    create folder tFolder & "/assets"
  end if

  if tError is empty then
    put DefaultAppYaml() into url("binfile:" & tFolder & "/app.yml")
    put DefaultAppScript() into url("binfile:" & tFolder & "/app.livecodescript")
  end if

  if tError is empty then
    local tBehaviorFile

    create folder tFolder & "/ui/sample_window"
    create folder tFolder & "/ui/sample_window/behaviors"

    put tFolder & "/ui/sample_window/behaviors/card_behavior.livecodescript" into tBehaviorFile
    put the uSampleWindowBehavior of me into url ("binfile:" & tBehaviorFile)

    clone stack "LevureSampleWindowTemplate" as "LevureSampleWindow"
    set the behavior of this card of stack "LevureSampleWindow" to the long id of stack tBehaviorFile
    save stack "LevureSampleWindow" as (tFolder & "/ui/sample_window/sample_window.livecode")
    delete stack "LevureSampleWindow"
    delete stack tBehaviorFile
  end if

  return tError
end CreateApplicationFilesAndFolders


command CreateStandaloneStackfile
  local tError

  if tError is empty then
    clone stack "LevureStandaloneTemplate" as "LevureStandalone"
    set the stackfiles of stack "LevureStandalone" to "levureFramework,../levure/framework/levure.livecodescript"
    set the behavior of stack "LevureStandalone" to the long id of stack (sSettingsA["target folder"] & "/levure/framework/levure.livecodescript")
    # levureFramework was loaded into memory when assigned as the behavior
    delete stack "levureFramework"
    save stack "LevureStandalone" as (sSettingsA["target folder"] & "/app/standalone.livecode")
    delete stack "LevureStandalone"
  end if

  return tError
end CreateStandaloneStackfile


command SetupGitInFolder
  local tFolder, tResult, tError

  put the defaultFolder into tFolder
  set the defaultFolder to sSettingsA["target folder"]

  if tError is empty then
    put shell(sSettingsA["git folder"] & "git init") into tResult
    if the result is not empty then
      put tResult into tError
    end if
  end if

  if tError is empty then
    put shell(sSettingsA["git folder"] & "git submodule add https://github.com/trevordevore/levure.git levure") into tResult
    if the result is not empty then
      put tResult into tError
    end if
  end if

  if tError is empty then
    put the uGitIgnoreFile of this stack into url("binfile:" & sSettingsA["target folder"] & "/.gitignore")
  end if

  set the defaultFolder to tFolder

  return tError
end SetupGitInFolder


command AddFilesToGit
  local tFolder, tResult, tError

  put the defaultFolder into tFolder
  set the defaultFolder to sSettingsA["target folder"]

  if tError is empty then
    put shell(sSettingsA["git folder"] & "git add .") into tResult
    if the result is not empty then
      put tResult into tError
    end if
  end if

  set the defaultFolder to tFolder

  return tError
end AddfilesToGit


private function DefaultAppYaml
  return the uAppYAML of this stack
end DefaultAppYaml


private function DefaultAppScript
  return the uAppStackScript of this stack
end DefaultAppScript


command UnzipLevureFiles pFilename
  local tError

  if tError is empty then
    revZipOpenArchive pFilename, "read"
    put the result into tError
  end if

  if tError is empty then
    zipDecompressArchiveToFolder pFilename, sSettingsA["target folder"], empty, "UnzipPackageCallback"
    put the result into tError
  end if

  revZipCloseArchive pFilename

  return tError
end UnzipLevureFiles


command UnzipPackageCallback pItemNo, pItemCount

end UnzipPackageCallback


command AppProjectCompleted
  answer "Your Levure project has been created."
end AppProjectCompleted


command AnswerError pMsg, pError
  if pError is not empty then
    answer error "An error occurred while" && pMsg && "[" && pError & "]."
  end if
end AnswerError


/**
* \brief Creates a zip file from a directory. The ZIP archive should already have been opened with revZipOpenArchive.
*
* \param pZipArchivePath The path to save the zip archive to. This should already have been opened with revZipOpenArchive.
* \param pRootFolderPath The folder to save in the zip archive.
* \param pIncludeRootFolderInArchiveItemNames Pass in true to include the name of pRootFolderPath in the zip archive.
* \param pFilesToExclude Files that should not be included in the archive.
* \param pExtensionsThatArentCompressed File extensions that should be added without any compression.
* \param pFolderPath Used when calling itself recursively. Pass in empty.
*
* \return empty
*/
command zipAddFolderToArchive pZipArchivePath, pRootFolderPath, pIncludeRootFolderInArchiveItemNames, pFilesToExclude, pExtensionsThatArentCompressed, pFolderPath
  local theArchiveItemName,theCharNo,tError,theFile
  local theFiles,theFolder,theFolders

  put pIncludeRootFolderInArchiveItemNames is true into pIncludeRootFolderInArchiveItemNames
  set the wholeMatches to true

  replace comma with cr in pExtensionsThatArentCompressed

  if pFolderPath is empty then
    put pRootFolderPath into pFolderPath
    if pIncludeRootFolderInArchiveItemNames then
      set the itemdel to slash # we want folder to be reflected in archive item name
      delete item -1 of pRootFolderPath
    end if
  end if

  put fileFilesInFolder(pFolderPath, true, true) into theFiles
  filter theFiles without "*/.DS_Store"
  set the itemdel to "."

  repeat for each line theFile in theFiles
    if theFile is among the lines of pFilesToExclude then next repeat

    put theFile into theArchiveItemName
    put offset(pRootFolderPath, theArchiveItemName) into theCharNo
    if theCharNo is 0 then return "file is not in expected folder"

    delete char 1 to (the number of chars of pRootFolderPath + 1) of theArchiveItemName # strip root folder up to slash (zip item names shouldn't start with a slash)

    if item -1 of theArchiveItemName is among the lines of pExtensionsThatArentCompressed then
      revZipAddUncompressedItemWithFile pZipArchivePath, theArchiveItemName, theFile
    else
      revZipAddItemWithFile pZipArchivePath, theArchiveItemName, theFile
    end if
    if the result is not empty then
      put the result into tError
      exit REPEAT
    end if
  end REPEAT

  if tError is empty then
    put fileFoldersInFolder(pFolderPath, true, true) into theFolders
    repeat for each line theFolder in theFolders
      zipAddFolderToArchive pZipArchivePath, pRootFolderPath, pIncludeRootFolderInArchiveItemNames, pFilesToExclude, pExtensionsThatArentCompressed, theFolder
      put the result into tError
      if tError is not empty then
        exit REPEAT
      end if
    end REPEAT
  end if

  return tError
end zipAddFolderToArchive


/**
* \brief Decompresses a ZIP archive to a folder. The ZIP archive should already have been opened with revZipOpenArchive.
*
* \param pZipArchivePath The path to the zip archive. This should already have been opened with revZipOpenArchive.
* \param pOutputFolder The folder to save the zip archive to.
* \param pItemsToExclude List of files that won't be extracted from the ZIP archive.
* \param pCallbackHandler The handler to call with progress updates.
*
* \return empty
*/
command zipDecompressArchiveToFolder pZipArchivePath, pOutputFolder, pItemsToExclude, pCallbackHandler
  local tError, theFileType, theArchiveItems, theItemCount, i
  local theFilePath, theDirectoryPath, theCard

  if the last char of pOutputFolder is slash then delete the last char of pOutputFolder

  set the wholeMatches to true
  put the fileType into theFileType
  set the fileType to empty

  put revZipEnumerateItems(pZipArchivePath) into theArchiveItems
  put the number of lines of theArchiveItems into theItemCount

  repeat for each line theArchiveItem in theArchiveItems
    add 1 to i

    if theArchiveItem is among the lines of pItemsToExclude then next repeat

    put pOutputFolder & slash & theArchiveItem into theFilePath
    if the last char of theFilePath is "/" then
      ## Directory
      fileCreateAllFoldersInPath theFilePath, pOutputFolder
      put _ZipErrorMsg("creating directory" && theFilePath, the result) into tError
    else
      put fileExtractDirectory(theFilePath) into theDirectoryPath

      if theDirectoryPath is not pOutputFolder then
        fileCreateAllFoldersInPath theDirectoryPath, pOutputFolder
        put _ZipErrorMsg("creating parent directory" && theDirectoryPath, the result) into tError
      end if

      if tError is empty then
        if pCallbackHandler is not empty then
          put CardOf(the long ID of the target) into theCard
          if theCard is not empty then
            dispatch pCallbackHandler to theCard with i, theItemCount
          else
            dispatch pCallbackHandler with i, theItemCount
          end if
          --                    put "dispatch" && quote & pCallbackHandler && "i, theItemCount" & quote && "to theCard" into theDo
          --               do theDo
        end if

        revZipExtractItemToFile pZipArchivePath, theArchiveItem, theFilePath
        put _ZipErrorMsg("archive:" && theArchiveItem & ", filepath:" && theFilePath, the result) into tError
      end if
    end if

    if tError is not empty then exit REPEAT
  end REPEAT

  set the fileType to theFileType

  return tError
end zipDecompressArchiveToFolder


private function _ZipErrorMsg pPrefix, pError
  if pError is not empty then
    answer quote & pError & quote
    if pPrefix begins with "ziperr," then
      delete char 1 to 7 of pPrefix
    end if
    return pPrefix & ": " & pError
  else
    return empty
  end if
end _ZipErrorMsg


function CardOf pControl
  local theCharNo

  put the long ID of pControl into pControl ## force the long id

  if word 1 of pControl is "stack" then
    put empty into pControl -- has no card
  else
    if word 1 of pControl is not "card" then
      put offset(" of card ", pControl) into theCharNo
      if theCharNo > 0 then
        delete char 1 to (theCharNo + 3) of pControl
      else
        put empty into pControl
      end if
    end if
  end if
  return pControl
end CardOf


command fileCreateAllFoldersInPath pPath, pRootPath, pPerms
  local theCheck,tError,thePathSegment

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

  ## Permissions
  if pPerms is not "shared" then put "user" into pPerms
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

      if not fileIsFolder(pRootPath) then
        put "root path does not exist" into tError
      end if
    end if
  end if

  ## VALIDATE ANCESTORY OF PATH
  if tError is empty then
    put char 1 to -2 of pRootPath into theCheck ## -2 gets rid of trailing slash
    if char 1 to (number of chars of theCheck) of pPath is not theCheck then
      put "path is not a child of root path" into tError
    end if
  end if

  ## CREATE FOLDERS
  if tError is empty then
    if number of items of pPath > number of items of pRootPath then
      put pRootPath & item (number of items of pRootPath + 1) of pPath into thePathSegment

      if not fileIsFolder(thePathSegment) then
        create folder thePathSegment
        if the result is not empty then
          put "error creating folder (" & the result & ")" into tError
        else
          if pPerms is "shared" then
            fileSetPermissions thePathSegment, "execute", "execute", "execute"
            if the result is not empty then
              put format("error setting permissions for folder \"%s\" (%s)", thePathSegment, line 1 of the result) into tError
            end if
          end if
        end if
      end if

      if tError is empty then
        fileCreateAllFoldersInPath pPath, thePathSegment, pPerms
        put the result into tError
      end if
    end if
  end if

  return tError
end fileCreateAllFoldersInPath


on fileSetPermissions pFile, pOwner, pGroup, pAll
  local tError,theResult

  put _escapeForShell(pFile) into pFile

  switch the platform
    case "Win32"
      /*
      Displays or changes file attributes.
      ATTRIB [+R | -R] [+A | -A] [+S | -S] [+H | -H] [[drive:][path]filename]  [/S] [/D]

      + Sets an attribute.
      - Clears an attribute.
      R Read-only file attribute.
      A Archive file attribute.
      S system file attribute.
      H Hidden file attribute.
      /S Processes files in all directories in the specified path.
      /D Processes folders as well
      */

      switch pOwner
        case "read"
          put "+r" into pOwner
          break
        case "write"
          put "-r" into pOwner
          break
      end switch
      put shell (format ("attrib %s %s", pOwner, pFile) ) into theResult
      break

    case "MacOS"
      put _executableBitFromType(pOwner) into pOwner
      put _executableBitFromType(pGroup) into pGroup
      put _executableBitFromType(pAll) into pAll
      put shell(format("chmod %u%u%u %s ", pOwner, pGroup, pAll, pFile)) into theResult
      break
  end SWITCH

  if the result is not empty then
    put line 1 of theResult into tError
  end if

  return tError
end fileSetPermissions


private function _executableBitFromType pType
  switch pType
    case "execute"
      put 7 into pType
      break
    case "write"
      put 6 into pType
      break
    case "read"
      put 5 into pType
      break
    default
      put 0 into pType
  end switch
  return pType
end _executableBitFromType


private function _escapeForShell pStr
  local theChar,theSpecialChars

  if the platform is "win32" then
    replace "/" with "\" in pStr
    put quote & pStr & quote into pStr
  else
    put "\" & space & quote & "'`<>!;()[]?#$^&*=|" into theSpecialChars
    repeat for each char theChar in theSpecialChars
      replace theChar with ("\" & theChar) in pStr
    end REPEAT
  end if

  return pStr
end _escapeForShell


## Used for removing multiple slashes from folder paths
private command _stripDoubleSlash @pVariable
  local theCharNo,thePrefix

  ## Don't wipe out UNC prefixes
  if char 1 to 2 of pVariable is "//" then
    put "//" into thePrefix
    delete char 1 to 2 of pVariable
  end if

  repeat forever
    put offset("//", pVariable) into theCharNo
    if theCharNo > 0 then
      replace "//" with slash in pVariable
    else
      exit repeat
    end if
  end repeat

  if thePrefix is not empty then
    put thePrefix before pVariable
  end if

  return empty
end _stripDoubleSlash


function fileIsFolder pPath
  local theFolder, isAFolder

  put the defaultFolder into theFolder
  set the defaultfolder to pPath
  put the result is empty into isAFolder
  set the defaultFolder to theFolder
  return isAFolder
end fileIsFolder


function fileExtractDirectory pFilePath
  set the itemDelimiter to slash
  return item 1 to -2 of pFilePath
end fileExtractDirectory


function fileFilesInFolder pFolder, pFullPath, pIncludeHidden
  local theDefault,theFile,theFiles,theFullFiles

  if not fileIsFolder(pFolder) then return empty
  if last char of pFolder is not slash then put slash after pFolder

  put the defaultFolder into theDefault
  set the defaultFolder to pFolder
  put the files into theFiles
  set the defaultFolder to theDefault
  if pIncludeHidden is not true then
    filter theFiles without ".*"
  else
    filter theFiles without "..*"
  end if

  if pFullPath then
    repeat for each line theFile in theFiles
      put pFolder & theFile & cr after theFullFiles
    end REPEAT
    delete last char of theFullFiles
    return theFullFiles
  else
    return theFiles
  end if
end fileFilesInFolder


function fileFoldersInFolder pFolder, pFullPath, pIncludeHidden
  local theDefault,theFolders,theFullFolders,theFolder

  if not fileIsFolder(pFolder) then return empty
  if last char of pFolder is not slash then put slash after pFolder

  put the defaultFolder into theDefault
  set the defaultFolder to pFolder
  put the folders into theFolders
  set the defaultFolder to theDefault

  if pIncludeHidden is not true then
    filter theFolders without ".*"
  else
    filter theFolders without "..*"
  end if

  if pFullPath then
    repeat for each line theFolder in theFolders
      put pFolder & theFolder &cr after theFullFolders
    end repeat
    delete last char of theFullFolders
    return theFullFolders
  else
    return theFolders
  end if
end fileFoldersInFolder
