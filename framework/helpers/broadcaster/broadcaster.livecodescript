script "Broadcaster Library"
local sBroadcastListenersA


on libraryStack
  if the target is not me then pass libraryStack
end libraryStack


on releaseStack
  if the target is not me then pass releaseStack
end releaseStack


/**
Summary: Returns an array of the objects that are listening for broadcasts for a particular category.

pCategory: Return listeners listening for broadcasts in this category.
pBroadcast: Optional. If a non-empty value is passed in then only listeners for this specific broadcast will be returned.

Returns: A nested array. Dimension 1 is numerically indexed starting with 1. Dimension 2 has `broadcast` and `controls` keys.

Description:
`pCategory` is the category you are interested in. Here is some sample code which shows how to see which controls are
listening for broadcasts from the Preferences helper:

```
put broadcasterListeners("prefs") into tListenersA
repeat with i = 1 to the number of elements of tListenersA
  put "Broadcast:" && tListenersA[i]["broadcast"] & cr after tText
  put "Controls that are listening:" & cr after tText
  repeat for each line tControl in tListenersA[i]["controls"]
    put "  " & tControl & cr after tText
  end repeat
  put cr after tText
end repeat

put tText
```
*/
function broadcasterListeners pCategory, pBroadcast
  local tA, tKeys, tKey, i

  if pBroadcast is empty then
    put the keys of sBroadcastListenersA[pCategory]["listeners"] into pBroadcast
    sort lines of tKeys
  end if

  repeat for each line tKey in pBroadcast
    add 1 to i
    put tKey into tA[i]["broadcast"]
    put sBroadcastListenersA[pCategory]["listeners"][tKey]["controls"] into tA[i]["controls"]
  end repeat

  return tA
end broadcasterListeners


/**
Summary: Registers a control to receive a notification for broadcasts associated with a specific category.

Returns: Error message

pCategory: The category that pBroadcasts belong to.
pBroadcasts: A comma delimited list of broadcasts from pCategory that pBroadcastTarget is interested in.
pBroadcastTarget: A reference to the object that will be sent pMessage.
pMessage: The message that will be sent to pBroadcastTarget. If left empty then the default message for the broadcast type will be sent.

Description:
Broadcasts are separated into different catgories. For example, the Preferences helper uses the `prefs` category when
broadcasting messages. Broadcasts generated from your app might use the `app` category. Categories are simply a means of organizing broadcasts
based on who is generating the broadcast.

Example:
# When used with the `Preferences` helper an object can be notified when a preference is changed.
broadcasterListenForBroadcast "prefs", "default text size", the long id of me, "UpdateDefaultTextSize"

# Be notified when media files have finished downloading.
broadcasterListenForBroadcast "app", "media files downloaded", the long id of me, "MediaFilesDownloadsComplete"
*/
command broadcasterListenForBroadcasts pCategory, pBroadcasts, pBroadcastTarget, pMessage
  local tError, tType
  local tLineNo, theProperty, tRegisteredControls

  if pMessage is empty then throw param(0) && "expects a message"

  # Create a name that won't break easily
  put _customControlReference(pBroadcastTarget) into pBroadcastTarget

  repeat for each item tType in pBroadcasts
    put sBroadcastListenersA[pCategory]["listeners"][tType]["controls"] into tRegisteredControls

    put lineOffset(pBroadcastTarget & tab, tRegisteredControls) into tLineNo
    if tLineNo is 0 then
      put the number of lines of tRegisteredControls + 1 into tLineNo
    end if
    put pBroadcastTarget & tab & pMessage into line tLineNo of tRegisteredControls

    put tRegisteredControls into sBroadcastListenersA[pCategory]["listeners"][tType]["controls"]
  end repeat

  return tError
end broadcasterListenForBroadcasts


