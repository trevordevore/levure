script "Application Preferences"
constant kUserPrefStackname = "pref stack - user"
constant kSharedPrefStackname = "pref stack - shared"

local sUseExternal
local sDefaultPrefsA, sDefaultSharedPrefsA

private function useExternal
  if sUseExternal is empty then
    _loadDefaultPreferences
    
    set the wholematches to true
    put the platform is "macos" and "Preferences" is among the lines of levureExternalsLoadedInMemory() into sUseExternal
  end if
  
  return sUseExternal
end useExternal


private function prefFilenameForPlatform pPlatform
  local tA
  
  if pPlatform is empty then put the platform into pPlatform
  if pPlatform is "win32" then put "win" into pPlatform
  put "preferences" into tA[1]
  put pPlatform into tA[2]
  put "filename" into tA[3]
  return levureAppGet(tA)
end prefFilenameForPlatform


private command _loadDefaultPreferences
  local tYamlFile
  
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
  
  return tError
end _loadDefaultPreferences


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
  
  if pUserOrShared is "shared" then
    put kSharedPrefStackname into tStack
  else
    put kUserPrefStackname into tStack
  end if   
  
  ## OS X external behavior
  if the platform is "macos" and useExternal() then
    if the keys of pValue is empty then
      if pValue contains NULL OR pType is "binary" then
        osxHLPrefSetBinary pKey, "pValue", prefFilenameForPlatform()
      else
        osxHLPrefSetString pKey, pValue, prefFilenameForPlatform()
      end if
    else
      put "_LCA" & arrayEncode(pValue) into pValue
      osxHLPrefSetBinary pKey, "pValue", prefFilenameForPlatform()
    end if
    put the result into theError
    
  else
    local tCustomSets, tCustomKeys, tLineNo
    
    ## Verify pref stack is available
    _EnsurePrefStackIsLoaded tStack
    if not the result then
      answer param(0) && "tried to access preference but preferences have not been initialized:" && pKey & "."
      return empty
    end if
    
    set wholeMatches to true
    put long name of stack tStack into tStack
    
    ## TO AVOID PROPERTY NAME CONFLICTS WE PREPEND
    put "u" before pKey
    
    ## DELETE customKey OR customPropertySet OF STACK
    put customPropertySets of tStack into tCustomSets
    put lineOffset(pKey, tCustomSets) into tLineNo
    if theLineNo > 0 then delete line tLineNo of tCustomSets
    set customPropertySets of tStack to tCustomSets
    
    put customKeys of tStack into tCustomKeys
    put lineOffset(pKey, tCustomKeys) into tLineNo
    if tLineNo > 0 then delete line tLineNo of tCustomKeys
    set customKeys of tStack to tCustomKeys
    
    ## STORE STRINGS IN THE STACK DEFAULT CUSTOM PROPS
    ## STORE ARRAYS AS CUSTOM PROPERTY SETS OF THE STACK
    if the keys of pValue is empty then
      set the pKey of tStack to pValue
    else        
      set the customProperties[pKey] of tStack to pValue
    end if
    
    delete char 1 of pKey -- get rid of "u" prefix
  end if
  
  # Broadcasting is one of framework helpers
  appBroadcast "prefs", pKey, empty
  
  return theError
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
  
  if pUserOrShared is "shared" then
    put kSharedPrefStackname into tStack
  else
    put kUserPrefStackname into tStack
  end if
  
  ##########
  ## If pref isn't set then look for default value
  ##########
  if not appPrefIsSet(pKey, pUserOrShared) then    
    if pUserOrShared is "shared" then
      put sDefaultSharedPrefsA[pKey] into tValue
    else
      put sDefaultPrefsA[pKey] into tValue
    end if
    
  else
    
    ##########
    ## OS X external behavior
    ##########
    if the platform is "macos" and useExternal() then
      local tValueA
      
      osxHLPrefGet pKey, "tValueA", prefFilenameForPlatform()
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
            put tValueA["value"] into tValue
            break
        end switch
      end if
      
    else
      
      ##########
      ## Stack behavior
      ##########
      _EnsurePrefStackIsLoaded tStack
      if not the result then
        answer param(0) && "tried to access preference but preferences have not been initialized:" && pKey & "."
        return empty
      end if
      
      set the wholeMatches to true
      put long name of stack tStack into tStack
      
      ## TO AVOID PROPERTY NAME CONFLICTS WE PREPEND
      put "u" before pKey
      if pKey is among lines of customPropertySets of tStack then
        put the customProperties[pKey] of tStack into tValue
      else
        put the pKey of tStack into tValue
      end if
    end if
    
  end if
  
  return theValue
end appGetPref


function appGetPreferenceFile pType  
  local tFile
  
  put prefFilenameForPlatform() into tFile
  
  if tFile is not empty then
    if pType is "user" then
      return systemPreferencesFolder() & slash & tFile
    else
      return systemApplicationDataFolder("shared") & slash & tFile
    end if
  else
    return empty
  end if
end appGetPreferenceFile


