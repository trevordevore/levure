script "app"
command PreloadApplication
  # Uncomment to use Sublime Text external editor in development
  -- if the environment is "development" then
  --   levureLoadExternalEditorServer
  -- end if
end PreloadApplication


command InitializeApplication

end InitializeApplication


command OpenApplication
  # Open the sample window
  go stack "LevureSampleWindow"
end OpenApplication


command PreShutdownApplication

end PreShutdownApplication
