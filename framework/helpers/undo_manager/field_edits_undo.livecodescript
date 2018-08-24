script "Undo Manager Field Edits Undo Frontscript"
constant kTimer = 20000
local sWatchForFirstInput = false
local sLogMessages = false
local sLastTimestamp = 0

on openField
  put true into sWatchForFirstInput
  pass openField
end openField

on closeField
  put false into sWatchForFirstInput
  undoReset "edit field"
  pass closeField
end closeField

on exitField
  put false into sWatchForFirstInput
  undoReset "edit field"
  pass exitField
end exitField

on deleteKey
  _logUndoIfNecessary "Delete Text"
  pass deletekey
end deleteKey


on backspaceKey
  _logUndoIfNecessary "Delete Text"
  pass backspacekey
end backspaceKey

## Change to rawkeydown once we get a hold of a list of keys to ignore
on keydown pKeyCode
  local tMsg

  if sWatchForFirstInput then put "Typing" into tMsg
  else put "Replace Text" into tMsg
  _logUndoIfNecessary tMsg
  pass keydown
end keydown


on returnInField
  local tMsg

  if sWatchForFirstInput then put "Typing" into tMsg
  else put "Replace Text" into tMsg
  _logUndoIfNecessary tMsg
  pass returnInField
end returnInField


on enterInField
  local tMsg

  if sWatchForFirstInput then put "Typing" into tMsg
  else put "Replace Text" into tMsg
  _logUndoIfNecessary tMsg
  pass enterInField
end enterInField


/**
Summary: Stores a memento for a field prior to changes being made.
*/
command undoStoreMementos pUndoStack, @pMementosA
  if pUndoStack is not "edit field" then pass undoStoreMementos

  local i

  repeat with i = 1 to the number of elements of pMementosA
    if pMementosA[i]["control"] is empty then
      put the long id of the selectedField into pMementosA[i]["control"]
    end if
    put word 1 to 4 of the selectedchunk into pMementosA[i]["control selected chunk"]
    if codepointToNum(the last char of the selectedtext) is among the items of "10,11" then
      subtract 1 from word 4 of pMementosA[i]["control selected chunk"]
    end if

    local tControl

    put pMementosA[i]["control"] into tControl
    put compress(the htmltext of tControl) into pMementosA[i]["value"]
  end repeat
end undoStoreMementos


/**
Summary: Restores mementos for a field edit.
*/
command undoRestoreMementos pUndoStack, @pMementosA
  local tControl, tChunk, i, e

  # Only process messages sent to this stack script
  if pUndoStack is not "edit field" then pass undoRestoreMementos

  lock screen

  repeat with i = 1 to the number of elements of pMementosA
    put pMementosA[i]["control"] into tControl
    if there is not a tControl then next repeat

    set the htmltext of tControl to decompress(pMementosA[i]["value"])
    put pMementosA[i]["control selected chunk"] into tChunk

    try
      if tChunk is not empty then
        select char (word 2 of tChunk) to (word 4 of tChunk) of tControl
      else
        select after the last char of tControl
      end if
    catch e
      ## Seen this error before.
      ## Don't know cause though
      --      Type: Chunk: can't select object that isn't open

      --      Object: stack "lib.glx.UndoManager"

      --      Line: select char (word 2 of tChunk) to (word 4 of tChunk) of tControl

      --      Line No: 627
      --      Hint: undoTextRestoreMemento
      put param(0) && e
    end try

    dispatch "TextChanged" to tControl ## let control know that content was updated.
  end repeat

  if tControl is not empty then
    dispatch "EditFieldMementosRestored" to tControl
  end if

  unlock screen

  ## Start watching text input again
  put true into sWatchForFirstInput
end undoRestoreMementos


command undoCleanupMementos pUndoStack, pMementosA
  ## Nothing to do
end undoCleanupMementos


## This handler will log an undo if there is a selectedChunk or if the text entry is the first in the field
private command _logUndoIfNecessary pMsg
  if the environment is not "development" then
    if the selectedfield is not empty and the uEnableFieldUndo of the selectedField is not false then
      # Log an undo entry if:
      # a) we are watching for first input
      # b) a range of text is being replaced.
      # c) the user hasn't typed anything in kTimer number of seconds
      if sWatchForFirstInput or word 4 of the selectedchunk > word 2 of the selectedchunk \
            or (the milliseconds - sLastTimestamp) > kTimer then
        undoLogEditFieldUndo pMsg
        put the milliseconds into sLastTimestamp
      end if
    end if
  end if
end _logUndoIfNecessary


# Summary: Logs an undo for field editing.
# pMsg: The label to use for the undo action.
# Returns: empty
command undoLogEditFieldUndo pMsg
  ## text is selected
  local theMementoA

  put "update" into theMementoA["type"]
  put _longIDWithoutHierarchy(the long id of the selectedfield) into theMementoA["contorl"]
  undoAddAction "edit field", pMsg, _Array("1", theMementoA)
  put false into sWatchForFirstInput
end undoLogEditFieldUndo


private function _longIDWithoutHierarchy pControl
  local tFirstCharToDelete,tLastCharToDelete

  put the long ID of pControl into pControl

  if word 1 of pControl is not among the items of "card,stack" then
    if pControl contains "of group id" then
      put length(word 1 to 4 of pControl) + 1 into tFirstCharToDelete
      put offset(" card id", pControl) - 1 into tLastCharToDelete
      delete char tFirstCharToDelete to tLastCharToDelete of pControl
    end if
  end if

  return pControl
end _longIDWithoutHierarchy
