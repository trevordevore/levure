script "app"
command PreloadApplication

end PreloadApplication


command InitializeApplication

end InitializeApplication


command OpenApplication
  # Open the sample window
  go stack "LevureSampleWindow"
end OpenApplication


command PreShutdownApplication

end PreShutdownApplication
