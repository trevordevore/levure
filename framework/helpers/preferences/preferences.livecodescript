script "Application Preferences Library"
local sUseExternal, sUseBroadcaster
local sDefaultPrefsA, sDefaultSharedPrefsA
local sPrefsA


on libraryStack
  if the target is not me then
    if sUseBroadcaster is false then
      put the short name of the target is "appBroadcaster" into sUseBroadcaster
    end if
  else
    put null into sPrefsA["user"]
    put null into sPrefsA["shared"]

    _loadDefaultPreferences
    if the result is not empty then
      throw "error loading default preferences:" && the result
    end if
  end if

  pass libraryStack
end libraryStack


on releaseStack
  if the target is not me then
    if sUseBroadcaster then
      if the short name of the target is "appBroadcaster" then
        put false into sUseBroadcaster
      end if
    end if
  end if

  pass releaseStack
end releaseStack


private function useBroadcaster
  if sUseBroadcaster is empty then
    set the wholematches to true
    put "appBroadcaster" is among the lines of the stacksinuse into sUseBroadcaster
  end if

  return sUseBroadcaster
end useBroadcaster


private function useExternal pUserOrShared
  if sUseExternal is empty then
    set the wholematches to true
    put the platform is "macos" and "Preferences" is among the lines of levureExternalsLoadedInMemory() into sUseExternal
  end if

  return sUseExternal and (pUserOrShared is "user")
end useExternal


private function prefFilenameForPlatform pUserOrShared, pPlatform
  local tA

  validateKey pUserOrShared

  if pPlatform is empty then put the platform into pPlatform
  if pPlatform is "win32" then put "windows" into pPlatform
  put "preferences" into tA[1]
  put pUserOrShared into tA[2]
  put pPlatform into tA[3]
  put "filename" into tA[4]
  return levureAppGet(tA)
end prefFilenameForPlatform


private command _loadDefaultPreferences
  local tError, tYamlFile

  put levureAppFolder() & "/prefs.yml" into tYamlFile
  if there is a file tYamlFile then
    put yamlFileToArray(tYamlFile) into sDefaultPrefsA
    put the result into tError
  end if

  if tError is empty then
    put levureAppFolder() & "/prefs_shared.yml" into tYamlFile
    if there is a file tYamlFile then
      put yamlFileToArray(tYamlFile) into sDefaultSharedPrefsA
      put the result into tError
    end if
  end if

  return tError for error
end _loadDefaultPreferences


function appGetDefaultPrefs pUserOrShared
  if pUserOrShared is "shared" then
    return sDefaultSharedPrefsA
  else
    return sDefaultPrefsA
  end if
end appGetDefaultPrefs


command appResetPrefs pUserOrShared
  validateKey pUserOrShared

  ## OS X external behavior
  if useExternal(pUserOrShared) then
    /*
    Implement once we switch to a module
    http://stackoverflow.com/questions/8259786/cocoa-resetting-nsuserdefaults
    */
  else
    put empty into sPrefsA[pUserOrShared]
    appSavePrefs pUserOrShared

    put empty into sPrefsA[pUserOrShared]["init"]
    delete local sPrefsA[pUserOrShared]["init"]
  end if
end appResetPrefs


command appReloadPrefs pUserOrShared
  validateKey pUserOrShared
  put null into sPrefsA[pUserOrShared]
  _ensurePrefsAreLoaded pUserOrShared
end appReloadPrefs


/**
* \brief Sets an application preference.
* \param pKey Name of preference to set.
* \param pValue Value to set preference to. This can be a string or an array.
* \param pUserOrShared Pass in "shared" to set a pref in shared preferences. Leave empty for default behavior.
* \param pType Pass in "binary" to force pref to be stored as binary (OS X). By default if value contains NULL then it will be stored as binary.
*
* \package Preferences
*
* \return error message
*/
command appSetPref pKey, pValue, pUserOrShared, pType
  local tStack, tError

  validateKey pUserOrShared

  ## OS X external behavior
  if useExternal(pUserOrShared) then
    if the keys of pValue is empty then
      if pValue contains NULL OR pType is "binary" then
        osxHLPrefSetBinary pKey, "pValue", prefFilenameForPlatform("user")
      else
        # encode strings as UTF8 or this will fail in LC 8. Convert to module at some point.
        osxHLPrefSetString pKey, textEncode(pValue, "utf8"), prefFilenameForPlatform("user")
      end if
    else
      put "_LCA" & arrayEncode(pValue) into pValue
      osxHLPrefSetBinary pKey, "pValue", prefFilenameForPlatform("user")
    end if
    put the result into tError

  else
    _ensurePrefsAreLoaded pUserOrShared
    put pValue into sPrefsA[pUserOrShared][pKey]
  end if

  # Broadcasting is one of framework helpers
  if tError is empty then
    if useBroadcaster() then
      appBroadcast "prefs", pKey, empty
    end if
  end if

  return tError for error
end appSetPref


