# External Editor Server Plugin

`external_editor_server.livecodescript` is a server that listens for requests telling the server that a LiveCode script only stack has been updated. When a request is received, the current environment is checked to see if a stack with a particular name and filename exist in memory. If the stack exists then the script is updated with the contents of the file.

You can call `levureLoadExternalEditorServer` while a Levure-based application is open to turn the server on. The following code snippet demonstrates turning on external editor support whenever your application is opened in the LiveCode IDE.

```
command InitializeApplication
  # Use external editor in development
  if the environment is "development" then
    levureLoadExternalEditorServer
  end if

  ...
end InitializeApplication
```
