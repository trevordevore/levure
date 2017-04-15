# translate Helper

The **translate** helper manages loading and retrieving strings in your user interface. Translations are stored as YAML files in a `./locales` folder. Each locale file should contain the same keys which you access using the `_t` function in your application. Using the `_t` function allows you to change the target locale in order to change the language of the stirngs that appear in your user interface.

## Configuration

Locale files are YAML files stored in a `locales` folder that sits alongsde the `app.yml` file. You add a separate locale file for each language you want to support. A locale value contains key:value pairs.


### Example:
```
# ./locales/en.yml
greeting: Hi there!

# ./locales/fr.yml
greeting: Salut!

```
```
# Display "Hi there!" to the user
translateSetLocale "en"
answer _t("greeting")

# Display "Salut!" to the user
translateSetLocale "fr"
answer _t("greeting")
```
