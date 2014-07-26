
#import "ImageDetailsController.h"
#import "TiVoHTTPClient.h"

#include <syslog.h>
#include <dlfcn.h>

#import <UIKit/UIKit.h>

@implementation ImageDetailsView

-(id)initWithFrame:(CGRect)frame
{
  self = [super initWithFrame: frame];
  if (nil != self) {
    self.userInteractionEnabled = YES;
  }

  return self;
}

-(id)initWithImage: (UIImage *)image
{
  self = [super initWithImage: image];
  self.userInteractionEnabled = YES;
  self.contentMode = UIViewContentModeCenter;
  [self setBackgroundColor: [UIColor blackColor]];

  return self;
}

-(void)touchesMoved:(NSSet *)touches withEvent: (UIEvent*)event
{
  NSSet *allTouches = [event allTouches];

  switch([allTouches count]) {
    case 1:
      /* image is being panned */
      syslog(LOG_DEBUG, "Pan left/right");
      break;
    case 2:
      /* image is being zoomed in or out */
      syslog(LOG_DEBUG, "Zoom in/out");
      break;
  }
  
}

-(void)touchesEnded: (NSSet *)touches withEvent:(UIEvent*)event
{
  UITouch *touch = [[event allTouches] anyObject];
  syslog(LOG_DEBUG, "touchesEnded");
}

-(void)touchesBegan: (NSSet *)touches withEvent:(UIEvent *)event
{
  UITouch *touch = [[event allTouches] anyObject];
  syslog(LOG_DEBUG, "touchesBegan..");
}

@end

@implementation ImageDetailsController 
{

}

-(void)loadView
{
  self.title = @"Image";

  TiVoItem *item = [items objectAtIndex: row];

  /* load our image */
  NSString *url;
  if ([item->url hasPrefix: @"/"])
    url = [NSString stringWithFormat: @"http://%@:%d%@?Width=320&Height=420", 
          tivo->address, servicePort, item->url];
  else     
    url = [NSString stringWithFormat: @"http://%@:%d/%@?Width=320&Height=420", 
          tivo->address, servicePort, item->url];
  UIImage *image = [UIImage imageWithData: [NSData dataWithContentsOfURL:
         [NSURL URLWithString: url]]];

  self.view = [[[ImageDetailsView alloc] initWithImage: image] autorelease];
}

-(void)viewDidLoad
{
  saveBtn = [[[UIBarButtonItem alloc] initWithTitle:@"Save Image" style:UIBarButtonItemStyleBordered 
            target:self action:@selector(saveImage:)] autorelease];

  self.navigationItem.rightBarButtonItem = saveBtn;
}

-(void)setTivoDevice: (TivoDevice*)t
{
  tivo = t;
}

-(void)setServicePort: (int)p
{
  servicePort = p;
}

-(void)setItemIndex: (int)r
{
  row = r;
}

-(void)setItems: (NSMutableArray*)i
{
  items = i;
}

- (void)image:(UIImage *)image didFinishSavingWithError:(NSError *)error 
             contextInfo:(void *)contextInfo
{
  // Was there an error?
  if (error != NULL)
  {
    // Show error message...

  }
  else  // No errors
  {
    // Show message image successfully saved
  }
}

-(void)saveImage: (id)sender
{
  UIImageWriteToSavedPhotosAlbum(theImage, self, 
            @selector(image:didFinishSavingWithError:contextInfo:), nil);
}

@end
