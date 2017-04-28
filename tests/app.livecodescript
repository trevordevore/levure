script "app"
command InitializeApplication

end InitializeApplication


command OpenApplication
  RunTests
  go stack "Show UnitTest Results"
end OpenApplication


command ProcessFiles pFiles

end ProcessFiles


command ProcessURLs pURLs

end ProcessURLs


command RunTests
  local tAppA

  put levureAppGetConfig() into tAppA

  # Test that app config with comments present is being parsed properly
  verify_equal levureAppGet("multiple instances"), false, "multiple instances"
  verify_equal levureAppGet("relaunch in background"), false, "relaunch in background"
  verify_equal tAppA["application data folder"]["user"]["default"], "LevureUnitTestApp/1.0", "default user app data folder"

  # Test default pref values
  verify_equal prefsGetPref("unicode text"), "∂©Ekl", "wrong encoding in `unicode text` key"
  verify_equal prefsGetPref("test: key", "user"), "test: value", "incorrect parsing of `:` in `test: key` key"
  verify_equal prefsGetPref("test #key", "user"), "value #", "incorrect parsing of comment in `test #key` key"
end RunTests
