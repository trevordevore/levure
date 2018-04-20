script "Undo Manager"
local sUndoStructure
local sUndoLogA
local sMaxUndo = 30

on libraryStack
  if the target is not me then pass libraryStack

  # Register default types
  undoRegisterType "create", "delete"
  undoRegisterType "delete", "create"
  undoRegisterType "update", "update"

  undoReset "default"
end libraryStack


on releaseStack
  if the target is not me then pass releaseStack

  remove script of stack "Undo Manager Field Edits Undo Frontscript" from front
end releaseStack


/**
Summary: Registers the "edit field" undo stack for use while a user is editing text in a field.

Description:
Thie handler registers the "edit field" undo stack and inserts a frontscript into the message path.
The frontscript monitors edits made in a field while it has focus. Undo/redo affects typing done before focus
is removed from the field.


Returns: empty
*/
command undoRegisterEditFieldType
  undoReset "edit field"

  insert script of stack "Undo Manager Field Edits Undo Frontscript" into front

  undoSetTargetForStackCallbacks "edit field", the long id of stack "Undo Manager Field Edits Undo Frontscript"
  return empty
end undoRegisterEditFieldType


/**
Summary: Sets the maximum number of undo actions that will be saved in an undo stack.

pMax: The maximum number of undo entries to store.

Returns: empty
*/
command undoSetMaxUndos pMax
  if pMax is not an integer then put 1 into pMax
  put max(1, pMax) into sMaxUndo
  return empty
end undoSetMaxUndos


/**
Summary: Returns the maximum number of undo actions that are stored in an undo stack.

Returns: Number of undo entries to store
*/
function undoGetMaxUndos
  return sMaxUndo
end undoGetMaxUndos


/**
Summary: Registers an undo type with the Undo Manager.

Parameters:
pType: The type to register.
pInverseType: When calling undoUndo the type of the undo action will be set to
this value. For example, if pType is "create" then this might be
"delete". Leave empty  if there is no inverse type. If this value is
different then pType then make sure you register this type as well.

Returns: empty

Description:
When adding an undo entry to an undo stack, you specify a type.
The type helps the application know how to undo or redo the action.
Each type has callbacks that will be triggered when that type of undo entry
needs to be undone or redone.
*/
command undoRegisterType pType, pInverseType
  local tLineNo

  set the wholematches to true

  put pInverseType into sUndoStructure[pType]["inverse type"]

  return empty
end undoRegisterType


private command _cleanupIndex pUndoStack, pUndoOrRedo, pIndex
  local i, tType, tArray, tTarget

  put _getTargetForMessages(pUndoStack) into tTarget
  dispatch "undoCleanupMementos" to tTarget with pUndoStack, sUndoLogA[pUndoStack][pUndoOrRedo][pIndex]["mementos"]

  delete local sUndoLogA[pUndoStack][pUndoOrRedo][ pIndex ]

  return empty
end _cleanupIndex


/**
Summary: Returns the target object for messages.

pUndoStack: The target undo stack.

Returns: object reference or empty.

Description:
If an target callback has been defined for the type then that callback is returned.
If not then the target for the undo stack is returned.
*/
private function _getTargetForMessages pUndoStack
  if sUndoLogA[pUndoStack]["target"] is not empty then
    return sUndoLogA[pUndoStack]["target"]
  else
    return the long id of the target
  end if
end _getTargetForMessages


/**
Summary: Resets an undo stack.

pUndoStack: The undo stack to target.

Returns: empty

Description:
Cleanup callbacks will be sent for any undo actions in the stack.
*/
command undoReset pUndoStack
  local tIndexes, tIndex

  put _validateUndoStackString(pUndoStack) into pUndoStack

  _cleanupStackIndexes pUndoStack

  ## Clean out undo stack key
  put empty into sUndoLogA[pUndoStack]["undo"]
  put empty into sUndoLogA[pUndoStack]["redo"]

  return empty
end undoReset


/**
Summary: Prints the undo log array. Use for troublehsooting.

Returns: text representation of internal array
*/
function undoPrintLog
  return _printArray(sUndoLogA)
end undoPrintLog


/**
Summary: Returns true if there is an undo action.

pUndoStack: The name of the undo stack to target. Leave empty for "default"

Returns: Boolean
*/
function undoCanUndo pUndoStack
  put _validateUndoStackString(pUndoStack) into pUndoStack
  return the keys of sUndoLogA[pUndoStack]["undo"] is not empty
