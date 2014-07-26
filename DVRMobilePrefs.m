
#import "Beacon.h"
#import "DVRMobilePrefs.h"

#include <syslog.h>

@implementation DVRMobilePrefs
{

}

/* constants */
CFStringRef appId = CFSTR("com.mobilemixture.DVRMobilePro");

-(void) SavePreferences
{
  if (!dirty)
    return;

  NSMutableArray *tivosArray = [[NSMutableArray alloc] initWithCapacity:10];
  TivoDevice *nextTivo;

  int i;
  for (i = 0; i < [tivos count]; i++) {
    nextTivo = [tivos objectAtIndex:i];
    NSMutableArray *tivoArray = [[NSMutableArray alloc] initWithCapacity:10];

    if (nextTivo->address)
      [tivoArray addObject: nextTivo->address];
    else
      [tivoArray addObject: @""];

    if (nextTivo->swversion)
      [tivoArray addObject: nextTivo->swversion];
    else
      [tivoArray addObject: @""];

    if (nextTivo->identity)
      [tivoArray addObject: nextTivo->identity];
    else
      [tivoArray addObject: @""];

    if (nextTivo->machine_name)
      [tivoArray addObject: nextTivo->machine_name];
    else
      [tivoArray addObject: @""];

    if (nextTivo->platform)
      [tivoArray addObject: nextTivo->platform];
    else
      [tivoArray addObject: @""];

    if (nextTivo->services)
      [tivoArray addObject: nextTivo->services];
    else
      [tivoArray addObject: @""];
 
    if (nextTivo->mak)
      [tivoArray addObject: nextTivo->mak];
    else
      [tivoArray addObject: @""];

    syslog(LOG_DEBUG, "saving tivo %s", [nextTivo->machine_name UTF8String]);
    [tivosArray addObject: tivoArray];
  }

  if ([tivos count] > 0) {
    CFPreferencesSetAppValue(CFSTR("TivoDevices"), tivosArray, appId);
  }

  syslog(LOG_DEBUG, "Saving non-tivo preferences");

  CFPreferencesSetAppValue(CFSTR("Name"), Name, appId);
  CFPreferencesSetAppValue(CFSTR("Network.Broadcast"), NetworkBroadcast, appId);
  CFPreferencesSetAppValue(CFSTR("Network.Port"), NetworkPort, appId);
  CFPreferencesSetAppValue(CFSTR("Photos.Container"), PhotosContainer, appId);
  CFPreferencesSetAppValue(CFSTR("Photos.JPEGQuality"), PhotosJPEGQuality, appId);
  CFPreferencesSetAppValue(CFSTR("Music.Container"), MusicContainer, appId);
  CFPreferencesSetAppValue(CFSTR("Video.Container"), VideoContainer, appId);

  if (autoStart)
    CFPreferencesSetAppValue(CFSTR("AutoStart"), CFSTR("true"), appId);
  else
    CFPreferencesSetAppValue(CFSTR("AutoStart"), CFSTR("false"), appId);

  CFPreferencesAppSynchronize(appId);
}

-(NSString*)LoadGUID
{
  NSString *theGUID = [[UIDevice currentDevice] uniqueIdentifier];

  return [[NSString alloc] initWithString:theGUID]; 
}

-(NSString *)LoadName
{
  UIDevice *device = [UIDevice currentDevice];
  char buf[256];

  int i = 0, j = 0;
  for (i = 0; i < [device.name length]; i++) {
    unichar c = [device.name characterAtIndex:i];
    if (c < 255)
      buf[j++] = c;
    else if (c == 8217)
      buf[j++] = '\'';
    else
      buf[j++] = '?';
  }
  buf[j++] = 0;

  return [[NSString alloc] initWithCString:buf];
}

