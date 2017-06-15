script "Preferences Library"
constant kPrefsErr = "prefserr,"

local sUseExternal, sUseBroadcaster
local sDefaultPrefsA, sDefaultSharedPrefsA
local sPrefsA


on libraryStack
  if the target is not me then pass libraryStack

  put null into sPrefsA["user"]
  put null into sPrefsA["shared"]

  _loadDefaultPreferences
  if the result is not empty then
    throw kPrefsErr & "unable to load default preferences:" && the result
  end if
end libraryStack


on releaseStack
  if the target is not me then pass releaseStack
end releaseStack


/**
Summary: Returns true if the broadcaster helper is available.
*/
private function useBroadcaster
  if sUseBroadcaster is empty then
    put levureIsHelperLoaded("broadcaster") into sUseBroadcaster
  end if

  return sUseBroadcaster
end useBroadcaster


/**
Summary: Returns true if an external should be used for interfacing with the OS prefs API.
*/
private function useExternal pUserOrShared
  if sUseExternal is empty then
    set the wholematches to true
    put the platform is "macos" and "Preferences" is among the lines of levureExternalsLoadedInMemory() into sUseExternal
  end if

  return sUseExternal and (pUserOrShared is "user")
end useExternal


/**
Summary: Returns the preference file name for the category and platform.

pUserOrShared: Preferences category. "user" or "shared". Default is "user".
pPlatform: macos, ios, windows, android, linux

Returns: Pref file name defined in `app.yml`
*/
private function prefFilenameForPlatform pUserOrShared, pPlatform
  local tA, tDefaultPrefName, tPrefName

  validateKey pUserOrShared

  if pPlatform is empty then put the platform into pPlatform

  switch pPlatform
    case "win32"
      put "windows" into pPlatform
      break
    case "iphone"
      put "ios" into pPlatform
      break
  end switch

  put "preferences filename" into tA[1]
  put pUserOrShared into tA[2]

  put "default" into tA[3]
  put levureAppGet(tA) into tDefaultPrefName

  put pPlatform into tA[3]
  put levureAppGet(tA) into tPrefName

  if tPrefName is empty then put tDefaultPrefName into tPrefName

  if tPrefName is empty then
    throw kPrefsErr & param(0) && ": the" && quote & "preferences filename" & quote \
          && "property has not been set for" && pPlatform && "in app.yml"
  end if

  return tPrefName
end prefFilenameForPlatform


/**
Summary: Loads the `prefs.yml` and `prefs_shared.yml` files if they exist.

Returns: Error

Description:
Looks for and loads `prefs.yml` and `prefs_shared.yml` files alongside the `app.yml` file.
`prefs.yml` defines default values for "user" category prefs. `prefs_shared.yml` defines
default values for "shared" category prefs.
*/
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


/**
Summary: Returns the entire array of default preferences.

pUserOrShared: Preferences category. "user" or "shared". Default is "user".

Returns: Array representing YAML configuration store in `prefs.yml` and `prefs_shared.yml`
*/
function prefsGetDefaults pUserOrShared
  if pUserOrShared is "shared" then
    return sDefaultSharedPrefsA
  else
    return sDefaultPrefsA
  end if
end prefsGetDefaults


/**
Summary: Resets all values in in preferences to empty.

pUserOrShared: Preferences category. "user" or "shared". Default is "user".

Returns: Empty

Description:
Use this handler if you would like to reset all preferences to their default values as defined
in `prefs.yml` and `prefs_shared.yml`.

Note that on OS X this command currently does not work.
*/
command prefsReset pUserOrShared
  validateKey pUserOrShared

  ## OS X external behavior
  if useExternal(pUserOrShared) then
    /*
    Implement once we switch to a module
    http://stackoverflow.com/questions/8259786/cocoa-resetting-nsuserdefaults
    */
  else
    put empty into sPrefsA[pUserOrShared]
    prefsSave pUserOrShared

    # recreate "user" or "shared" key as an array type
    put empty into sPrefsA[pUserOrShared]["init"]
    delete local sPrefsA[pUserOrShared]["init"]
  end if

  return empty for value
end prefsReset


