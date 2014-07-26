
#import "SettingsViewController.h"
#import "AboutViewController.h"
#import "HelpViewController.h"
#import "CustomSpinningGearView.h"

#include <syslog.h>

@implementation SettingsViewNavController
{

}

-(id)initWithRootViewController:(id)controller
{
  self = [super initWithRootViewController:controller];
  return self;
}

-(void)loadView
{
  [super loadView];
}

@end;


@implementation SettingsViewController
{

}

static const CGFloat KEYBOARD_ANIMATION_DURATION = 0.3;
static const CGFloat MINIMUM_SCROLL_FRACTION = 0.2;
static const CGFloat MAXIMUM_SCROLL_FRACTION = 0.8;
static const CGFloat PORTRAIT_KEYBOARD_HEIGHT = 216;
static const CGFloat LANDSCAPE_KEYBOARD_HEIGHT = 140;

static const NSInteger TAG_TF_GUID 		= 1;
static const NSInteger TAG_TF_NAME 		= 2;
static const NSInteger TAG_TF_BROADCAST 	= 3;
static const NSInteger TAG_TF_PORT 		= 4;
static const NSInteger TAG_TF_CONTAINER 	= 5;
static const NSInteger TAG_TF_JPEG 		= 6;
static const NSInteger TAG_TF_MUSIC_CONTAINER   = 7;
static const NSInteger TAG_TF_MUSIC_DOWNLOADS   = 8;
static const NSInteger TAG_SLIDER_JPEG          = 9;
static const NSInteger TAG_SWITCH_AUTOSTART     = 10;
static const NSInteger TAG_BTN_RESET            = 11;


-(void)setDVRMobilePrefs: (DVRMobilePrefs*)p
{
  prefs = p;
}

-(void)textFieldDidBeginEditing:(UITextField *)textField
{
  syslog(LOG_DEBUG, "textFieldDidBeginEditing..");

  CGRect textFieldRect = [self.view.window convertRect:textField.bounds fromView:textField];
  CGRect viewRect = [self.view.window convertRect:self.view.bounds fromView:self.view];

  CGFloat midline = textFieldRect.origin.y + 0.5 * textFieldRect.size.height;
  CGFloat numerator = midline - viewRect.origin.y
            - MINIMUM_SCROLL_FRACTION * viewRect.size.height;
  CGFloat denominator = (MAXIMUM_SCROLL_FRACTION - MINIMUM_SCROLL_FRACTION)
            * viewRect.size.height;
  CGFloat heightFraction = numerator / denominator;

  if (heightFraction < 0.0)
    heightFraction = 0.0;
  else if (heightFraction > 1.0)
    heightFraction = 1.0;

  UIInterfaceOrientation orientation = [[UIApplication sharedApplication] statusBarOrientation];
  if (orientation == UIInterfaceOrientationPortrait ||
      orientation == UIInterfaceOrientationPortraitUpsideDown)
    animatedDistance = floor(PORTRAIT_KEYBOARD_HEIGHT * heightFraction);
  else
    animatedDistance = floor(LANDSCAPE_KEYBOARD_HEIGHT * heightFraction);

  CGRect viewFrame = self.view.frame;
  viewFrame.origin.y -= animatedDistance;
    
  [UIView beginAnimations:nil context:NULL];
  [UIView setAnimationBeginsFromCurrentState:YES];
  [UIView setAnimationDuration:KEYBOARD_ANIMATION_DURATION];
    
  [self.view setFrame:viewFrame];
    
  [UIView commitAnimations];

}

