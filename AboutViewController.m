
#import "AboutViewController.h"

@implementation AboutViewController
{

}

-(void)loadView
{

  self.view = [[[UIWebView alloc] initWithFrame: [[UIScreen mainScreen] applicationFrame]] autorelease];
  [self.view loadRequest:[NSURLRequest requestWithURL:[NSURL 
            fileURLWithPath:[[NSBundle mainBundle] pathForResource:@"about" ofType:@"html"] isDirectory:NO]]];
  self.title = @"About";
  self.view.backgroundColor = [UIColor blackColor];
}

@end;