/**
Summary: Reloads preferences from the file on disk.

pUserOrShared: Preferences category. "user" or "shared". Default is "user".

Returns: Empty

Description:
This handler will clear out any values that are stored internally and reloads
preferences from the file on disk.

Note that this command does nothing on OS X which handles preferences using Cocoa
APIs.
*/
command prefsReload pUserOrShared
  validateKey pUserOrShared

  if not useExternal(pUserOrShared) then
    put null into sPrefsA[pUserOrShared]
    _ensurePrefsAreLoaded pUserOrShared
  end if
  return empty for value
end prefsReload


/**
Summary: Sets an application preference.

pKey: Name of preference to set.
pValue: Value to set preference to. This can be a string or an array.
pUserOrShared: Preferences category. "user" or "shared". Default is "user".
pType: Pass in "binary" to force pref to be stored as binary (OS X). By default if value contains NULL then it will be stored as binary.

Returns: error message
*/
command prefsSetPref pKey, pValue, pUserOrShared, pType
  local tStack, tError

  validateKey pUserOrShared

  # OS X external behavior
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
      broadcasterBroadcast "prefs", pKey, pKey
    end if
  end if

  return tError for error
end prefsSetPref


/**
Summary: Gets an application preference.

pKey: Name of preference to get.
pUserOrShared: Preferences category. "user" or "shared". Default is "user".

Returns: value
*/
function prefsGetPref pKey, pUserOrShared
  local tStack, tValue

  validateKey pUserOrShared

  if not prefsIsPrefSet(pKey, pUserOrShared) then
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
            put tValueA["value"] into tValue
            if tValue begins with "_LCA" then
              try # Assume a value with _LCA prefix is an array. If operation fails then tValue stays the same.
                put arrayDecode(byte 5 to -1 of tValue) into tValue
              end try
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
end prefsGetPref


/**
Summary: Checks if a preference has been set on the computer the application is running on.

pKey: Name of preference to check.
pUserOrShared: Preferences category. "user" or "shared". Default is "user".

Returns: true/false
*/
function prefsIsPrefSet pKey, pUserOrShared
  local tStack

  validateKey pUserOrShared

  ## OS X external behavior
  if useExternal(pUserOrShared) then

    return osxHLPrefExists(pKey, prefFilenameForPlatform("user"))

  else
    _ensurePrefsAreLoaded pUserOrShared
    return pKey is among the keys of sPrefsA[pUserOrShared]
  end if
end prefsIsPrefSet


/**
Summary: Saves preferences to disk.

pUserOrShared: Preferences category. "user" or "shared". Default is "user".

Returns: Error message

Description:
When setting preferences the preference is updated in memory. To permanently
store changes on disk use this command.
*/
command prefsSave pUserOrShared
  local tError, tFile

  validateKey pUserOrShared

  put prefsGetPreferenceFile(pUserOrShared) into tFile

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
end prefsSave


/**
Summary: Returns the file where preferences are stored.

pUserOrShared: Preferences category. "user" or "shared". Default is "user".

Returns: Filename or empty

Description:
Returns the filename of the preference file. If an external is being used on OS X
then empty will be returned.
*/
function prefsGetPreferenceFile pUserOrShared
  local tFile

  validateKey pUserOrShared

  put prefFilenameForPlatform(pUserOrShared) into tFile

  if tFile is not empty then
    return _preferencesFolder(pUserOrShared) & "/" & tFile
  else
    return empty
  end if
end prefsGetPreferenceFile


private function _preferencesFolder pUserOrShared
  if pUserOrShared is "user" then
    switch the platform
      case "macos"
        return specialFolderPath("preferences")
      case "win32"
      case "linux"
      case "iphone"
      case "android"
        return levureApplicationDataFolder("user")
      default
        return empty
    end switch
  else
    switch the platform
      case "macos"
      case "win32"
      case "linux"
        return levureApplicationDataFolder("shared")
      default
        return empty
    end switch
  end if
end _preferencesFolder


private command _ensurePrefsAreLoaded pUserOrShared
  validateKey pUserOrShared

  if sPrefsA[pUserOrShared] is null then
    local tFile

    if pUserOrShared is "shared" then
      put prefsGetPreferenceFile("shared") into tFile
    else
      put prefsGetPreferenceFile("user") into tFile
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
            throw kPrefsErr & "error loading preferences:" && e
          end try
        else
          put empty into sPrefsA[pUserOrShared]
        end if
        return true
      else
        throw kPrefsErr & "error loading preferences:" && tError
      end if
    else
      # create "user" or "shared" key as an array type
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
