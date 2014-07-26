
#import "ShareViewController.h"
#import "TiVoHTTPServer.h"

#include <syslog.h>
#include <dlfcn.h>

#import <UIKit/UIKit.h>


@implementation ShareViewNavController
{

}

-(id)initWithRootViewController:(id)controller
{
  self = [super initWithRootViewController:controller];
  return self;
}

-(void)loadView
{
  [super loadView];
}

-(void)setTivoObjects: (Beacon*)b withHttpServer:(TiVoHTTPServer*)h
{
  beacon = b;
  httpd = h;
}

-(void)setDVRMobilePrefs: (DVRMobilePrefs*)p
{
  prefs = p;
  tivos = [prefs GetTivos];
}

@end;


@implementation ShareViewController 
{

}

-(BOOL)isWifiActive
{
  /* for now, always return YES */
  return YES;

  void *libHandle = dlopen("/System/Library/PrivateFrameworks/Preferences.framework/Preferences", RTLD_LAZY);

  if (libHandle) {
    syslog(LOG_DEBUG, "got a handle to PrivateFrameworks/Preferences");
    BOOL (*isEnabled)() = dlsym(libHandle, "PSWiFiIsEnabled");
    if (isEnabled) {
      syslog(LOG_DEBUG, "imported symbol");
      return (isEnabled());
    }
  }

  return NO;
}

-(void)setTivoObjects: (Beacon*)b withHttpServer:(TiVoHTTPServer*)h
{
  beacon = b;
  httpd = h;
}

-(void)loadView
{
  self.view = [[[UIScrollView alloc] initWithFrame: [[UIScreen mainScreen] bounds]] autorelease];
  self.view.backgroundColor = [UIColor blackColor];
  self.title = @"Share";

  spinningGear = [[CustomSpinningGearView alloc] autorelease];
  [spinningGear initialize];
  [spinningGear setText: @"Starting Service"];

  inactiveHTML = @"<html><body bgcolor=\"black\"><font color=\"white\">The <b>DVRMobile</b> Service is currently inactive.<br/><br/>Select <b><i>Start Service</i></b> to begin sharing content with your TiVo.</font></body></html>";

  activeHTML = [[NSString alloc] initWithFormat:@"<html><body bgcolor=\"black\"><font color=\"white\">The <b>DVRMobile</b> Service is active.<br/><br/>To view your <b>Photos</b> or <b>Music</b> on your TiVo, enter your TiVo Central menu, then choose: <br><br><b>&nbsp;Music, Photos, & Showcases</b><br>&nbsp;&nbsp;&gt;<i>%@</i><br>&nbsp;&nbsp;&gt;<i>%@</i><br><br></font></body></html>", [prefs GetPhotosContainer], [prefs GetMusicContainer]];

  if ([self isWifiActive]) {
    syslog(LOG_DEBUG, "WiFi is enabled.");

    startServiceBtn = [[UIBarButtonItem alloc] initWithTitle:@"Start Service"
           style:UIBarButtonItemStyleBordered target:self 
           action:@selector(StartTivoService:)];
    stopServiceBtn = [[UIBarButtonItem alloc] initWithTitle:@"Stop Service"
           style:UIBarButtonItemStyleBordered target:self 
           action:@selector(StopTivoService:)];
    disableDimBtn = [[UIBarButtonItem alloc] initWithTitle:@"Disable Dim"
           style:UIBarButtonItemStyleBordered target:self
           action:@selector(DisableDim:)];
    enableDimBtn = [[UIBarButtonItem alloc] initWithTitle:@"Enable Dim"
           style:UIBarButtonItemStyleBordered target:self
           action:@selector(EnableDim:)];
           
    self.navigationItem.leftBarButtonItem = startServiceBtn;
    self.navigationItem.rightBarButtonItem = disableDimBtn;

    statusHtmlLabel = [[UIWebView alloc] initWithFrame:CGRectMake(20,30,280,380)];
    statusHtmlLabel.backgroundColor = [UIColor blackColor];
    [statusHtmlLabel loadHTMLString: inactiveHTML baseURL:nil];
    [statusHtmlLabel setDelegate:self];
    [statusHtmlLabel setHidden:YES];
            
    [self.view addSubview: statusHtmlLabel];
    [self.view addSubview: spinningGear];
  } else {
    syslog(LOG_ERR, "WiFi is NOT enabled for DVRMobile.");
    UILabel *wifiError = [[[UILabel alloc] initWithFrame:CGRectMake(60,170,180,75)] autorelease];
    wifiError.backgroundColor = [UIColor blackColor];
    wifiError.textColor = [UIColor whiteColor];
    wifiError.text = @"WiFi is not enabled.";
    wifiError.font = [UIFont boldSystemFontOfSize:16];

    [self.view addSubview: wifiError];
  }
}