end undoCanUndo


/**
Summary: Returns true if there is a redo action.

pUndoStack: The name of the undo stack to target. Leave empty for "default"

Returns: Boolean
*/
function undoCanRedo pUndoStack
  put _validateUndoStackString(pUndoStack) into pUndoStack
  return the keys of sUndoLogA[pUndoStack]["redo"] is not empty
end undoCanRedo


/**
Summary: Sets the target for undo type callbacks for an undo stack.

pUndoStack: The undo stack to target.
pTarget: The target object for messages.

Returns: empty

Description:
If a callback target control is set for an undo stack then any undo type
which doesn't specify a contorl will send to the undo stack control.
*/
command undoSetTargetForStackCallbacks pUndoStack, pTarget
  put pTarget into sUndoLogA[pUndoStack]["target"]
  return empty
end undoSetTargetForStackCallbacks


/**
Summary: Returns the target that messages are sent to for an undo stack.

Parameters:
pUndoStack: The undo stack of interest.

Returns: Object reference
*/
function undoGetTargetForStackCallbacks pUndoStack
  return _getTargetForMessages(pUndoStack)
end undoGetTargetForStackCallbacks


/**
Summary: Adds an undo action to an undo stack.

pUndoStack: The name of the undo stack to associate the action with. If empty then the undo stack is "default".
pType: The undo action type. You must have registered this type with undoRegisterType.
pActionName: The name of the undo action. This is what you will display in the Edit > Undo/Redo menus.
pMementosA: A numerically indexed array of memento arrays for this action.

Returns: The array representing the undo action that was created.

Description:
Use this handler to add undo actions to an undo stack in your application.

```
local tMementoA, tMementosA

put tId into tMementoA["id"]
put tIndex into tMementoA["index"]

put tMementoA into tMementosA[1]

undoAddAction "document 1", "Create thing", tMementosA
```
*/
command undoAddAction pUndoStack, pActionName, pMementosA
  local i, tUndoIndex, tIndex, tTarget, tMementoA

  if pUndoStack is empty then put "default" into pUndoStack
  put _getNextUndoIndex(pUndoStack) into tUndoIndex

  repeat with i = 1 to the number of elements of pMementosA
    if sUndoStructure[ pMementosA[i]["type"] ] is not an array then return "undo not set up for this type"
  end repeat

  put pActionName into sUndoLogA[pUndoStack]["undo"][tUndoIndex]["action name"]
  put pMementosA into sUndoLogA[pUndoStack]["undo"][tUndoIndex]["mementos"]

  put _getTargetForMessages(pUndoStack) into tTarget
  dispatch "undoStoreMementos" to tTarget with pUndoStack, sUndoLogA[pUndoStack]["undo"][tUndoIndex]["mementos"]

  ## Redos are wiped out. "cleanup handler" is called so program
  ## can clean up after any internal data specific to the undo array.
  local tIndexes

  put the keys of sUndoLogA[pUndoStack]["redo"] into tIndexes
  sort lines of tIndexes numeric descending
  repeat for each line tIndex in tIndexes
    _cleanupIndex pUndoStack, "redo", tIndex
  end repeat

  ## Limit undos
  local tUndoCount, tDeleteCount

  put the keys of sUndoLogA[pUndoStack]["undo"] into tIndexes
  sort lines of tIndexes numeric ascending
  put the number of lines of tIndexes into tUndoCount
  put tUndoCount - sMaxUndo into tDeleteCount
  repeat with i = tDeleteCount down to 1
    _cleanupIndex pUndoStack, "undo", line i of tIndexes
  end repeat

  return sUndoLogA[pUndoStack]["undo"][tUndoIndex]
end undoAddAction


/**
Summary: Returns the undo structure for the next undo in the stack.

pUndoStack: The undo stack to target.

Description:
Use this for comparisons to determine if a new undo action should be added to the stack
(e.g. actions that repeat but you only want 1 undo for).

Returns: Array or empty
*/
function undoGetNextUndoInStack pUndoStack
  local tIndex

  put _validateUndoStackString(pUndoStack) into pUndoStack

  if undoCanUndo(pUndoStack) then
    put item 2 of the extents of sUndoLogA[pUndoStack]["undo"] into tIndex
    return sUndoLogA[pUndoStack]["undo"][tIndex]
  else
    return empty
  end if
end undoGetNextUndoInStack


