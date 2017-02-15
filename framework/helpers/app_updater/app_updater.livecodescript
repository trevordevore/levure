script "AppUpdater"
local sUpdateIsAvailable = "false"
local sAppUpdateStructure
local sUseSparkle
local sCallbacksA
local sNumberOfDownloadTries


/**
 * \brief Call when application starts up to check for an update in background.
 */
command appCheckForUpdateInBackground
  if _killUpdater() then
    send "_appCheckForUpdateInBackground" to me in 10 milliseconds
  end if
end appCheckForUpdateInBackground


/**
* \brief Use in menu item. Checks if an update is available. If so then the user is prompted to update and the update process begins.
*
* \param pCallback Pass in a callback to be notified when this is complete. First param is error message.
*
* \return Error message
*/
command appPromptUserToUpdateIfAvailable pCallback
  local tError

  put item 1 to -3 of (line -2 of the executioncontexts) into sCallbacksA["update"]["object"]
  put pCallback into sCallbacksA["update"]["handler"]

  appCheckForUpdate "_appPromptUserToUpdateIfAvailableCallback"
  put the result into tError

  return tError for error
end appPromptUserToUpdateIfAvailable


/**
* \brief Checks if an update for you application is available on the update server.
*
* This handler gets the necessary information from the update server to see if a update \
      * for your application is available. After calling this command you can check appIsUpdateAvailable()
      * to see if there is an available update.
*/
command appCheckForUpdate pCallback
  local tError

  if _killUpdater() then return empty

  put item 1 to -3 of (line -2 of the executioncontexts) into sCallbacksA["check"]["object"]
  put pCallback into sCallbacksA["check"]["handler"]

  if _useSparkle() then
    _RunSparkleUpdater
    put the result into tError
  else
    local tURL

    # Legacy support for glxapp updater dialog.
    if there is a stack "glxappUpdateDialog" then
      set the name of stack "glxappUpdateDialog" to "appUpdateDialog"
    end if

    ## RESET STRUCTURE
    put empty into sAppUpdateStructure

    put levureAppGet("auto update url") into tURL

    load url tURL with message "_appUpdaterInfoDownloaded"
    put the result into tError
  end if

  ## No need to have error in the error message which can occur with the socket timeout error message
  if word 1 of tError is "error" then delete word 1 of tError
  return tError for error
end appCheckForUpdate


/**
* \brief Ask the user if they would like to update their version of the application.
*
* \param pParamsA Any parameters you want to pass to the appUpdateDialog stack via the array stored in the dialogData.
*
* \package Application Updater
*
* \return "cancel" or "update"
*/
command appPromptUserToUpdate pParamsA
  local tErrorMsg, tError

  if there is not a stack "appUpdateDialog" then
    put "Unable to load update description window." into tErrorMsg

    if sAppUpdateStructure["updater dialog"] is not empty then
      try
        put decompress(sAppUpdateStructure["updater dialog"]) into sAppUpdateStructure["updater dialog"]
      catch e
        put "invalid updater dialog" into tError
      end try

      if tError is empty then
        local tDialogA

        put pParamsA into tDialogA
        put sAppUpdateStructure["change log"] into tDialogA["change log"]
        put sAppUpdateStructure["application version"] into tDialogA["application version"]
        set the dialogData to tDialogA

        ## This doesn't throw an error if there is no stack
        go stack sAppUpdateStructure["updater dialog"] as modal
        if the result is "no such card" then ## 'no such card'
          put "invalid update dialog stack" into tError
        end if
      end if

      if tError is not empty then
        ## Stack didn't load properly
        _DisplayError tErrorMsg
        set the dialogData to "cancel"
      end if
    else
      _DisplayError tErrorMsg
      set the dialogData to "cancel"
    end if
  else
    modal stack "appUpdateDialog"
  end if
  return the dialogData
end appPromptUserToUpdate


