jetslammed
==========

Library to modify process (like SpringBoard) jetsam memory limits for iOS and manage/allow multiple tweaks requesting different memory limits.

jetslammed will set the memory limit to the highest requested limit.

 * From within the target process (ie, SpringBoard), use:
 *      jetslammed_updateWaterMark(350, "mytweakname");
 *
 * Default watermark levels are in /System/Library/LaunchDaemons/com.apple.jetsamproperties.<device id>.plist
 *  ie, com.apple.SpringBoard on iOS 8 for iPhone6 is JetsamMemoryLimit=240

Add the following depends to your control file (and link to the libjetslammed.dylib and use the included jetslammed.h):

Depends: jetslammed



