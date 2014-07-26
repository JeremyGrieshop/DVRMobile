
#import "HelpViewController.h"

@implementation HelpViewController
{

}

-(void)loadView
{
  self.view = [[[UIWebView alloc] initWithFrame: [[UIScreen mainScreen] applicationFrame]] autorelease];
  [self.view loadRequest:[NSURLRequest requestWithURL:[NSURL
            fileURLWithPath:[[NSBundle mainBundle] pathForResource:@"help" 
            ofType:@"html"] isDirectory:NO]]];
  self.title = @"Help";
  self.view.backgroundColor = [UIColor blackColor];
}

@end;
