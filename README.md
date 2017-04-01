levure
=====================

# Levure Application Framework

Levure is an application development framework for LiveCode. The primary goals of Levure are the following:

1. Lightweight. The framework has a minimal amount of code for loading, managing, and packaging your application. Common functionality is added via libraries and helper components.
2. Designed for use with version control systems. Wherever possible configuration and scripts are text files. While developers can take advantage of the efficiency of binary stack files for the UI, almost all of the scripts should be stored in script only stack files and assigned as behaviors.

# Screencasts

- [Thoughts on using script only stacks and levure framework](https://www.youtube.com/watch?v=e1p_FTRi1-Q)
- [Creating Script Only Behaviors with LiveCode 9](https://www.youtube.com/watch?v=eyggLzIbeSU)

# Learn How To Use Levure

Visit the [Levure Wiki](https://github.com/trevordevore/levure/wiki/) to get started.

# How To Help

Want to help this project? There are a number of ways to contribute.

- Review the [wiki](https://github.com/trevordevore/levure/wiki/) and submit improvements.
- Wrap YAML C++ library in module. YAML support is very limited right now. Ideally we would use `-` instead of `1:, 2:, 3:, etc.` keys.
- Create module for iOS prefs that uses NSUserDefaults.
- Move preferences external for OS X into a module.
- Create a helper component for the MAS (security-scoped bookmarks and licensing).
  - secscopGetBookmarkFromURL(pUTF8Filename) to generate bookmark data for a filename
  - secscopInitializeURLFromBookmarkData(pBookmarkData) to generate security scoped filenames using bookmark data
  - secscopStopUsingURL(pSecurityScopedFilename) to release a security scoped filename.
- Help with an auto update helper component
  - Needs module wrapped around WinSparkle: https://winsparkle.org
  - Needs module wrapped around latest Sparkle: https://sparkle-project.org

# Known Issues

- If you use scripts for all behaviors then you have to manually construct behaviors with behaviors when a stack opens. A script only stack can't have a behavior property assigned to it. This is not an issue for behaviors loaded through the `behaviors` key in `app.yml` as the `LoadBehavior` message is dispatched to each stack and it can set its own behavior. For behaviors that are part of your `ui` components you need to make sure that you assign the parent behavior somewhere else (e.g. in a `preopenstack` message or in the `InitializeApplicaiton` message).
