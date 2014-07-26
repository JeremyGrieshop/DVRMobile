
#import <UIKit/UIKit.h>

#import "Beacon.h"
#import "TiVoHTTPServer.h"
#import "CustomSpinningGearView.h"

@interface ShareViewNavController : UINavigationController
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


@interface ShareViewController : UIViewController <UIWebViewDelegate, UIAlertViewDelegate>
{
  UIButton *startBtn;
  UIButton *stopBtn;
  UIBarButtonItem *startServiceBtn, *stopServiceBtn;
  UIBarButtonItem *disableDimBtn, *enableDimBtn;
  CustomSpinningGearView *spinningGear;
  UILabel *statusLabel;
  UIWebView *statusHtmlLabel;
  NSString *inactiveHTML, *activeHTML;
  DVRMobilePrefs *prefs;

  Beacon *beacon;
  TiVoHTTPServer *httpd;
}

-(void)loadView;
-(void)setTivoObjects: (Beacon*)beacon withHttpServer:(TiVoHTTPServer*)httpd;
-(void)setDVRMobilePrefs: (DVRMobilePrefs*)prefs;
-(void)StartTivoService: (id)sender;
-(void)StopTivoService: (id)sender;
-(void)StartTivoServiceThread: (id)sender;
-(void)StopTivoServiceThread: (id)sender;
-(void)showAboutWebView;
@end;
