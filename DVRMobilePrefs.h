
#import <CoreFoundation/CoreFoundation.h>
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#import "Beacon.h"

@class TivoDevice;


@interface DVRMobilePrefs : NSObject
{
  NSString *GUID;
  NSString *Name;
  NSString *NetworkBroadcast;
  NSString *NetworkPort;
  NSString *PhotosContainer;
  NSString *PhotosJPEGQuality;
  NSString *MusicContainer;
  NSString *VideoContainer;
  NSMutableArray *tivos;
  BOOL autoStart;

  BOOL dirty;
}

-(void)LoadPreferences;
-(void)SavePreferences;
-(NSMutableArray*)GetTivos;
-(NSString *)GetGUID;
-(NSString *)GetName;
-(void)SetName:(NSString*)n;
-(NSString *)GetNetworkBroadcast;
-(void)SetNetworkBroadcast:(NSString*)n;
-(NSString *)GetNetworkPort;
-(void)SetNetworkPort:(NSString*)n;
-(NSString *)GetPhotosJPEGQuality;
-(void)SetPhotosJPEGQuality:(NSString*)n;
-(NSString*)GetPhotosJPEGQuality;
-(void)SetPhotosContainer:(NSString*)c;
-(NSString*)GetPhotosContainer;
-(void)SetMusicContainer:(NSString*)c;
-(NSString*)GetMusicContainer;
-(void)SetVideoContainer:(NSString*)c;
-(NSString*)GetVideoContainer;
-(void)SetAutoStart:(BOOL)b;
-(BOOL)GetAutoStart;
-(void)AddTivoDevice:(TivoDevice*)tivo;
-(void)SetDirty:(BOOL)dirty;
-(void)DefaultSettings;
@end;
