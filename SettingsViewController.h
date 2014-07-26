
#import "DVRMobilePrefs.h"

#import <UIKit/UIKit.h>


@interface SettingsViewNavController : UINavigationController
{
}

-(id)initWithRootViewController:(id)controller;
-(void)loadView;
@end;


@interface SettingsViewController : UITableViewController 
     <UITableViewDelegate, UITableViewDataSource, UITextInputTraits, UITextFieldDelegate>
{
  UILabel *titleLabel, *guidLabel, *bcastLabel, *portLabel, *jpegLabel, *containerLabel, *nameLabel;
  UITextField *guidTF, *bcastTF, *portTF, *jpegTF, *containerTF, *nameTF;
  UISwitch *autoSwitch;
  UISlider *jpegSlider;
  UIBarButtonItem *aboutBtn, *helpBtn;
  UIButton *resetBtn;
  DVRMobilePrefs *prefs;
  CGFloat animatedDistance;
}

-(void)loadView;
-(void)setDVRMobilePrefs: (DVRMobilePrefs*)p;
-(void)help:(id)sender;
-(void)about:(id)sender;
@end;
