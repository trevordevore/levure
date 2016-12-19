script "levureExternalEditorServer"
constant kDefaultPort = "61373"

on libraryStack
  if the target is not me then pass libraryStack

end libraryStack


on releaseStack
  if the target is not me then pass releaseStack

end releaseStack


command levureExternalEditorStartServer pPort
  if pPort is not an integer then put kDefaultPort into pPort
  accept connections on port pPort with message "levureExternalEditorClientRequest"
  return the result
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
         return empty
      end try
   else
      write "file not found" to socket pIPAddr
   end if
end levureExternalEditorClientRequest
