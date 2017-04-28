script "app"

command PreloadApplication
  # Perform operations before stacks, extensions, and externals in app.yml are loaded.

end PreloadApplication


command InitializeApplication
  # Called after script-only stacks, extensions, and externals in app.yml are loaded.
  # Perform initialization operations before UI stack is opened.

  # Uncomment to use Sublime Text external editor in development
  -- if the environment is "development" then
  --   levureLoadExternalEditorServer
  -- end if

  # If this the first time application has run on this computer, call FirstRun
  # This method requires the preferences framework helper to be loaded.
  if prefsGetPref("software build") is empty then
    FirstRun
    prefsSetPref "software build", levureAppGet("build")
  end if

  # Perform initialization operations every time application runs.

  return true
end InitializeApplication


command FirstRun
  # Perform initialization operations only the first time application runs.
end FirstRun


command OpenApplication
  # Called after InitializeApplication.
  # Open UI stack

  # Open the starter app sample window UI stack
  go stack "LevureSampleWindow"
end OpenApplication


command PreShutdownApplication
  # Called before the application shuts down.
  # Perform any cleanup.
end PreShutdownApplication


on shutdownRequest
  # To keep app from quitting don't pass shutdownRequest
  pass shutdownRequest
end shutdownRequest


command ProcessURL pURLs
  # First parameter is line delimited list of urls your app has been requested to process.
  # Requires the [[FRAMEWORK]]/helpers/files_and_urls helper.
end ProcessURL


command ProcessFiles pFiles
  # First parameter is line delimited list of files your application supports
  # and that you should process.
  # Requires the [[FRAMEWORK]]/helpers/files_and_urls helper.
end ProcessFiles
