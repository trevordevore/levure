script "Show UnitTest Results Card Behavior"
on preOpenCard
  uiShowLog
end preOpenCard


on resizeStack pWidth, pHeight
  put 10 into tLeftMargin
  put 10 into tTopMargin
  put 10 into tRightMargin
  put 10 into tBottomMargin

  _setRect the long id of field "Info", tLeftMargin, tTopMargin, pWidth-tRightMargin, tTopMargin + 65
  _setRect the long id of field "Details", tLeftMargin, pHeight - tBottomMargin - 165, pWidth-tRightMargin, pHeight-tTopMargin
  _setRect the long id of group "Report", tLeftMargin, the bottom of field "Info" + 5, pWidth-tRightMargin, the top of field "Details" - 5
end resizeStack

command uiClearLogResults
  set the htmltext of field "Info" to _getHeader(0,0,0)
  set the dgData of group "Report" to empty
  set the text of field "Details" to empty
end uiClearLogResults


private function _getHeader pTestsRun, pVerificationsAttempted, pErrorCount
  local tLog

  put format("<p><b>Tests Run:</b> %u</p>\n", pTestsRun) after tLog
  put format("<p><b>Verification Attempts:</b> %u</p>\n", pVerificationsAttempted) after tLog
  put format("<p><b>Verification Errors:</b> %u</p>\n", pErrorCount) after tLog

  return tLog
end _getHeader


command uiShowLog
  local tLog, tLogA, tDataA

  put unittest_getLog() into tLogA

  put _getHeader(tLogA["tests run"], tLogA["verifications attempted"], the number of elements of tLogA["errors"]) into tLog

  set the htmltext of field "Info" of me to tLog
  set the text of field "Details" of me to empty

  repeat with i = 1 to item 2 of line 1 of the extents of tLogA["errors"]
    ## Visible
    put tLogA["errors"][i]["test name"] into tDataA[i]["test"]
    put tLogA["errors"][i]["error message"] into tDataA[i]["error"]
    put format("line %u: %s", tLogA["errors"][i]["line number"], tLogA["errors"][i]["failure message"]) into tDataA[i]["details"]

    ## Invisible
    put tLogA["errors"][i]["object"] into tDataA[i]["object"]
    put tLogA["errors"][i]["handler"] into tDataA[i]["handler"]
    put tLogA["errors"][i]["line number"] into tDataA[i]["line number"]
    put tLogA["errors"][i]["error message"] into tDataA[i]["error message"]
    put tLogA["errors"][i]["string 1 id"] into tDataA[i]["string 1 id"]
    put tLogA["errors"][i]["string 2 id"] into tDataA[i]["string 2 id"]
    put tLogA["errors"][i]["string 1 value"] into tDataA[i]["string 1 value"]
    put tLogA["errors"][i]["string 2 value"] into tDataA[i]["string 2 value"]
  end repeat

  go stack (the short name of me)
  set the dgData of group "Report" to tDataA
end uiShowLog


command uiShowTestDetails
  lock screen

  put the dgDataOfIndex[the dgHilitedIndex of group "Report"] of group "Report" into theDataA

  if theDataA["string 1 value"] is an array then
    put printKeys(theDataA["string 1 value"]) into theDataA["string 1 value"]
  end if
  if theDataA["string 2 value"] is an array then
    put printKeys(theDataA["string 2 value"]) into theDataA["string 2 value"]
  end if

  put "<p><b>Test:</b>" && theDataA["test"] & "</p>" & \
        "<p><b>Error:</b>" && theDataA["error"] & "</p>" & \
        "<p><b>Details:</b>" && theDataA["details"] & "</p>" & \
        "<p><b>Object:</b>" && theDataA["object"] & "</p>" & \
        "<p><b>Handler:</b>" && theDataA["handler"] & "</p>" & \
        "<p><b>Line Number:</b>" && theDataA["line number"] & "</p>" & \
        "<p><b>Extended Error:</b>" && theDataA["error message"] & "</p>" into theText
  if theDataA["string 1 id"] is not empty then
    set the text of field "details" to theDataA["string 1 value"]
    put the htmltext of field "details" into theDataA["string 1 value"]
    put "<p><b>" & theDataA["string 1 id"] & ":</b>" && theDataA["string 1 value"] & "</p>" after theText
  end if
  if theDataA["string 2 id"] is not empty then
    set the text of field "details" to theDataA["string 2 value"]
    put the htmltext of field "details" into theDataA["string 2 value"]
    put "<p><b>" & theDataA["string 2 id"] & ":</b>" && theDataA["string 2 value"] after theText
  end if

  set the htmltext of field "Details" to theText
  unlock screen
end uiShowTestDetails


function printKeys pArray, pDimension, pFullData
  if pDimension is empty then put 0 into pDimension

  put the keys of pArray into theKeys
  sort theKeys numeric

  repeat for each line theKey in theKeys
    if pArray[theKey] is an array then
      put printCharXTimes(space, pDimension * 5) & theKey & cr after theText
      put pArray[theKey] into theTempArray
      put printKeys(theTempArray, pDimension + 1, pFullData) after theText
    else
      if pFullData then
        put printCharXTimes(space, pDimension * 5) &  theKey & ":" && pArray[theKey] & cr after theText
      else
        put printCharXTimes(space, pDimension * 5) &  theKey & ":" && line 1 of pArray[theKey] & cr after theText
      end if
    end if
  end repeat

  return theText
end printKeys

function printCharXTimes pChar, pTimes
  local theStr

  repeat with i = 1 to pTimes
    put pChar after theStr
  end repeat
  return theStr
end printCharXTimes


private command _setRect pObject
  put the rect of pObject into tRect
  repeat with i = 2 to 5
    if param(i) is a number then
      put param(i) into item (i-1) of tRect
    end if
  end repeat
  set the rect of pObject to tRect
  return empty
end _setRect
