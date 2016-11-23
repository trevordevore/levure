script "app"

command InitializeApplication
  answer param(0)
end InitializeApplication


command OpenApplication
  go stack "MyApp"
end OpenApplication


command ProcessURL pUrls
  answer param(0) && pUrls
end ProcessURL


command ProcessFiles pFiles
  answer param(0) && pFiles
end ProcessFiles


on PreShutdownApplication

end PreShutdownApplication