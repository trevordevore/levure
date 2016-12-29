script "SparkleUpdater"
local sUpdateIsAvailable = "false"
local sAppUpdateStructure
local sUseSparkle


private function _useSparkle
  if sUseSparkle is empty then
    put "mergSparkle" is among the lines of levureExternalsLoadedInMemory() into sUseSparkle
  end if

  return sUseSparkle
end _useSparkle


/**
* \brief Sent before the app is relaunched. Use this opportunity to save any session data then call mergSparkleRelaunch to trigger the relaunch.
*
* Note: Not currently working as Sparkle external locks up when sending messages.
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
  pass mergSparkleFoundUpdate
end mergSparkleFoundUpdate


on _appFoundUpdate
  put true into sUpdateIsAvailable

end _appFoundUpdate


function appIsUpdateAvailable
  if the environment is "development" then
    return false
  else
    if _useSparkle() then
      return sUpdateIsAvailable is true OR mergSparkleUpdateInProgress()
    else
      return sUpdateIsAvailable
    end if
  end if
end appIsUpdateAvailable


command appInitializeUpdater
  send "_appInitializeUpdaterInBackground" to me in 10 milliseconds
end appInitializeUpdater


command _appInitializeUpdaterInBackground
  local tError

  if useSparkle() then
    mergSparkleStartup
    put the result into tError
  else
    appCheckForUpdate
    put the result into tError

    if theError is empty then
      if glxapp_getProp("update available") then
        ## Is user skipping this version?
        set the wholematches to true
        put glxapp_getProp("application update version") into theVersion
        put lineoffset(theVersion, appGetPref("updates to ignore")) into theLineNo

        if theLineNo is 0 then
          ## Notify
          put true into theA["show skip button"]
          glxapp_promptUserToUpdate theA
          if the result is "install" then
            glxapp_installUpdate
            put the result into theError
          end if
        end if
      end if
    end if
  end if

  return tError for error
end _appInitializeUpdaterInBackground


/**
* \brief Checks if an update for you application is available on the update server.
*
* This handler gets the necessary information from the update server to see if a update \
      * for your application is available. After calling this command you can check the  \
      * 'update available' property (glxapp_getProp("update available") ) to see if there is an \
      * available update.
*/
command appCheckForUpdate
  local requiresUpdating,theCurrentVersion,tError,tFileContent
  local theServerVersion,theUpdaterURL,theURL

  if the environment is "development" then return empty

  if _useSparkle() then
    _RunSparkleUpdater
    put the result into tError
  else
    ## RESET STRUCTURE
    put empty into sAppUpdateStructure

    put levureAppGet("auto update url") into tURL

    load url tURL with message "_appUpdaterInfoDownloaded"
    put the result into tError
  end if

  ## No need to have error in the error message which I've seen with the socket timeout error message
  if word 1 of tError is "error" then delete word 1 of tError
  return tError
end appCheckForUpdate


command _appUpdaterInfoDownloaded pUrl, pUrlStatus
  local tFileContent

  if pUrlStatus is "cached" then
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
    end if
  end if
end _appUpdaterInfoDownloaded


command _appUpdaterChangeLogDownloaded pUrl, pUrlStatus
  if pUrlStatus is "cached" then
    put url pUrl into sAppUpdateStructure["change log"]
    unload url pURL

    if there is not a stack "glxappUpdateDialog" and sAppUpdateStructure["updater dialog"] is not empty then
      load url sAppUpdateStructure["updater dialog"] with message "_appUpdaterDialogDownloaded"
      put the result into tError
    end if
  end if
end _appUpdaterChangeLogDownloaded


command _appUpdaterDialogDownloaded pUrl, pUrlStatus
  if pUrlStatus is "cached" then
    put url pUrl into sAppUpdateStructure["updater dialog"]
    unload url pURL
  end if
end _appUpdaterDialogDownloaded


/**
* \brief Checks if an update is available. If so then the user is prompted to update and the update process begins.
*
* \package Application Updater
*
* \return Error message
*/
command glxapp_updateIfAvailable
  # No special circumstances. Proceed.
  glxapp_checkForUpdate
  put the result into tError

  if tError is empty then
    if "mergSparkle" is not among the lines of _externalsLoadedInMemory() then
      if glxapp_getProp("update available") then
        glxapp_promptUserToUpdate
        if the result is "install" then
          glxapp_installUpdate
          put the result into tError
        end if
      else
        put "no update available" into tError
      end if
    end if
  end if

  return tError
end glxapp_updateIfAvailable


