
#import <CoreFoundation/CoreFoundation.h>
#import <Foundation/Foundation.h>

#import "HttpDelegate.h"
#import "DVRMobilePrefs.h"
#import "Beacon.h"
#import "Photos.h"
#import "Music.h"
#import "Video.h"
#import "CustomSpinningGearView.h"

@interface TiVoHTTPServer: NSObject
{
  Beacon *beacon;
  int sock, clientSock;
  id graphicsLock;
  Cache *resourceCache;
@public
  BOOL stopFlag, isStopped, isStarted, isRunning;
  DVRMobilePrefs *prefs;
  NSMutableArray *tivos;
  Photos *photos;
  Music *music;
  Video *video;
  CustomSpinningGearView *spinningGear;
}
-(void)initialize;
-(void)setBeacon: (Beacon*)beacon;
-(void)ServeForever;
-(void)stop;
-(BOOL)isStarted;
-(BOOL)isRunning;
-(BOOL)isStopped;
-(void)setDVRMobilePrefs: (DVRMobilePrefs*)p;
-(void)setSpinningGearView: (CustomSpinningGearView*)v;
@end

@interface TiVoHTTPHandler: NSObject <HttpDelegate>
{
  BOOL stopFlag;
  int clientSock;
  id graphicsLock;
  Cache *resourceCache;
  Beacon *beacon;
  NSString *cmd;
  NSString *uri;
  NSString *version;
  NSString *address;
  NSMutableArray *headerNames;
  NSMutableArray *headerValues;
  NSMutableArray *tivos;
  DVRMobilePrefs *prefs;
  Photos *photos;
  Music *music;
  Video *video;
}
-(void)setDVRMobilePrefs: (DVRMobilePrefs*)p;
-(void)initialize;
-(void)ReadLine: (char*)buf size:(int)size;
-(void)ProcessRequest;
-(void)ParseRequest;
-(void)setBeacon: (Beacon*)beacon;
-(void)setClientSock: (int)clientSock;
-(void)setGraphicsLock: (id)lock;
-(void)setResourceCache: (Cache *)cache;
-(void)setDVRMobilePrefs: (DVRMobilePrefs*)p;
-(void)setPhotos: (Photos*)p;
-(void)setMusic: (Music*)m;
-(void)setVideo: (Video*)v;
-(void)AddTivoDevice:(TivoDevice*)tivo;
-(NSString*)GetTivoName:(NSString*)identifier;
-(void)doGET;
-(void)QueryContainer: (NSArray*)attrs;
-(void)QueryItem: (NSArray*)attrs;
-(void)RootContainer;
@end
