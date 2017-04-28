script "libUnitTest"
local sLogA


on libraryStack
  if the long id of the target is not me then pass libraryStack
end libraryStack


on releaseStack
  if the long id of the target is not me then pass releaseStack
end releaseStack


command unittest_resetLog
  put empty into sLogA
end unittest_resetLog


function unittest_getLog
  return sLogA
end unittest_getLog


command verify pBoolean, pErrorMessage
    local theStatement,theValue
    local theContextA, e

    _incrementVerifications

    if not pBoolean then
        put _GetCallerContextArray() into theContextA

        unittest_logVerificationFailure "statement is false", pErrorMessage, theContextA, "boolean", pBoolean
    end if

    return empty
end verify


## This looks at control custom properties rather than properties since that is more common.
## To check if two controls have the same props us very_equalProperties
command verify_equal pValue1, pValue2, pErrorMsg
    local theArray1,theArray2,theProps1,theProps2
    local theSet,theSets1,theSets2

    put _GetCallerContextArray() into theContextA

    _incrementVerifications

    if there is pValue1 and there is a pValue2 then
        ## two controls. We compare custom property sets
        put _CustomPropertySets(pValue1) into theSets1
        put _CustomPropertySets(pValue1) into theSets2
        if theSets1 is not theSets2 then
            ## custom props don't match
            put _ControlPropertyArray(pValue1) into theProps1
            put _ControlPropertyArray(pValue2) into theProps2
            unittest_logVerificationFailure "object custom property sets are not equal", pErrorMsg, theContextA, _ControlReference(pValue1), theProps1, _ControlReference(pValue2), theProps2
        else
            repeat for each line theSet in theSets1
                put the customProperties[theSet] of pValue1 into theArray1
                put the customProperties[theSet] of pValue2 into theArray2
                if theArray1 is not theArray2 then
                    ## custom property values in set to not match
                    put _ControlPropertyArray(pValue1) into theProps1
                    put _ControlPropertyArray(pValue2) into theProps2
                    unittest_logVerificationFailure "object custom properties are not equal in" && quote & theSet & quote && "set", pErrorMsg, theContextA, \
                            _ControlReference(pValue1), theProps1, _ControlReference(pValue2), theProps2
                    exit repeat
                end if
            end repeat
        end if
    else if the keys of pValue1 is not empty and the keys of pValue2 is not empty then
        ## two arrays
        if pValue1 is not pValue2 then
            ## arrays don't match. Log both array values
            unittest_logVerificationFailure "arrays are not equal", pErrorMsg, theContextA, "array 1", pValue1, "array 2", pValue2
        end if
    else
        ## treat as strings
        if pValue1 is not pValue2 then
            ## values are not equal
            unittest_logVerificationFailure "strings are not equal", pErrorMsg, theContextA, "string 1", pValue1, "string 2", pValue2
        end if
    end if

    return empty
end verify_equal


command verify_equalProperties pControl1, pControl2, pErrorMsg
    put the properties of pControl1 into theArray1
    put the properties of pControl2 into theArray2
    if theArray1 is not theArray2 then
        put _GetCallerContextArray() into theContextA

        ## arrays don't match, log both array values
        put _ControlPropertyArray(pControl1) into theProps1
        put _ControlPropertyArray(pControl2) into theProps2
        unittest_logVerificationFailure "properties are not equal", pErrorMsg, theContextA, _ControlReference(pControl1), theProps1, _ControlReference(pControl2), theProps2
    end if
end verify_equalProperties


command unittest_incrementTestsRun
    add 1 to sLogA["tests run"]
end unittest_incrementTestsRun