/**
* \brief Gets an application preference.
* \param pKey Name of preference to get.
*
* \package Preferences
*
* \return value
*/
function appGetPref pKey, pUserOrShared
  local tStack, tValue

  validateKey pUserOrShared

  if not appPrefIsSet(pKey, pUserOrShared) then
    if pUserOrShared is "shared" then
      put sDefaultSharedPrefsA[pKey] into tValue
    else
      put sDefaultPrefsA[pKey] into tValue
    end if
  else
    if useExternal(pUserOrShared) then
      local tValueA

      osxHLPrefGet pKey, "tValueA", prefFilenameForPlatform("user")
      if the result is empty then
        switch tValueA["type"]
          case "binary"
            if tValueA["value"] begins with "_LCA" then
              try ## Assume everything is an array. If it fails then tValue stays the same
                put arrayDecode(char 5 to -1 of tValueA["value"]) into tValue
              end try
            else
              put tValueA["value"] into tValue
            end if
            break
          case "string"
          default
            put textDecode(tValueA["value"], "utf8") into tValue
            break
        end switch
      end if

    else
      _ensurePrefsAreLoaded pUserOrShared
      put sPrefsA[pUserOrShared][pKey] into tValue
    end if
  end if

  return tValue for value
end appGetPref


/**
* \brief Checks if a preference has been set on the computer the application is running on.
* \param pKey Name of preference to check.
*
* \return true/false
*/
function appPrefIsSet pKey, pUserOrShared
  local tStack

  validateKey pUserOrShared

  ## OS X external behavior
  if useExternal(pUserOrShared) then

    return osxHLPrefExists(pKey, prefFilenameForPlatform("user"))

  else
    _ensurePrefsAreLoaded pUserOrShared
    return pKey is among the keys of sPrefsA[pUserOrShared]
  end if
end appPrefIsSet


/**
* \brief Saves preferences to disk.
* \param pKey Name of preference to check.
*
* When setting preferences the preference is updated in memory. To permanently
* store changes on disk use this command.
*
* \return Error message
*/
command appSavePrefs pUserOrShared
  local tError, tFile

  validateKey pUserOrShared

  put appGetPreferenceFile(pUserOrShared) into tFile

  if tFile is not empty then
    if useExternal(pUserOrShared) then

      osxHLPrefSavePrefs prefFilenameForPlatform("user")
      put the result into tError

    else

      saveContentsToFile tFile, arrayEncode(sPrefsA[pUserOrShared])
      put the result into tError

    end if
  end if

  return tError
end appSavePrefs


function appGetPreferenceFile pUserOrShared
  local tFile

  validateKey pUserOrShared

  put prefFilenameForPlatform(pUserOrShared) into tFile

  if tFile is not empty then
    if pUserOrShared is "user" then
      return _systemPreferencesFolder() & slash & tFile
    else
      return _systemAppDataFolder("shared") & slash & tFile
    end if
  else
    return empty
  end if
end appGetPreferenceFile


private function _systemPreferencesFolder
  switch the platform
    case "macos"
      return specialFolderPath("preferences")
    case "win32"
    case "linux"
      return _systemAppDataFolder("user")
    default
      return empty
  end switch
end _systemPreferencesFolder


private function _systemAppDataFolder pUserOrShared
  if pUserOrShared is not "shared" then
    switch the platform
      case "win32"
      case "macos"
        return specialFolderPath("support")
      case "linux"
        return specialFolderPath("home")
      default
        return empty
    end switch
  else
    switch the platform
      case "macos"
        return specialFolderPath("asup")
      case "win32"
        return specialFolderPath("35")
      case "linux"
        return "/opt"
      default
        return empty
    end switch
  end if
end _systemAppDataFolder


private command _ensurePrefsAreLoaded pUserOrShared
  validateKey pUserOrShared

  if sPrefsA[pUserOrShared] is null then
    local tFile

    if pUserOrShared is "shared" then
      put appGetPreferenceFile("shared") into tFile
    else
      put appGetPreferenceFile("user") into tFile
    end if

    if there is a file tFile then
      local tError, tData

      put readFileContents(tFile) into tData
      put the result into tError

      if tError is empty then
        if tData is not empty then
          try
            put arrayDecode(tData) into sPrefsA[pUserOrShared]
          catch e
            throw "error loading preferences:" && e
          end try
        else
          put empty into sPrefsA[pUserOrShared]
        end if
        return true
      else
        throw "error loading preferences:" && tError
      end if
    else
      put 1 into sPrefsA[pUserOrShared]["init"]
      delete local sPrefsA[pUserOrShared]["init"]
      return true
    end if
  else
    return true
  end if
end _ensurePrefsAreLoaded


private function _errorMsg pMsg, pError
  if pError is not empty then
    return pMsg && "[" & pError & "]"
  else
    return empty
  end if
end _errorMsg


private function readFileContents pFilename
  local tError

  open file pFilename for binary read
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


private command saveContentsToFile pFilename, pData
  local tError, tTempFilename

  put pFilename & ".tmp" into tTempFilename

  open file tTempFilename for binary write
  put the result into tError

  if tError is empty then
    write pData to file tTempFilename
    put the result into tError

    close file tTempFilename
  end if

  if tError is not empty then
    put "(" & pFilename & ")" after tError
  end if

  if tError is empty then
    delete file pFilename

    rename file tTempFilename to pFilename
    put _errorMsg("renaming temp file" && tTempFilename, the result) into tError
  end if

  if tTempFilename is not empty then
    delete file tTempFilename
  end if

  if tError is empty then
    return empty for value
  else
    return tError && "(" & pFilename & ")" for error
  end if
end saveContentsToFile


private command validateKey @xUserOrShared
  if xUserOrShared is not "shared" then put "user" into xUserOrShared
  return empty for value
end validateKey
