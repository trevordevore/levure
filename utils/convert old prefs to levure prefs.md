If you are moving an existing project over to the Levure framework then you may want to convert your old preference file to the format supported by the framework.

Here is an example that converts a preference stack created by the GLX Application Framework to the format used by Levure. In this example, the preference file defined in the `app.yml` file has a different name then the existing preference file that the GLX Application Framework was saving to. The Levure-based application will create a new preference file that will be used going forward.

`PreloadApplication` is a message sent to your `app` stack before the application files have been loaded into memory.

```
command PreloadApplication
  # Convert preferences file from stack to arrayEncode() so it will work with new
  # preferences library. Check to see if a preference that should have a value
  # is empty. Make sure you don't use a preference that has a default value!
  if the platform is "win32" and prefsGetPref("software build") is empty then
    local tPreferenceFile, tOldPreferenceFile

    set the itemdelimiter to "/"
    put prefsGetPreferenceFile("user") into tPreferenceFile
    put item 1 to -2 of tPreferenceFile & "/My Old Preferences.dat" into tOldPreferenceFile

    if there is a stack tOldPreferenceFile then
      local tPrefsA, tSet, tSetA, tKey

      repeat for each line tKey in the customKeys[""] of stack tOldPreferenceFile
        if tKey is "glxPrefFile" then next repeat

        # move to array, stripping "u" prefix
        put the tKey of stack tOldPreferenceFile into tPrefsA[char 2 to -1 of tKey]
      end repeat

      repeat for each line tSet in the customPropertySets of stack tOldPreferenceFile
        put the customProperties[tSet] of stack tOldPreferenceFile into tPrefsA[char 2 to -1 of tSet]
      end repeat

      put arrayEncode(tPrefsA) into URL("binfile:" & tPreferenceFile)
      prefsReload "user"
    end if
  end if
end PreloadApplication
```
