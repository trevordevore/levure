levure
=====================

# Levure Application Framework

Levure is an application development framework for LiveCode. The primary goals of Levure are the following:

1. Lightweight. The framework has a minimal amount of code for loading, managing, and packaging your application. Common functionality is added via helper components.
2. Provide common features such as preferences, logging, and undo management.
3. Easily extensible. **Helpers** provide a framework for developers to add features which can easily be added to any application.
4. Easy to organize. Levure applications are organized using the file system. Easily browse your app structure and add files.
5. Designed for use with version control systems. Wherever possible configuration and scripts are text files. While developers can take advantage of the efficiency of binary stack files for the UI, almost all of the scripts should be stored in script only stack files and assigned as behaviors.

# Screencasts

You will find screencasts about Levure on [Trevor DeVore's YouTube channel](https://www.youtube.com/channel/UCluXVDvheCjGSJmCMssc0fw).

# Learn How To Use Levure

Visit the [Levure Wiki](https://github.com/trevordevore/levure/wiki/) to get started.

# How To Help

Want to help this project? There are a number of ways to contribute.

- Review the [wiki](https://github.com/trevordevore/levure/wiki/) and submit improvements.
- Need to decide how errors should be reported when loading helpers. Should a developer throw an error or use some other mechanism? Ideally the application should report the error to the end user and then quit. We don't want the application hanging around if an error occurs on loading.
- Create a helper component for the MAS (security-scoped bookmarks and licensing). (2018-05-28: Trevor DeVore is working on an FFI module for this.)
  - secscopGetBookmarkFromURL(pUTF8Filename) to generate bookmark data for a filename
  - secscopInitializeURLFromBookmarkData(pBookmarkData) to generate security scoped filenames using bookmark data
  - secscopStopUsingURL(pSecurityScopedFilename) to release a security scoped filename.
- Help with an auto update helper component (2018-07-18: Trevor DeVore is working on FFI modules for both of these.)
  - Needs module wrapped around WinSparkle: https://winsparkle.org
  - Needs module wrapped around latest Sparkle: https://sparkle-project.org