/**
* \brief Downloads the Windows installer from the server.
*
* The _appUpdaterDownloaded message is sent when the updater finishes downloading from the server.
* If Sparkle is being used then the Sparkle updater handles everything but this shouldn't be the entry point
* for Sparkle.
*
* \return Error message
*/
command appInstallUpdate
  local tError

  if _killUpdater() then
    exit appInstallUpdate
  end if

  if _useSparkle() then
    _RunSparkleUpdater
    put the result into tError
  else
    dispatch "PreUpdateApplication" to stack levureAppStackName()
    if it is not "handled" or the result is not false then
      put 1 into sNumberOfDownloadTries

      load URL sAppUpdateStructure["updater url"] with message "_appUpdaterDownloaded"
      if the result is not empty then
        put libURLErrorData(sAppUpdateStructure["updater url"]) into tError
      end if
    else if it is "handled" then
      put "cancel" into tError
    end if
  end if

  return tError
end appInstallUpdate


function appIsUpdateAvailable
  if _killUpdater() then
    return false
  else
    if _useSparkle() then
      return sUpdateIsAvailable is true OR mergSparkleUpdateInProgress()
    else
      return sUpdateIsAvailable
    end if
  end if
end appIsUpdateAvailable


command _appCheckForUpdateInBackground
  local tError

  if _useSparkle() then
    mergSparkleStartup
    put the result into tError
  else
    appCheckForUpdate "_appCheckForUpdateInBackgroundCallback"
    put the result into tError
  end if

  if tError is not empty then
    _DisplayError tError
  end if
end _appCheckForUpdateInBackground


command _appUpdaterInfoDownloaded pUrl, pUrlStatus
  local tFileContent, tError

  switch pUrlStatus
    case "cached"
      put url pUrl into tFileContent
      unload url pURL

      ## Normalize line endings
      replace numToChar(13) & numToChar(10) with numToChar(10) in tFileContent
      replace numToChar(13) with numToChar(10) in tFileContent

      put line 1 of tFileContent into sAppUpdateStructure["application version"]
      put line 2 of tFileContent into sAppUpdateStructure["engine version"]
      put line 3 of tFileContent into sAppUpdateStructure["updater url"]
      put line 4 of tFileContent into sAppUpdateStructure["change log"]
      put line 8 of tFileContent into sAppUpdateStructure["updater dialog"] ## might be empty

      if sAppUpdateStructure["change log"] is not empty then
        load url sAppUpdateStructure["change log"] with message "_appUpdaterChangeLogDownloaded"
        put the result into tError
      else if sAppUpdateStructure["updater dialog"] is not empty then
        load url sAppUpdateStructure["updater dialog"] with message "_appUpdaterDialogDownloaded"
        put the result into tError
      else
        _dispatchCheckCallback
        exit _appUpdaterInfoDownloaded
      end if
      break
    case "cancelled"
      break
    case "error"
      if param(3) is not empty then
        put param(3) into tError
      else
        put libURLErrorData(pURL) into tError
      end if
      break
    case "timeout"
    default
      put pUrlStatus && "[" & pURL & "]" into tError
      break
  end switch

  # Early exit if error
  if tError is not empty then
    _dispatchCheckCallback tError
  end if
end _appUpdaterInfoDownloaded


command _appUpdaterChangeLogDownloaded pUrl, pUrlStatus
  local tError

  switch pUrlStatus
    case "cached"
      put url pUrl into sAppUpdateStructure["change log"]
      unload url pURL

      if there is not a stack "appUpdateDialog" AND sAppUpdateStructure["updater dialog"] is not empty then
        load url sAppUpdateStructure["updater dialog"] with message "_appUpdaterDialogDownloaded"
        put the result into tError
      else
        _dispatchCheckCallback
        exit _appUpdaterChangeLogDownloaded
      end if
      break
    case "cancelled"
      break
    case "error"
      if param(3) is not empty then
        put param(3) into tError
      else
        put libURLErrorData(pURL) into tError
      end if
      break
    case "timeout"
    default
      put pUrlStatus && "[" & pURL & "]" into tError
      break
  end switch

  # Early exit if error
  if tError is not empty then
    _dispatchCheckCallback tError
  end if
end _appUpdaterChangeLogDownloaded


command _appUpdaterDialogDownloaded pUrl, pUrlStatus
  local tError

  switch pUrlStatus
    case "cached"
      put url pUrl into sAppUpdateStructure["updater dialog"]
      unload url pURL
      break
    case "cancelled"
      break
    case "error"
      if param(3) is not empty then
        put param(3) into tError
      else
        put libURLErrorData(pURL) into tError
      end if
      break
    case "timeout"
    default
      put pUrlStatus && "[" & pURL & "]" into tError
      break
  end switch

  _dispatchCheckCallback tError
