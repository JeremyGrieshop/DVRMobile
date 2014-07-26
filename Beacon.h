
#import <CoreFoundation/CoreFoundation.h>
#import <Foundation/Foundation.h>

#import "DVRMobilePrefs.h"

@class DVRMobilePrefs;

@interface TivoDevice: NSObject
{
@public
  NSString *address;
  NSString *swversion;
  NSString *identity;
  NSString *machine_name;
  NSString *platform;
  NSString *services;
  NSString *mak;
}
@end

@interface Beacon : NSObject
{
@public
  int UDPSock, TCPSock;
  //NSMutableArray *beacon;
  NSMutableArray *services;
  DVRMobilePrefs *prefs;
  BOOL stopFlag;
  NSTimer *timer;
}

- (void)setDVRMobilePrefs: (DVRMobilePrefs*)p;
- (void)start;
- (void)stop;
- (void)listen;
- (BOOL)SendBeacon;
- (TivoDevice*)Scan:(int)timeout;
- (void)addService: (NSString*)service;
- (TivoDevice*)GetTivoDevice: (NSString*)address;
@end