/**
* \brief Ask the user if they would like to update their version of the application.
*
* \param pParamsA Any parameters you want to pass to the glxappUpdateDialog stack via the array stored in the dialogData.
*
* \package Application Updater
*
* \return "cancel" or "update"
*/
command glxapp_promptUserToUpdate pParamsA
  local tErrorMsg, tError

  if there is not a stack "glxappUpdateDialog" then
    put  "Unable to load update description window." into tErrorMsg

    if sAppUpdateStructure["updater dialog"] is not empty then
      try
        put decompress(sAppUpdateStructure["updater dialog"]) into sAppUpdateStructure["updater dialog"]
      catch e
        put "invalid updater dialog" into tError
      end try

      if tError is empty then
        put pParamsA into theA
        put sAppUpdateStructure["change log"] into theA["change log"]
        set the dialogData to theA

        ## This doesn't throw an error if there is no stack
        go stack sAppUpdateStructure["updater dialog"] as modal
        if the result is "no such card" then ## 'no such card'
          put "invalid stack" into tError
        end if
      end if

      if tError is not empty then
        ## Stack didn't load properly
        answer tErrorMsg
        set the dialogData to "cancel"
      end if
    else
      answer tErrorMsg
      set the dialogData to "cancel"
    end if
  else
    modal stack "glxappUpdateDialog"
  end if
  return the dialogData
end glxapp_promptUserToUpdate


local sNumberOfDownloadTries


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

  return tError
end _RunSparkleUpdater


/**
* \brief Begins the application update process by downloading the updater stack from the server.
*
* The glxapp_updaterDownloaded message is sent when the updater finishes downloading from the server.
* If Sparkle is being used then the Sparkle updater handles everything.
*
* \package Application Updater
*
* \return Error message
*/
command glxapp_installUpdate
  local tError

  if "mergSparkle" is among the lines of _externalsLoadedInMemory() then
    if the environment is not "development" then
      _RunSparkleUpdater
      put the result into tError
    end if
  else

    put true into sRuntimePropertiesA["application is cleaning up"]

    dispatch "PreUpdateApplication" to stack levureAppStackName()
    if it is not "handled" or the result is not false then
      ##  SHOULD WE CANCEL ALL URL DOWNLOADS AT THIS POINT?
      ## WE NEED TO MONITOR DOWNLOADING
      put 1 into sNumberOfDownloadTries

      load URL sAppUpdateStructure["updater url"] with message "glxapp_updaterDownloaded"
      if the result is not empty then
        put libURLErrorData(sAppUpdateStructure["updater url"]) into tError
      end if
    else if it is "handled" then
      put "cancel" into tError
    end if

    put false into sRuntimePropertiesA["application is cleaning up"]
  end if


  return tError
end glxapp_installUpdate


/**
* \brief This message is received when the application updater stack finishes downloading from the update server.
*
* Calls glxapp_validateAndLaunchUpdater if updater is successfully downloaded.
*
* \package Application Updater
*
* \return Error message
*
* \seealso glxapp_validateAndLaunchUpdater
*/
on glxapp_updaterDownloaded pURL, pURLStatus
  switch pURLStatus
    case "timeout"
    case "socket timeout" ## ssl may return this error during timeout
      if sNumberOfDownloadTries < 5 then
        add 1 to sNumberOfDownloadTries
        wait 10 milliseconds with messages ## let libURL breathe (might not be required for non-blocking load call but just in case)

        load URL pURL with message "glxapp_updaterDownloaded"
        if the result is not empty then
          answer "An error occured while downloading the updater (" & libURLErrorData(pURL) & ")."
        end if
      else
        answer "A timeout occured while downloading the updater."
      end if
      break

    case "error"
      answer "An error occured while downloading the updater (" & libURLErrorData(pURL) & ")."
      break

    case "cached"
      glxapp_validateAndLaunchUpdater
      break
    default

  end switch
end glxapp_updaterDownloaded


/**
* \brief Launches the updater stack and runs the updater.
*
* Called from glxapp_updaterDownloaded
*
* \package Application Updater
*
* \return Empty. Displays an answer dialog if an error occurs.
*
* \seealso glxapp_updaterDownloaded
*/
command glxapp_validateAndLaunchUpdater
  ## VERYIFY
  -- sAppUpdateStructure["checksum"]

  ## OPEN AND LAUNCH
  put URL sAppUpdateStructure["updater url"] into theStackData
  unload URL sAppUpdateStructure["updater url"]

  try
    go invisible stack decompress(theStackData)
    send "RunUpdater" to stack "glxappUpdater" in 0 milliseconds
  catch e
    answer "An error occured while launching the updater (" & char 1 to 20 of theStackData & ")."
  end try

  return empty
end glxapp_validateAndLaunchUpdater


## Compares version strings used in the application framework.
## pString1 and pString2 are version strings.
## pOperator is either "=", "<", ">", ">=", or "<="
## e.g. glxapputil_compareVersionStrings("1.0.0 b15", ">", "1.0.0 r1")
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
      put 3 into tStage1
      break
    default
      put 9 into tStage1
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
      put 3 into tStage2
      break
    default
      put 9 into tStage2
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
