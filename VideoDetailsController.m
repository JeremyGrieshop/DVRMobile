
#import "VideoDetailsController.h"
#import "TiVoHTTPClient.h"

#include <syslog.h>
#include <dlfcn.h>

#import <UIKit/UIKit.h>


@implementation VideoDetailsController 
{

}

-(void)loadView
{
  self.view = [[[UIScrollView alloc] initWithFrame: [[UIScreen mainScreen] bounds]] autorelease];
  self.view.backgroundColor = [UIColor whiteColor];
  self.title = @"Video";

  //NSString *date = [[NSDate dateWithTimeIntervalSince1970: 
  //         [video->captureDate doubleValue]] descriptionWithCalendarFormat:
  //         @"%m/%d/%y %H:%M" timeZone:nil locale:nil];
  html = [NSString stringWithFormat: 
           @"<html><center><h2>%@</h2></center> \
               <b>Duration: </b>%d Minutes<br><br> \
               <b>Date: </b>%@<br><br> \
               <b>Description: </b>%@<br><br> \
             </html>",
           (video->episodeTitle == nil ? video->title : video->episodeTitle), 
           [(video->duration) intValue]/(1000*60), video->captureDate, 
           video->description
         ];

  htmlView = [[UIWebView alloc] initWithFrame:CGRectMake(10,10,290,460)];
  htmlView.backgroundColor = [UIColor whiteColor];
  [htmlView loadHTMLString: html baseURL:nil];
  //[htmlView loadRequest:[NSURLRequest requestWithURL: 
  //         [NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:@"VideoDetails" 
  //                ofType:@"html"] isDirectory:NO]]];

  [self.view addSubview: htmlView];
}

-(void)viewDidLoad
{
  downloadBtn = [[[UIBarButtonItem alloc] initWithTitle:@"Download" style:UIBarButtonItemStyleBordered target:self action:@selector(download:)] autorelease];

  self.navigationItem.rightBarButtonItem = downloadBtn;
}

-(void)download: (id)sender
{

}

-(void)setTiVoItem: (TiVoItem*)i
{
  video = i;
}

@end