private function systemPreferencesFolder
  if the platform is "macos" then
    return specialFolderPath("preferences")
  else if the platform is "win32" then
    return systemApplicationDataFolder("user")
  else if the platform is "linux" then
    return specialFolderPath("home")
  else
    return empty
  end if
end systemPreferencesFolder


private function systemApplicationDataFolder pUserOrShared
  local tDefaultFolder
  local tPath
  
  if pUserOrShared is not "shared" then
    put "user" into pUserOrShared
  end if
  
  if pUserOrShared is "user" then
    if the platform is "macos" then
      put specialFolderPath("support") into tPath
    else if the platform is "linux" then
      put specialFolderPath("home") into tPath
    else if the platform is "win32" then
      ## VERSIONS PRIOR TO WIN2000 USE REGISTRY SINCE SPECIALFOLDERPATH DOESN'T RETURN PROPER VALUE
      if word 2 of the systemVersion >= 5 then
        put specialFolderPath(26) into tPath ## USER APPLICATION DATA FOLDER
      end if
      
      if tPath is empty or tPath is "\\" then ## I've seen "\\" returned for redirected folder in a domain
        put queryRegistry("HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\" & \
              "CurrentVersion\Explorer\Shell Folders\AppData") into tPath
        replace "\" with "/" in tPath ## Convert to LiveCode slashes
      end if
    end if
    
  else
    ## SHARED
    if the platform is "macos" then
      put specialFolderPath("asup") into tPath
    else if the platform is "linux" then
      put "/opt" into tPath
    else                    
      ## VERSIONS PRIOR TO WIN2000 USE REGISTRY SINCE SPECIALFOLDERPATH DOESN'T RETURN PROPER VALUE
      if word 2 of the systemVersion >= 5 then
        put specialFolderPath(35) into tPath
      end if
      
      if tPath is empty or tPath is "\\" then
        put queryRegistry("HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\" & \
              "CurrentVersion\Explorer\Shell Folders\Common AppData") into tPath
        replace "\" with "/" in tPath
      end if
    end if
  end if
  
  return tPath
end systemApplicationDataFolder


private command _EnsurePrefStackIsLoaded pStackName
  if there is not a stack pStackName then
    local tFile, tStackIsLoaded
    
    if pStackName is kSharedPrefStackname then
      put appGetPreferenceFile("shared") into tFile
    else
      put appGetPreferenceFile("user") into tFile
    end if
    put there is a stack tFile into tStackIsLoaded
    if not tStackIsLoaded or the short name of stack tFile is not pStackName then
      return false
    end if
  end if
  
  return true
end _EnsurePrefStackIsLoaded


/**
* \brief Checks if a preference has been set on the computer the application is running on.
* \param pKey Name of preference to check.
*
* \package Preferences
*
* \return true/false
*/
function appPrefIsSet pKey, pUserOrShared
  local tStack
  
  if pUserOrShared is "shared" then
    put kSharedPrefStackname into tStack
  else
    put kUserPrefStackname into tStack
  end if   
  
  ## OS X external behavior
  if the platform is "macos" and useExternal() then
    
    return osxHLPrefExists(pKey, prefFilenameForPlatform())
    
  else
    _EnsurePrefStackIsLoaded tStack
    if not the result then
      answer param(0) && "tried to check preference but preferences have not been initialized:" && pKey & "."
      return false
    end if
    
    set the wholeMatches to true
    put long name of stack tStack into tStack
    put "u" before pKey
    return pKey is among the lines the customKeys[""] of tStack or pKey is among the lines of the customPropertySets of tStack
  end if
end appPrefIsSet


/**
* \brief Saves preferences to disk.
* \param pKey Name of preference to check.
*
* When setting preferences the preference is updated in memory. To permanently
* store changes on disk use this command.
*
* \package Preferences
*
* \return Error message
*/
command appSavePrefs pUserOrShared
  local tError, tFile
  
  put appGetPreferenceFile(pUserOrShared) into tFile
  
  ## OS X external behavior
  if the platform is "macos" AND useExternal() then
    
    osxHLPrefSavePrefs prefFilenameForPlatform()
    put the result into tError
    
  else
    
    if there is a file tFile then
      compact stack tFile
      
      save stack tFile as (tFile & "_tmp") with format "2.7"
      put _errorMsg(format("unable to save temp prefs file \"%s\"", tFile & "_tmp"), the result) into tError
      
      if tError is empty then
        delete file tFile
        put _errorMsg(format("unable to delete prefs file \"%s\"", tFile), the result) into tError
      end if
      
      if tError is empty then
        save stack (tFile & "_tmp") as tFile
        put _errorMsg(format("unable to restore prefs file \"%s\"", tFile), the result) into tError
      end if
      
      if tError is empty then
        delete file (tFile & "_tmp")
        put _errorMsg(format("unable to delete temp prefs file \"%s\"", tFile & "_tmp"), the result) into tError
      end if
    end if
    
  end if
  
  return theError
end appSavePrefs


private function _errorMsg pMsg, pError
  if pError is not empty then
    return pMsg && "[" & pError & "]"
  else
    return empty
  end if
end _errorMsg