/**
Summary: Unregisters an object that is listening for broadcasts.

pCategory: The category that pBroadcasts belong to.
pBroadcasts: A comma delimited list of broadcasts the listener is no longer interested in.
pBroadcastTarget: A reference to the object that is listening for broadcasts.

Returns: Error message
*/
command broadcasterStopListeningForBroadcasts pCategory, pBroadcasts, pBroadcastTarget
  _deleteBroadcastListener pCategory, pBroadcasts, pBroadcastTarget
  return the result
end broadcasterStopListeningForBroadcasts


/**
Summary: Broadcasts a message to any objects that are listening.

pCategory: The category that pBroadcasts belong to.
pBroadcasts: A comma delimited list of the broadcasts to trigger. Every object listening for these broadcasts will be sent a message.
pParamsPackageA: An array that will be sent along with the broadcast. You can include any data relevant to the broadcast in this array.

Returns: empty

Description:
Typically `pBroadcasts` will only contain one broadcast to send, especially if you are using `pParamsPackageA`.

Example:
# Notify listeners that a document was updated by someone.
put 1 into tParamsA["document id"]
put "Jane Doe" into tParamsA["updated by"]
broadcasterBroadcast "app", "document updated", tParamsA
*/
command broadcasterBroadcast pCategory, pBroadcasts, pParamsPackageA
  local tRegisteredControls, tRegisteredControl
  local tControl, tMessage

  set the itemDelimiter to tab
  replace comma with tab in pBroadcasts

  repeat for each item tType in pBroadcasts
    put sBroadcastListenersA[pCategory]["listeners"][tType]["controls"] into tRegisteredControls

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
end broadcasterBroadcast


/**
Summary: Sends a broadcast message using `send in time`.

pCategory: The category that pBroadcasts belong to.
pBroadcasts: A comma delimited list of the broadcasts to trigger. Every object listening for these broadcasts will be sent a message.
pParamsPackageA: An array that will be sent along with the broadcast. You can include any data relevant to the broadcast in this array.
pMillisecs: The amount of time in milliseconds to wait before broadcasting. Default value is 0.

Description:
Use this form to broadcast a message outside of the current event loop.

Example:
# Notify listeners after the window has closed
on closeStack
  ...

  put 1 into tParamsA["document id"]
  broadcasterBroadcastInTime "app", "document window closed", tParamsA, 10

  ...
end closeStack

*/
command broadcasterBroadcastInTime pCategory, pBroadcasts, pParamsPackageA, pMillisecs
  if pMillisecs is not an integer then put 0 into pMillisecs
  send "broadcasterBroadcast pCategory, pBroadcasts, pParamsPackageA" to me in pMillisecs milliseconds
  return empty
end broadcasterBroadcastInTime


private command _deleteBroadcastListener pCategory, pBroadcasts, pBroadcastTarget
  local tLineNo, tRegisteredControls, tTargetExists
  local tType, tError

  put there is a pBroadcastTarget into tTargetExists

  # Delete all listeners if no specific types is passed in
  if pBroadcasts is empty then
    put the keys of sBroadcastListenersA[pCategory]["listeners"] into pBroadcasts
    replace cr with comma in pBroadcasts
  end if

  if tTargetExists then
    put _customControlReference(pBroadcastTarget) into pBroadcastTarget
  end if

  repeat for each item tType in pBroadcasts
    put sBroadcastListenersA[pCategory]["listeners"][tType]["controls"] into tRegisteredControls

    put lineOffset(pBroadcastTarget & tab, tRegisteredControls) into tLineNo
    if tLineNo > 0 then
      delete line tLineNo of tRegisteredControls

      put tRegisteredControls into sBroadcastListenersA[pCategory]["listeners"][tType]["controls"]
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
    put the short name of tStack into tStack  # get stack short name
    put quote & tStack & quote into char (tStackOffset + 10) to -1 of pControl
  else
    ## stack "something "reference
    put the short name of pControl into tStack  # get stack short name
    put quote & tStack & quote into char 7 to -1 of pControl
  end if

  return pControl
end _customControlReference
