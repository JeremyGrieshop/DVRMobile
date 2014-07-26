
#import <UIKit/UIKit.h>
#import "TiVoHTTPClient.h"

@interface VideoDetailsController : UIViewController <UIWebViewDelegate, UIAlertViewDelegate>
{
  UIWebView *htmlView;
  NSString *html;
  TiVoItem *video;
  UIBarButtonItem *downloadBtn;
}

-(void)loadView;
-(void)setTiVoItem: (TiVoItem *)i;
@end;
