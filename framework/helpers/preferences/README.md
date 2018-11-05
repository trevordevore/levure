# preferences

Levure provides your LiveCode application with a preferences management system.

On macOS an extension (>= LC 9) or an external (< LC 9) is used so you can set preferences using the macOS NSUserDefaults API. On iOS an extension is used to access NSUserDefaults. On Windows, Linux, and Android preferences are stored in a file containing data serialized using arrayEncode.

## Contents

* [Activate the preferences framework helper](#activate-the-preferences-framework-helper)
* [Set the preferences file name](#set-the-preferences-file-name)
* [Set default preferences values](#set-default-preferences-values)
* [Set a preference to a value](#set-a-preference-to-a-value)
* [Get a preference value](#get-a-preference-value)
* [Saving preferences](#saving-preferences)
* [API](#api)

## Activate the preferences framework helper

The `levure/framework/helpers/preferences` helper provides an API for managing your application preferences. By default this helper is activated for you in `app.yml`:

```
# app.yml

helpers:
  - folder: ./helpers
  - filename: "[[FRAMEWORK]]/helpers/preferences"
```

## Set the preferences file name

You set the preferences file name for the platforms your application supports in `app.yml`. You can provide an optional default file name for all platforms and then override it for specific platforms. A file name can be specified for *user* which is for the the current user using the application, or for *shared* which is shared among all users on the computer. Note the *shared* is only available on macOS, windows, and linux. It is not supported on mobile devices.

The "user" preferences file is stored in the folder returned by `levureApplicationDataFolder("user")` on all platforms except macOS, where it is stored in `~/Library/Preferences`, so you should specify only the name of the preferences file without any other path information.

The "shared" preferences file is stored in the folder returned by `levureApplicationDataFolder("shared")` on all supported platforms.

Do not use quote marks around your `preferences filename` value in `app.yml`.

```
# app.yml

preferences filename:
  user:
    default:
    macos:
    windows:
    linux:
    ios:
    android:
  shared:
    default:
    macos:
    windows:
    linux:
```

### Examples

You can set an optional default preferences filename for all platforms and then override it for specific platforms. So this:

```
preferences filename:
  user:
    default: My Application.prefs
    macos: com.mycompany.myapplication
    windows:
    linux:
    ios: com.mycompany.myapplication
    android:
```

Will cause your application to create and use these user preferences file names:

| Platform | Preferences File Name |
| ---- | ----------- |
| macOS |  com.mycompany.myapplication |
| Windows |  My Application.prefs |
| Linux |  My Application.prefs |
| iOS |  com.mycompany.myapplication |
| Android |  My Application.prefs |

Note that in this example the `default:` preferences file name is used for all platforms except for macOS and iOS where it is overridden with the `macos:` and `ios:` file names.

## Set default preferences values

You can set default preferences values in a `prefs.yml` file that sits alongside `app.yml` in your `app` folder. You specify the default values by entering them as `name: value` pairs, one preference per line.

Do not use quote marks around your default preferences values in `prefs.yml`.

```
# prefs.yml

my preference 1: my preference 1 default value
my preference 2: 100
my preference 3: true
```

## Set a preference to a value

While your application is running you can set an application preference to a value with the `prefsSetPref` command. If the preference does not already exist, it will be created and set to the value.

```
# prefsSetPref examples
prefsSetPref "my preference 1", "a string value"
prefsSetPref "my preference 2", 80
prefsSetPref "my preference 3", false
```

## Get a preference value

While your application is running you can get a preference value with the `prefsGetPref` function.

```
# prefsGetPref example
put prefsGetPref("my preference name") into tPreferenceValue
```

## Saving preferences

Levure will automatically call `prefsSave` when your application is running as a standalone and shuts down. `prefsSave "user"` and `prefsSave "shared"` is called in the `levureShutdownApplication` command in the `levure.livecodescript` script. You can save preferences at any other point by calling `prefsSave user|shared`.

<br>

## API

- [prefsGetDefaults](#prefsGetDefaults)
- [prefsGetPref](#prefsGetPref)
- [prefsGetPreferenceFile](#prefsGetPreferenceFile)
- [prefsIsCategoryConfigured](#prefsIsCategoryConfigured)
- [prefsIsPrefSet](#prefsIsPrefSet)
>
- [prefsReload](#prefsReload)
- [prefsReset](#prefsReset)
- [prefsSave](#prefsSave)
- [prefsSetPref](#prefsSetPref)

<br>

## <a name="prefsGetDefaults"></a>prefsGetDefaults

**Type**: function

**Syntax**: `prefsGetDefaults(<pUserOrShared>)`

**Summary**: Returns the entire array of default preferences.

**Returns**: Array representing YAML configuration store in `prefs.yml` and `prefs_shared.yml`

**Parameters**:

| Name | Description |
|:---- |:----------- |
| `pUserOrShared` |  Preferences category. "user" or "shared". Default is "user". |

<br>

## <a name="prefsGetPref"></a>prefsGetPref

**Type**: function

**Syntax**: `prefsGetPref(<pKey>,<pUserOrShared>)`

**Summary**: Gets an application preference.

**Returns**: value

**Parameters**:

| Name | Description |
|:---- |:----------- |
| `pKey` |  Name of preference to get. |
| `pUserOrShared` |  Preferences category. "user" or "shared". Default is "user". |

<br>

## <a name="prefsGetPreferenceFile"></a>prefsGetPreferenceFile

**Type**: function

**Syntax**: `prefsGetPreferenceFile(<pUserOrShared>)`

**Summary**: Returns the file where preferences are stored.

**Returns**: Filename or empty

**Parameters**:

| Name | Description |
|:---- |:----------- |
| `pUserOrShared` |  Preferences category. "user" or "shared". Default is "user". |

**Description**:

Returns the filename of the preference file.


<br>

## <a name="prefsIsCategoryConfigured"></a>prefsIsCategoryConfigured

**Type**: function

**Syntax**: `prefsIsCategoryConfigured(<pUserOrShared>)`

**Summary**: Use this to check if preferences have been configured for "user" or "shared".

**Returns**: Boolean

<br>

## <a name="prefsIsPrefSet"></a>prefsIsPrefSet

**Type**: function

**Syntax**: `prefsIsPrefSet(<pKey>,<pUserOrShared>)`

**Summary**: Checks if a preference has been set on the computer the application is running on.

**Returns**: true/false

**Parameters**:

| Name | Description |
|:---- |:----------- |
| `pKey` |  Name of preference to check. |
| `pUserOrShared` |  Preferences category. "user" or "shared". Default is "user". |

<br>

## <a name="prefsReload"></a>prefsReload

**Type**: command

**Syntax**: `prefsReload <pUserOrShared>`

**Summary**: Reloads preferences from the file on disk.

**Returns**: Empty

**Parameters**:

| Name | Description |
|:---- |:----------- |
| `pUserOrShared` |  Preferences category. "user" or "shared". Default is "user". |

**Description**:

This handler will clear out any values that are stored internally and reloads
preferences from the file on disk.

Note that this command does nothing on macOS or iOS which handle preferences using the NSUserDefaults
APIs.


<br>

## <a name="prefsReset"></a>prefsReset

**Type**: command

**Syntax**: `prefsReset <pUserOrShared>`

**Summary**: Resets all values in in preferences to empty.

**Returns**: Empty

**Parameters**:

| Name | Description |
|:---- |:----------- |
| `pUserOrShared` |  Preferences category. "user" or "shared". Default is "user". |

**Description**:

Use this handler if you would like to reset all preferences to their default values as defined
in `prefs.yml` and `prefs_shared.yml`.

Note that on macOS this command currently does not work.


<br>

## <a name="prefsSave"></a>prefsSave

**Type**: command

**Syntax**: `prefsSave <pUserOrShared>`

**Summary**: Saves preferences to disk.

**Returns**: Error message

**Parameters**:

| Name | Description |
|:---- |:----------- |
| `pUserOrShared` |  Preferences category. "user" or "shared". Default is "user". |

**Description**:

When setting preferences the preference is updated in memory. To permanently
store changes on disk use this command.


<br>

## <a name="prefsSetPref"></a>prefsSetPref

**Type**: command

**Syntax**: `prefsSetPref <pKey>,<pValue>,<pUserOrShared>,<pType>`

**Summary**: Sets an application preference.

**Returns**: error message

**Parameters**:

| Name | Description |
|:---- |:----------- |
| `pKey` |  Name of preference to set. |
| `pValue` |  Value to set preference to. This can be a string or an array. |
| `pUserOrShared` |  Preferences category. "user" or "shared". Default is "user". |
| `pType` |  Pass in "binary" to force pref to be stored as binary (macOS and iOS). By default if value contains NULL then it will be stored as binary. |



