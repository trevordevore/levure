# External Editor Server Plugin

`external_editor_server.livecodescript` is a server that listens for requests telling the server that a LiveCode script only stack has been updated. When a request is received, the current environemnt is checked to see if a stack with a particular name and filename exist in memory. If the stack exists then the script is updated with the contents of the file.

You can call `levureLoadExternalEditorServer` while a Levure-based application is open to turn the server on.
