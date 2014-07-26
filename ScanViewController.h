

#import <UIKit/UIKit.h>

#import "Beacon.h"
#import "TiVoHTTPServer.h"
#import "TivoDetailsViewController.h"
#import "CustomSpinningGearView.h"

@interface ScanViewNavController : UINavigationController
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

@interface ScanViewController : UITableViewController <UIAlertViewDelegate>
{
  Beacon *beacon;
  TiVoHTTPServer *httpd;
  NSMutableArray *tivos;
  DVRMobilePrefs *prefs;
  UIBarButtonItem *refreshBtn;
  CustomSpinningGearView *customSpinningGearView;
  UIAlertView *warningAlert;
  UIImage *tivoIcon, *iphoneIcon, *pcIcon;
  TivoDetailsViewController *tivoView;
}

-(void)loadView;
-(void)setTivoObjects: (Beacon*)beacon withHttpServer:(TiVoHTTPServer*)httpd;
-(void)setDVRMobilePrefs: (DVRMobilePrefs*)p;
@end;
