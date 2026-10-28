# App icon

The Raspberry Pi Stats app icon: a house with a mint pulse inside an 80% teal-to-violet ring on the dark ground.

`icon.svg` is the source. `build.py` renders it to a 1024×1024 RGB PNG with no alpha. The asset catalog uses that one universal size, and Xcode makes the rest.

The ring gradient was approved for the icon only. Inside the app, the Aurora glow family is still the only gradient.
