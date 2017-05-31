# broadcaster

The `Broadcaster` helper adds messaging APIs to your application. Objects within an aplication can register to be notified when certain events within the application occur. When an event of a certain kind is broadcast then all listeners are notified. There are two reasons you might want to use the Broadcaster helepr in your application:

- So the broadcaster doesn't need to know in advance who the listeners are.
- So multiple objects can respond to a message that is being broadcast.

## Contents

* [Activate the broadcaster framework helper](#activate-the-broadcaster-framework-helper)
* [Using the Broadcaster API](#using-the-broadcaster-api)

## Activate the broadcaster framework helper

To add the Broadcaster helper to your application add it under the `helpers` section of the `app.yml` file:

```
# app.yml

helpers:
  - folder: ./helpers
  - filename: "[[FRAMEWORK]]/helpers/broadcaster"
```

## Using the Broadcaster API

The Broadcaster API provides a means whereby intersted controls (e.g. stacks, cards, buttons, etc.) can be notified when a specific event occurs. The event that generates a broadcast is not interested in who is listening. It simply broadcasts a message. Controls that have registered for a specific event will be sent a message when the event occurs.

To illustrate how this helper can be used consider preferences in an application. An application typically has a preferences window where settings can be modified. Each time a preference that affects your appliction's user interface your code must make that update. The code that allows the user to change a preference should not have to know about all of the controls that might change, however. This is where broadcasting comes in. The `Preferences` helper uses the broadcaster APIs which means you can register to be notified whenever "prefs" are updated.

Assuming your app is using the Broadcaster helper, each time `prefsSetPref` is called the following broadcaster API call is made:

```
# pKey is the preference key that was modified.
broadcasterBroadcast "prefs", pKey, pKey
```

With that in mind your application can ask to be notified whenever a specific preference key is updated.

Example:

```
# Register to be notified when this card when the default text size preference is changed
on openCard
  broadcasterListenForBroadcast "prefs", "default text size", the long id of me, "UpdateUIWithDefaultTextSize"
end openCard

# When card closes it is no longer interested in being notified
on closeCard
  broadcasterStopListeningForBroadcasts "prefs", "default text size", the long id of me
end closeCard

# Update UI when default text size changes
command UpdateUIWithDefaultTextSize pPreferenceKey
  # The broadcaster passes in the name of the preference that was updated
  # as the first parameter.
  put prefsGetPref(pPreferenceKey) into tNewValue

  # Use tNewValue ot update the UI
  ...
end UpdateUIWithDefaultTextSize
```

<br>

## API

- [broadcasterBroadcast](#broadcasterBroadcast)
- [broadcasterBroadcastInTime](#broadcasterBroadcastInTime)
- [broadcasterListeners](#broadcasterListeners)
- [broadcasterListenForBroadcasts](#broadcasterListenForBroadcasts)
- [broadcasterStopListeningForBroadcasts](#broadcasterStopListeningForBroadcasts)


<br>

## <a name="broadcasterBroadcast"></a>broadcasterBroadcast

**Type**: command

**Syntax**: `broadcasterBroadcast <pCategory>,<pBroadcasts>,<pParamsPackageA>`

**Summary**: Broadcasts a message to any objects that are listening.

**Returns**: empty

**Parameters**:

| Name | Description |
|:---- |:----------- |
| `pCategory` |  The category that pBroadcasts belong to. |
| `pBroadcasts` |  A comma delimited list of the broadcasts to trigger. Every object listening for these broadcasts will be sent a message. |
| `pParamsPackageA` |  An array that will be sent along with the broadcast. You can include any data relevant to the broadcast in this array. |

**Description**:

Typically `pBroadcasts` will only contain one broadcast to send, especially if you are using `pParamsPackageA`.

**Example**:
```
# Notify listeners that a document was updated by someone.
put 1 into tParamsA["document id"]
put "Jane Doe" into tParamsA["updated by"]
broadcasterBroadcast "app", "document updated", tParamsA

```

<br>

## <a name="broadcasterBroadcastInTime"></a>broadcasterBroadcastInTime

**Type**: command

**Syntax**: `broadcasterBroadcastInTime <pCategory>,<pBroadcasts>,<pParamsPackageA>,<pMillisecs>`

**Summary**: Sends a broadcast message using `send in time`.

**Parameters**:

| Name | Description |
|:---- |:----------- |
| `pCategory` |  The category that pBroadcasts belong to. |
| `pBroadcasts` |  A comma delimited list of the broadcasts to trigger. Every object listening for these broadcasts will be sent a message. |
| `pParamsPackageA` |  An array that will be sent along with the broadcast. You can include any data relevant to the broadcast in this array. |
| `pMillisecs` |  The amount of time in milliseconds to wait before broadcasting. Default value is 0. |

**Description**:

Use this form to broadcast a message outside of the current event loop.

**Example**:
```
# Notify listeners after the window has closed
on closeStack
  ...

  put 1 into tParamsA["document id"]
  broadcasterBroadcastInTime "app", "document window closed", tParamsA, 10

  ...
end closeStack

```

<br>

## <a name="broadcasterListeners"></a>broadcasterListeners

**Type**: function

**Syntax**: `broadcasterListeners(<pCategory>,<pBroadcast>)`

**Summary**: Returns an array of the objects that are listening for broadcasts for a particular category.

**Returns**: A nested array. Dimension 1 is numerically indexed starting with 1. Dimension 2 has `broadcast` and `controls` keys.

**Parameters**:

| Name | Description |
|:---- |:----------- |
| `pCategory` |  Return listeners listening for broadcasts in this category. |
| `pBroadcast` |  Optional. If a non-empty value is passed in then only listeners for this specific broadcast will be returned. |

**Description**:

`pCategory` is the category you are interested in. Here is some sample code which shows how to see which controls are
listening for broadcasts from the Preferences helper:

```
put broadcasterListeners("prefs") into tListenersA
repeat with i = 1 to the number of elements of tListenersA
  put "Broadcast:" && tListenersA[i]["broadcast"] & cr after tText
  put "Controls that are listening:" & cr after tText
  repeat for each line tControl in tListenersA[i]["controls"]
    put "  " & tControl & cr after tText
  end repeat
  put cr after tText
end repeat

put tText
```


<br>

## <a name="broadcasterListenForBroadcasts"></a>broadcasterListenForBroadcasts

**Type**: command

**Syntax**: `broadcasterListenForBroadcasts <pCategory>,<pBroadcasts>,<pBroadcastTarget>,<pMessage>`

**Summary**: Registers a control to receive a notification for broadcasts associated with a specific category.

**Returns**: Error message

**Parameters**:

| Name | Description |
|:---- |:----------- |
| `pCategory` |  The category that pBroadcasts belong to. |
| `pBroadcasts` |  A comma delimited list of broadcasts from pCategory that pBroadcastTarget is interested in. |
| `pBroadcastTarget` |  A reference to the object that will be sent pMessage. |
| `pMessage` |  The message that will be sent to pBroadcastTarget. If left empty then the default message for the broadcast type will be sent. |

**Description**:

Broadcasts are separated into different catgories. For example, the Preferences helper uses the `prefs` category when
broadcasting messages. Broadcasts generated from your app might use the `app` category. Categories are simply a means of organizing broadcasts
based on who is generating the broadcast.

**Example**:
```
# When used with the `Preferences` helper an object can be notified when a preference is changed.
broadcasterListenForBroadcast "prefs", "default text size", the long id of me, "UpdateDefaultTextSize"

# Be notified when media files have finished downloading.
broadcasterListenForBroadcast "app", "media files downloaded", the long id of me, "MediaFilesDownloadsComplete"

```

<br>

## <a name="broadcasterStopListeningForBroadcasts"></a>broadcasterStopListeningForBroadcasts

**Type**: command

**Syntax**: `broadcasterStopListeningForBroadcasts <pCategory>,<pBroadcasts>,<pBroadcastTarget>`

**Summary**: Unregisters an object that is listening for broadcasts.

**Returns**: Error message

**Parameters**:

| Name | Description |
|:---- |:----------- |
| `pCategory` |  The category that pBroadcasts belong to. |
| `pBroadcasts` |  A comma delimited list of broadcasts the listener is no longer interested in. |
| `pBroadcastTarget` |  A reference to the object that is listening for broadcasts. |



