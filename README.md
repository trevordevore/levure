# levure 
Application development framework for LiveCode

## Design

Application stack files are organized using folders. Every strack that is a window goes in 
the `windows` folder. Each stack has a folder for the binary stack and a subfolder named 
behaviors for any behaviors assigned to the stack.

- app.livecode
- windows/
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
  - libdragreorder.LiveCode
  
## Loading

When the application is loaded files are loaded in the following order:

- All stack files in the `libraries` folder.
- All behavior stacks in the `windows` folder.
- All `window` stacks.

## Packaging

- Create a stack for behaviors
  - Make all behavior stacks substacks of that stack.

## Plugins

Todo: How are plugins installed?

- preference
- window manager
- supported files handler
- logging
- MAS (security-scoped filenames and licensing)