script "Undo Manager Field Edits Undo Frontscript"
local sWatchForFirstInput = false
local sLogMessages = false

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


## We override the memento restorer so we can log first input logging
command undoTextRestoreMementoExtended @pUndoObjectA, @pInverseUndoObjectA
  undoTextRestoreMemento pUndoObjectA, pInverseUndoObjectA

  ## Start watching text input again
  put true into sWatchForFirstInput
end undoTextRestoreMementoExtended


## This handler will log an undo if there is a selectedChunk or if the text entry is the first in the field
private command _logUndoIfNecessary pMsg
  if the environment is not "development" then
    if the selectedfield is not empty and the uEnableFieldUndo of the selectedField is not false then
      if sWatchForFirstInput or word 4 of the selectedchunk > word 2 of the selectedchunk then
        undoLogEditFieldUndo pMsg
      end if
    end if
  end if
end _logUndoIfNecessary


# Summary: Logs an undo for field editing.
# pMsg: The label to use for the undo action.
# Returns: empty
command undoLogEditFieldUndo pMsg
  ## text is selected
  undoAddActionToUndoStack "edit field", "edit field", pMsg, "control:" & _longIDWithoutHierarchy(the long id of the selectedfield), "control selected chunk:" & the selectedchunk
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
