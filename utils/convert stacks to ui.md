# Converting stacks to UI components

If you are going to version control your stacks then you should have each stack in its own stack file and all scripts should be in script only stack files.
There are several ways to do that:
- Geoff Canyon's Navigator has functionality built-in to break out your scripts.  You can [download it on dropbox](https://www.dropbox.com/s/kz3zqi4botzglgq/navigator.zip?dl=1) or [clone or fork it on github](https://github.com/gcanyon/navigator)
- The [Levure videos on YouTube](https://www.youtube.com/watch?v=eyggLzIbeSU) demonstrate how to do it manually.
- This repo includes two scripts which can aid you in converting your stacks.

## Save a stack in memory to a stack file on disk

Run the following script to save a stack in memory to a file on disk. This can be used to place each stack in your application in its own **ui** folder.

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

put the filename of stack tStack into tFilename
if tFilename is empty then
  answer error "You must save the stack before running this script."
  exit to top
end if

if tTarget is "stack" then
  put the long id of stack tStack into tObject
  put "stack" into tTargetName
  put tStack && toUpper(char 1 of tTarget) & char 2 to -1 of tTarget && \
    "Behavior" into tBehaviorStackName
else
  put the long id of this card of stack tStack into tObject
  if the short name of tObject is not empty AND not (the short name of tObject begins with "card id ") then
    put tolower(the short name of tObject) & "_card" into tTargetName
    replace space with "_" in tTargetName
    put tStack && tTargetName && toUpper(char 1 of tTarget) & char 2 to -1 of tTarget && \
      "Behavior" into tBehaviorStackName
  else
    put "card" into tTargetName
    put tStack && toUpper(char 1 of tTarget) & char 2 to -1 of tTarget && \
      "Behavior" into tBehaviorStackName
  end if
end if

set the itemDelimiter to "/"

put "behaviors" into the last item of tFilename
if there is not a folder tFilename then
  create folder tFilename
  if the result is not empty then
    answer error "Error creating behaviors folder:" && the result
    exit to top
  end if
end if

put the script of tObject into tScript
put "/" & tTargetName & ".livecodescript" after tFilename
put textencode("script " & quote & tBehaviorStackName & quote & cr & cr & tScript, "utf8") into URL("binfile:" & tFilename)
if the result is not empty then
  answer error "Error saving script:" && the result
  exit to top
end if

set the script of tObject to empty
put the stackfiles of stack tStack into tStackFiles
put tBehaviorStackName & "," & "behaviors/" & item -1 of tFilename into line (the number of lines of tStackFiles + 1) of tStackFiles
set the stackfiles of stack tStack to tStackFiles
set the behavior of tObject to the long id of stack tBehaviorStackName
```