end _appUpdaterDialogDownloaded


private command _dispatchCheckCallback pError
  if pError is empty then
    put _compareVersionStrings( \
            levureAppGet("version") & "." & levureAppGet("build"), \
            "<", \
            sAppUpdateStructure["application version"]) into sUpdateIsAvailable
  end if

  if sCallbacksA["check"]["handler"] is not empty then
    if there is a sCallbacksA["check"]["object"] then
      dispatch sCallbacksA["check"]["handler"] to sCallbacksA["check"]["object"] with pError
    else
      dispatch sCallbacksA["check"]["handler"] with pError
    end if
  end if

  delete local sCallbacksA["check"]
end _dispatchCheckCallback


command _appPromptUserToUpdateIfAvailableCallback pError
  if pError is empty then
    if not _useSparkle() then
      if appIsUpdateAvailable() then
        local tParamsA

        put true into tParamsA["show skip button"]
        appPromptUserToUpdate tParamsA
        if the result is "install" then
          appInstallUpdate
          put the result into pError
        end if
      else
        put "no update available" into pError
      end if
    end if
  end if

  if sCallbacksA["update"]["handler"] is not empty then
    if there is a sCallbacksA["update"]["object"] then
      dispatch sCallbacksA["update"]["handler"] to sCallbacksA["update"]["object"] with pError
    else
      dispatch sCallbacksA["update"]["handler"] with pError
    end if
  else if pError is not empty then
    _DisplayError pError
  end if

  delete local sCallbacksA["update"]
end _appPromptUserToUpdateIfAvailableCallback


command _appCheckForUpdateInBackgroundCallback pError
  if pError is empty then
    if appIsUpdateAvailable() then
      local tVersion, tLineNo

      ## Is user skipping this version?
      set the wholematches to true
      put levureAppGet("version") & "." & levureAppGet("build") into tVersion
      put lineoffset(tVersion, appGetPref("blacklisted app versions")) into tLineNo

      if tLineNo is 0 then
        local tParamsA

        put true into tParamsA["show skip button"]
        appPromptUserToUpdate tParamsA
        if the result is "install" then
          appInstallUpdate
          put the result into pError
        end if
      end if
    end if
  end if

  if pError is not empty then
    _DisplayError pError
  end if
end _appCheckForUpdateInBackgroundCallback


/**
* \brief Runs the Sparkle updater. If an update is already in progress then relaunch is performed.
*
*/
private command _RunSparkleUpdater
  local tError

  try
    # If an update is canceled in mergSparklePreRelaunch then the
    # update will still be in progress. Just relaunch.
    if mergSparkleUpdateInProgress() then
      mergSparkleRelaunch
      return empty
    end if

    # start the sparkle update process
    mergSparkleCheckForUpdates
    put the result into tError
  catch tError
  end try

  return tError for error
end _RunSparkleUpdater


private function _useSparkle
  if sUseSparkle is empty then
    put "mergSparkle" is among the lines of levureExternalsLoadedInMemory() into sUseSparkle
  end if

  return sUseSparkle
end _useSparkle


/**
* \brief Sent before the app is relaunched. Use this opportunity to save any session data then call mergSparkleRelaunch to trigger the relaunch.
*/
on mergSparklePreRelaunch
  dispatch "PreUpdateApplication" to stack levureAppStackName()
  if it is "handled" and the result is not false then
    levureShutdownApplication
  end if
end mergSparklePreRelaunch


/**
* \brief Sent to the object that called mergSparkleStartup when an update is found. Flag that update is available.
*/
on mergSparkleFoundUpdate
  put true into sUpdateIsAvailable

  _dispatchCheckCallback

  pass mergSparkleFoundUpdate
end mergSparkleFoundUpdate


private function _killUpdater
  return the environment is "development" OR levureBuildProfile() is "test"
end _killUpdater


