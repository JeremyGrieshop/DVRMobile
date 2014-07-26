
#import "TransfersViewController.h"
#import "TivoDetailsViewController.h"

#include <syslog.h>
#include <time.h>

@implementation TransfersViewNavController
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

@implementation TransfersViewController
{

}

-(void)loadView
{
  self.title = @"Transfers";
  //self.tableView = [[UITableView alloc] initWithFrame:
  //     [[UIScreen mainScreen] bounds]];
  self.view = [[[UIImageView alloc] 
      initWithImage:[UIImage imageNamed:@"transfers_coming_soon.png"]] autorelease];
}

-(void)viewDidLoad 
{
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

-(NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
  return 1;
}

-(NSInteger)tableView:(UITableView*)tableView numberOfRowsInSection:(NSInteger)section
{
  return 1;
}

-(UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
  static NSString *MyIdentifier = @"MyIdentifier";

  UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:MyIdentifier];
  if (cell == nil) {
    CGRect cellFrame = CGRectMake(0, 0, 300, 70);
    cell = [[[UITableViewCell alloc] initWithFrame:cellFrame reuseIdentifier:MyIdentifier] autorelease];
  }

  //[cell setText:@"    [Feature Not Implemented]"];
  //cell.textAlignment = UITextAlignmentCenter;

  return cell;
}

-(NSIndexPath *) tableView:(UITableView *)tableView
      willSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
  return nil;
}

-(void)tableView:(UITableView *)tableView 
      didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
  int row = [indexPath row];
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
