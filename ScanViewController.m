
#import "ScanViewController.h"
#import "TivoDetailsViewController.h"

#include <syslog.h>
#include <time.h>

@implementation ScanViewNavController
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

-(void)setTivoObjects: (Beacon*)b withHttpServer:(TiVoHTTPServer*)h
{
  beacon = b;
  httpd = h;
}

-(void)setDVRMobilePrefs: (DVRMobilePrefs*)p
{
  prefs = p;
  tivos = [prefs GetTivos];
}

@end;

@implementation ScanViewController
{

}

-(void)loadView
{
  self.tableView = [[[UITableView alloc] initWithFrame:
       [[UIScreen mainScreen] bounds]] autorelease];
  self.title = @"Devices";

  refreshBtn = [[[UIBarButtonItem alloc] 
        initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh 
        target:self action:@selector(refreshTable:)] autorelease];

  tivoIcon = [UIImage imageNamed:@"icon2.png"];
  pcIcon = [UIImage imageNamed:@"pc.png"];
  iphoneIcon = [UIImage imageNamed:@"iphone.png"];

  customSpinningGearView = [[CustomSpinningGearView alloc] autorelease];
  [customSpinningGearView initialize];
  [customSpinningGearView setText: @"Scanning"];

  [self.view addSubview: customSpinningGearView];
}

-(void)refreshTable: (id) sender
{
  /* the beacon is already scanning, simply reload the table data */
  [customSpinningGearView show];

  [NSThread detachNewThreadSelector:@selector(refreshTableThread:)
       toTarget:self withObject:nil];

  [self.tableView reloadData];
}

-(void)refreshTableThread: (id) sender
{
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

  sleep(2);

  [self.tableView reloadData];

  [customSpinningGearView stop];

  [pool release];
}

-(void)viewDidLoad {
  self.navigationItem.rightBarButtonItem = refreshBtn;
}

-(void)setTivoObjects: (Beacon*)b withHttpServer:(TiVoHTTPServer*)h
{
  beacon = b;
  httpd = h;
}

-(void)setDVRMobilePrefs: (DVRMobilePrefs*)p
{
  prefs = p;
  tivos = [prefs GetTivos];
}

-(void)tableView:(UITableView *)tableView willBeginEditingRowAtIndexPath:(NSIndexPath *)indexPath
{
  syslog(LOG_DEBUG, "willBeginEditingRowAtIndexPath..");
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath
{
  syslog(LOG_DEBUG, "editingStyleForRowAtIndexPath..");
  return UITableViewCellEditingStyleDelete;
}

-(void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle 
       forRowAtIndexPath:(NSIndexPath *)indexPath
{
  int row = [indexPath row];

  syslog(LOG_DEBUG, "commitEditingStyle for row %d..", row);

  [tivos removeObjectAtIndex: row]; 
  [prefs SetDirty: YES];
  [tableView deleteRowsAtIndexPaths: [NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationFade];
}

-(NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
  return 1;
}

-(NSInteger)tableView:(UITableView*)tableView numberOfRowsInSection:(NSInteger)section
{
  if ([tivos count] > 0) {
    return [tivos count];
  }

  return 1;
}

-(UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
  static NSString *MyIdentifier = @"TivoCellIdentifier";
  UILabel *machineLabel, *descrLabel;

  UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:MyIdentifier];
  if (cell == nil) {
    CGRect cellFrame = CGRectMake(0, 0, 300, 70);
    cell = [[[UITableViewCell alloc] initWithFrame:cellFrame reuseIdentifier:MyIdentifier] autorelease];
  }

  int row = [indexPath row];
  if ([tivos count] > 0) {
    TivoDevice *device = [tivos objectAtIndex:row];

    machineLabel = [[UILabel alloc] initWithFrame:CGRectMake(80,5,290,35)];
    descrLabel = [[UILabel alloc] initWithFrame:CGRectMake(80,45,290,25)];

    if ([device->machine_name length] > 20)
      machineLabel.font = [UIFont boldSystemFontOfSize:18];
    else
      machineLabel.font = [UIFont boldSystemFontOfSize:20];
    machineLabel.text = device->machine_name;

    descrLabel.font = [UIFont boldSystemFontOfSize:14];
    descrLabel.textColor = [UIColor lightGrayColor];
    descrLabel.text = [[[device->platform 
               stringByAppendingString: @" ["]
               stringByAppendingString: device->address]
               stringByAppendingString: @"]"];

    [cell setText: @""];

    if (device->platform == nil)
      [cell setImage: tivoIcon];
    if ([device->platform hasPrefix:@"pc/iphone"])
      [cell setImage: iphoneIcon];
    else if ([device->platform hasPrefix:@"pc"])
      [cell setImage: pcIcon];
    else
      [cell setImage: tivoIcon];

    [cell.contentView addSubview: machineLabel];
    [cell.contentView addSubview: descrLabel];

    [descrLabel release];
    [machineLabel release];
  } else {
    [cell setText:@"[No TiVo Devices Found]"];
    cell.textAlignment = UITextAlignmentCenter;
  }

  return cell;
}

-(NSIndexPath *) tableView:(UITableView *)tableView
      willSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
  if ([tivos count] == 0)
    return nil;

  return indexPath;
}

-(void)tableView:(UITableView *)tableView 
      didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
  int row = [indexPath row];

  if ([tivos count] > 0) {
    TivoDevice *tivo = [tivos objectAtIndex:row];

    syslog(LOG_INFO, "selected tivo device %s", [tivo->machine_name UTF8String]);
    
    tivoView = [[TivoDetailsViewController alloc] autorelease];
    [tivoView setTivoDevice: tivo];
    [tivoView setDVRMobilePrefs: prefs];
    [self.navigationController pushViewController: tivoView animated:YES];
  }
}

-(CGFloat)tableView:(UITableView*)tableView heightForRowAtIndexPath:(NSIndexPath*)indexPath
{
  return 80.0;
}

- (void)viewWillAppear:(BOOL)animated 
{
  [super viewWillAppear:animated];

  [self.tableView reloadData];
}

- (void)viewDidAppear:(BOOL)animated 
{
  [super viewDidAppear:animated];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation 
{
  // Return YES for supported orientations
  return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

- (void)didReceiveMemoryWarning 
{
  [super didReceiveMemoryWarning]; // Releases the view if it doesn't have a superview
  // Release anything that's not essential, such as cached data
}

- (void)dealloc 
{
  [super dealloc];
}

@end