/**
* \brief This message is received when the application updater stack finishes downloading from the update server.
**
* \return Error message
*/
command _appUpdaterDownloaded pURL, pURLStatus
  switch pURLStatus
    case "timeout"
    case "socket timeout" ## ssl may return this error during timeout
      if sNumberOfDownloadTries < 5 then
        add 1 to sNumberOfDownloadTries
        wait 10 milliseconds with messages ## let libURL breathe (might not be required for non-blocking load call but just in case)

        load URL pURL with message "_appUpdaterDownloaded"
        if the result is not empty then
          _DisplayError libURLErrorData(pURL)
        end if
      else
        _DisplayError "server didn't respond in time"
      end if
      break

    case "error"
      _DisplayError libURLErrorData(pURL)
      break

    case "cached"
      _appValidateAndLaunchUpdater
      break
    default

  end switch
end _appUpdaterDownloaded


/**
* \brief Launches the updater stack and runs the updater.
*
* Called from _appUpdaterDownloaded
**
* \return Empty. Displays an answer dialog if an error occurs.
*/
private command _appValidateAndLaunchUpdater
  local tStackData

  put URL sAppUpdateStructure["updater url"] into tStackData
  unload URL sAppUpdateStructure["updater url"]

  try
    go invisible stack decompress(tStackData)
    send "RunUpdater" to stack "appUpdaterDialog" in 0 milliseconds
  catch e
    answer "An error occured while launching the updater (" & char 1 to 20 of tStackData & ")."
  end try

  return empty
end _appValidateAndLaunchUpdater


private command _DisplayError pMsg
  answer error "An error occurred while trying to download the updater:" && pMsg & "."
end _DisplayError


## Compares version strings used in the application framework.
## pString1 and pString2 are version strings.
## pOperator is either "=", "<", ">", ">=", or "<="
## e.g. _compareVersionStrings("1.0.0 b15", ">", "1.0.0 r1")
##       would return false becase a release build is newer than a beta.
private function _compareVersionStrings pString1, pOperator, pString2
  local tBoolean,tMatch,tPattern,tRelation
  local tVersion1,tVersion2
  local tMajor1,tMinor1,tRevision1,tBuild1,tStage1
  local tMajor2,tMinor2,tRevision2,tBuild2,tStage2

  ## SUPPORTS REV STYLE STRINGS WITH "-"
  put "(\d{1,3})\.(\d{1,3})\.?(\d{1,3})?[\.-]?([a-zA-Z]*)?[-]?(\d{1,3})?" into tPattern
  replace space with empty in pString1
  replace space with empty in pString2

  put matchText(pString1, tPattern, tMajor1, tMinor1, tRevision1, tStage1, tBuild1) into tMatch
  put matchText(pString2, tPattern, tMajor2, tMinor2, tRevision2, tStage2, tBuild2) into tMatch
  switch char 1 of tStage1
    case "a"
      put 1 into tStage1
      break
    case "b"
      put 2 into tStage1
      break
    case "d"
      put 0 into tStage1
      break
    case "r"
    case "f"
    default
      put 3 into tStage1
      break
  end switch

  switch char 1 of tStage2
    case "a"
      put 1 into tStage2
      break
    case "b"
      put 2 into tStage2
      break
    case "d"
      put 0 into tStage2
      break
    case "r"
    case "f"
    default
      put 3 into tStage2
      break
  end switch

  put format("%03u%03u%03u.%u%03u", tMajor1, tMinor1, tRevision1, tStage1, tBuild1) into tVersion1
  put format("%03u%03u%03u.%u%03u", tMajor2, tMinor2, tRevision2, tStage2, tBuild2) into tVersion2

  if tVersion1 > tVersion2 then
    put 1 into tRelation
  else if tVersion1 < tVersion2 then
    put -1 into tRelation
  else
    put 0 into tRelation
  end if

  put false into tBoolean

  switch pOperator
    case "="
      if tRelation = 0 then put true into tBoolean
      break
    case "<"
      if tRelation = -1 then put true into tBoolean
      break
    case ">"
      if tRelation = 1 then put true into tBoolean
      break
    case ">="
      if tRelation >= 0 then put true into tBoolean
      break
    case "<="
      if tRelation <= 0 then put true into tBoolean
      break
  end SWITCH

  return tBoolean
end _compareVersionStrings
