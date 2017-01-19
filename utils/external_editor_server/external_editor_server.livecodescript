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
  local tStackName, tFilename

  read from socket pIPAddr until linefeed
  delete the last char of it

  split it by "&" and "="
  put textDecode(urldecode(it["stack"]), "utf8") into tStackName
  put textDecode(urldecode(it["filename"]), "utf8") into tFilename

  if there is a stack tStackName and the filename of stack tStackName is tFilename then
    try
      set the script of stack tStackName to (line 2 to -1 of url("file:" & tFilename))
      write "success" to socket pIPAddr
    catch e
      write "error:" && e to socket pIPAddr
      beep
      put e
      answer error "Error setting script of stack" && tStackName & "."
    end try
  else
    write "file not found" to socket pIPAddr
  end if
end levureExternalEditorClientRequest
