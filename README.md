levure
=====================

# Levure Application Framework

Levure is an application development framework for LiveCode. The primary goals of Levure are the following:

1. Lightweight. The framework has a minimal amount of code for loading, managing, and packaging your application. Common functionality is added via helper components.
2. Provide common features such as preferences, logging, and undo management.
3. Easily extensible. **Helpers** provide a framework for developers to add features which can easily be added to any application. Some helpers are [included with Levure](https://github.com/trevordevore/levure/wiki/framework-helpers) while others are [available from 3rd parties](https://github.com/trevordevore/levure/wiki/3rd-party-helpers).
4. Easy to organize. Levure applications are organized using the file system. Easily browse your app structure and add files.
5. Designed for use with version control systems. Wherever possible configuration and scripts are text files. While developers can take advantage of the efficiency of binary stack files for the UI, almost all of the scripts should be stored in script only stack files and assigned as behaviors.

# Screencasts

You will find screencasts about Levure on [Trevor DeVore's YouTube channel](https://www.youtube.com/channel/UCluXVDvheCjGSJmCMssc0fw).

# Learn How To Use Levure

Visit the [Levure Wiki](https://github.com/trevordevore/levure/wiki/) to get started.

# How To Help

Want to help this project? There are a number of ways to contribute.

- Review the [wiki](https://github.com/trevordevore/levure/wiki/) and submit improvements.
- Create Helpers and make them available to the community. You can add them to the [3rd party helpers page](https://github.com/trevordevore/levure/wiki/3rd-party-helpers).
- Need to decide how errors should be reported when loading helpers. Should a developer throw an error or use some other mechanism? Ideally the application should report the error to the end user and then quit. We don't want the application hanging around if an error occurs on loading.
