
#import <UIKit/UIKit.h>
#import "DVRMobilePrefs.h"
#import "TiVoHTTPClient.h"
#import "CustomSpinningGearView.h"

@interface ThumbnailCell : UITableViewCell
{
  UIImage *image1, *image2, *image3, *image4;

}

@end;

@interface TestAsyncViewController : UITableViewController <UIAlertViewDelegate>
{
  TivoDevice *tivo;
  DVRMobilePrefs *prefs;
  TiVoHTTPClient *client;
  UIImage *video_icon, *audio_icon, *photo_icon, *folder_icon;
  TiVoContainer *container;
  CustomSpinningGearView *spinningGear;
  NSString *uri;
  NSString *serviceProtocol;
  int servicePort;
}

-(void)loadView;
-(void)setDVRMobilePrefs: (DVRMobilePrefs*)p;
-(void)setTivoDevice: (TivoDevice*)tivo;
-(void)setUri: (NSString*)u;
@end;