command unittest_logVerificationFailure pInternalFailureMessage, pErrorMsg, pContextA, pIDString1, pValue1, pIDString2, pValue2
  put item 2 of line 1 of the extents of sLogA["errors"] + 1 into theIndex

  if pContextA is not an array then
    put _GetCallerContextArray(4) into pContextA ## guess as to context
  end if

  put _FindTestNameInExecutionContexts() into theTest

  put theTest into sLogA["errors"][theIndex]["test name"]
  put pInternalFailureMessage into sLogA["errors"][theIndex]["failure message"]
  put pContextA["object"] into sLogA["errors"][theIndex]["object"]
  put pContextA["handler"] into sLogA["errors"][theIndex]["handler"]
  put pContextA["line number"] into sLogA["errors"][theIndex]["line number"]
  put pErrorMsg into sLogA["errors"][theIndex]["error message"]
  put pIDString1 into sLogA["errors"][theIndex]["string 1 id"]
  put pIDString2 into sLogA["errors"][theIndex]["string 2 id"]

  put pValue1 into sLogA["errors"][theIndex]["string 1 value"]
  put pValue2 into sLogA["errors"][theIndex]["string 2 value"]
end unittest_logVerificationFailure


--> Private

private command _incrementVerifications
    add 1 to sLogA["verifications attempted"]
end _incrementVerifications


private function _FindTestNameInExecutionContexts
    put the executioncontexts into theContexts
    repeat with i = the number of lines of theContexts down to 1
        put line i of theContexts into theContext
        if not(item 1 to -3 of theContext contains the short name of me) then
            set the itemdelimiter to comma
            return item -2 of theContext
        end if
    end repeat
    return empty
end _FindTestNameInExecutionContexts


## pConextLineNo defaults to -3 which is handler that called the handler calling this function
private function _GetCallerContextArray pConextLineNo
    if pConextLineNo is not an integer then put -3 into pConextLineNo

    put line -3 of the executioncontexts into theContext
    repeat for each item theItem in theContext
        add 1 to theItemNo
        if theItem is an integer then
            ## we found the line number
            put theItem into theContextA["line number"]
            put item (theItemNo - 1) of theContext into theContextA["handler"]
            put item 1 to (theItemNo - 2) of theContext into theContextA["object"]
            exit repeat
        end if
    end repeat

    return theContextA
end _GetCallerContextArray


private function _ControlReference pControl
    put the long id of pControl into pControl
    put the short name of pControl into theName
    put _LongIDWithoutHierarchy(pControl) into theID
    return theName && "(" & theID & ")"
end _ControlReference


private function _RefWithShortStackName pControl
    local theStack

    if word 1 of pControl is not "stack" then
        put offset(" of stack ", pControl) into theStackOffset
        put char (theStackOffset + 4) to -1 of pControl into theStack
        put the short name of theStack into theStack	# get stack short name
        put quote & theStack & quote into char (theStackOffset + 10) to -1 of pControl	# insert short name
    else
        put "stack" && quote & the short name of pControl & quote into pControl
    end if	# get stack reference

    return pObject
end _RefWithShortStackName


-- Returns the id of an object without any group hierarchy info.  Just card and stack.
private function _LongIDWithoutHierarchy pControl
    local theFirstCharToDelete,theLastCharToDelete

    put the long id of pControl into pControl
    put _RefWithShortStackName(pControl) into pControl

    if word 1 of pControl is not among the items of "card,stack" then
        if pControl contains "of group id" then
            put length(word 1 to 4 of pControl) + 1 into theFirstCharToDelete
            put offset(" card id", pControl) - 1 into theLastCharToDelete
            delete char theFirstCharToDelete to theLastCharToDelete of pControl
        end if
    end if

    return pControl
end _LongIDWithoutHierarchy


private function _CustomPropertySets pControl
    put the custompropertysets of pControl into theSets
    filter theSets without "cRev*"
    filter theSets without "cGlx*"
    sort theSets
    return theSets
end _CustomPropertySets


private function _ControlPropertyArray pControl
    put the properties of pControl into thePropsA
    put _CustomPropertySets(pControl) into theSets
    put the number of lines of theSets into theSetCount

    put theSetCount into thePropsA["custom properties","count"]
    repeat with i = 1 to the number of lines of theSets
        put line i of theSets into theSet
        put theSet into thePropsA["custom properties", i, "name"]
        put the customProperties[theSet] of pControl into theSetA
        put arrayencode(theSetA) into thePropsA["custom properties", i, "data"]
    end repeat
end _ControlPropertyArray
