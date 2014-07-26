
#include <stdio.h>
#include <syslog.h>
#include <unistd.h>
#include <sys/fcntl.h>

#import "DVRMobile.h"
#import "Beacon.h"
#import "DVRMobilePrefs.h"
#import "TiVoHTTPServer.h"
#import "ShareViewController.h"
#import "SettingsViewController.h"
#import "ScanViewController.h"
#import "TransfersViewController.h"

#import <AudioToolbox/AudioToolbox.h>
#import <UIKit/UITabBar.h>
#import <UIKit/UITabBarItem.h>

int main(int argc, char **argv)
{
  NSAutoreleasePool *autoreleasePool = [
    [ NSAutoreleasePool alloc ] init
  ];

  /* setup signal handlers */
  signal(SIGPIPE, SIG_IGN);

  int returnCode = UIApplicationMain(argc, argv, @"DVRMobilePro", @"DVRMobilePro");

  [ autoreleasePool release ];

  return returnCode;
}

@implementation DVRMobilePro

-(void)applicationDidFinishLaunching: (id) unused
{
  syslog(LOG_DEBUG, "DVRMobile, applicationDidFinishLaunching..");

  background = NO;
  stop = NO;

  window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];

  tabBarController = [[UITabBarController alloc] initWithNibName:nil bundle:nil];

  /* setup our TabBarItems */
  UITabBarItem *shareTabItem = [[[UITabBarItem  alloc]
     initWithTitle: @"Share" image:[UIImage imageNamed:@"tivo.png"] tag:0] autorelease];
  UITabBarItem *settingsTabItem = [[[UITabBarItem  alloc]
     initWithTitle: @"Settings" image:[UIImage imageNamed:@"settings-icon.png"] tag:1] autorelease];
  settingsTabItem.title = @"Settings";
  UITabBarItem *scanTabItem = [[[UITabBarItem  alloc]
     initWithTitle: @"Scan" image:[UIImage imageNamed:@"wifi.png"] tag:2] autorelease];
  UITabBarItem *transfersTabItem = [[[UITabBarItem  alloc]
     initWithTitle: @"Transfers" image:[UIImage imageNamed:@"transfers.png"] tag:3] autorelease];

  /* create the Share controller view */
  ShareViewController *shareView = [[ShareViewController alloc] autorelease];
  ShareViewNavController *shareNavView = [[[ShareViewNavController alloc]
       initWithRootViewController: shareView] autorelease];
  shareNavView.tabBarItem = shareTabItem;
  shareNavView.title = @"Share";

  /* create the Settings controller view */
  SettingsViewController *settingsView = [[SettingsViewController alloc] autorelease];
  SettingsViewNavController *settingsNavView = [[[SettingsViewNavController alloc]
       initWithRootViewController: settingsView] autorelease];
  settingsNavView.tabBarItem = settingsTabItem;
  settingsNavView.title = @"Settings";
  
  /* create the Scan controller view */
  ScanViewController *scanView = [[ScanViewController alloc] autorelease];
  ScanViewNavController *scanNavView = [[[ScanViewNavController alloc] 
       initWithRootViewController: scanView] autorelease];
  scanNavView.tabBarItem = scanTabItem;
  scanNavView.title = @"Devices";

  /* create the Transfers view */
  TransfersViewController *transfersView = [[TransfersViewController alloc] autorelease];
  TransfersViewNavController *transfersNavView = [[[TransfersViewNavController alloc] 
       initWithRootViewController: transfersView] autorelease];
  //transfersNavView.tabBarItem = transfersTabItem;
  transfersView.tabBarItem = transfersTabItem;
  transfersNavView.title = @"Transfers";

  tabBarController.viewControllers =
       [NSArray arrayWithObjects:shareNavView, scanNavView, transfersView, settingsNavView, nil ];

  [window addSubview: tabBarController.view];
  [window makeKeyAndVisible];

  /* load our preferences */ 
  prefs = [DVRMobilePrefs alloc];
  [prefs LoadPreferences];

  /* create http server */
  httpd = [TiVoHTTPServer alloc];
  [httpd initialize];
  [httpd setDVRMobilePrefs: prefs];

  /* create beacon */
  beacon = [Beacon alloc];
  [beacon setDVRMobilePrefs: prefs];

  /* start our beacon scanner */
  [NSThread detachNewThreadSelector:@selector(BeaconScanner:)
     toTarget:self withObject:nil];

  /* Add services to beacon */
  NSString *serviceStr = [[NSString alloc] 
        initWithFormat:@"TiVoMediaServer:%@/http", [prefs GetNetworkPort]];
  [beacon addService: serviceStr];

  /* set http beacon */
  [httpd setBeacon: beacon];

  /* send our tivo objects to each view */
  [shareView setTivoObjects: beacon withHttpServer:httpd];
  [shareView setDVRMobilePrefs: prefs];
  [scanView  setTivoObjects: beacon withHttpServer:httpd];
  [scanView  setDVRMobilePrefs: prefs];
  [settingsView  setDVRMobilePrefs: prefs];
}

-(void) BeaconScanner: (id)obj
{
  TivoDevice *device;

  while (!stop) {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    device = [beacon Scan: 35];
    if (device != nil) {
      [prefs AddTivoDevice: device];
    }

    [pool release];
  }
}

-(void)applicationDidBecomeActive: (UIApplication *)application
{
  syslog(LOG_INFO, "applicationDidBecomeActive..");
  window.hidden = NO;
  background = NO;
}

-(void)applicationWillResignActive: (UIApplication *)application
{
  syslog(LOG_DEBUG, "applicationWillResignActive..");
}

-(void)applicationWillTerminate:(UIApplication *)application
{
  syslog(LOG_DEBUG, "applicationWillTerminate.. saving prefs.");

  [prefs SavePreferences];
}

-(void)applicationWillResume
{
  syslog(LOG_DEBUG, "applicationWillResume..");
  window.hidden = NO;
  background = NO;
}

-(void)setBackground: (BOOL)b
{
  background = b;
}

- (void)setServiceRunning: (BOOL)b
{
  serviceRunning = b;
}

@end