/**
Summary: Performs an undo operation for the last undo added to the stack.

pUndoStack: The undo stack to target.

Returns: empty or "can't undo"
*/
command undoUndo pUndoStack
  local tIndex

  put _validateUndoStackString(pUndoStack) into pUndoStack

  if undoCanUndo(pUndoStack) then
    _reverseAction pUndoStack, "undo", item 2 of the extents of sUndoLogA[pUndoStack]["undo"]
    return empty
  else
    return "can't undo"
  end if
end undoUndo


/**
Summary: Performs an redo operation for the last redo added to the stack.

pUndoStack: The undo stack to target.

Returns: empty or "can't redo"
*/
command undoRedo pUndoStack
  put _validateUndoStackString(pUndoStack) into pUndoStack

  if undoCanRedo(pUndoStack) then
    _reverseAction pUndoStack, "redo", item 2 of the extents of sUndoLogA[pUndoStack]["redo"]
    return empty
  else
    return "can't redo"
  end if
end undoRedo


/**
Summary: Returns the next undo action name in a stack.

pUndoStack: The undo stack to target.

Description:
The action name that was assigned when calling undoAddAction.

Returns: String
*/
function undoUndoActionName pUndoStack
  local tIndex

  put _validateUndoStackString(pUndoStack) into pUndoStack

  put item 2 of the extents of sUndoLogA[pUndoStack]["undo"] into tIndex
  if tIndex > 0 then
    return sUndoLogA[pUndoStack]["undo"][tIndex]["action name"]
  else
    return empty
  end if
end undoUndoActionName


/**
Summary: Returns the next redo action name in a stack.

pUndoStack: The undo stack to target.

Description:
The action name that was assigned when calling undoAddAction.

Returns: String
*/
function undoRedoActionName pUndoStack
  local tIndex

  put _validateUndoStackString(pUndoStack) into pUndoStack

  put item 2 of the extents of sUndoLogA[pUndoStack]["redo"] into tIndex
  if tIndex > 0 then
    return sUndoLogA[pUndoStack]["redo"][tIndex]["action name"]
  else
    return empty
  end if
end undoRedoActionName


/**
Summary: Removes the last added undo action from the undo stack.

pUndoStack: The undo stack to target.

Returns: empty
*/
command undoRemoveLatest pUndoStack
  local tIndex

  put _validateUndoStackString(pUndoStack) into pUndoStack

  put item 2 of the extents of sUndoLogA[pUndoStack]["undo"] into tIndex
  _cleanupIndex pUndoStack, "undo", tIndex
  return empty
end undoRemoveLatest


/**
Summary: Removes all undo entries for a particular owner.

pUndoStack: The undo stack to target.

Returns: empty
*/
command undoCleanupStack pUndoStack
  _cleanupStackIndexes pUndoStack

  delete local sUndoLogA[pUndoStack]

  return empty
end undoCleanupStack


private command _cleanupStackIndexes pUndoStack
  local tKey, tIndexes, tIndex

  ## Send cleanup handlers to for each undo and redo
  repeat for each item tKey in "undo,redo"
    put the keys of sUndoLogA[pUndoStack][tKey] into tIndexes
    sort lines of tIndexes numeric descending
    repeat for each item tIndex in tIndexes
      _cleanupIndex pUndoStack, tKey, tIndex
    end repeat
  end repeat

  return empty
end _cleanupStackIndexes


private function _validateUndoStackString pUndoStack
  if _FieldEditingIsActive() and _FocusedObjectIsFieldEdit() and the uEnableFieldUndo of the selectedField is not "false" then
    put "edit field" into pUndoStack
  else if pUndoStack is empty then
    put "default" into pUndoStack
  end if
  return pUndoStack
end _validateUndoStackString


private function _FieldEditingIsActive
  return "edit field" is among the keys of sUndoLogA
end _FieldEditingIsActive


private function _FocusedObjectIsFieldEdit
  return the selectedfield is not empty and not the locktext of the selectedfield and not the listbehavior of the selectedfield
end _FocusedObjectIsFieldEdit


private function _getNextUndoIndex pUndoStack
  local tMaxIndex

  put item 2 of the extents of sUndoLogA[pUndoStack]["undo"] into tMaxIndex
  return tMaxIndex + 1
end _getNextUndoIndex


private function _getNextRedoIndex pUndoStack
  local tMaxIndex

  put item 2 of the extents of sUndoLogA[pUndoStack]["redo"] into tMaxIndex
  return tMaxIndex + 1
end _getNextRedoIndex


