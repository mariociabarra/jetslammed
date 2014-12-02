CC=/Applications/XCode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang
CXX=/Applications/XCode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang++
CFLAGS_NOARCH=-miphoneos-version-min=7.0  -fobjc-arc  -Wno-unknown-pragmas -Wno-deprecated-declarations  -fPIC -O2 -std=gnu99 -isysroot /Developer/iPhoneOS7.0.sdk -Iheaders -I/Developer/iPhoneOS7.0.sdk/usr/include/libxml2 -I. -I../ISXLicensing
CPPFLAGS_NOARCH=-miphoneos-version-min=7.0  -fobjc-arc   -Werror -Wno-unknown-pragmas -Wno-deprecated-declarations -fPIC -O2 -isysroot /Developer/iPhoneOS7.0.sdk -Iheaders -I/Developer/iPhoneOS7.0.sdk/usr/include/libxml2
CFLAGS=-arch armv7 -arch arm64 $(CFLAGS_NOARCH)
CPPFLAGS=-arch armv7 -arch arm64 $(CPPFLAGS_NOARCH)
CFLAGS32=-arch armv7 $(CFLAGS_NOARCH)
CPPFLAGS32=-arch armv7 $(CPPFLAGS_NOARCH)
CFLAGS64=-arch arm64 $(CFLAGS_NOARCH)
CPPFLAGS64=-arch arm64 $(CPPFLAGS_NOARCH)
LDFLAGS=-arch armv7 -arch arm64 -miphoneos-version-min=7.0 -O2 -isysroot /Developer/iPhoneOS7.0.sdk -F/Developer/iPhoneOS7.0.sdk/System/Library/Frameworks -F/Developer/iPhoneOS7.0.sdk/System/Library/PrivateFrameworks -L.

HOST := $(shell cat ~/.targethost)

VERSION ?= 1.0

all: deploy

##############################################################################################

JETSLAMMED_SRCS_C=jetslammed.m
JETSLAMMED_OBJS=$(JETSLAMMED_SRCS_C:.m=.o)
JETSLAMMED_DEPENDS=$(JETSLAMMED_SRCS_C:.m=.d)
JETSLAMMED_FRAMEWORKS=-framework Foundation

JETSLAMMED_DAEMON_SRCS_C=jetslammed_daemon.m
JETSLAMMED_DAEMON_OBJS=$(JETSLAMMED_DAEMON_SRCS_C:.m=.o)
JETSLAMMED_DAEMON_DEPENDS=$(JETSLAMMED_DAEMON_SRCS_C:.m=.d)
JETSLAMMED_DAEMON_FRAMEWORKS=-framework Foundation

.PHONY: clean deploy

deploy: jetslammed_$(VERSION)_iphoneos-arm.deb
	scp jetslammed_$(VERSION)_iphoneos-arm.deb root@$(HOST):/tmp/jetslammed_$(VERSION)_iphoneos-arm.deb
	ssh root@$(HOST) "dpkg -i /tmp/jetslammed_$(VERSION)_iphoneos-arm.deb;"

jetslammed_$(VERSION)_iphoneos-arm.deb: packaging/control.sh libjetslammed.dylib jetslammed_daemon
		$(eval TEMPDIR := $(shell mktemp -d -t jetslammed.deb))
		mkdir -p $(TEMPDIR)/DEBIAN
		mkdir -p $(TEMPDIR)/usr/lib/
		mkdir -p $(TEMPDIR)/usr/include/
		mkdir -p $(TEMPDIR)/usr/libexec/
		mkdir -p $(TEMPDIR)/Library/LaunchDaemons/
		cp libjetslammed.dylib $(TEMPDIR)/usr/lib/
		cp jetslammed.h $(TEMPDIR)/usr/include/
		cp jetslammed_daemon $(TEMPDIR)/usr/libexec/
		cp jetslammed.plist $(TEMPDIR)/Library/LaunchDaemons/
		packaging/control.sh $(VERSION) > $(TEMPDIR)/DEBIAN/control
		cp packaging/prerm $(TEMPDIR)/DEBIAN/
		cp packaging/postinst $(TEMPDIR)/DEBIAN/
		sudo chown -R 0:0 $(TEMPDIR)
		COPYFILE_DISABLE=1 COPY_EXTENDED_ATTRIBUTES_DISABLE=1 sudo -E dpkg-deb -Zlzma -b $(TEMPDIR) $@
		sudo rm -rf $(TEMPDIR)

libjetslammed.dylib:	$(JETSLAMMED_OBJS)
		$(CC) -dynamiclib $(LDFLAGS) $(JETSLAMMED_FRAMEWORKS) $(JETSLAMMED_OBJS)   -o $@

jetslammed_daemon:	$(JETSLAMMED_DAEMON_OBJS)
		$(CC) $(LDFLAGS) $(JETSLAMMED_DAEMON_FRAMEWORKS) $(JETSLAMMED_DAEMON_OBJS)   -o $@
		scp $@ root@$(HOST):/usr/libexec/

clean:
	rm -f *.o
	rm -f $(JETSLAMMED_OBJS)
	rm -f $(JETSLAMMED_DEPENDS)
	rm -f libjetslammed.dylib
	rm -f jetslammed_daemon
	rm -f jetslammed_*_iphoneos-arm.deb

%.d:	%.m
	$(CC) -M -MG $(CFLAGS32) $< > $@


# vim: set ts=8 sts=8 sw=8 noet:
