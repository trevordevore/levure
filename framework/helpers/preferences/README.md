# preferences Helper

The **preferences** helper manages storing, retrieving, and setting default values for preferences in your application. A default value is the value that will be returned by the API for a preference key if the user hasn't specified a setting for the preference key yet.

## Specify the preferences file name

You specify the preferences file name for the platforms your application supports in `app.yml`. If you want all platforms to use the same file name then set the `default` key. For any platforms your application does not support just leave the entry blank.

**IMPORTANT:** Do not use quote marks around your strings in `app.yml`.

```
# app.yml

preferences filename:
  user:
    default: Default Application Preferences
    macos: My Mac OS Application Preferences
    windows: My Windows Application Preferences
    linux: My Linux Application Preferences
    ios: My iOS Application Preferences
    android: My Android Application Preferences
  shared:
    default: Default Shared Application Preferences
    macos: Shared Mac OS Application Preferences
    windows: Shared Windows Application Preferences
    linux: Shared Linux Application Preferences
```

## Set default preferences values

You set default preferences values in a `prefs.yml` file that sits alongside `app.yml` in your `app` folder. You specify the default values by entering them as `name: value` pairs, one preference per line.

**IMPORTANT:** Do not use quote marks around your strings in `prefs.yml`.

```
my preference 1: my preference 1 default value
my preference 2: 100
my preference 3: true
```

## Set a preference to a value

While your application is running you can set an application preference to a value with the `appSetPref` command. If the preference does not already exist, it will be created and set to the value.

```
appSetPref "my preference name", "my preference value"
```

The full syntax is:

```
appSetPref <pKey>, <pValue>, <pUserOrShared>, <pType>
```

**Parameters**:

| Name | Description |
|:---- |:----------- |
| `pKey` |  Pass in name of preference to set. |
| `pValue` |  Pass in value to set preference to. This can be a string or an array. |
| `pUserOrShared` |  Pass in "shared" to set a pref in shared preferences. Leave empty for default behavior. |
| `pType` |  Pass in "binary" to force pref to be stored as binary (OS X). By default if value contains NULL then it will be stored as binary. |

## Get a preference value

While your application is running you can get a preference value with the `appGetPref` function.

```
put appGetPref("my preference name") into tPreferenceValue
```

The syntax is:

```
appGetPref(<pKey>)
```

**Returns:** Value of a preference.

**Parameters**:

| Name | Description |
|:---- |:----------- |
| `pKey` |  Pass in name of preference whose value you want to get. |