private command _reverseAction pUndoStack, pTargetQueue, pIndex
  local tInverseQueue, i, tType, tInverseIndex, tTarget, tHasManyMementos

  put _validateUndoStackString(pUndoStack) into pUndoStack
  if pTargetQueue is "undo" then
    put "redo" into tInverseQueue
    put _getNextRedoIndex(pUndoStack) into tInverseIndex
  else
    put "undo" into tInverseQueue
    put _getNextUndoIndex(pUndoStack) into tInverseIndex
  end if

  # Store redo
  put sUndoLogA[pUndoStack][pTargetQueue][pIndex] into sUndoLogA[pUndoStack][tInverseQueue][tInverseIndex]

  # Inverse types
  repeat with i = 1 to the number of elements of sUndoLogA[pUndoStack][tInverseQueue][tInverseIndex]["mementos"]
    put sUndoLogA[pUndoStack][tInverseQueue][tInverseIndex]["mementos"][i]["type"] into tType

    put sUndoStructure[tType]["inverse type"] into sUndoLogA[pUndoStack][tInverseQueue][tInverseIndex]["mementos"][i]["type"]
  end repeat

  local tKeys, tKey

  # Move over all keys except "mementos" to inverse
  put the keys of sUndoLogA[pUndoStack][pTargetQueue][pIndex] into tKeys
  repeat for each line tKey in tKeys
    if tKey is "mementos" then next repeat
    put sUndoLogA[pUndoStack][pTargetQueue][pIndex][tKey] into sUndoLogA[pUndoStack][tInverseQueue][tInverseIndex][tKey]
  end repeat

  # Store memento for inverse: Reverse order of mementos, set inverse type, and dispatch message
  put 0 into i
  put the keys of sUndoLogA[pUndoStack][pTargetQueue][pIndex]["mementos"] into tKeys
  sort lines of tKeys descending numeric
  repeat for each line tKey in tKeys
    add 1 to i

    put sUndoLogA[pUndoStack][pTargetQueue][pIndex]["mementos"][tKey] into sUndoLogA[pUndoStack][tInverseQueue][tInverseIndex]["mementos"][i]
    put sUndoLogA[pUndoStack][tInverseQueue][tInverseIndex]["mementos"][i]["type"] into tType
    put sUndoStructure[tType]["inverse type"] into tType
    put tType into sUndoLogA[pUndoStack][tInverseQueue][tInverseIndex]["mementos"][i]["type"]
  end repeat

  put _getTargetForMessages(pUndoStack) into tTarget
  dispatch "undoStoreMementos" to tTarget with pUndoStack, sUndoLogA[pUndoStack][tInverseQueue][tInverseIndex]["mementos"]

  ## Run the undo
  dispatch "undoRestoreMementos" to tTarget with pUndoStack, sUndoLogA[pUndoStack][pTargetQueue][pIndex]["mementos"]

  delete local sUndoLogA[pUndoStack][pTargetQueue][pIndex]

  return empty
end _reverseAction


private function _keysAreNumeric pKeys
  local tKey

  repeat for each line tKey in pKeys
    if tKey is not an integer then return false
  end repeat
  return true
end _keysAreNumeric


private function _uniqueName pControl
  local i,tSeed,tStr

  put "ABCDEFGHIJKLMNOPQRSTUVWXYZ_0123456789" into tSeed
  repeat with i = 1 to 20
    put char random(length(tSeed)) of tSeed after tStr
  end repeat

  return tStr
end _uniqueName


private function _printArray pArray, pDimension, pFullData
  local tKeys, tKey, tText, tTempArray

  if pDimension is empty then put 0 into pDimension

  put the keys of pArray into tKeys
  sort tKeys numeric

  repeat for each line tKey in tKeys
    if pArray[tKey] is an array then
      put _printCharXTimes(space, pDimension * 3) & tKey & cr after tText
      put _printArray(pArray[tKey], pDimension + 1, pFullData) after tText
    else
      if pFullData then
        put _printCharXTimes(space, pDimension * 3) &  tKey & ":" && pArray[tKey] & cr after tText
      else
        put _printCharXTimes(space, pDimension * 3) &  tKey & ":" && line 1 of pArray[tKey] & cr after tText
      end if
    end if
  end repeat

  return tText
end _printArray

private function _printCharXTimes pChar, pTimes
  local tStr

  repeat with i = 1 to pTimes
    put pChar after tStr
  end repeat
  return tStr
end _printCharXTimes