- (void)textFieldDidEndEditing:(UITextField *)textField
{
  syslog(LOG_DEBUG, "textFieldDidEndEditing, tag = %d, text=%s..", textField.tag, 
       [textField.text UTF8String]);

  CGRect viewFrame = self.view.frame;
  viewFrame.origin.y += animatedDistance;
    
  [UIView beginAnimations:nil context:NULL];
  [UIView setAnimationBeginsFromCurrentState:YES];
  [UIView setAnimationDuration:KEYBOARD_ANIMATION_DURATION];
    
  [self.view setFrame:viewFrame];
    
  [UIView commitAnimations];

  /* commit changes to preferences */
  if (textField.tag == TAG_TF_NAME) {
    [prefs SetName: textField.text];
  } else if (textField.tag == TAG_TF_BROADCAST) {
    [prefs SetNetworkBroadcast: textField.text];
  } else if (textField.tag == TAG_TF_PORT) {
    [prefs SetNetworkPort: textField.text];
  } else if (textField.tag == TAG_TF_CONTAINER) {
    [prefs SetPhotosContainer: textField.text];
  }
}

-(void)sliderEvent: (id)sender
{
  UISlider *slider = (UISlider *)sender;

  float value = slider.value;
  syslog(LOG_DEBUG, "sliderEvent, new value = %f", value);

  [prefs SetPhotosJPEGQuality: [[NSString stringWithFormat: @"%f", value] retain]];
}

-(void)switchAction:(UISwitch*)sender
{
  if (sender.on) {
    syslog(LOG_DEBUG, "AutoStart ON");
    [prefs SetAutoStart: YES];
  } else {
    syslog(LOG_DEBUG, "AutoStart OFF");
    [prefs SetAutoStart: NO];
  }
}

-(void)loadView
{
  self.tableView = [[[UITableView alloc] initWithFrame: [[UIScreen mainScreen] bounds]
         style:UITableViewStyleGrouped] autorelease];
  self.title = @"Settings";
}

-(void)viewDidLoad {
  aboutBtn = [[[UIBarButtonItem alloc] initWithTitle:@"About" style:UIBarButtonItemStyleBordered
        target:self action:@selector(about:)] autorelease];
  helpBtn = [[[UIBarButtonItem alloc] initWithTitle:@"Help" style:UIBarButtonItemStyleBordered
        target:self action:@selector(help:)] autorelease];

  self.navigationItem.rightBarButtonItem = aboutBtn;
  self.navigationItem.leftBarButtonItem = helpBtn;
}

-(void)help:(id)sender
{
  HelpViewController *helpView = [[HelpViewController alloc] autorelease];
  [self.navigationController pushViewController: helpView animated:YES];
}

-(void)about:(id)sender
{
  AboutViewController *aboutView = [[AboutViewController alloc] autorelease];
  [self.navigationController pushViewController: aboutView animated:YES];
}


-(NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
  return 5;
}

-(NSInteger)tableView: (UITableView*)tableView numberOfRowsInSection:(NSInteger)section
{
  if (section == 0)
    return 1;
  else if (section == 1)
    return 3;
  else if (section == 2)
    return 2;
  else if (section == 3)
    return 2;
  else if (section == 4)
    return 1;
  
  return 0;
}

-(NSString*)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
  if (section == 1)
    return @"General";
  else if (section == 2)
    return @"Network";
  else if (section == 3)
    return @"Photos";
  else if (section == 4)
    return @"Music";

  return nil;
}

-(NSIndexPath *) tableView:(UITableView *)tableView
      willSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
  int section = [indexPath section];
  int row = [indexPath row];

  if (section == 0 || (section == 1 && row == 0))
    return nil;

  return indexPath;
}

-(CGFloat)tableView:(UITableView*)tableView heightForRowAtIndexPath:(NSIndexPath*)indexPath
{
  int row = [indexPath row];
  int section = [indexPath section];

  if (section == 3 && row == 1)
    return 75.0;
  else
    return 50.0;
}

-(void)alertView:(UIAlertView *)actionSheet clickedButtonAtIndex:(NSInteger) buttonIndex
{
  if (buttonIndex == 1) {
    syslog(LOG_DEBUG, "Defaulting settings..");

    [prefs DefaultSettings];
    [self.tableView reloadData];
  }
}

-(void) reset: (id)sender
{
  syslog(LOG_DEBUG, "reset settings..");
 
  UIAlertView *warningAlert = [[UIAlertView alloc] initWithTitle:@"Warning"
      message:@"This will reset all your settings to their defaults.  Continue?"
      delegate:self cancelButtonTitle:@"Cancel"
      otherButtonTitles:@"Yes", nil];
  [warningAlert show];
  [warningAlert release]; 
}

