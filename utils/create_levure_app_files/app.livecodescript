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


command ProcessURL URLsToProcess #URLsToProcess is line-delimited
	#REQUIREMENTS:  {{FRAMEWORK}}/helpers/files_and_urls helper
	
end ProcessURL


command ProcessFiles listOfFiles #listOfFiles is line-delimited
	#REQUIREMENTS:  {{FRAMEWORK}}/helpers/files_and_urls helper

end processFiles