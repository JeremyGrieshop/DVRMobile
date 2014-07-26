#!/bin/sh

gcc -save-temps -g -o test test.c -I/var/include -I/var/include/gcc/darwin/4.0 -I/var/include/libxml2 -I/var/root/Source/DVRMobile -fsigned-char -ObjC -fobjc-exceptions -Wall -Wundeclared-selector -Wreturn-type -Wnested-externs -Wredundant-decls -Wbad-function-cast -Wchar-subscripts -Winline -Wswitch -Wshadow  -D_CTYPE_H_ -D_UNISTD_H_ -D_BSD_ARM_SETJMP_H -lobjc -bind_at_load -w -F/System/Library/Frameworks -F/System/Library/PrivateFrameworks  -framework CoreFoundation -framework Foundation  -framework UIKit -framework QuartzCore -framework CoreGraphics -framework PhotoLibrary  -framework MusicLibrary -framework AudioToolbox -framework MediaPlayer /usr/lib/libxml2.dylib Beacon.o Cache.o DVRMobilePrefs.o Music.o Photos.o TiVoHTTPServer.o TiVoHTTPClient.o HttpClient.o Video.o /usr/lib/libssl.dylib /usr/lib/libcrypto.dylib


ldid -S test
