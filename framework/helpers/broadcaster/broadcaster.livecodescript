script "appBroadcaster"
local sBroadcastListenersA


on libraryStack
  # pass so other libraries can check to see if this is being put in use.
  pass libraryStack
end libraryStack


on releaseStack
  pass releaseStack
end releaseStack

/** 
* \brief Returns an array of all the objects that are listening for broadcasts for a particular id.
*
* \param pId
*
* When an object unpublishes a broadcast the custom properties that were stored when the broadcast \
      * was published are removed.
*
* \return A nested array. Dimension 1 is numerically indexed starting with 1. Dimension 2 has "type" and "controls" keys
*/
function appBroadcastListeners pId
  local tA, tKeys, tKey, i   
  
  put the keys of sBroadcastListenersA[pId]["listeners"] into tKeys
  sort lines of tKeys
  repeat for each line tKey in tKeys
    add 1 to i
    put tKey into tA[i]["type"]
    put sBroadcastListenersA[pId]["listeners"][tKey]["controls"] into tA[i]["controls"]
  end repeat
  
  return tA
end appBroadcastListeners


/** 
* \brief Registers an object to listen for broadcasts that another object can send.
*
* \param pId
* \param pBroadcastTypes A comma delimited list of types of broadcasts the listener wants to hear about.
* \param pBroadcastTarget A reference to the object that will listen for broadcasts from pObject.
* \param pMessage The message that will be sent to pBroadcastTarget. If left empty then the default message for the broadcast type will be sent. 
*
* \return Error message
*/
command appListenForBroadcast pId, pBroadcastTypes, pBroadcastTarget, pMessage
  local tError, tType
  local tLineNo, theProperty, tRegisteredControls
  
  if pMessage is empty then throw param(0) && "expects a message"
  
  # Create a name that won't break easily
  put _customControlReference(pBroadcastTarget) into pBroadcastTarget
  
  repeat for each item tType in pBroadcastTypes
    put sBroadcastListenersA[pId]["listeners"][tType]["controls"] into tRegisteredControls
    
    put lineOffset(pBroadcastTarget & tab, tRegisteredControls) into tLineNo
    if tLineNo is 0 then
      put the number of lines of tRegisteredControls + 1 into tLineNo
    end if
    put pBroadcastTarget & tab & pMessage into line tLineNo of tRegisteredControls
    
    put tRegisteredControls into sBroadcastListenersA[pId]["listeners"][tType]["controls"]
  end repeat
  
  return tError
end appListenForBroadcast


/** 
* \brief Unregisters an object that is listening for broadcasts from another object.
*
* \param pId
* \param pBroadcastTypes A comma delimited list of types of broadcasts the listener no longer wants to hear about.
* \param pBroadcastTarget A reference to the object that is listening for broadcasts from pObject.
*
* \return Error message
*/
command appStopListeningForBroadcast pId, pBroadcastTypes, pBroadcastTarget
  _deleteBroadcastListener pId, pBroadcastTypes, pBroadcastTarget
  return the result
end appStopListeningForBroadcast


/** 
* \brief Broadcasts a message from an object to any objects that are listening.
*
* \param pId
* \param pBroadcastTypes A comma delimited list of the types of broadcasts to broadcast. Every object \
      * listening for broadcasts of the specified types will be sent a message.
* \param pParamsPackageA An array that will be sent along with the broadcast. You can include any data relevant to the broadcast in this array.
*
* \return empty
*
*/
command appBroadcast pId, pBroadcastTypes, pParamsPackageA
  local tRegisteredControls, tRegisteredControl
  local tControl, tMessage
  
  set the itemDelimiter to tab
  replace comma with tab in pBroadcastTypes
  
  repeat for each item tType in pBroadcastTypes
    put sBroadcastListenersA[pId]["listeners"][tType]["controls"] into tRegisteredControls
    
    lock screen
    repeat for each line tRegisteredControl in tRegisteredControls         
      put item 1 of tRegisteredControl into tControl
      put item 2 of tRegisteredControl into tMessage
      
      if there is a tControl then
        dispatch tMessage to tControl with pParamsPackageA
      end if
    end repeat
    unlock screen
  end repeat
  
  return empty
end appBroadcast


command appBroadcastInTime pId, pBroadcastTypes, pParamsPackageA, pMillisecs
  if pMillisecs is not an integer then put 0 into pMillisecs
  send "appBroadcast pId, pBroadcastTypes, pParamsPackageA" to me in pMillisecs milliseconds
  return empty
end appBroadcastInTime


private command _deleteBroadcastListener pId, pBroadcastTypes, pBroadcastTarget
  local tLineNo, tRegisteredControls, tTargetExists
  local tType, tError
  
  put there is a pBroadcastTarget into tTargetExists
  
  # Delete all listeners if no specific types is passed in
  if pBroadcastTypes is empty then
    put the keys of sBroadcastListenersA[pId]["listeners"] into pBroadcastTypes
    replace cr with comma in pBroadcastTypes
  end if
  
  if tTargetExists then
    put _customControlReference(pBroadcastTarget) into pBroadcastTarget
  end if
  
  repeat for each item tType in pBroadcastTypes
    put sBroadcastListenersA[pId]["listeners"][tType]["controls"] into tRegisteredControls
    
    put lineOffset(pBroadcastTarget & tab, tRegisteredControls) into tLineNo
    if tLineNo > 0 then
      delete line tLineNo of tRegisteredControls
      
      put tRegisteredControls into sBroadcastListenersA[pId]["listeners"][tType]["controls"]
    end if
  end repeat
  
  return tError
end _deleteBroadcastListener


private function _customControlReference pControl
  local tFirstCharToDelete
  local tLastCharToDelete
  local tStackOffset=0,tSecondStackOffset
  local tStack
  
  put the long ID of pControl into pControl
  
  ## Get id without hierarchy    
  ## Strip any nested refs
  if pControl contains "of group id" then
    put length(word 1 to 4 of pControl) + 1 into tFirstCharToDelete
    put offset(" card id", pControl) - 1 into tLastCharToDelete
    delete char tFirstCharToDelete to tLastCharToDelete of pControl
  end if
  
  if word 1 of pControl is not "stack" then
    put offset(" of stack ", pControl) into tStackOffset
  end if
  put offset(" of stack ", pControl, tStackOffset) into tSecondStackOffset
  if tSecondStackOffset > 0 then
    ## Strip mainstack ref if substack.
    ## We want user to move stacks around.
    add tSecondStackOffset to tStackOffset
    delete char tStackOffset to -1 of pControl
  else if tStackOffset > 0 then
    ## Shorten stack name
    put char (tStackOffset + 4) to -1 of pControl into tStack
    put the short name of tStack into tStack	# get stack short name
    put quote & tStack & quote into char (tStackOffset + 10) to -1 of pControl
  else
    ## stack "something "reference
    put the short name of pControl into tStack	# get stack short name
    put quote & tStack & quote into char 7 to -1 of pControl
  end if
  
  return pControl
end _customControlReference
