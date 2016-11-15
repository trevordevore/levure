script "levureFramework"

##########
## This script must be assigned to a behavior of a stack that will be built as a standalone.
##########
constant kVersion = "0.0.1.0"
constant kAppStackName = "app"
constant kApplicationExternals = "levureAppExternals"

local sRootFolder             # Folder where standalone resides
local sAppFolder              # Folder where the `app` stack resides
local sAppA
local sRuntimePropertiesA


after mouseDown pBtnNum
  # Load app if user clicks on button in standalone stack
  if word 1 of the target is "button" then
    startup
  end if
end mouseDown


on startup
   set visible of me to false
   set the loc of me to the screenloc
   levureInitializeAndRunApplication
end startup


on relaunch
  if sRuntimePropertiesA["application has loaded"] then
    if sAppA["multiple instances"] then
      pass relaunch
    else
      dispatch "RelaunchApplication" to stack kAppStackName

      local i, tParams

      repeat with i = 1 to the paramcount
        put param(i) & cr after tParams
      end repeat

      #
      # If `background` is returned then the engine won't bring any stacks forward.
      #
      # `send` is used to processed outside of relaunch. Saw instances where
      # url processing opened a pref window but pref window would not come forward
      # when called. Main window stayed in front. Adding the send in time fixed it.
      # My guess is code brough a stack forward and then engine brought forward the defaultStack 
      # after relaunch finished. This may no longer be a bug. Need to test. In any case,
      # send in time is desirable as engine is going to bring defaultStack forward and
      # then developer code can handle any special cases.
      if tParams is not empty then
        # This handler is defined in a helper
        send "appProcessCommandLineParameters tParams" to stack kAppStackName in 0 milliseconds
      end if

      if sAppA["relaunch in background"] then
        return "background"
      end if
    end if
  end if
end relaunch


command levureInitializeAndRunApplication
  local tError
  
  levureInitializeFramework
  put the result into tError
  
  if tError is empty then
    ## Use a send so that if any dialogs are displayed in developer handled messages the
    ## loading process will not stop
    send "levureRunApplication" to me in 0 milliseconds
  end if
  
  if tError is not empty then
    answer error "An error occurred while initializaing the application [" &  tError & "]."
    
    if the environment is not "development" then
      quit
    end if
  end if
end levureInitializeAndRunApplication


command levureInitializeFramework pRootFolder
  local tError, tStacksInApp

  put false into sRuntimePropertiesA["application has loaded"]

  if the long id of me is the long id of this me OR word 1 of the long id of me is not "stack" then
    put "the framework is not assigned to a stack as a behavior" into tError
  end if

  if tError is empty then
    if pRootFolder is not empty then
      put normalizeFolderPath(pRootFolder) into sRootFolder
    else
      put myFolder() into sRootFolder
    end if
  end if

  if tError is empty then
    loadAppConfig
    put the result into tError
  end if

  if tError is empty then
    loadCommandLineArguments

    loadAppStack
    put the result into tError
  end if

  if tError is empty then
    loadHelpers tStacksInApp
    put the result into tError
  end if

  if tError is empty then
    set the stackFiles of stack kAppStackName to tStacksInApp
  end if

  return tError for error
end levureInitializeFramework


command levureRunApplication
  local tError, tStacksInApp
  
  if tError is empty then
    put the stackFiles of stack kAppStackName into tStacksInApp
    loadAppAssets tStacksInApp
  end if
  
  # Add lookup for all stacks in app. They will be loaded into memory as needed
  # when referenced by name.
  if tError is empty then
    set the stackFiles of stack kAppStackName to tStacksInApp
    
    dispatch "InitializeApplication" to stack kAppStackName
    if it is "handled" and the result is false then
      ## user can quit app if they want
      if lockMessages is true then unlock messages
      unloadApp
      
      ## Only quit if not in development. This allows developer to troubleshoot.
      if the environment is not "development" then
        quit
      end if
    else
      ## Slight delay here so that appleEvents can be sent before
      ## Application is loaded. This allows URLs that launched application
      ## to be tucked away in "process url"
      send "levurefinishLoadingApplication" to me in 10 milliseconds
    end if
  end if
  
  -- display tError
end levureRunApplication


