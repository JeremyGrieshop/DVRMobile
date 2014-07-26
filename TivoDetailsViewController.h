

#import <UIKit/UIKit.h>

#import "Beacon.h"
#import "DVRMobilePrefs.h"
#import "TivoNowPlayingViewController.h"
#import "CustomSpinningGearView.h"

@interface TivoDetailsViewController: UITableViewController 
     <UITableViewDelegate, UITableViewDataSource, UITextInputTraits, UITextFieldDelegate>
{
  UILabel *titleLabel, *machineLabel, *identityLabel, *platformLabel;
  UILabel *servicesLabel, *addressLabel, *makLabel, *swversionLabel;
  UILabel *nowPlayingLabel, *remoteLabel;
  UITextField *machineTF, *identityTF, *platformTF, *servicesTF, *addressTF, *makTF, *swversionTF;
  UIBarButtonItem *aboutBtn, *helpBtn;
  TivoNowPlayingViewController *tivoNowPlayingView;
  DVRMobilePrefs *prefs;
  TivoDevice *tivo;
  CustomSpinningGearView *spin;  
  CGFloat animatedDistance;
}

-(void)loadView;
-(void)help:(id)sender;
-(void)about:(id)sender;
-(void)setTivoDevice:(TivoDevice*)tivo;
-(void)setDVRMobilePrefs: (DVRMobilePrefs*)p;
@end;
