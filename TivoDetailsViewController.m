
#import "TivoDetailsViewController.h"
#import "AboutViewController.h"
#import "HelpViewController.h"
#import "CustomSpinningGearView.h"

#include <syslog.h>

@implementation TivoDetailsViewController
{

}

static const CGFloat KEYBOARD_ANIMATION_DURATION = 0.3;
static const CGFloat MINIMUM_SCROLL_FRACTION = 0.2;
static const CGFloat MAXIMUM_SCROLL_FRACTION = 0.8;
static const CGFloat PORTRAIT_KEYBOARD_HEIGHT = 216;
static const CGFloat LANDSCAPE_KEYBOARD_HEIGHT = 140;

static const NSInteger TAG_TF_MAK = 0;


-(void)loadView
{
  self.tableView = [[[UITableView alloc] initWithFrame: [[UIScreen mainScreen] bounds]
         style:UITableViewStyleGrouped] autorelease];
  self.title = @"Tivo Details";
}

-(void)tableView: (UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath*)indexPath
{
  int section = [indexPath section];
  int row = [indexPath row];

  if (section == 0 && row == 0) {
    syslog(LOG_DEBUG, "selected NowPlaying for tivo %s", [tivo->machine_name UTF8String]);

    tivoNowPlayingView = [[TivoNowPlayingViewController alloc] autorelease];
    [tivoNowPlayingView setTivoDevice: tivo];
    [tivoNowPlayingView setDVRMobilePrefs: prefs];
   
    if ([tivo->platform hasPrefix: @"tcd/"]) {
      [tivoNowPlayingView setUri: @"%2FNowPlaying"];
    } else {
      [tivoNowPlayingView setUri: @"%2F"];
    }

    [self.navigationController pushViewController: tivoNowPlayingView animated:YES];
  }
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
  viewFrame.origin.y += 120;

  [UIView beginAnimations:nil context:NULL];
  [UIView setAnimationBeginsFromCurrentState:YES];
  [UIView setAnimationDuration:KEYBOARD_ANIMATION_DURATION];

  [self.view setFrame:viewFrame];

  [UIView commitAnimations];

}

- (void)textFieldDidEndEditing:(UITextField *)textField
{
  CGRect viewFrame = self.view.frame;
  viewFrame.origin.y += animatedDistance;
  viewFrame.origin.y -= 120;

  [UIView beginAnimations:nil context:NULL];
  [UIView setAnimationBeginsFromCurrentState:YES];
  [UIView setAnimationDuration:KEYBOARD_ANIMATION_DURATION];

  [self.view setFrame:viewFrame];

  [UIView commitAnimations];

  /* commit changes to preferences */
  if (textField.tag == TAG_TF_MAK) {
    tivo->mak = textField.text;
    [tivo->mak retain];
    [prefs SetDirty: YES];
  }
}

-(void)viewDidLoad {
  //helpBtn = [[UIBarButtonItem alloc] initWithTitle:@"Help" style:UIBarButtonItemStyleBordered
  //      target:self action:@selector(help:)];

  //self.navigationItem.rightBarButtonItem = helpBtn;
}

-(void)help:(id)sender
{
  HelpViewController *helpView = [HelpViewController alloc];
  [self.navigationController pushViewController: helpView animated:YES];
}

-(void)about:(id)sender
{
  AboutViewController *aboutView = [AboutViewController alloc];
  [self.navigationController pushViewController: aboutView animated:YES];
}


-(NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
  return 2;
}

-(NSInteger)tableView: (UITableView*)tableView numberOfRowsInSection:(NSInteger)section
{
  if (section == 0) {
    if ([tivo->platform hasPrefix: @"tcd/Series3"])
      return 2;
    else
      return 1;
  } else {
    return 7;
  }
}

-(NSString*)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
  if (section == 0)
    return @"Device Options";
  if (section == 1)
    return @"Tivo Details";

  return nil;
}

