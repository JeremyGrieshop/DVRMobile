

#import <UIKit/UIKit.h>

#import "Beacon.h"
#import "TiVoHTTPServer.h"

@interface TransfersViewNavController : UINavigationController
{
  Beacon *beacon;
  TiVoHTTPServer *httpd;
  DVRMobilePrefs *prefs;
  NSMutableArray *tivos;
}

-(id)initWithRootViewController:(id)controller;
-(void)loadView;
-(void)setTivoObjects: (Beacon*)beacon withHttpServer:(TiVoHTTPServer*)httpd;
-(void)setDVRMobilePrefs: (DVRMobilePrefs*)p;
@end;

@interface TransfersViewController : UITableViewController
{
  Beacon *beacon;
  TiVoHTTPServer *httpd;
  NSMutableArray *tivos;
  DVRMobilePrefs *prefs;
  UIBarButtonItem *refreshBtn;
  UIActivityIndicatorView *spinningGear;
  UIProgressView *progressView;
}

-(void)loadView;
-(void)setTivoObjects: (Beacon*)beacon withHttpServer:(TiVoHTTPServer*)httpd;
-(void)setDVRMobilePrefs: (DVRMobilePrefs*)p;
@end;
