# window_manager

The `Window Manager` helper provides the following features to your application:

- Maintains the size and coordinates of stack windows across sessions.
- Ensures that stack windows appear on screen and at an appropriate size when opened, even if the monitor setup has changed across sessions.
- Resizes the menu menubar group of a stack window when the stack is resized.
- Adds new messages that are sent to a stack window when it opens, when card controls needs to be resized, or when the user has finished dragging the stack window around on the screen.

## Contents

* [Activate the window_manager framework helper](#activate-the-window_manager-framework-helper)
* [Using the Window Manager helper](#using-the-window-manager-helper)

## Activate the window_manager framework helper

To add the Window Manager helper to your application add it under the `helpers` section of the `app.yml` file:

```
# app.yml

helpers:
  - folder: ./helpers
  - filename: "[[FRAMEWORK]]/helpers/window_manager"
```

## Using the Window Manager helper

The Window Manager library uses properties assigned to a stack to determine
whether or not the library is managed by the library. The properties are stored
in the uWindowManager custom property set. To set these properties use the `windowSetProperty` command:

```
windowSetProperty pStackName, pProperty, pValue
```

Example:

```
# Manage all properties on the "Document Window" stack
windowSetProperty "Document Window", "managed properties", "all"
```

| Property | Value |
| ----- | ----- |
| `managed properties` | A comma delimited list. Possible list item values are `messages`, `rect`, `menu`, or `all` |
| `default width` | integer or percent (e.g. 80%). Percentage is relative to total available screen width. |
| `default height` | integer or percent (e.g. 80%). Percentage is relative to total available screen height. |
| `default loc` | point (e.g. 100,50) |
| `center window on screen` | true/false |

The `managed properties` property affects how the Window Manager library treats a stack. Following is
a description of what each property does if present in the `managed properties` list.

### all

Tells the Window Manager library to manage all properties discussed below.

### messages

The library will dispach additional messages to a stack. `PreOpenWindow`/`OpenWindow`
mimic `preOpenStack`/`openStack`. The messages are sent after the window and menu group have been resized, however.
A parameter specifying whether or not the stack has been opened during the current sessions is also sent.
`PreOpenView`/`OpenView` mimic `preOpenCard`/`openCard` except that a parameter specifying whether
or not the stack has been opened during the current sessions is also sent.

If the Window Manager helper is managing messages for your stack window then you should write handlers to process the helepr messages and not the engine messages. **IMPORTANT!** - Your application MUST pass the openCard message so that it reaches the libraries layer of the message path. Otherwise the helper
cannot track whether or not cards or stacks have been opened in the current session. The helper also uses a frontscript to monitor `closeStack`, `preOpenStack`, `preOpenCard`, `openStack`, `openCard`, `resizeStack`, and `moveStack`. If your application scripts interfere with the frontscript receiving these messages then it will break the helper.

`PreOpenWindow`: Sent to the current card right before the stack opens. The first parameter passed to the handler
will be true if the stack has been opened at least once in the current session, false if it has not.

`OpenWindow`: Sent to the current card when the stack opens. The first parameter passed to the handler
will be true if the stack has been opened at least once in the current session, false if it has not.

`PreOpenView`: Sent to a card right before it opens. The first parameter passed to the handler
will be true if the card has been opened at least once in the current session, false if it has not.

`OpenView`: Sent to a card when it opens. The first parameter passed to the handler
will be true if the card has been opened at least once in the current session, false if it has not.

`ResizeView`: Sent to the current card when the card controls should be resized. This will be sent more often than `resizeStack`.
In addition to being sent when the user resizes the stack, the message is sent each time a different card is opened in a stack.
The first parameter is the width of the card, the second parameter is the height of the card.

`moveStackEnd`: Sent when the user has finished dragging a stack around the screen. This can be useful if you
your app stores a default window position and you want to update that information after a window is moved.

Example:
```
on moveStackEnd
  prefsSetPref "default window dimensions", the width of me & "," & the height of me
  prefsSetPref "default window screen", the screen of me
end moveStackEnd
```

### rect

The Window Manager will manage the window rect if this property is present in the `managed properties` list.
The rect is managed as described below. Note that you must use the Preferences helper if the `rect` is managed.

- When the stack is opened `windowPositionWithinConstraints` is called.
- When the stack is closed `windowSaveWindowPosition` is called.
- When the desktop size is changed `windowPositionWithinConstraints` is called.

### menu

The library manages the menu of a stack in the following ways:

- The stack's default menu will be resized by `windowResizeMenu` as needed.
- The backgroundcolor of the stack will be set to the background color of the stack when the stack opens.
- The `editmenus` property of the stack will be set to true when the stack is opened in the IDE.

<br>

## API

- [windowWasVisibleInPreOpenStack](#windowWasVisibleInPreOpenStack)
- [openCard](#openCard)
- [windowCalculateRectForWindow](#windowCalculateRectForWindow)
- [windowCheckWindowAfterDesktopChanged](#windowCheckWindowAfterDesktopChanged)
- [windowCheckWindowAfterMove](#windowCheckWindowAfterMove)
>
- [windowClearWindowCache](#windowClearWindowCache)
- [windowGetProperty](#windowGetProperty)
- [windowGoStack](#windowGoStack)
- [windowHasCardBeenOpened](#windowHasCardBeenOpened)
- [windowHasWindowBeenOpened](#windowHasWindowBeenOpened)
>
- [windowIsManaged](#windowIsManaged)
- [windowIsPropertyManaged](#windowIsPropertyManaged)
- [windowResizeMenu](#windowResizeMenu)
- [windowResolveTargetStack](#windowResolveTargetStack)
- [windowSaveWindowPosition](#windowSaveWindowPosition)
>
- [windowSetCardInitializedState](#windowSetCardInitializedState)
- [windowSetInitializedState](#windowSetInitializedState)
- [windowSetProperty](#windowSetProperty)
- [windowSetWindowRectBeforeOpening](#windowSetWindowRectBeforeOpening)
- [windowTopMostWindowOfMode](#windowTopMostWindowOfMode)
>
- [windowTopMostWindowWithModeOfCeiling](#windowTopMostWindowWithModeOfCeiling)

<br>

## <a name="windowWasVisibleInPreOpenStack"></a>windowWasVisibleInPreOpenStack

**Type**: function

**Syntax**: `windowWasVisibleInPreOpenStack(<pStackName>)`

**Summary**: Used by the `openCard` handler in the windowManager library to check if a window should be shown in `openCard`.

**Returns**: Boolean



<br>

## <a name="openCard"></a>openCard

**Type**: command

**Syntax**: `openCard `

**Summary**: Marks the current card as initialized.

**Description**:

Your application MUST pass the openCard message so that it reaches this library. Otherwise the library
cannot track whether or not cards or stacks have been opened in the current session.


<br>

## <a name="windowCalculateRectForWindow"></a>windowCalculateRectForWindow

**Type**: function

**Syntax**: `windowCalculateRectForWindow(<pStackName>,<pScreenRect>,<pRect>,<pLoc>)`

**Summary**: Calculates the rect that should be used to open a stack window.

**Returns**: rectangle

**Parameters**:

| Name | Description |
|:---- |:----------- |
| `pStackName` |  Name of the target stack
[pScreenRect]: Optional screen rect to use to contrain the stack window.
[pRect]: Optional rect for the stack window.
[pLoc]: Optional loc. |

**Description**:

The rect returned can be used to set `the effective rect` of the stack. The rect will
size the stack window such that it is entirely visible on the screen it is displayed on.


<br>

## <a name="windowCheckWindowAfterDesktopChanged"></a>windowCheckWindowAfterDesktopChanged

**Type**: command

**Syntax**: `windowCheckWindowAfterDesktopChanged <pStackName>`

**Summary**: Positions a window after the desktop has changed.

**Returns**: empty

**Parameters**:

| Name | Description |
|:---- |:----------- |
| `pStackName` |  The name of the target stack. |

**Description**:

After the desktop changes two things must be checked:
1. That the stack size isn't too lage for the monitor the stack is opening on.
2. That the entire stack will appear on the monitor.


<br>

## <a name="windowCheckWindowAfterMove"></a>windowCheckWindowAfterMove

**Type**: command

**Syntax**: `windowCheckWindowAfterMove <pStackName>`

**Summary**: Positions a window after the user moves it.

**Returns**: empty

**Parameters**:

| Name | Description |
|:---- |:----------- |
| `pStackName` |  The name of the target stack. |

**Description**:

After the user moves a stack window two things need to be checked:
1. That the stack size isn't too lage for the monitor the stack is now on.
2. That the top and bottom of the title bar are in an actionable area of the screen.


<br>

## <a name="windowClearWindowCache"></a>windowClearWindowCache

**Type**: command

**Syntax**: `windowClearWindowCache <pStackName>`

**Summary**: Clears the internal librar cache for a stack.

**Returns**: empty

**Parameters**:

| Name | Description |
|:---- |:----------- |
| `pStackName` |  The name of the target stack. The default is `this stack`. |

**Description**:

This handler should be called when closing a managed stack that has `destroyStack` set to true.


<br>

## <a name="windowGetProperty"></a>windowGetProperty

**Type**: function

**Syntax**: `windowGetProperty(<pStackName>,<pProperty>)`

**Summary**: Returns a window manager property for a stack.

**Returns**: mixed

**Parameters**:

| Name | Description |
|:---- |:----------- |
| `pProperty` |  The property to get. |
| `pStackName` |  The name of the stack the property is attached to. If empty then the owner of the target is assumed. |

**Description**:

The Window Manager library uses properties assigned to a stack to determine
whether or not the library is managed by the library. The properties are stored
in the uWindowManager custom property set. This handler accesses that property set.


<br>

## <a name="windowGoStack"></a>windowGoStack

**Type**: command

**Syntax**: `windowGoStack <pStackName>,<pMode>`

**Summary**: Opens a stack window and loads the card that was open the last time the stack window was closed.

**Returns**: empty

**Parameters**:

| Name | Description |
|:---- |:----------- |
| `pStackName` |  The name of the target stack. The default is `this stack`. |
| `pMode` |  The mode to open window in.  Default is "toplevel". |

**Description**:

If the stack window has not been opened before then it goes to card 1. Stack window must be in
memory.


<br>

## <a name="windowHasCardBeenOpened"></a>windowHasCardBeenOpened

**Type**: function

**Syntax**: `windowHasCardBeenOpened(<pStackName>,<pCard>)`

**Summary**: Returns whether or not a card has been opened at least once during the current session.

**Returns**: empty

**Parameters**:

| Name | Description |
|:---- |:----------- |
| `pStackName` |  The name of the target stack. The default is `this stack`. |
| `pCard` |  The name of the target card. The default is `this card`. |

**Description**:

If you want to know if a card has been opened in your own code you should use the `windowHasCardBeenOpened` handler.


<br>

## <a name="windowHasWindowBeenOpened"></a>windowHasWindowBeenOpened

**Type**: function

**Syntax**: `windowHasWindowBeenOpened(<pStackName>)`

**Summary**: Returns true if the window has been initialized, false otherwise.

**Returns**: true/false

**Parameters**:

| Name | Description |
|:---- |:----------- |
| `pStackName` |  The name of the target stack. The default is `this stack`. |

<br>

## <a name="windowIsManaged"></a>windowIsManaged

**Type**: function

**Syntax**: `windowIsManaged(<pStackName>)`

**Summary**: Summary Returns true if a window is being managed by this library.

**Returns**: true/false

**Parameters**:

| Name | Description |
|:---- |:----------- |
| `pStackName` |  The name of the target stack. The default is `this stack`. |

**Description**:

A stack is considered to be manaaged by this library if the
`uWindowManager["managed properties"]` custom property is not empty.


<br>

## <a name="windowIsPropertyManaged"></a>windowIsPropertyManaged

**Type**: function

**Syntax**: `windowIsPropertyManaged(<pWindow>,<pProperty>)`

**Summary**: Summary Returns true if a specific property of the window is being managed by this library.

**Returns**: true/false

**Description**:

A property is considered to be manaaged by this library if the
`uWindowManager["managed properties"]` custom property is `all` or contains the property.


<br>

## <a name="windowResizeMenu"></a>windowResizeMenu

**Type**: command

**Syntax**: `windowResizeMenu <pStackName>`

**Summary**: Resizes a stack's menu to fill the width of the stack.

**Parameters**:

| Name | Description |
|:---- |:----------- |
| `pStackName` |  The name of the target stack. |

**Description**:

A stack's menu is the group name assigned to the `menubar` property of the stack.


<br>

## <a name="windowResolveTargetStack"></a>windowResolveTargetStack

**Type**: function

**Syntax**: `windowResolveTargetStack()`

**Summary**: Determines the stack of the current event's target.

**Returns**: stack name

<br>

## <a name="windowSaveWindowPosition"></a>windowSaveWindowPosition

**Type**: command

**Syntax**: `windowSaveWindowPosition <pStackName>`

**Summary**: Saves the coordinates of the stack in preferences.

**Parameters**:

| Name | Description |
|:---- |:----------- |
| `pStackName` |  The name of the target stack. |

**Description**:

This handler requires the Preferences helper.


<br>

## <a name="windowSetCardInitializedState"></a>windowSetCardInitializedState

**Type**: command

**Syntax**: `windowSetCardInitializedState <pStackName>,<pCard>,<pIsInit>`

**Summary**: Sets the initialized state of a card.

**Returns**: true/false

**Parameters**:

| Name | Description |
|:---- |:----------- |
| `pStackName` |  The name of the target stack. The default is `this stack`. |
| `pCard` |  The name of the target card. The default is `this card`. |
| `pIsInit` |  true/false |

<br>

## <a name="windowSetInitializedState"></a>windowSetInitializedState

**Type**: command

**Syntax**: `windowSetInitializedState <pStackName>,<pIsInit>`

**Summary**: Sets the initialized state of a window.

**Returns**: empty

**Parameters**:

| Name | Description |
|:---- |:----------- |
| `pStackName` |  The name of the target stack. The default is `this stack`. |
| `pIsInit` |  true/false |

<br>

## <a name="windowSetProperty"></a>windowSetProperty

**Type**: command

**Syntax**: `windowSetProperty <pStackName>,<pProperty>,<pValue>`

**Summary**: Use this command to set Window Manager library properties on a stack.

**Returns**: empty

**Parameters**:

| Name | Description |
|:---- |:----------- |
| `pProperty` |  The property to set. |
| `pValue` |  The value to set the property to. |
| `pStackName` |  The name of the stack the property is attached to. If empty then the owner of the target is assumed. |

<br>

## <a name="windowSetWindowRectBeforeOpening"></a>windowSetWindowRectBeforeOpening

**Type**: command

**Syntax**: `windowSetWindowRectBeforeOpening <pStackName>,<pRestoreFromPrefs>,<pScreenNo>`

**Summary**: Called during preOpenStack to position a window before it is displayed.

**Returns**: empty

**Parameters**:

| Name | Description |
|:---- |:----------- |
| `pStackName` |  The name of the target stack. |
| `pRestoreFromPrefs` |  Boolean value specifying whether or not the handler will look for previous stack window rect in prefs.
[pScreenNo]: The screen number to display the stack on. Default is 1. This will be ignored if pRestoreFromPrefs is true. |

**Description**:

After determining the rect to use the handler then alters the rect as needed in order to ensure the following:

1. That the stack size isn't too lage for the monitor the stack is opening on.
2. That the entire stack will appear on the monitor.


<br>

## <a name="windowTopMostWindowOfMode"></a>windowTopMostWindowOfMode

**Type**: function

**Syntax**: `windowTopMostWindowOfMode(<pMode>)`

**Summary**: Returns the name of the frontmost stack with a mode of pMode.

**Returns**: Stack name or empty

**Parameters**:

| Name | Description |
|:---- |:----------- |
| `pMode` |  An integer representing the mode the stack must have. See the `mode` propery for stacks in the dictionary for more information. |

**Description**:

The stack must have the same mode as pMode and be visible.


<br>

## <a name="windowTopMostWindowWithModeOfCeiling"></a>windowTopMostWindowWithModeOfCeiling

**Type**: function

**Syntax**: `windowTopMostWindowWithModeOfCeiling(<pMode>)`

**Summary**: Returns the name of the frontmost stack of with mode of pMode or lower.

**Returns**: Stack name or empty

**Parameters**:

| Name | Description |
|:---- |:----------- |
| `pMode` |  The maximum mode the returned stack can have. |

**Description**:

The stack must have a mode no higher than pMode and be visible.