-(void) LoadPreferences
{
  NSMutableArray *tivosArray;
  NSMutableArray *tivoArray;
  tivos = [[NSMutableArray alloc] initWithCapacity:10];

  /* always load the GUID, never store it */
  GUID = [self LoadGUID];
  Name = [self LoadName];
  NetworkBroadcast = @"255.255.255.255";
  NetworkPort = @"9032";
  PhotosContainer = [[NSString alloc] initWithString:
          [@"Photos on " stringByAppendingString: Name]];
  MusicContainer = [[NSString alloc] initWithString:
          [@"Music on " stringByAppendingString: Name]];
  VideoContainer = [[NSString alloc] initWithString:
          [@"Videos on " stringByAppendingString: Name]];
  PhotosJPEGQuality = @"0.5";
  autoStart = NO;

  /* load our preferences */
  CFArrayRef appKeys = CFPreferencesCopyKeyList(appId, kCFPreferencesCurrentUser, kCFPreferencesAnyHost);

  if (appKeys == nil) {
    /* cannot find prefs */
    syslog(LOG_INFO, "Could not load app preferences, building new one");

    CFPreferencesSetAppValue(CFSTR("Name"), Name, appId);
    CFPreferencesSetAppValue(CFSTR("Network.Broadcast"), NetworkBroadcast, appId);
    CFPreferencesSetAppValue(CFSTR("Network.Port"), NetworkPort, appId);
    CFPreferencesSetAppValue(CFSTR("Photos.Container"), PhotosContainer, appId);
    CFPreferencesSetAppValue(CFSTR("Photos.JPEGQuality"), PhotosJPEGQuality, appId);
    CFPreferencesSetAppValue(CFSTR("Music.Container"), MusicContainer, appId);
    CFPreferencesSetAppValue(CFSTR("Video.Container"), VideoContainer, appId);
    CFPreferencesSetAppValue(CFSTR("AutoStart"), autoStart, appId);

    CFPreferencesAppSynchronize(appId);
  } else {
    syslog(LOG_INFO, "App preferences loaded");
    int i;
    for (i = 0; i < CFArrayGetCount(appKeys); i++) {
      NSString *nextPref = CFArrayGetValueAtIndex(appKeys, i);

      if ([nextPref isEqualToString:@"TivoDevices"]) {
        tivosArray = CFPreferencesCopyAppValue(nextPref, appId);
        int j;
        for (j = 0; j < [tivosArray count]; j++) {
          TivoDevice *nextTivo = [TivoDevice alloc];
          tivoArray = [tivosArray objectAtIndex:j];

          nextTivo->address = [tivoArray objectAtIndex:0];
          nextTivo->swversion = [tivoArray objectAtIndex:1];
          nextTivo->identity = [tivoArray objectAtIndex:2];
          nextTivo->machine_name = [tivoArray objectAtIndex:3];
          nextTivo->platform = [tivoArray objectAtIndex:4];
          nextTivo->services = [tivoArray objectAtIndex:5];
          nextTivo->mak = [tivoArray objectAtIndex:6];

          syslog(LOG_DEBUG, "Loadng TivoDevice = %s", [nextTivo->machine_name UTF8String]);
          [tivos addObject:nextTivo];
        }

      } else {
        Boolean valid;
        if ([nextPref isEqualToString: @"Name"]) 
          Name = CFPreferencesCopyAppValue(nextPref, appId);
        if ([nextPref isEqualToString: @"Network.Broadcast"])
          NetworkBroadcast = CFPreferencesCopyAppValue(nextPref, appId);
        else if ([nextPref isEqualToString: @"Network.Port"])
          NetworkPort = CFPreferencesCopyAppValue(nextPref, appId);
        else if ([nextPref isEqualToString: @"Photos.Container"])
          PhotosContainer = CFPreferencesCopyAppValue(nextPref, appId);
        else if ([nextPref isEqualToString: @"Photos.JPEGQuality"])
          PhotosJPEGQuality = CFPreferencesCopyAppValue(nextPref, appId);
        else if ([nextPref isEqualToString: @"AutoStart"]) {
          NSString *autoStartStr = CFPreferencesCopyAppValue(nextPref, appId);
          if ([autoStartStr isEqualToString: @"true"])
            autoStart = YES;
          else
            autoStart = NO;
        }

        syslog(LOG_DEBUG, "Loaded pref: %s=%s", [nextPref UTF8String], 
             [CFPreferencesCopyAppValue(nextPref, appId) UTF8String]);
      }
    }
  }

  dirty = NO;
}

-(NSMutableArray *)GetTivos
{
  return tivos;
}

