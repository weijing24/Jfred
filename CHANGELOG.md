# Changelog

## 1.1.5

### Preferences

On macOS 26 and later the Preferences search field is a single capsule in the trailing toolbar. The extra rounded frame that sat around the field is gone. Placement is unchanged: the field does not overlap the window controls or the sidebar. Earlier systems are unchanged.

## 1.1.4

### Preferences

On macOS 26 and later the Preferences window again uses the regular sidebar-and-detail layout, so every sidebar item and the selected pane are visible. The search field stays a trailing toolbar item and no longer overlaps the window controls or the sidebar. The sidebar material still reaches the top and bottom of the window, with even padding on the first and last items. Earlier systems are unchanged.

## 1.1.2

### Preferences

The Preferences search field sits in the detail toolbar on macOS 26 and later, trailing, so it no longer overlaps the window controls or the sidebar. The sidebar material now extends through the window's bottom corners, and the last item uses the same even inset as the first. Earlier systems are unchanged.

## 1.1.1

### Preferences

On macOS 26 and later the Preferences sidebar extends under the transparent titlebar to the top and bottom of the window, so selecting General or Update no longer leaves a hairline gap against the window chrome. Item padding and the selection highlight are evenly inset. Earlier systems are unchanged.

## 1.1.0

### Appearance

The launcher and Preferences are redrawn for the current macOS design language. On macOS 26 and later the launcher uses the system glass material, larger window corners, a refined search field, and softer result-row highlights. Earlier systems keep the previous material or flat look.

A new System theme follows light and dark appearance and is the default for new setups. Glassy Light, Glassy Dark, Flat Light, and Flat Dark sit alongside the existing built-in themes. A theme already saved in your settings is left as it is.

Preferences use a unified toolbar, a translucent sidebar, and consistent system symbols. The workflow editor now uses the same light chrome as the rest of Preferences. Large Type and the clipboard preview pane follow the same corner and material language. Behaviour is unchanged: the launcher hotkey, theme editor, and workflow canvas keep working as before.

## 1.0.0

### Jfred 1.0

Jfred 1.0 is the first formal release of the menu-bar launcher: one shortcut for search, clipboard history, snippets, file search, and the workflows you import. Your data stays on this Mac. There is no account, and update checks do not send usage data.

### Launcher and search

Type a few characters and Jfred searches apps, files, web keywords, system commands, and the other sources you have enabled. Results follow how you actually use the app, so frequent items rise sooner. An empty query can show recent apps and clipboard items first. Return opens the current row; modifier keys run other actions.

### Clipboard history

The history viewer lists what you copied and previews the selected item on the right. Images appear on a white board with their size; files show an icon and path; text stays as it was. Click only selects and updates the preview. Double-click or Return copies, and can paste automatically if you turn that on. Scrolling the list never copies by accident. Password managers are kept out of the history by default.

### Snippets

Give frequently used text a keyword and let it expand as you type, or search snippets from the clipboard viewer. Snippets can be grouped, and expansion can restore the clipboard or play a sound. Auto expansion needs Accessibility permission.

### File search

Search files and folders with a keyword, or type a path to browse a directory. You can limit the search scope, file types, and result count. Return opens a file or enters a folder. Quick Look is available when you need a preview, and a selected file can be sent to Universal Actions.

### Workflows

Build a chain of keywords, scripts, filters, and actions, or import a compatible workflow package. Import from the Workflows pane with the import button, the menu, or by dropping a file; the package is copied into Jfred's own library and does not change your other data. Script-filter results and keyword-entry rows use the workflow's own artwork — including PNG, ICNS, and PDF icons — instead of generic placeholders. The canvas lets you edit objects, connections, and a debug run.

### Appearance and hotkeys

Built-in launcher themes can be duplicated and edited: width, corners, type size, and colors update in a live preview. Themes can be imported or exported as appearance files. The launcher hotkey, the Universal Actions hotkey, and per-workflow hotkeys are recorded in Preferences. If a combination is already taken, the page says so. Jfred can also start at login and stays out of the Dock until you open Preferences.

### Universal actions

Act on the current result, or on text and files selected in other apps: open, reveal in Finder, copy the path, Quick Look, Large Type, and more. The action list can be chosen with a hotkey and ordered by recent use.

### Updates

The Updates pane checks public GitHub releases, verifies the official disk image for your architecture, and replaces this copy of Jfred in place. Move the app to the Applications folder first. Pre-releases are included only when you ask for them.

### Also in 1.0

- Calculator and unit conversion
- Dictionary and spelling
- Custom web searches, bookmarks, and browser history
- System commands (sleep, quit apps, eject disks, and more), each of which can be turned off
- Send a command to your terminal app
- Contacts search
- Music playback and a mini player
- 1Password bookmarks
- Quick Look and result previews
- Large Type
- Local usage statistics that you can clear at any time

Jfred 1.0 is a native macOS app for Apple Silicon, and requires macOS 14 or later.
