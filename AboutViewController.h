

#import <UIKit/UIKit.h>


@interface AboutViewController: UIViewController 
{
  UILabel *titleLabel, *aboutLabel;
  UIBarButtonItem *aboutBtn, *helpBtn;
  UIWebView *aboutHtmlContent;
}

-(void)loadView;
@end;
