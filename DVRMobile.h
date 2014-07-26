
#import <CoreFoundation/CoreFoundation.h>
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <UIKit/UITextView.h>

#import "Beacon.h"
#import "DVRMobilePrefs.h"
#import "TiVoHTTPServer.h"

@interface MainView : UIView
{
}
- (id)initWithFrame:(CGRect)rect;
- (void)dealloc;
@end


@interface DVRMobilePro : UIApplication
{
  UIWindow *window;
  UIView *mainView;
  UITabBarController *tabBarController;
  DVRMobilePrefs *prefs;
  Beacon *beacon;
  TiVoHTTPServer *httpd;
  BOOL background;
  BOOL serviceRunning;
  BOOL stop;
}
- (void)applicationDidFinishLaunching: (NSNotification *)aNotification;
- (void)setBackground: (BOOL)b;
- (void)setServiceRunning: (BOOL) b;
@end

