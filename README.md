# levure 
Application development framework for LiveCode

## File and Folder Organization

Application stack files are organized using folders. Any UI stacks go in the`components` folder. Each stack has a folder for the binary stack and a subfolder named behaviors for any behaviors assigned to the stack. The behavior stacks should be assigned to the `stackfiles` property of the UI stack so that they are loaded into memory as needed.

- app.yml
- application.livecode
- standalone.livecode
- levure.livecode
- components/
  - preferences/
    - preferences.livecode
    - behaviors/
      - card.livecode
      - stack.livecode
  - document window/
    - document.livecode
    - behaviors/
      - card.livecode
      - stack.livecode
      - tools.livecode
- libraries/
  - libcontrols.livecode
  - libdatahelpers.livecode
- backscripts/
  - mybackscript.livecode
- frontscripts/
  - myfrontscripts.livecode
- helpers/
  - miscellaneous/
    - config.yml
    - ui.livecode
    - frontscript.livecode
    - backscript.livecode
    - library.livecode
  - logging/
    - config.yml
    - library.livecode
  - preferences/
    - config.yml
    - library.livecode
    - preference.bundle
  - my external
    - config.yml
    - macos.bundle
    - windows.dll
    - linux.so
  
## app.yml

An application is configured using the `app.yml` file. 

```
password: ?????

copy files:
  all:
    ...
  macos:
    ...
  win:
    ...
  linux:
    ...
```

## standalone.livecode

This stack is used to build the standalone for the supported platforms. Its only function is to load the levure.livecode stack and dispatch the `RunApplication` message to it.

## application.livecode

This stack has `InitializeApplication` and `OpenApplication` handlers. Framework calls these handlers after it finishes loading. Developer uses these handlers to initialize and open the application once.
  
## Loading

The framework logic is located in the levure.livecode file. When the `RunApplication` message is dispatched to the stack the following occurs:

1. if an sAppA script local exists then use values from that. The presence of the variable means the app has been packaged. Otherwise load the app.yml file that sits alongside the stack file. If app.yml is not found then app cannot be loaded.
2. Load application.livecode
3. Load helpers (Load externals, libraries, backscripts, and frontscripts. Add ui stacks to list of stackFiles to be assigned later)
4. Load app libraries and start using.
5. Load app backscripts and insert.
6. Load app frontscripts and insert.
8. Add list of stacks in `components` folder to stackFiles list.
9. Assign stackFiles list to stackFiles property of `application` stack.
10. Dispatch `InitializeApplication` to `application` stack.
11. Dispatch `OpenApplication` to `application` stack.

## Packaging

- Create a stack for behaviors
  - Make all behavior stacks substacks of that stack.

## Helpers (plugins)

Helpers provide additional common functionality to an application. A helper consists of a folder, a config.yml file, and any supporting files. A helper can be made up of the following;

- library stacks
- backscripts
- frontscripts
- ui stacks
- externals

### Helper Examples:

- preference
- window manager
- supported files handler
- logging
- MAS (security-scoped filenames and licensing)
- auto update