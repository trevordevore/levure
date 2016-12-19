script "levureExternalEditorServer"
on libraryStack
  if the target is not me then pass libraryStack

  StartServer
end libraryStack


on releaseStack
  if the target is not me then pass releaseStack


end releaseStack


private command StartServer
  accept connections on port 62475 with message "levureExternalEditorClientRequest"
end StartServer


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
