

#import <UIKit/UIKit.h>


@interface HelpViewController: UIViewController 
{
  UIBarButtonItem *aboutBtn, *helpBtn;
  UIWebView *helpHtmlContent;
}

-(void)loadView;
@end;
