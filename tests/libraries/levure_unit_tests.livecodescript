script "Levure Framework Unit Tests"
command RunTests
  SetupTests

  RunTest "TestPreferences"

  dispatch "uiShowLog" to this card of stack "Show UnitTest Results"
end RunTests


command SetupTests

end SetupTests


command RunTest pTest
  unittest_incrementTestsRun
  dispatch pTest to me
end RunTest


command TestAppConfigFileParsing

end TestAppConfigFileParsing


command TestPreferences
  local tA, tText

  verify_equal prefsGetPref("test: key", "user"), "test: value", "yaml keys not parsed correctly"

  put "∂©Ekl" into tA["text"]

  /*
  Need way of resetting prefs on macOS. Retry once we can convert to a module.

  put appGetDefaultPrefs("shared") into tDefaultPrefsA
  verify_equal tDefaultPrefsA, tA, "shared default prefs do not match"

  put appGetDefaultPrefs("user") into tDefaultPrefsA
  verify_equal tDefaultPrefsA, tA, "user default prefs do not match"

  put prefsGetPref("text") into tText
  verify_equal tText, tA["text"], "get pref did not return default value"
  */

  prefsSetPref "text", "©´©´©´©"
  verify_equal the result, empty, "error setting pref to unicode string"

  put prefsGetPref("text") into tText
  verify_equal tText, "©´©´©´©", "get pref did not return pref value"
end TestPreferences


function TestResourcesFolder
  local tFolder

  put the effective filename of this stack into tFolder
  set the itemDelimiter to slash
  put "resources" into item -2 to -1 of tFolder
  return tFolder
end TestResourcesFolder