-(UITableViewCell *)tableView:(UITableView *)tableView
    cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
  int section = [indexPath section];
  int row = [indexPath row];

  UITableViewCell *cell;
  if (section == 0) {
    if (row == 0) {
      cell = [tableView dequeueReusableCellWithIdentifier: @"NowPlayingIdentifier"];
      if (cell == nil) {
        CGRect cellFrame = CGRectMake(0, 0, 300, 65);
        cell = [[[UITableViewCell alloc] initWithFrame:cellFrame
        reuseIdentifier:@"NowPlayingIdentifier"] autorelease];
      }

      nowPlayingLabel = [[UILabel alloc] initWithFrame:CGRectMake(10,5,280,35)];
      nowPlayingLabel.font = [UIFont boldSystemFontOfSize:18];

      if ([tivo->platform hasPrefix: @"tcd/"])
        nowPlayingLabel.text = @"Now Playing";
      else
        nowPlayingLabel.text = @"View Media";
      
      cell.accessoryType = UITableViewCellAccessoryDetailDisclosureButton; 
      [cell.contentView addSubview:nowPlayingLabel]; 
    } else if (row == 1) {
      cell = [tableView dequeueReusableCellWithIdentifier: @"remoteIdentifier"];
      if (cell == nil) {
        CGRect cellFrame = CGRectMake(0, 0, 300, 65);
        cell = [[[UITableViewCell alloc] initWithFrame:cellFrame
        reuseIdentifier:@"remoteIdentifier"] autorelease];
      }

      remoteLabel = [[UILabel alloc] initWithFrame:CGRectMake(10,5,280,35)];
      remoteLabel.font = [UIFont boldSystemFontOfSize:18];
      remoteLabel.text = @"Remote Control";
     
      cell.accessoryType = UITableViewCellAccessoryDetailDisclosureButton; 
      [cell.contentView addSubview:remoteLabel]; 
    }
  } else if (section == 1) {
    /* General section */
    if (row == 0) {
      cell = [tableView dequeueReusableCellWithIdentifier: @"machineIdentifier"];
      if (cell == nil) {
        CGRect cellFrame = CGRectMake(0, 0, 300, 65);
        cell = [[[UITableViewCell alloc] initWithFrame:cellFrame
        reuseIdentifier:@"machineIdentifier"] autorelease];

        machineLabel = [[UILabel alloc] initWithFrame:CGRectMake(10,5,80,30)];
        machineLabel.text = @"Name: ";

        machineTF = [[UITextField alloc] initWithFrame:CGRectMake(100,8,150,30)];
        machineTF.text = tivo->machine_name;
        machineTF.enabled = NO;
     
        [cell.contentView addSubview:machineLabel]; 
        [cell.contentView addSubview:machineTF]; 

        [machineLabel release];
        [machineTF release];
      }
    } else if (row == 1) {
      cell = [tableView dequeueReusableCellWithIdentifier: @"addressIdentifier"]; 
      if (cell == nil) {
        CGRect cellFrame = CGRectMake(0, 0, 300, 65);
        cell = [[[UITableViewCell alloc] initWithFrame:cellFrame
        reuseIdentifier:@"addressIdentifier"] autorelease];

        addressLabel = [[UILabel alloc] initWithFrame:CGRectMake(10,5,80,30)];
        addressLabel.text = @"Address: ";

        addressTF = [[UITextField alloc] initWithFrame:CGRectMake(100,8,150,30)];
        addressTF.text = tivo->address;
        addressTF.enabled = NO;
     
        [cell.contentView addSubview:addressLabel]; 
        [cell.contentView addSubview:addressTF]; 

        [addressLabel release];
        [addressTF release];
      }
    } else if (row == 2) {
      cell = [tableView dequeueReusableCellWithIdentifier: @"identityIdentifier"];
      if (cell == nil) {
        CGRect cellFrame = CGRectMake(0, 0, 300, 65);
        cell = [[[UITableViewCell alloc] initWithFrame:cellFrame
        reuseIdentifier:@"identityIdentifier"] autorelease];

        identityLabel = [[UILabel alloc] initWithFrame:CGRectMake(10,5,80,30)];
        identityLabel.text = @"Identity: ";

        identityTF = [[UITextField alloc] initWithFrame:CGRectMake(100,9,150,30)];
        if ([tivo->identity length] > 20)
          identityTF.font = [UIFont systemFontOfSize: 10];
        else if ([tivo->identity length] > 12)
          identityTF.font = [UIFont systemFontOfSize: 12];
        identityTF.text = tivo->identity;
        identityTF.enabled = NO;
     
        [cell.contentView addSubview:identityLabel]; 
        [cell.contentView addSubview:identityTF]; 

        [identityLabel release];
        [identityTF release];
      }
    } else if (row == 3) {
      cell = [tableView dequeueReusableCellWithIdentifier: @"platformIdentifier"];
      if (cell == nil) {
        CGRect cellFrame = CGRectMake(0, 0, 300, 65);
        cell = [[[UITableViewCell alloc] initWithFrame:cellFrame
        reuseIdentifier:@"platformIdentifier"] autorelease];

        platformLabel = [[UILabel alloc] initWithFrame:CGRectMake(10,5,80,30)];
        platformLabel.text = @"Platform: ";

        platformTF = [[UITextField alloc] initWithFrame:CGRectMake(100,8,150,30)];
        platformTF.text = tivo->platform;
        platformTF.enabled = NO;
     
        [cell.contentView addSubview:platformLabel]; 
        [cell.contentView addSubview:platformTF]; 

        [platformLabel release];
        [platformTF release];
      }
    } else if (row == 4) {
      cell = [tableView dequeueReusableCellWithIdentifier: @"swversionIdentifier"]; 
      if (cell == nil) {
        CGRect cellFrame = CGRectMake(0, 0, 300, 65);
        cell = [[[UITableViewCell alloc] initWithFrame:cellFrame
        reuseIdentifier:@"swversionIdentifier"] autorelease];

        swversionLabel = [[UILabel alloc] initWithFrame:CGRectMake(10,5,80,30)];
        swversionLabel.text = @"Version: ";

        swversionTF = [[UITextField alloc] initWithFrame:CGRectMake(100,8,150,30)];
        swversionTF.text = tivo->swversion;
        swversionTF.enabled = NO;

        [cell.contentView addSubview:swversionLabel];
        [cell.contentView addSubview:swversionTF]; 

        [swversionLabel release];
        [swversionTF release];
      }
    } else if (row == 5) {
      cell = [tableView dequeueReusableCellWithIdentifier: @"servicesIdentifier"];
      if (cell == nil) {
        CGRect cellFrame = CGRectMake(0, 0, 300, 65);
        cell = [[[UITableViewCell alloc] initWithFrame:cellFrame
        reuseIdentifier:@"servicesIdentifier"] autorelease];

        servicesLabel = [[UILabel alloc] initWithFrame:CGRectMake(10,5,80,30)];
        servicesLabel.text = @"Services: ";

        servicesTF = [[UITextField alloc] initWithFrame:CGRectMake(100,9,150,30)];
        servicesTF.text = tivo->services;
        servicesTF.enabled = NO;
        servicesTF.font = [UIFont systemFontOfSize:12];
     
        [cell.contentView addSubview:servicesLabel]; 
        [cell.contentView addSubview:servicesTF]; 

        [servicesLabel release];
        [servicesTF release];
      }
    } else if (row == 6) {
      cell = [tableView dequeueReusableCellWithIdentifier: @"makIdentifier"]; 
      if (cell == nil) {
        CGRect cellFrame = CGRectMake(0, 0, 300, 65);
        cell = [[[UITableViewCell alloc] initWithFrame:cellFrame
        reuseIdentifier:@"makIdentifier"] autorelease];

        makLabel = [[UILabel alloc] initWithFrame:CGRectMake(10,5,80,30)];
        makLabel.text = @"MAK: ";

        makTF = [[UITextField alloc] initWithFrame:CGRectMake(100,8,150,30)];
        makTF.clearButtonMode = UITextFieldViewModeWhileEditing;
        makTF.returnKeyType = UIReturnKeyDone;
        makTF.delegate = self;
        makTF.tag = TAG_TF_MAK;
        if (tivo->mak != nil)
          makTF.text = tivo->mak;
        else
          makTF.text = @"";
     
        [cell.contentView addSubview:makLabel]; 
        [cell.contentView addSubview:makTF]; 

        [makLabel release];
        [makTF release];
      }
    }
  }

  return cell;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
  [textField resignFirstResponder];
  return NO;
}

- (void)setTivoDevice:(TivoDevice *)t
{
  tivo = t;
}

-(void)setDVRMobilePrefs: (DVRMobilePrefs*)p
{
  prefs = p;
}

@end
