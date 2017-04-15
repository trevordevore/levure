# font_loader Helper

The **font_loader** helper manages loading, unloading, and packaging of custom fonts that your application uses. Fonts will be loaded and available for use when your application launches. When you package your application the fonts will be included.

## Configuration

You configure fonts in the `app.yml` file by adding a `font` key. The `font` key is a list with at `filename` key and an optional `global` key. `global` is true/false (false by default). If `true` then the font will be made available to all applications on the computer.


### Example:
```
fonts:
  1:
    filename: resources/password.ttf
  2:
    filename: resources/MySpecialFont.ttf
    global: true
```