private command loadCommandLineArguments
  if the platform is not "macos" then
    local tValue, tParams, i
    
    set the itemDelimiter to "."
    repeat with i = 1 to ($# - 1)
      put value("$" & i) into tValue
      put tValue & cr after tParams
    end repeat
    
    if tParams is not empty then
      appProcessCommandLineParameters tParams
    end if
  end if
end loadCommandLineArguments


command levurefinishLoadingApplication
  local msgsAreLocked
  
  dispatch "OpenApplication" to stack kAppStackName
  put true into sRuntimePropertiesA["application has loaded"]
  
  # Don't fire off any messages when closing the standalone stack
  put the lockMessages into msgsAreLocked
  lock messages
  close me
  set the lockMessages to msgsAreLocked
end levurefinishLoadingApplication


function levureApplicationHasLoaded
  return sRuntimePropertiesA["application has loaded"]
end levureApplicationHasLoaded


function levureAppGet pProp
  if pProp is among the keys of pProp then
    return sAppA[pProp]
  else
    throw "invalid levure app property:" && pProp
  end if
end levureAppGet


private command normalizeAppArray
  put sAppA["multiple instances"] is true into sAppA["multiple instances"]
  put sAppA["relaunch in background"] is true into sAppA["relaunch in background"]
  
  repeat for each item tKey in "password,file extensions,file extension groups"
    if tKey is not among the keys of sAppA then
      put empty into sAppA[tKey]
    end if
  end repeat
  
  # Normalize file and folder paths
  repeat with i = 1 to the number of elements of sAppA["components"]
    put normalizeRelativeFilename(sAppA["components"][i]["filename"]) into sAppA["components"][i]["filename"]
  end repeat
  
  repeat with i = 1 to the number of elements of sAppA["helper source folders"]
    put normalizeFolderPath(sAppA["helper source folders"][i]) into sAppA["helper source folders"][i]
  end repeat
  
  return empty for value
end normalizeAppArray


private command unloadApp
  repeat with i = 1 to the number of elements of sAppA["frontscripts"]
    remove stack sAppA["frontscripts"][i]["filename"] from front
  end repeat
  repeat with i = 1 to the number of elements of sAppA["backscripts"]
    remove stack sAppA["backscripts"][i]["filename"] from back
  end repeat
  repeat with i = 1 to the number of elements of sAppA["libraries"]
    stop using stack sAppA["libraries"][i]["filename"]
  end repeat
  unloadExternals
end unloadApp


private command loadAppConfig
  local tError
  
  if the environment is not "development" and sAppA is an array then
    # Packaged application. 
    # - 'app' stack should be in memory
    # - sAppA should have configuration info
    
  else
    # Development
        
    # Search order:
    # 1. root folder which by default is the folder where the standalone resides
    # 2. Directly inside any folders alongside the root folder.
    
    # Search folders
    local tFolders, tFolder
        
    if there is a file (sRootFolder & "/app.yml") then
      put sRootFolder into sAppFolder
    else
      put folderListing(sRootFolder) into tFolders
    
      repeat for each line tFolder in tFolders
        if there is a file (tFolder & "/app.yml") then
          put tFolder into sAppFolder
          exit repeat
        end if
      end repeat
    end if
    
    put yamlFileToArray(sAppFolder & "/app.yml") into sAppA
    put the result into tError
    
    if tError is empty then
      normalizeAppArray
    end if
    
    # If not explicitly configured, load any libraries, frontscripts, or backscripts
    if tError is empty then
      local i
      
      if the number of elements of sAppA["libraries"] > 1 then
        repeat with i = 1 to the number of elements of sAppA["libraries"]
          put sRootFolder & "/libraries/" before sAppA["libraries"][i]["filename"]
        end repeat
      else
        put 0 into i
        repeat for each line tFile in fileListing(sRootFolder & "/libraries")
          add 1 to i
          put tFile into sAppA["libraries"][i]["filename"]
        end repeat
      end if
      
      if the number of elements of sAppA["backscripts"] > 1 then
        repeat with i = 1 to the number of elements of sAppA["backscripts"]
          put sRootFolder & "/backscripts/" before sAppA["backscripts"][i]["filename"]
        end repeat
      else
        put 0 into i
        repeat for each line tFile in fileListing(sRootFolder & "/backscripts")
          add 1 to i
          put tFile into sAppA["backscripts"][i]["backscripts"]
        end repeat
      end if
      
      if the number of elements of sAppA["frontscripts"] > 1 then
        repeat with i = 1 to the number of elements of sAppA["frontscripts"]
          put sRootFolder & "/frontscripts/" before sAppA["frontscripts"][i]["filename"]
        end repeat
      else
        put 0 into i
        repeat for each line tFile in fileListing(sRootFolder & "/frontscripts")
          add 1 to i
          put tFile into sAppA["frontscripts"][i]["filename"]
        end repeat
      end if
    end if
  end if
  
  if sAppA is not an array then
    put "invalid app.yml file" into tError
  end if
  
  return tError for error
end loadAppConfig


private command loadAppStack
  # app stack will already be in memory if this is a packaged app
  if there is not a stack kAppStackName then
    if there is not a stack (sAppFolder & "/app.livecodescript") \
      AND there is not a stack (sAppFolder & "/app.livecode") then
      return "app stack not found" for error
    end if
  end if
  
  start using stack kAppStackName

  return empty for value
end loadAppStack


private command loadAppAssets @xStacks
  local tError
  
  if tError is empty then
    local i
    
    repeat with i = 1 to the number of elements of sAppA["components"]
      put sAppA["components"][i]["name"] & "," & \
            sRootFolder & "/components/" & sAppA["components"][i]["filename"] & cr after xStacks
    end repeat
    if the number of elements of sAppA["components"] > 0 then
      delete the last char of xStacks
    end if
  end if
  
  if tError is empty then
    loadMessagePathAssets sAppA
  end if
  
  return tError
end loadAppAssets


private command loadMessagePathAssets pArrayA
  repeat with i = 1 to the number of elements of pArrayA["libraries"]
    start using stack pArrayA["libraries"][i]["filename"]
  end repeat
  
  repeat with i = 1 to the number of elements of pArrayA["backscripts"]
    insert script of stack pArrayA["backscripts"][i]["filename"] into back
  end repeat
  
  repeat with i = 1 to the number of elements of pArrayA["frontscripts"]
    insert script of stack pArrayA["frontscripts"][i]["filename"] into front
  end repeat
  
  return empty for value
end loadMessagePathAssets


private command loadHelpers @xStacks
  local tError, i
  local tHelperRootFolders, tHelperRootFolder, tHelperFolders, tHelper
  local tConfigA
  
  # Helpers are loaded in following order:
  # 1. levureFrameworkFolder().
  # 2. sAppFolder (if different than [1]).
  # 3. "helper source folders" setting.
  put levureFrameworkFolder() & "/helpers" & cr into tHelperRootFolders
  if sAppFolder is not line 1 of tHelperRootFolders then
    put sAppFolder & "/helpers" & cr after tHelperRootFolders
  end if
  repeat with i = 1 to the number of elements of sAppA["helper source folders"]
    put resolveRelativeFolderReference(sAppA["helper source folders"][i], sAppFolder) & cr after tHelperRootFolders
    put the result into tError
    
    if tError is not empty then exit repeat
  end repeat
  
  if tError is empty then
    delete the last char of tHelperRootFolders
    if the environment is "development" then
      replace "{{USER_EXTENSIONS}}" with revEnvironmentCustomizationPath() in tHelperRootFolders
    end if
  end if
  
  answer tHelperRootFolders
  
  if tError is empty then
    repeat for each line tHelperRootFolder in tHelperRootFolders
      put folderListing(tHelperRootFolder) into tHelperFolders
    
      repeat for each line tHelper in tHelperFolders
        put yamlFileToArray(tHelper & "/helper.yml") into tConfigA
        put the result into tError
      
        if tError is empty then
          local tExternals
        
          repeat with i = 1 to the number of elements of tConfigA["stacks"]
            put tConfigA["stacks"][i]["name"] & "," & \
                  tHelper & "/" & normalizeRelativeFilename(tConfigA["stacks"][i]["filename"]) & cr after xStacks
          end repeat
          if the number of elements of tConfigA["stacks"] > 0 then
            delete the last char of xStacks
          end if
        
          repeat with i = 1 to the number of elements of tConfigA["externals"]
            put tHelper & "/" & normalizeRelativeFilename(tConfigA["externals"][i]["filename"]) & cr after tExternals
          end repeat
          delete the last char of tExternals
        
          repeat with i = 1 to the number of elements of tConfigA["libraries"]
            put tHelper & "/" before tConfigA["libraries"][i]["filename"]
          end repeat
        
          repeat with i = 1 to the number of elements of tConfigA["backscripts"]
            put tHelper & "/" before tConfigA["backscripts"][i]["filename"]
          end repeat
        
          repeat with i = 1 to the number of elements of tConfigA["frontscripts"]
            put tHelper & "/" before tConfigA["frontscripts"][i]["filename"]
          end repeat
        
          loadExternals tExternals
          loadMessagePathAssets tConfigA
        end if
      
        if tError is not empty then exit repeat
      end repeat
    end repeat
  end if
  
  return tError for error
end loadHelpers


private command loadExternals pFilenames
  if pFilenames is empty then return empty for value
  
  if there is a stack kApplicationExternals then
    delete stack kApplicationExternals
    
    /*dispatch "PreloadExternals" to stack kAppStackName with pFilenames
    if it is "handled" then
      put the result into pFilenames
    end if*/
    
    reset the templatestack
    set the destroyWindow of the templatestack to true
    set the destroyStack of the templatestack to true
    set the visible of the templatestack to false
    set the style of the templatestack to "palette"
    
    set the externals of the templatestack to pFilenames
    
    local msgsAreLocked
    put the lockMessages into msgsAreLocked
    lock messages
    create stack kApplicationExternals
    reset the templatestack
    
    go stack kApplicationExternals
    start using stack kApplicationExternals
    set the lockMessages to msgsAreLocked
  end if
end loadExternals


## deleting externals stack when app aborts during initialization routines
## was causing crashes on OS 10.7.3 (glxapp framework). Stack is only purged when
## developer explicitly calls this handler via glxapp_unloadExternals.
## Note: only enable this if we see similar crashes in 8+
private command unloadExternals --pPurgeFromMemory
  if there is a stack kApplicationExternals then
    stop using stack kApplicationExternals
    --if pPurgeFromMemory then
    delete stack kApplicationExternals
    --else
    --close stack kApplicationExternals
    --end if
  end if
end unloadExternals


private function normalizeRelativeFilename pFilename
  if char 1 of pFilename is "/" then
    delete char 1 of pFilename
  else if char 1 to 2 of pFilename is "./" then
    delete char 1 to 2 of pFilename
  end if
  return pFilename for value
end normalizeRelativeFilename


private function normalizeFolderPath pFilename
  repeat while the last char of pFilename is "/"
    delete the last char of pFilename
  end repeat
  
  return pFilename
end normalizeFolderPath


private function myFolder
  put the effective filename of this stack into tFolder
  set the itemDelimiter to "/"
  delete the last item of tFolder
  return tFolder for value
end myFolder


function levureFrameworkFolder
  put the filename of (the long id this me) into tFolder
  set the itemDelimiter to "/"
  delete the last item of tFolder
  return tFolder for value
end levureFrameworkFolder


private function resolveRelativeFolderReference pFilename, pRootFolder
  set the itemDelimiter to "/"
  
  repeat while pFilename begins with "../"
    if pRootFolder is empty then
      return "relative path is too deep for root folder" for error
    else
      delete the last item of pRootFolder
      delete char 1 to 3 of pFilename
    end if
  end repeat
  
  return pRootFolder & "/" & pFilename for value
end resolveRelativeFolderReference


private function folderListing pFilename
  local tFolders, tFolder, tFullPathFolders
  
  put folders(pFilename) into tFolders
  if line 1 of tFolders is ".." then delete line 1 of tFolders
  
  repeat for each line tFolder in tFolders
    put pFilename & "/" & tFolder & cr after tFullPathFolders
  end repeat
  delete the last char of tFullPathFolders
  
  return tFullPathFolders for value
end folderListing


private function fileListing pFilename
  local tFiles, tFile, tFullPathFiles
  
  put files(pFilename) into tFiles
  
  repeat for each line tFile in tFiles
    put pFilename & "/" & tFile & cr after tFullPathFiles
  end repeat
  delete the last char of tFullPathFiles
  
  return tFullPathFiles for value
end fileListing


private function yamlFileToArray pFilename
  local tError
  
  put readFileContents(pFilename) into tYaml
  put the result into tError
  
  if tError is empty then
    return yamlToArray(tYaml) for value
  else
    return tError for error
  end if
end yamlFileToArray


private function readFileContents pFilename
  local tError
  
  open file pFilename for read
  put the result into tError
  
  if tError is empty then
    read from file pFilename until eof
    if the result is not "eof" then
      put the result into tError
    end if
    
    close file pFilename
  end if
  
  if tError is empty then
    return it for value
  else
    return tError for error
  end if
end readFileContents


/**********************
Basic YAML support until an LCB extension is written.
***********************/
/**
Array-to-Yaml and Yaml-to-Array library
Mark Wieder 2016
wtf licenced : have fun

Public functions here:
arrayToYaml
yamlToArray
*/

-- allow 4 spaces per indentation in output yaml files
-- adjust as desired
constant kIndent = 4

/*
arrayToYaml

Convert a LiveCode array to yaml format

@pArray : the array to convert
@pIndentLevel : initially empty, recursion sets this
*/
private function arrayToYaml pArray, pIndentLevel
  local tYaml
  local tIndentLevel
  
  put pIndentLevel into tIndentLevel
  if tIndentLevel is empty then
    put kIndent into tIndentLevel
    put "ArrayName :" & cr into tYaml
  end if
  if pArray is an array then
    repeat for each key tKey in pArray
      if pArray[tKey] is an array then
        put indent(tIndentLevel) & tKey && ":" && pArray[tKey] & cr after tYaml
        add kIndent to tIndentLevel
        -- recurse to work through multidimensional arrays
        put arrayToYaml(pArray[tKey], tIndentLevel) after tYaml
        subtract kIndent from tIndentLevel
      else
        put indent(tIndentLevel) & tKey && ":" && pArray[tKey] & cr after tYaml
      end if
    end repeat
  else
    throw "not an array"
  end if
  return tYaml
end arrayToYaml

/*
indent

Used internally by arrayToYaml
*/
private function indent pIndentLevel
  local tIndentLevel
  
  -- return the proper number of spaces for indentation
  repeat pIndentLevel times
    put space after tIndentLevel
  end repeat
  return tIndentLevel
end indent

/*
indentationLevel

Return the indentation level of the supplied line
NOTE: changes the input line in situ to remove the indentation
Used internally by yamlToArray
*/
private function indentationLevel @pLine
  local tIndentationLevel
  local tKey, tValue
  
  put 0 into tIndentationLevel
  repeat while char 1 of pLine is space
    add 1 to tIndentationLevel
    delete char 1 of pLine
  end repeat
  return tIndentationLevel
end indentationLevel

/*
yamlToArray

Convert yaml format text to a LiveCode array
*/
private function yamlToArray pYaml
  local tArray
  local tIndentation, tPrevIndent
  local tWorkingLine
  local tYamlHeading
  local tKey, tValue
  
  repeat for each line tLine in pYaml
    put tLine into tWorkingLine
    if word 1 to -1 of tWorkingLine is empty then next repeat
    
    set the itemdelimiter to ":"
    put item 1 of tWorkingLine into tKey
    repeat while char -1 of tKey is in ": "
      delete char -1 of tKey
    end repeat
    put word 1 to -1 of item 2 of tWorkingLine into tValue
    put indentationLevel(tKey) into tIndentation
    set the itemdelimiter to ","
    if tPrevIndent is empty then
      -- first time through
      put tIndentation into tPrevIndent
      put tKey into tYamlHeading
      put tValue into tArray[tYamlHeading]
    else
      switch
        case tIndentation < tPrevIndent
          -- remove the last array index
          repeat with i = tPrevIndent down to tIndentation+1
            RemoveLastIndexFrom tYamlHeading
          end repeat
          put tIndentation into tPrevIndent
          yamlAddToArray tArray, tYamlHeading, tKey, tValue
          put tKey into item (the number of items of tYamlHeading + 1) of tYamlHeading
          break
        case tIndentation is tPrevIndent
          RemoveLastIndexFrom tYamlHeading
          yamlAddToArray tArray, tYamlHeading, tKey, tValue
          put tKey into item (the number of items of tYamlHeading + 1) of tYamlHeading
          break
        case tIndentation > tPrevIndent
          -- add an array index
          yamlAddToArray tArray, tYamlHeading, tKey, tValue
          put tKey into item (the number of items of tYamlHeading + 1) of tYamlHeading
          put tIndentation into tPrevIndent
          break
      end switch
    end if
  end repeat
  return tArray
end yamlToArray

private command yamlAddToArray @xArray, pYamlHeading, pKey, pValue
  if pYamlHeading is empty then
    do "put pValue into xArray[" & quote & pKey & quote & "]"
  else
    do "put pValue into xArray" & yamlPathToArrayPath(pYamlHeading) & "[" & quote & pKey & quote & "]"
  end if
end yamlAddToArray

private command RemoveLastIndexFrom @pIndexString
  set the itemdelimiter to comma
  delete item -1 of pIndexString
end RemoveLastIndexFrom

private function yamlPathToArrayPath pYamlPath
  local tArrayPath
  
  set the itemdelimiter to comma
  repeat for each item tPath in pYamlPath
    put "[" & quote & tPath & quote & "]" after tArrayPath
  end repeat
  return tArrayPath
end yamlPathToArrayPath
