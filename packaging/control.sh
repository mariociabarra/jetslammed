#!/bin/bash
cat << END_CONTROL_FILE
Package: jetslammed
Name: Jetslammed
Version: $1
Architecture: iphoneos-arm
Section: Utilities
Depends: firmware (>= 7)
Author: Mario Ciabarra <https://github.com/mariociabarra/jetslammed>
Maintainer: Mario Ciabarra <https://github.com/mariociabarra/jetslammed>
Sponsor: ModMyi.com <http://modmyi.com/forums/index.php?styleid=31>
Depiction: http://modmyi.com/info/jetslammer.d.php
Description: Library for modifying jetsam memory limits per process
END_CONTROL_FILE
