CC=/usr/bin/gcc

CFLAGS= -fsigned-char -g -ObjC -fobjc-exceptions \
  -Wall -Wundeclared-selector -Wreturn-type -Wnested-externs \
  -Wredundant-decls \
  -Wbad-function-cast \
  -Wchar-subscripts \
  -Winline -Wswitch -Wshadow \
  -I/var/include \
  -I/var/include/gcc/darwin/4.0 \
  -I/var/include/libxml2 \
  -D_CTYPE_H_ \
  -D_UNISTD_H_ \
  -D_BSD_ARM_SETJMP_H

LD=$(CC)

LDFLAGS=-lobjc -bind_at_load -w \
    -F/System/Library/Frameworks \
    -F/System/Library/PrivateFrameworks \
    -framework CoreFoundation \
    -framework Foundation \
    -framework UIKit \
    -framework IOKit \
    -framework CoreGraphics \
    -framework AudioToolbox \
    -framework PhotoLibrary \
    -framework MusicLibrary \
    -framework MediaPlayer \
    -lssl -lcrypto -lxml2


#    -L/usr/lib -lc /usr/lib/libgcc_s.1.dylib \
#    -multiply_defined suppress

all:   DVRMobilePro

DVRMobilePro:  DVRMobile.o Beacon.o TiVoHTTPServer.o Photos.o Music.o Cache.o \
               ShareViewController.o SettingsViewController.o ScanViewController.o \
               AboutViewController.o HelpViewController.o TivoDetailsViewController.o \
               DVRMobilePrefs.o TransfersViewController.o HttpClient.o TiVoHTTPClient.o \
               TivoNowPlayingViewController.o CustomSpinningGearView.o \
               VideoDetailsController.o ImageDetailsController.o Video.o AsyncImageView.o
	$(LD) $(LDFLAGS) -o $@ $^
	nm DVRMobilePro | sort > DVRMobilePro.syms

%.o:    %.m
		$(CC) -c $(CFLAGS) $< -o $@

clean:
		rm -f *.o DVRMobilePro

install:
		rm /Applications/DVRMobilePro.app/DVRMobilePro
		cp DVRMobilePro /Applications/DVRMobilePro.app/
		ldid -S /Applications/DVRMobilePro.app/DVRMobilePro
