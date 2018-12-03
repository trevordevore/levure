# file_system

The File System helper adds support for managing files and url protocols. It adds the following features:

* Allows you to define file extensions that your application supports.
* Allows you to organize file extensions into groups that can be used with the `answer file with type` command in LiveCode.
* Define url protocols that the operating system will ask your application to process.
* Manage a recently opened files list.
* Dispatches the `ProcessFiles` message to your `app` stack when the operating system asks your application to open a file with an extension that your application supports.
* Dispatches the `ProcessURL` message to your `app` stack when the operating system asks your application to process a URL protocol that your application supports.

## Contents

* [Activate the File System framework helper](#activate-the-file-system-framework-helper)
* [Configuration](#configuration)
  * [file extensions](#file-extensions)
  * [file extension groups](#file-extension-groups)
  * [url protocols](#url-protocols)
* [Processing requests to open files or urls](#processing-requests-to-open-files-or-urls)
* [Recent Files](#recent-files)
* [API](#api)

## Activate the File System framework helper

To add the File System helper to your application add it under the `helpers` section of the `app.yml` file:

```
# app.yml

helpers:
  - folder: ./helpers
  - filename: "[[FRAMEWORK]]/helpers/files_and_urls"
```

## Configuration

All configuration settings for the helper are stored in the `app.yml` file. There are three root level keys you can add:

* `file extensions`
* `file extension groups`
* `url protocols`

The syntax looks like this:

```
# app.yml

file extensions:
  [Type]: [Extensions (comma-delimited)]
file extension groups:
  [Group Name]:
    - name: [Category Name]
      extensions: [Extensions (comma-delimited)]
    ...
url protocols:
  [Protocol]: [Description]
```

### file extensions

The `file extensions` key contains a list of file extensions that your application supports. Each list entry consists of type and a comma delimited list of extensions associated with that type. An extension item can include a file type by adding the file type separated from the extension with the "|" character.

Example entry in `app.yml`:

```
file extensions:
  JPEG File: jpeg,jpg|JPEG
  PNG File: png
  BMP file: bmp
  GIF file: gif
```

Once you've defined your extensions you can use the `fileSystemFileExtensionsForTypes()` function to return all extensions with a given type.

Example:

```
put fileSystemFileExtensionsForTypes("jpeg file") into tExtensions
```

`tExtensions` now contain a CR delimited list of extensions:

```
jpeg
jpg|JPEG
```

You can also generate a type filter string for use with `ask file with type`.

```
put fileSystemFileDialogTypeFilterFromExtension("jpeg file") into tFilterStr
ask file "Select a JPEG file" with type tFilterStr
```

`tFilterStr` contains the following value:

```
JPEG file|jpeg,jpg|JPEG
```

### file extension groups

The `file extension groups` key contains groups which contain categories of file extensions. These groups can be used to create filters for the `answer file with type` command in LiveCode.

Example entry in `app.yml`:

```
file extension groups:
  Media Files:
    - name: All Files
      extensions: jpg,jpeg,png,bmp,gif,mp4,mp3
    - name: Image Files
      extensions: jpg,jpeg,png,bmp,gif
    - name: Audio Files
      extensions: mp4,mp3
```

Once you have defined your groups and categories it is simple to generate filter strings for use with `answer file with type`.

```
put fileSystemFileDialogTypeFilterFromGroup("Media Files") into tFilterStr
```

`tFilterStr` now contains the following value:

```
All Files|jpg,jpeg,png,bmp,gif,mp4,mp3|
Image Files|jpg,jpeg,png,bmp,gif|
Audio Files|mp4,mp3|
```

You can now use the string to filter files with `answer file with type`:

```
answer file "Select a media file" with type tFilterStr
```

You can also get a list of all extensions in a group or a group category:

```
put fileSystemFileExtensionGroupExtensions("Media Files") into tExtensions
```

`tExtensions` now contains the following value:

```
jpg
jpeg
png
bmp
gif
mp4
mp3
```

If you want extensions for a particular category use `fileSystemFileExtensionGroupExtensionsForCategory`:

```
put fileSystemFileExtensionGroupExtensionsForCategory("Medai Files", "Audio Files") into tExtensions
```

`tExtensions` now contains the following value:

```
mp4
mp3
```

### url protocols

The `url protocols` entry defines protocols that the operating system should pass off to your application for processing. For example, when the user clicks a link in a web browser that uses the `my-cool-app` protocol the url should be passed to your application so you can open the url.

Example entry in `app.yml` for processing a url such as `my-application://mydomain.com/open/12345`:

```
url protocols:
  my-application: "My Application Protocol"
```

Each time your application starts up on Windows the helper will call `fileSystemRegisterURLProtocol` to make sure that your application is registered to handle the protocol.

Note: On macOS and iOS you need to manually add your protocol to the `Info.plist` file.

```
<array>
  <dict>
    <key>CFBundleURLName</key>
    <string>My Application URL</string>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>my-application</string>
    </array>
  </dict>
</array>
```

## Processing requests to open files or urls

By configuring `file extensions` the File System helper can help you process requests to open supported files. The helper does two things:

1. Creates a list of supported files that were passed to the application on the command line.
2. Sends the `ProcessFiles` message to `app.livecodescript` whenever the operating system requests that your application open a supported file.

When an application is launched the command line parameters will be checked for files with supported extensions. A CR-delimited list of files is stored and will be accessible via the `fileSystemFilesToProcessOnOpen()` function. You can then check this function in the `OpenApplication` message. Here is an example:

```
# app.livecodescript

command OpenApplication
  if fileSystemFilesToProcessOnOpen() is not empty then
    ProcessMyFiles fileSystemFilesToProcessOnOpen() # YOU MUST WRITE A 'PROCESSMYFILES' ROUTINE
  end if
end OpenApplication
```

If the operating system notifies your application that a supported file should be opened (e.g. the user drops a file on your application) then the `ProcessFiles` message will be sent. Here is an example:

```
# app.livecodescript

command ProcessFiles pFiles
  ProcessMyFiles pFiles # YOU MUST WRITE A 'PROCESSMYFILES' ROUTINE
end ProcessFiles
```

A similiar function and message exist for URLs.

`fileSystemURLsToProcessOnOpen()` example:


```
# app.livecodescript

command OpenApplication
  if fileSystemURLsToProcessOnOpen() is not empty then
    ProcessMyURL fileSystemURLsToProcessOnOpen() # YOU MUST WRITE A 'PROCESSMYURL' ROUTINE
  end if
end OpenApplication
```

`ProcessURL` example:


```
# app.livecodescript

command ProcessURL pURL
  ProcessMyURL pURL # YOU MUST WRITE A 'PROCESSMYURL' ROUTINE
end ProcessURL
```

## Recent Files

The File System helper API provides handlers to help manage lists of recent files that your application has opened. There are handlers to add and remove files from a list as well as generate a string suitable for displaying a *File** > **Recent Files** menu.

**Important**: The recent files API handlers assume the presence of the Preferences helper.

Add a file to a list of recently opened files:

```
answer file "Select file to open:" with type fileSystemFileDialogTypeFilterFromGroup("Articles")
put it into tFilename
if tFilename is empty then exit to top

# fileSystemAddToRecentlyOpened pCategory, pFile, pTag, pSecurityBookmark
fileSystemAddToRecentlyOpened "articles", tFilename, empty, empty

put fileSystemRecentlyOpenedMenuText("articles") into tRecentFilesMenu
# Now add tRecentFilesMenu to your File menu...
```

To list the recently opened files without any formatting applied for displaying in a menu use `fileSystemRecentlyOpened()`. It takes a second parameter that if true will truncate the file paths to their shortest unique length.

```
# fileSystemRecentlyOpened pCategory, pShortVersion
put true into tShortVersion
put fileSystemRecentlyOpened("articles", tShortVersion) into tRecentFiles
```

To remove a file from a list call `fileSystemRemoveFromRecentlyOpened`.

```
fileSystemRemoveFromRecentlyOpened "articles", tFilename
```

You can specify the maximum number of files to be stored in a list using `fileSystemSetMaxRecentFiles`:

```
fileSystemSetMaxRecentFiles 15
```

If you are working in a sandboxed environment and need the security bookmark to open a file then use the `fileSystemSecurityBookmarkForRecentlyOpenedFile()` function:

```
# fileSystemSecurityBookmarkForRecentlyOpenedFile pCategory, pTag
put fileSystemSecurityBookmarkForRecentlyOpenedFile("articles", tFilename) into tSecurityBookmark

# Use tSecurityBookmark to generate a security scoped filename...
```

The helper does not currently provide an API for working with security scoped filenames. Consider using the [sandbox](https://github.com/trevordevore/levurehelper-sandbox) helper if you are working in a sandboxed enviroment on macOS.

<br>

## API

- [appleEvent](#appleEvent)
- [fileSystemAddToRecentlyOpened](#fileSystemAddToRecentlyOpened)
- [fileSystemFileDialogTypeFilterFromExtension](#fileSystemFileDialogTypeFilterFromExtension)
- [fileSystemFileDialogTypeFilterFromGroup](#fileSystemFileDialogTypeFilterFromGroup)
- [fileSystemFileExtensionGroupExtensions](#fileSystemFileExtensionGroupExtensions)
>
- [fileSystemFileExtensionGroupExtensionsForCategory](#fileSystemFileExtensionGroupExtensionsForCategory)
- [fileSystemFileExtensionsForTypes](#fileSystemFileExtensionsForTypes)
- [fileSystemFilesToProcessOnOpen](#fileSystemFilesToProcessOnOpen)
- [fileSystemRecentlyOpened](#fileSystemRecentlyOpened)
- [fileSystemRecentlyOpenedMenuText](#fileSystemRecentlyOpenedMenuText)
>
- [fileSystemRegisterURLProtocol](#fileSystemRegisterURLProtocol)
- [fileSystemRemoveFromRecentlyOpened](#fileSystemRemoveFromRecentlyOpened)
- [fileSystemSecurityBookmarkForRecentlyOpenedFile](#fileSystemSecurityBookmarkForRecentlyOpenedFile)
- [fileSystemSetMaxRecentFiles](#fileSystemSetMaxRecentFiles)
- [fileSystemURLsToProcessOnOpen](#fileSystemURLsToProcessOnOpen)
>
- [ProcessCommandLineParameters](#ProcessCommandLineParameters)
- [urlWakeUp](#urlWakeUp)

<br>

## <a name="appleEvent"></a>appleEvent

**Type**: command

**Syntax**: `appleEvent <pClass>,<pID>,<pSender>`

**Summary**: Processes files and urls that are sent to the application via appleEvents on macOS.

**Description**:

On macOS appleEvents are sent when an application should open a file or url. URLs and supported files
will be extracted from the message. If the application is running then `ProcessFiles` or `ProcessURL`
will be sent to the `app` stack. If the application is still loading then the files and urls will
be accessible using the `fileSystemFilesToProcessOnOpen()` and `fileSystemURLsToProcessOnOpen()` functions.


<br>

## <a name="fileSystemAddToRecentlyOpened"></a>fileSystemAddToRecentlyOpened

**Type**: command

**Syntax**: `fileSystemAddToRecentlyOpened <pCategory>,<pFile>,<pTag>,<pSecurityBookmark>`

**Summary**: Adds a file to the list of recently opened files for a specific category.

**Returns**: Error message

**Parameters**:

| Name | Description |
|:---- |:----------- |
| `pCategory` |  The category to add the file to. This is simply a string that helps you organize multiple lists of recent files. |
| `pFile` |  The full path to the file to add to the recent file list. |
| `pTag` |  This will be used as the tag in the menu that is generated by fileSystemRecentlyOpenedMenuText. If empty then pFile is used. A tag can be useful if you are opening something other than a file. For example, perhaps it is a database record and you want to store the record id. |
| `pSecurityBookmark` |  Pass in any security related bookmark data. Security bookmarks are required when opening a file in a sandboxed environment on macos. This will be stored with the entry as it may be needed to open the file. |

**Description**:

Calling this handler will save preferences.


<br>

## <a name="fileSystemFileDialogTypeFilterFromExtension"></a>fileSystemFileDialogTypeFilterFromExtension

**Type**: function

**Syntax**: `fileSystemFileDialogTypeFilterFromExtension(<pExtensionName>)`

**Summary**: Creates a file type filter string from an extension that is suitable for use with `ask file with type`.

**Returns**: filter type string

**Parameters**:

| Name | Description |
|:---- |:----------- |
| `pExtensionName` |  A file extension name that has been defined in the `file extensions` key of the `app.yml` file. |

**Description**:

`ask file with type` filters the available files that a user can select in the dialog using a specially
formatted string. This function will generate that string based on file extensions that you have defined
in your application using the `file extensions` key of the `app.yml` file. The string will look something similar to this:

```
JPEG file|jpg|JPEG
```

**Examples**:
```
# app.yml
file extensions:
  JPEG File: jpeg,jpg

#
put fileSystemFileDialogTypeFilterFromExtension("JPEG File") into theTypeFilter
ask files "Select JPEG Files" with theTypeFilter

```

<br>

## <a name="fileSystemFileDialogTypeFilterFromGroup"></a>fileSystemFileDialogTypeFilterFromGroup

**Type**: function

**Syntax**: `fileSystemFileDialogTypeFilterFromGroup(<pFileExtGroupName>)`

**Summary**: Creates a file type filter string from a file extension group that is suitable for use with `ask file with type`.

**Returns**: filter type string

**Parameters**:

| Name | Description |
|:---- |:----------- |
| `pFileExtGroupName` |  A file extension group name that has been defined in the `file extension groups` key of the `app.yml` file. |

**Description**:

`ask file with type` filters the available files that a user can select in the dialog using a specially
formatted string. This function will generate that string based on the file extensions that have
been defined in the `file extension groups` key of the `app.yml` file. The string will look something similar to this:

```
JPEG file|jpg|JPEG
PNG file|png|PNG
GIF file|gif|GIF
```

**Examples**:
```
# app.yml
file extension groups:
  Media Files:
    - name: All Files
```

<br>

## <a name="fileSystemFileExtensionGroupExtensions"></a>fileSystemFileExtensionGroupExtensions

**Type**: function

**Syntax**: `fileSystemFileExtensionGroupExtensions(<pFileExtGroupName>)`

**Summary**: Returns a list of file extensions for a File Type Filter Group.

**Returns**: CR-delimited list

**Parameters**:

| Name | Description |
|:---- |:----------- |
| `pFileExtGroupName` |  A file extension group name that has been defined in the `file extension groups` key of the `app.yml` file. |

**Examples**:
```
put fileSystemFileExtensionGroupExtensions("Select Image", "Image Files") into theExtensions
jpeg
jpg
png
bmp
gif

```

<br>

## <a name="fileSystemFileExtensionGroupExtensionsForCategory"></a>fileSystemFileExtensionGroupExtensionsForCategory

**Type**: function

**Syntax**: `fileSystemFileExtensionGroupExtensionsForCategory(<pFileExtGroupName>,<pCategoryName>)`

**Summary**: Returns a list of extensions for a specific category within a file extension group.

**Returns**: A CR-delimited list of file extensions

**Parameters**:

| Name | Description |
|:---- |:----------- |
| `pFileExtGroupName` |  A file extension group name that has been defined in the `file extension groups` key of the `app.yml` file. |
| `pCategoryName` |  A category of file extensions within pFileExtGroupName. |

**Examples**:
```
# app.yml
file extension groups:
  Media Files:
    - name: All Files
```

<br>

## <a name="fileSystemFileExtensionsForTypes"></a>fileSystemFileExtensionsForTypes

**Type**: function

**Syntax**: `fileSystemFileExtensionsForTypes(<pTypes>)`

**Summary**: Returns a CR delimited list of extensions associated with a given type.

**Returns**: CR-delimited list of extensions

**Description**:

Assume the following configuration in the `app.yml` file:

```
file extensions:
  JPEG File: jpeg,jpg
  PNG File: png
  BMP file: bmp
  GIF file: gif
```

You can get a list of JPEG extensions using the following code:

```
put fileSystemFileExtensionsForTypes("jpeg file") into tExtensions
```

`tExtensions` now contains the following value:

```
jpeg
jpg
```


<br>

## <a name="fileSystemFilesToProcessOnOpen"></a>fileSystemFilesToProcessOnOpen

**Type**: function

**Syntax**: `fileSystemFilesToProcessOnOpen()`

**Summary**: Returns a list of files that the operating system passed to your application at launch.

**Returns**: CR-delimited list

**Description**:

The helper will look at files passed to the application at launch and create a list of files
that are supported. A file is supported if the file extension is listed in the `file extensions` key
in the `app.yml` file.


<br>

## <a name="fileSystemRecentlyOpened"></a>fileSystemRecentlyOpened

**Type**: function

**Syntax**: `fileSystemRecentlyOpened(<pCategory>,<pShortVersion>)`

**Summary**: Returns a list of recently opened files for a particular category.

**Returns**: CR-delimited list

**Parameters**:

| Name | Description |
|:---- |:----------- |
| `pCategory` |  The category to retrieve the list of recently opened files for. |
| `pShortVersion` |  Pass in true if you would like the file paths truncated to their shortest unique length. Default is full file path. |

<br>

## <a name="fileSystemRecentlyOpenedMenuText"></a>fileSystemRecentlyOpenedMenuText

**Type**: function

**Syntax**: `fileSystemRecentlyOpenedMenuText(<pCategory>)`

**Summary**: Returns a list of recently opened files for a particular category which has been encoded for display in a menu.

**Returns**: CR-delimited list

**Parameters**:

| Name | Description |
|:---- |:----------- |
| `pCategory` |  The category to retrieve the list of recently opened files for. |

**Description**:

Each line of the returned list will be prefixed with a tab and will have special characters escaped
for display in a menu.


<br>

## <a name="fileSystemRegisterURLProtocol"></a>fileSystemRegisterURLProtocol

**Type**: command

**Syntax**: `fileSystemRegisterURLProtocol <pProtocol>,<pDescription>`

**Summary**: Registers the application to process a particular URL handler on Windows.

pProtocol The protocol to register (i.e. x-myapplication).
pDescription Description of the protocol.

**Returns**: Error

**Description**:

Calling this handler on platforms other than Windows does nothing.

<br>

## <a name="fileSystemRemoveFromRecentlyOpened"></a>fileSystemRemoveFromRecentlyOpened

**Type**: command

**Syntax**: `fileSystemRemoveFromRecentlyOpened <pCategory>,<pFile>`

**Summary**: Removes a file from the list of recently opened files for a specific category.

**Returns**: Error message

**Parameters**:

| Name | Description |
|:---- |:----------- |
| `pCategory` |  The category to remove the file from. This is simply a string that helps you organize multiple lists of recent files. |
| `pFile` |  The full path to the file to remove from the recent file list. |

**Description**:

Calling this handler will save preferences.


<br>

## <a name="fileSystemSecurityBookmarkForRecentlyOpenedFile"></a>fileSystemSecurityBookmarkForRecentlyOpenedFile

**Type**: function

**Syntax**: `fileSystemSecurityBookmarkForRecentlyOpenedFile(<pCategory>,<pTag>)`

**Summary**: Returns the security scoped bookmark data for a file.

**Returns**: bookmark data

**Parameters**:

| Name | Description |
|:---- |:----------- |
| `pCategory` |  The category to retrieve the list of recently opened files for. |
| `pTag` |  The tag assigned to the recently opened file. Unless you explicitly set a tag this will be the filename. |

<br>

## <a name="fileSystemSetMaxRecentFiles"></a>fileSystemSetMaxRecentFiles

**Type**: command

**Syntax**: `fileSystemSetMaxRecentFiles <pMax>`

**Summary**: Sets the maximum number of files that will be stored in the recent files list.

**Returns**: empty

**Parameters**:

| Name | Description |
|:---- |:----------- |
| `pMax` |  The maximum number of files to store in the list. |

**Description**:

Once the threshold is met the last file in the list will be removed when another file is added.


<br>

## <a name="fileSystemURLsToProcessOnOpen"></a>fileSystemURLsToProcessOnOpen

**Type**: function

**Syntax**: `fileSystemURLsToProcessOnOpen()`

**Summary**: Returns a list of URLs that the operating system passed to your application at launch.

**Returns**: CR-delimited list

<br>

## <a name="ProcessCommandLineParameters"></a>ProcessCommandLineParameters

**Type**: command

**Syntax**: `ProcessCommandLineParameters <pParams>`

**Summary**: Process parameters passed to the application on the command line.

**Returns**: empty

**Description**:

The `ProcessCommandLineParameters` message is sent from the framework when an application is loading up.
This handler processes URLs and files passed in on the command line. If '-url' appears in the params then the next param is considered
a URL that needs to be processed. Otherwise all params are treated as files and any files with supported
extensions are extracted and made available to the application for processing.

If the application is running then `ProcessFiles` or `ProcessURL`
will be sent to the `app` stack. If the application is still loading then the files and urls will
be accessible using the `fileSystemFilesToProcessOnOpen()` and `fileSystemURLsToProcessOnOpen()` functions.


<br>

## <a name="urlWakeUp"></a>urlWakeUp

**Type**: command

**Syntax**: `urlWakeUp <pUrl>`

**Summary**: Process the file/url so that levure handlers can be used for processing the request.

**Parameters**:

| Name | Description |
|:---- |:----------- |
| `pUrl` |  If this is a file then it starts with file:// |

**Description**:

If a url caused the OS to open the app then this is called before levure app finishes loading.
It can be handled like other events triggered by file/url open requests.