-(void)AddTivoDevice:(TivoDevice*)tivo
{
  TivoDevice *foundTivo = nil;

  syslog(LOG_DEBUG, "trying to add tivo (%s)", [tivo->machine_name UTF8String]);

  /* first check to make sure we don't already have it */
  int i;
  for (i = 0; i < [tivos count]; i++) {
    TivoDevice *device = [tivos objectAtIndex:i];

    if ([device->identity isEqualToString: tivo->identity])
      foundTivo = device;
  }

  if (foundTivo) {
    dirty = YES;

    /* check to see if we have to merge info (new IP, etc.) */
    if (![foundTivo->machine_name isEqualToString: tivo->machine_name]) {
      if (tivo->machine_name && ![tivo->machine_name isEqualToString: @""]) {
        foundTivo->machine_name = tivo->machine_name;
        [foundTivo->machine_name retain];
      }
    }

    if (![foundTivo->address isEqualToString: tivo->address]) {
      if (tivo->address && ![tivo->address isEqualToString: @""]){
        foundTivo->address = tivo->address;
        [foundTivo->address retain];
      }
    }

    if (![foundTivo->mak isEqualToString: tivo->mak]) {
      if (tivo->mak && ![tivo->mak isEqualToString: @""]) {
        foundTivo->mak = tivo->mak;
        [foundTivo->mak retain];
      }
    }
  } else {
    [tivo retain];
    if (tivo->machine_name)
      [tivo->machine_name retain];
    if (tivo->address)
      [tivo->address retain];
    if (tivo->mak)
      [tivo->mak retain];
    if (tivo->swversion)
      [tivo->swversion retain];
    if (tivo->platform)
      [tivo->platform retain];
    if (tivo->services)
      [tivo->services retain];
    if (tivo->identity)
      [tivo->identity retain];

    [tivos addObject: tivo];
    dirty = YES;
  }
}

-(NSString *)GetGUID
{
  return GUID;
}

-(NSString *)GetName
{
  return Name;
}

-(void)SetName: (NSString *)n
{
  Name = n;
}

-(NSString *)GetNetworkBroadcast
{
  return NetworkBroadcast;
}

-(void)SetNetworkBroadcast: (NSString *)b
{
  NetworkBroadcast = b;
  dirty = YES;
}

-(NSString *)GetNetworkPort
{
  return NetworkPort;
}

-(void)SetNetworkPort: (NSString *)p
{
  NetworkPort = p;
  dirty = YES;
}

-(NSString *)GetPhotosJPEGQuality
{
  return PhotosJPEGQuality;
}

-(void)SetPhotosContainer: (NSString *)c
{
  PhotosContainer = c;
  dirty = YES;
}

-(NSString *)GetPhotosContainer
{
  return PhotosContainer;
}

-(void)SetMusicContainer: (NSString *)c
{
  MusicContainer = c;
  dirty = YES;
}

-(NSString *)GetMusicContainer
{
  return MusicContainer;
}

-(void)SetVideoContainer: (NSString *)c
{       
  VideoContainer = c;
  dirty = YES;
}

-(NSString *)GetVideoContainer
{
  return VideoContainer;
}

-(void)SetPhotosJPEGQuality: (NSString *)j
{
  PhotosJPEGQuality = j;
  dirty = YES;
}

-(BOOL)GetAutoStart
{
  return autoStart;
}

-(void)SetAutoStart: (BOOL)b
{
  autoStart = b;
  dirty = YES;
}

-(void)SetDirty:(BOOL)d
{
  dirty = d;
}

-(void)DefaultSettings
{
  GUID = [self LoadGUID];
  Name = [self LoadName];
  NetworkBroadcast = @"255.255.255.255";
  NetworkPort = @"9032";
  PhotosContainer = [[NSString alloc] initWithString:
          [@"Photos on " stringByAppendingString: Name]];
  MusicContainer = [[NSString alloc] initWithString:
          [@"Music on " stringByAppendingString: Name]];
  VideoContainer = [[NSString alloc] initWithString:
          [@"Videos on " stringByAppendingString: Name]];
  PhotosJPEGQuality = @"0.5";
  autoStart = NO;

  dirty = YES;
}

@end
