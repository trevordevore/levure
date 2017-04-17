script "Translate Library"
local sStringsA

on libraryStack
  if the target is not me then pass libraryStack
end libraryStack


on releaseStack
  if the target is not me then pass releaseStack
end releaseStack


function _t pKey
  local tStr

  put sStringsA[pKey] into tStr
  if tStr is empty then
    if the environment is "development" then
      answer "invalid key passed to _t:" && pKey
    else
      put pKey into tStr
    end if
  end if

  return tStr
end _t


command translateSetLocale pLocale
  local tError, tFilename

  put levureAppFolder() & "/locales/" & pLocale & ".yml" into tFilename
  if there is a file tFilename then
    put yamlFileToArray(tFilename) into sStringsA
    put the result into tError
  end if

  return tError
end translateSetLocale
