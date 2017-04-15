# files_and_urls Helper

The **files_and_urls** helper manages loading, unloading, and packaging of custom fonts that your application uses. Fonts will be loaded and available for use when your application launches. When you package your application the fonts will be included.

## File Extensions
used to determine supported files

- appFileExtensionsForTypes
- appFileDialogTypeFilterFromExtension

## File Extension Group
used to create file type filters

- appFileDialogTypeFilterFromGroup
- appFileExtensionGroupExtensions

## File Extension Group Category
categories of extensions within a file extension group

- appFileExtensionGroupExtensionsForCategory

## Recently opened files
Requires preferences helper

- appSetMaxRecentFiles
- appAddToRecentlyOpened
- appRemoveFromRecentlyOpened
- appRecentlyOpened
- appRecentlyOpenedMenuText
- appSecurityBookmarkForRecentlyOpenedFile

## URL Protocols

- appRegisterURLProtocol

## Configuration

You configure filesand urls in the `app.yml` file by adding `file extensions`, `file extension groups`, and `url protocols` keys.


### Example:
```
file extensions:
  JPEG File: jpeg,jpg
  PNG File: png
  BMP file: bmp
  GIF file: gif

file extension groups:
  Media Files:
    1:
      name: All Files
      extensions: jpg,jpeg,png,bmp,gif,svg,ai
    2:
      name: Vector Files
      extensions: svg,ai
    3:
      name: Bitmap Files
      extensions: jpg,jpeg,png,bmp,gif

url protocols:
  x-mycoolapp-app: My Cool App Protocol
  mycoolapp: My Cool App Protocol
```
