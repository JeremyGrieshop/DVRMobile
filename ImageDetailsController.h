
#import <UIKit/UIKit.h>
#import "Beacon.h"
#import "TiVoHTTPClient.h"
#import "CustomSpinningGearView.h"

@interface ImageDetailsView : UIImageView
{
}

@end

@interface ImageDetailsController : UIViewController
{
  UIImage *theImage;
  UIBarButtonItem *saveBtn;
  TivoDevice *tivo;
  NSMutableArray *items;
  int servicePort, row;
  CustomSpinningGearView *spinningGear;
}

-(void)loadView;
-(void)setTivoDevice: (TivoDevice*)tivo;
-(void)setServicePort: (int)p;
-(void)setItemIndex: (int)r;
-(void)setItems: (NSMutableArray*)items;
@end;