-(UITableViewCell *)tableView:(UITableView *)tableView
    cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
  int section = [indexPath section];
  int row = [indexPath row];

  syslog(LOG_DEBUG, "cellForRowAtIndexPath (%d,%d)..", section, row);

  UITableViewCell *cell;
  if (section == 0) {
    NSString *CellTableIdentifier = @"ResetButtonCellIdentifier";
    cell = [tableView dequeueReusableCellWithIdentifier: CellTableIdentifier]
;
    if (cell == nil) {
      CGRect cellFrame = CGRectMake(0, 0, 300, 65);
      cell = [[[UITableViewCell alloc] initWithFrame:cellFrame
          reuseIdentifier:CellTableIdentifier] autorelease];

      UIView *transparentBackground = [[UIView alloc] initWithFrame:CGRectZero];
      transparentBackground.backgroundColor = [UIColor clearColor];
      cell.backgroundView = transparentBackground;

      resetBtn = [UIButton buttonWithType: UIButtonTypeRoundedRect];
      resetBtn.frame = CGRectMake(80, 5, 160, 40);
      [resetBtn setTitle:@"Reset Settings" forState:UIControlStateNormal];
      [resetBtn addTarget:self action:@selector(reset:)
         forControlEvents:UIControlEventTouchUpInside];

      [cell.contentView addSubview: resetBtn];
    }
  } else if (section == 1) {
    /* General section */
    if (row == 0) {
      NSString *CellTableIdentifier = @"GUIDCellIdentifier";
      cell = [tableView dequeueReusableCellWithIdentifier: @"GUIDCellIdentifier"];
      if (cell == nil) {
        CGRect cellFrame = CGRectMake(0, 0, 300, 65);
        cell = [[[UITableViewCell alloc] initWithFrame:cellFrame 
            reuseIdentifier:CellTableIdentifier] autorelease];

        guidLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 5, 45, 30)];
        guidLabel.text = @"GUID:";
        guidLabel.font = [UIFont systemFontOfSize:12];
     
        guidTF = [[UITextField alloc] initWithFrame:CGRectMake(50, 13, 240, 30)];
        guidTF.enabled = NO;
        guidTF.font = [UIFont systemFontOfSize:11];
        guidTF.tag = TAG_TF_GUID;

        [cell.contentView addSubview:guidLabel];
        [cell.contentView addSubview:guidTF];

        [guidLabel release];
        [guidTF release];
      }

      guidTF = (UITextField *)[cell.contentView viewWithTag: TAG_TF_GUID];
      guidTF.text = [prefs GetGUID];

    } else if (row == 1) {
      NSString *CellTableIdentifier = @"NameCellIdentifier";
      cell = [tableView dequeueReusableCellWithIdentifier: @"NameCellIdentifier"];
      if (cell == nil) {
        CGRect cellFrame = CGRectMake(0, 0, 300, 65);
        cell = [[[UITableViewCell alloc] initWithFrame:cellFrame 
            reuseIdentifier:CellTableIdentifier] autorelease];

        nameLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 5, 80, 30)];
        nameLabel.text = @"Name:";

        nameTF = [[UITextField alloc] initWithFrame:CGRectMake(90, 13, 200, 30)];
        nameTF.font = [UIFont systemFontOfSize:12];
        nameTF.clearButtonMode = UITextFieldViewModeWhileEditing;
        nameTF.returnKeyType = UIReturnKeyDone;
        nameTF.delegate = self;
        nameTF.tag = TAG_TF_NAME;

        [cell.contentView addSubview:nameLabel];
        [cell.contentView addSubview:nameTF];

        [nameLabel release];
        [nameTF release];
      }

      nameTF = (UITextField *)[cell.contentView viewWithTag: TAG_TF_NAME];
      nameTF.text = [prefs GetName];

    } else if (row == 2) {
      NSString *CellTableIdentifier = @"AutoCellIdentifier";
      cell = [tableView dequeueReusableCellWithIdentifier: @"AutoCellIdentifier"];
      if (cell == nil) {
        CGRect cellFrame = CGRectMake(0, 0, 300, 65);
        cell = [[[UITableViewCell alloc] initWithFrame:cellFrame
            reuseIdentifier:CellTableIdentifier] autorelease];

        nameLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 5, 160, 30)];
        nameLabel.text = @"Auto Start Service:";

        autoSwitch = [[[UISwitch alloc] 
               initWithFrame:CGRectMake(190, 14, 100, 30)] autorelease];
        autoSwitch.tag = TAG_SWITCH_AUTOSTART;
        [autoSwitch addTarget:self action:@selector(switchAction:)
            forControlEvents:UIControlEventValueChanged];

        [cell.contentView addSubview:nameLabel];
        [cell.contentView addSubview:autoSwitch];

        [nameLabel release];
      }

      autoSwitch = (UISwitch *)[cell.contentView viewWithTag: TAG_SWITCH_AUTOSTART];
      [autoSwitch setOn: [prefs GetAutoStart] animated:NO];
    }
  } else if (section == 2) {
    /* Network section */
    if (row == 0) {
      NSString *CellTableIdentifier = @"BcastCellIdentifier";
      cell = [tableView dequeueReusableCellWithIdentifier: @"BcastCellIdentifier"];
      if (cell == nil) {
        CGRect cellFrame = CGRectMake(0, 0, 300, 65);
        cell = [[[UITableViewCell alloc] initWithFrame:cellFrame 
            reuseIdentifier:CellTableIdentifier] autorelease];

        bcastLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 5, 100, 30)];
        bcastLabel.text = @"Broadcast: ";

        bcastTF = [[UITextField alloc] initWithFrame:CGRectMake(120, 10, 170, 30)];
        bcastTF.clearButtonMode = UITextFieldViewModeWhileEditing;
        bcastTF.keyboardType = UIKeyboardTypeNumbersAndPunctuation;
        bcastTF.returnKeyType = UIReturnKeyDone;
        bcastTF.delegate = self;
        bcastTF.tag = TAG_TF_BROADCAST;
            
        [cell.contentView addSubview:bcastLabel];
        [cell.contentView addSubview:bcastTF];

        [bcastLabel release];
        [bcastTF release];
      }

      bcastTF = (UITextField *)[cell.contentView viewWithTag: TAG_TF_BROADCAST];
      bcastTF.text = [prefs GetNetworkBroadcast];
    } else if (row == 1) {
      NSString *CellTableIdentifier = @"PortCellIdentifier";
      cell = [tableView dequeueReusableCellWithIdentifier: @"PortCellIdentifier"];
      if (cell == nil) {
        CGRect cellFrame = CGRectMake(0, 0, 300, 65);
        cell = [[[UITableViewCell alloc] initWithFrame:cellFrame 
            reuseIdentifier:CellTableIdentifier] autorelease];

        portLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 5, 100, 30)];
        portLabel.text = @"Port: ";

        portTF = [[UITextField alloc] initWithFrame:CGRectMake(120, 10, 170, 30)];
        portTF.clearButtonMode = UITextFieldViewModeWhileEditing;
        portTF.keyboardType = UIKeyboardTypeNumbersAndPunctuation;
        portTF.returnKeyType = UIReturnKeyDone;
        portTF.delegate = self;
        portTF.tag = TAG_TF_PORT;

        [cell.contentView addSubview:portLabel];
        [cell.contentView addSubview:portTF];

        [portLabel release];
        [portTF release];
      }

      portTF = (UITextField *)[cell.contentView viewWithTag: TAG_TF_PORT];
      portTF.text = [prefs GetNetworkPort];
    }
  } else if (section == 3) {
    /* Photo Section */
    if (row == 0) {
      NSString *CellTableIdentifier = @"PhotosContainerCellIdentifier";
      cell = [tableView dequeueReusableCellWithIdentifier: @"PhotosContainerCellIdentifier"];
      if (cell == nil) {
        CGRect cellFrame = CGRectMake(0, 0, 300, 65);
        cell = [[[UITableViewCell alloc] initWithFrame:cellFrame 
            reuseIdentifier:CellTableIdentifier] autorelease];

        containerLabel = [[UILabel alloc] initWithFrame:CGRectMake(10,5,100,30)];
        containerLabel.text = @"Container: ";
      
        containerTF = [[UITextField alloc] initWithFrame:CGRectMake(100, 14, 190, 30)];
        containerTF.font = [UIFont systemFontOfSize:12];
        containerTF.clearButtonMode = UITextFieldViewModeWhileEditing;
        containerTF.returnKeyType = UIReturnKeyDone;
        containerTF.delegate = self;
        containerTF.tag = TAG_TF_CONTAINER;

        [cell.contentView addSubview: containerLabel];
        [cell.contentView addSubview: containerTF];

        [containerLabel release];
        [containerTF release];
      }

      containerTF = (UITextField *)[cell.contentView viewWithTag: TAG_TF_CONTAINER];
      containerTF.text = [prefs GetPhotosContainer];
    } else if (row == 1) {
      NSString *CellTableIdentifier = @"JPEGCellIdentifier";
      cell = [tableView dequeueReusableCellWithIdentifier: @"JPEGCellIdentifier"];
      if (cell == nil) {
        CGRect cellFrame = CGRectMake(0, 0, 300, 65);
        cell = [[[UITableViewCell alloc] initWithFrame:cellFrame 
            reuseIdentifier:CellTableIdentifier] autorelease];

        jpegLabel = [[UILabel alloc] initWithFrame:CGRectMake(10,5,130,30)];
        jpegLabel.text = @"JPEG Quality";
     
        jpegSlider = [[UISlider alloc] initWithFrame: CGRectMake(10,40,270,25)];
        jpegSlider.tag = TAG_SLIDER_JPEG;
        jpegSlider.minimumValue = 0.0f;
        jpegSlider.maximumValue = 1.0f;
        [jpegSlider setContinuous: YES];
        [jpegSlider addTarget:self action:@selector(sliderEvent:)
               forControlEvents:UIControlEventValueChanged];
        //[jpegSlider setShowValue: YES];

        [cell.contentView addSubview: jpegLabel];
        [cell.contentView addSubview: jpegSlider];

        [jpegLabel release];
        [jpegSlider release];
      }

      jpegSlider = (UISlider *)[cell.contentView viewWithTag: TAG_SLIDER_JPEG];
      [jpegSlider setValue: [[prefs GetPhotosJPEGQuality] floatValue]];
    }
  } else if (section == 4) {
    if (row == 0) {
      NSString *CellTableIdentifier = @"MusicContainerCellIdentifier";
      cell = [tableView dequeueReusableCellWithIdentifier: @"MusicContainerCellIdentifier"];
      if (cell == nil) {
        CGRect cellFrame = CGRectMake(0, 0, 300, 65);
        cell = [[[UITableViewCell alloc] initWithFrame:cellFrame
            reuseIdentifier:CellTableIdentifier] autorelease];

        containerLabel = [[UILabel alloc] initWithFrame:CGRectMake(10,5,100,30)];
        containerLabel.text = @"Container: ";

        containerTF = [[UITextField alloc] initWithFrame:CGRectMake(100, 14, 190, 30)];
        containerTF.font = [UIFont systemFontOfSize:12];
        containerTF.clearButtonMode = UITextFieldViewModeWhileEditing;
        containerTF.returnKeyType = UIReturnKeyDone;
        containerTF.delegate = self;
        containerTF.tag = TAG_TF_MUSIC_CONTAINER;

        [cell.contentView addSubview: containerLabel];
        [cell.contentView addSubview: containerTF];

        [containerLabel release];
        [containerTF release];
      }

      containerTF = (UITextField *)[cell.contentView viewWithTag: TAG_TF_MUSIC_CONTAINER];
      containerTF.text = [prefs GetMusicContainer];
    }
  } 

  return cell;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
  [textField resignFirstResponder];
  return NO;
}

-(void)tableView:(UITableView *)tableView
      didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{

}


@end
