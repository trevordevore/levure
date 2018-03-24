script "levureExternalEditorServer"
constant kDefaultPort = "61373"


command levureExternalEditorStartServer pPort
  local tError, tDefaultInterface

  if pPort is not an integer then put kDefaultPort into pPort

  put the defaultnetworkinterface into tDefaultInterface
  set the defaultnetworkinterface to "127.0.0.1"
  accept connections on port pPort with message "levureExternalEditorClientRequest"
  put the result into tError

  set the defaultnetworkinterface to tDefaultInterface

  return tError for error
end levureExternalEditorStartServer


on levureExternalEditorClientRequest pIPAddr
  local tError, tKey, tQueryA

  read from socket pIPAddr until linefeed
  delete the last char of it

  put it into tQueryA

  split tQueryA by "&" and "="

  repeat for each key tKey in tQueryA
    put textDecode(urldecode(tQueryA[tKey]), "utf8") into tQueryA[tKey]
  end repeat

  switch tQueryA["command"]
    case "open"
      if there is a stack tQueryA["filename"] then
        try
          go stack tQueryA["filename"]
        catch tError

        finally
          write "success" to socket pIPAddr
        end try

        if tError is not empty then
          throw tError
        end if

      else
        put "Stack file" && tQueryA["filename"] && "does not exist." into tError
        write "error:" && tError to socket pIPAddr
        answer error tError
      end if
      break
    default
      if there is a stack tQueryA["stack"] and the filename of stack tQueryA["stack"] is tQueryA["filename"] then
        try
          local tOldPreserveVariables, tOldExplicitVariables, tDefaultStack

          put the defaultStack into tDefaultStack
          put the preserveVariables into tOldPreserveVariables

          set the defaultStack to me
          set the preserveVariables to true

          lock messages
          create button "CompileScript"

          set the script of button "CompileScript" to (line 2 to -1 of url("file:" & tQueryA["filename"]))
          put the result into tError

          if tError is empty then
            set the script of stack tQueryA["stack"] to the script of button "CompileScript"
            write "success" to socket pIPAddr
          end if

          delete button "CompileScript"
          set the preserveVariables to tOldPreserveVariables
          set the defaultStack to tDefaultStack
          unlock messages
        catch tError

        end try

        if tError is not empty then
          write "error:" && tError to socket pIPAddr
          beep
          put tError
          answer error "Error setting script of stack" && tQueryA["stack"] & "."
        end if
      else
        write "file not found" to socket pIPAddr
      end if
  end switch
end levureExternalEditorClientRequest
