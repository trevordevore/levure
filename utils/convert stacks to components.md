# Converting stacks to components

If you are going to version control your stacks then you should have each stack in its own stack file and all scripts should be in script only stack files. Here are two scripts which can aide you in converting your stacks.

## Save a stack in memory to a stack file on disk

Run the following script to save a stack in memory to a file on disk. This can be used to place each stack in your application in its own components folder.

```
put "REPLACE_WITH_YOUR_STACK_NAME" into tStack
if there is not a stack tStack then 
  beep
  exit to top
end if

put tolower(tStack) into tDefaultName
replace " " with "_" in tDefaultName

ask file "Save As:" with tDefaultName & ".livecode"
put it into tFilename

if tFilename is not empty then
  lock messages
  put the mainstack of stack tStack into tMainStack
  set the mainstack of stack tStack to tStack
  save stack tStack as tFilename
  set the mainstack of stack tStack to tMainStack
  unlock messages
end if
```

## Make a card or stack script a script only stack for use as a behavior

Use this script to convert the card or stack script of a stack to a script only stack that is stored in a `behaviors` folder alongside the stack file. The script only stack will be assigned to the `stackfiles` of the target stack and will also be assigned as the behavior of the card or stack.

```
# You can use "card" or "stack" as tTarget
put "card" into tTarget

put the short name of this stack into tStack
if tTarget is "stack" then
  put the long id of stack tStack into tObject
  put "stack" into tTargetName
  put tStack && toUpper(char 1 of tTarget) & char 2 to -1 of tTarget && \
    "Behavior" into tBehaviorStackName
else
  put the long id of this card of stack tStack into tObject
  if the short name of tObject is not empty AND not (the short name of tObject begins with "card id ") then
    put tolower(the short name of tObject) & "_card" into tTargetName
    put tStack && tTargetName && toUpper(char 1 of tTarget) & char 2 to -1 of tTarget && \
      "Behavior" into tBehaviorStackName
  else
    put "card" into tTargetName
    put tStack && toUpper(char 1 of tTarget) & char 2 to -1 of tTarget && \
      "Behavior" into tBehaviorStackName
  end if
end if
put the script of tObject into tScript
put the filename of stack tStack into tFilename
set the itemDelimiter to "/"
put "behaviors/" & tTargetName & ".livecodescript" into the last item of tFilename
put "script " & quote & tBehaviorStackName & quote & cr & cr & tScript into URL("file:" & tFilename)
set the script of tObject to empty
put the stackfiles of stack tStack into tStackFiles
put tBehaviorStackName & "," & "behaviors/" & item -1 of tFilename into line (the number of lines of tStackFiles + 1) of tStackFiles
set the stackfiles of stack tStack to tStackFiles
set the behavior of tObject to the long id of stack tBehaviorStackName
```