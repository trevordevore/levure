# font_loader

The Font Loader helper manages loading, unloading, and packaging custom fonts that your application uses. Fonts are added to the application in the `app.yml` file.

## Contents

* [Activate the font_loader framework helper](#activate-the-font_loader-framework-helper)
* [Adding a font to your application](#adding-a-font-to-your-application)

## Activate the font_loader framework helper

To add the Font Loader helper to your application add it under the `helpers` section of the `app.yml` file:

```
# app.yml

helpers:
  - folder: ./helpers
  - filename: "[[FRAMEWORK]]/helpers/font_loader"
```

## Adding a font to your application

You configure fonts by adding a `fonts` key to the `app.yml` file. The following example loads the PasswordEntry.ttf font when your application is launched. The `global` property is optional and defaults to `false` which means the font will only be available to your application. If true then the font will be available to all applications on the computer.

```
# app.yml

fonts:
  - filename: assets/PasswordEntry.ttf
    global: false
```

When you package your application the font file will be copied into the application folder.
