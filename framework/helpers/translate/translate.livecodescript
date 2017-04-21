script "Translate Library"
local sStringsA

on libraryStack
  if the target is not me then pass libraryStack
end libraryStack


on releaseStack
  if the target is not me then pass releaseStack
end releaseStack


/**
Summary: Returns the translation string associated with a key.

pKey: The translation string key.

Returns: String

Description:
Use this function to get the translation string associated with a key. A key
will be the same across multiple translation files. The string assigned to
the key will be different for each language, however.
*/
function _t pKey
  local tStr

  put sStringsA[pKey] into tStr
  if tStr is empty then
    if the environment is "development" then
      answer error "invalid key passed to _t:" && pKey
    else
      put pKey into tStr
    end if
  end if

  return tStr
end _t


/**
Summary: Loads a translation file into memory.

pLocale: Locale identifier to load.

Returns: Error

Description:
Use this command to load a file containing translations for strings used in
your user interface. Locale files are stored in a `locales` folder that sits
alongside your `app.yml` file.

The command looks for a `.yml` file named `pLocale`.
*/
command translateSetLocale pLocale
  local tError, tFilename

  put levureAppFolder() & "/locales/" & pLocale & ".yml" into tFilename
  if there is a file tFilename then
    put yamlFileToArray(tFilename) into sStringsA
    put the result into tError
  end if

  return tError
end translateSetLocale