-(void)viewDidLoad
{
  syslog(LOG_DEBUG, "ShareViewController:  viewDidLoad..");

  if ([prefs GetAutoStart]) {
    syslog(LOG_DEBUG, "Auto Starting Service..");

    [self StartTivoService: nil];
  }
}

-(void)webViewDidFinishLoad:(UIWebView *)webView
{
  [self performSelector:@selector(showAboutWebView) withObject:nil afterDelay:.1];
}

- (void)showAboutWebView 
{
  [statusHtmlLabel setHidden:NO];
}

-(void) EnableDim:(id)sender
{
  UIApplication* app = [UIApplication sharedApplication];
  app.idleTimerDisabled = NO;
  self.navigationItem.rightBarButtonItem = disableDimBtn;
}

-(void) DisableDim:(id)sender
{
  UIApplication* app = [UIApplication sharedApplication];
  app.idleTimerDisabled = YES;
  self.navigationItem.rightBarButtonItem = enableDimBtn; 
}

-(void)AskBackground: (id) sender
{
  UIAlertView *warningAlert = [[UIAlertView alloc] initWithTitle:@"Warning"
      message:@"This action will send DVRMobile into the background.  Continue?"
      delegate:self cancelButtonTitle:@"Cancel"
      otherButtonTitles:@"Continue", nil];
  [warningAlert show];
  [warningAlert release];
}


-(void)alertView:(UIAlertView *)actionSheet clickedButtonAtIndex:(NSInteger) buttonIndex
{
  if (buttonIndex == 1) {
    [NSThread detachNewThreadSelector:@selector(Background:)
         toTarget:self withObject:nil];
  }
}

-(void) Background:(id)sender
{
  UIApplication* app = [UIApplication sharedApplication];

  [app setBackground: YES];
  [app setApplicationBadge:@"On"];
  [app performSelector: @selector(suspendWithAnimation:) withObject:nil afterDelay: 0];
}

-(void) StartTivoService:(id)sender 
{
  syslog(LOG_DEBUG, "starting tivo service..");

  [spinningGear show];

  [beacon start];

  [httpd setSpinningGearView: spinningGear];

  [NSThread detachNewThreadSelector: @selector(ServeForever)
       toTarget:httpd withObject:nil];

  [NSThread detachNewThreadSelector:@selector(StartTivoServiceThread:) 
      toTarget:self withObject:nil];
}

-(void) StartTivoServiceThread:(id)anObject 
{
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

  sleep(1);
  while (![httpd isStarted] && [httpd isRunning]) {
    sleep(1);
  }

  [spinningGear stop];

  if ([httpd isStarted]) {
    self.navigationItem.leftBarButtonItem = stopServiceBtn;
    [statusHtmlLabel loadHTMLString:activeHTML baseURL:nil];
  } else {
    /* unable to start service */
    UIAlertView *errorAlert = [[UIAlertView alloc] initWithTitle:@"Error"
        message:@"An error occured while attempting to start the service.  If this problem persists, wait one minute and restart DVRMobile."
        delegate:self cancelButtonTitle:nil otherButtonTitles:@"Continue", nil];
    [errorAlert show];
    [errorAlert release];
  }

  [pool release];
  [NSThread exit];
}

-(void) StopTivoService:(id)sender 
{
  syslog(LOG_DEBUG, "stopping tivo service..");
  UIApplication* app = [UIApplication sharedApplication];
  app.idleTimerDisabled = NO;
  [app setServiceRunning: NO];

  [spinningGear setText: @"Stopping Service"];
  [spinningGear show];

  [beacon stop];
  [httpd stop];

  [NSThread detachNewThreadSelector:@selector(StopTivoServiceThread:) 
      toTarget:self withObject:nil];
}

-(void) StopTivoServiceThread:(id)anObject
{
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

  sleep(1);
  while (![httpd isStopped]) {
    sleep(1);
  }

  self.navigationItem.leftBarButtonItem = startServiceBtn;
  [spinningGear stop];

    [statusHtmlLabel loadHTMLString:inactiveHTML baseURL:nil];

  [pool release];
}

-(void)setDVRMobilePrefs: (DVRMobilePrefs*)p
{
  prefs = p;
}

@end
