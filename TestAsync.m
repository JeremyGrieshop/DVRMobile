
#import "TivoNowPlayingViewController.h"
#import "TivoDetailsViewController.h"
#import "VideoDetailsController.h"
#import "ImageDetailsController.h"
#import "TiVoHTTPClient.h"
#import "CustomSpinningGearView.h"
#import "AsyncImageView.h"

#include <syslog.h>
#include <time.h>

@implementation ThumbnailCell
{

}

-(id)initWithFrame:(CGRect)frame reuseIdentifier:(NSString*)reuseIdentifier
{
syslog(LOG_DEBUG, "ThumbnailCell initWithFrame initWithFrame()");

  if (self = [super initWithFrame:frame reuseIdentifier:reuseIdentifier]) {
    UIView *view = self.contentView;

    [self setText: @"test.."];
  }
 
  return self;
}

-(void)dealloc
{
  syslog(LOG_DEBUG, "ThumbnailCell dealloc called..");
  [super dealloc];
}

-(void)touchesBegan: (NSSet *)touches withEvents: (UIEvent *)event
{
  syslog(LOG_DEBUG, "touchesBegan..");
}

@end

@implementation TivoNowPlayingViewController
{

}

-(void)loadView
{
  self.tableView = [[[UITableView alloc] initWithFrame:
       [[UIScreen mainScreen] bounds]] autorelease];
  self.title = @"Now Playing";

  video_icon = [UIImage imageNamed:@"video.png"];
  audio_icon = [UIImage imageNamed:@"audio.png"];
  photo_icon = [UIImage imageNamed:@"photo.png"];
  folder_icon = [UIImage imageNamed:@"folder.png"];
  
  spinningGear = [[CustomSpinningGearView alloc] autorelease];
  [spinningGear initialize];
  [spinningGear setText: @"Loading Data.."];
  
  [self.view addSubview: spinningGear];
}

-(void)LoadData: (id)anObject
{
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

  [self.view bringSubviewToFront: spinningGear];

  if (serviceProtocol && servicePort) {
    client = [[TiVoHTTPClient alloc] autorelease];

    /* tivos all seem to require SSL on port 443 */
    if ([tivo->platform hasPrefix: @"tcd/"])
      [client initialize: tivo->address port:443 secure:YES
           user:@"tivo" password: tivo->mak];
    else if ([serviceProtocol isEqualToString: @"https"])
      [client initialize: tivo->address port:servicePort secure:YES
           user:@"tivo" password: tivo->mak];
    else
      [client initialize: tivo->address port:servicePort secure:NO
           user:@"tivo" password: tivo->mak];

    syslog(LOG_DEBUG, "LoadData, fetching uri = %s", [uri UTF8String]);
    container = [client QueryContainer: uri];

    if (container) {
      [container retain];
      [container->items retain];
      int i = 0;
      for (i = 0; i < container->totalItems; i++) {
        TiVoItem *item = [container->items objectAtIndex:i];
        [item retain];
        [item->title retain];
        [item->contentType retain];
        [item->description retain];
        [item->episodeTitle retain];
        [item->captureDate retain];
        [item->duration retain];
        [item->url retain];
      }
    } else {
      NSString *errorString = [NSString stringWithFormat: @"An error occured connecting to this device.  Make sure the device is online and you have entered the correct MAK key, if appropriate.  Error Code is %d", [client GetErrorCode]];
      UIAlertView *warningAlert = [[UIAlertView alloc] initWithTitle:@"Error"
          message: errorString delegate:nil cancelButtonTitle: nil otherButtonTitles:@"Ok", nil];
      [warningAlert show];
      [warningAlert release];
    }
  }

  syslog(LOG_DEBUG, "NowPlaying.. stopping gear and reloading data");

  [spinningGear stop];
  [self.tableView reloadData];
 
  if (container) 
    syslog(LOG_INFO, "QueryContainer returned %d.", container->totalItems);
  else
    syslog(LOG_INFO, "QueryContainer returned no container");

  [pool release];
}

-(void)viewDidLoad 
{
  syslog(LOG_INFO, "viewDidLoad..");
  [self.view bringSubviewToFront: spinningGear];
}

-(void)setDVRMobilePrefs: (DVRMobilePrefs*)p
{
  prefs = p;
}

-(void)setTivoDevice: (TivoDevice*)t
{
  tivo = t;

  /* parse out the services */
  if ([tivo->services hasPrefix: @"TiVoMediaServer:"]) {
    NSArray *services= [tivo->services componentsSeparatedByString:@"/"];
    if (services && [services count] > 1) {
      serviceProtocol = [services objectAtIndex:1];
      [serviceProtocol retain];

      NSString *tempStr = [services objectAtIndex:0];
      NSArray *tempArr = [tempStr componentsSeparatedByString:@":"];
      if ([tempArr count] > 1) {
        servicePort = [[tempArr objectAtIndex:1] intValue];
      }
    }
  }
}

-(void)setUri: (NSString*)u
{
  syslog(LOG_DEBUG, "setting uri to %s", [u UTF8String]);
  uri = u;
  [uri retain];
}

-(NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
  return 1;
}

-(NSInteger)tableView:(UITableView*)tableView numberOfRowsInSection:(NSInteger)section
{
  if (container) {
    if ([container->contentType hasPrefix: @"image"]) {
      if (container->totalItems % 4)
        return (container->totalItems / 4 + 1);
      else
        return (container->totalItems / 4);
    } else {
      return container->totalItems;
    }
  } else
    return 0;
}

#define TITLE_TAG   1
#define DESCR_TAG   2
#define ASYNC1_TAG  3
#define ASYNC2_TAG  4
#define ASYNC3_TAG  5
#define ASYNC4_TAG  6

-(UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
  UILabel *titleLabel, *descrLabel;
  UITableViewCell *cell;
  static NSString *photoCellIdentifier = @"PhotoCell";

  UITableViewCell *folderCell = [tableView dequeueReusableCellWithIdentifier:@"FolderCell"];
  if (folderCell == nil) {
    CGRect cellFrame = CGRectMake(0, 0, 300, 60);
    folderCell = [[[UITableViewCell alloc] initWithFrame:cellFrame reuseIdentifier:@"FolderCell"] autorelease];
    [folderCell setImage: folder_icon];
    folderCell.accessoryType = UITableViewCellAccessoryDetailDisclosureButton;
    titleLabel = [[[UILabel alloc] initWithFrame:CGRectMake(80,5,205,50)] autorelease];
    titleLabel.lineBreakMode = UILineBreakModeWordWrap;
    titleLabel.tag = TITLE_TAG;

    [folderCell.contentView addSubview: titleLabel];
    [folderCell setText: @""];
  }

  UITableViewCell *videoCell = [tableView dequeueReusableCellWithIdentifier:@"VideoCell"];
  if (videoCell == nil) {
    CGRect cellFrame = CGRectMake(0, 0, 300, 60);
    videoCell = [[[UITableViewCell alloc] initWithFrame:cellFrame reuseIdentifier:@"VideoCell"] autorelease];
    [videoCell setImage: video_icon];
    descrLabel = [[[UILabel alloc] initWithFrame:CGRectMake(80,35,210,20)] autorelease];
    descrLabel.tag = DESCR_TAG;
    titleLabel = [[[UILabel alloc] initWithFrame:CGRectMake(80,3,270,32)] autorelease];
    titleLabel.lineBreakMode = UILineBreakModeWordWrap;
    titleLabel.tag = TITLE_TAG;

    [videoCell.contentView addSubview: titleLabel];
    [videoCell.contentView addSubview: descrLabel];
    [videoCell setText: @""];
  }

  UITableViewCell *audioCell = [tableView dequeueReusableCellWithIdentifier:@"AudioCell"];
  if (audioCell == nil) {
    CGRect cellFrame = CGRectMake(0, 0, 300, 60);
    audioCell = [[[UITableViewCell alloc] initWithFrame:cellFrame reuseIdentifier:@"AudioCell"] autorelease];
    [audioCell setImage: audio_icon];
    titleLabel = [[[UILabel alloc] initWithFrame:CGRectMake(80,5,220,35)] autorelease];
    titleLabel.lineBreakMode = UILineBreakModeWordWrap;
    titleLabel.tag = TITLE_TAG;

    [audioCell.contentView addSubview: titleLabel];
    [audioCell setText: @""];
  }

  ThumbnailCell *photoCell = [tableView dequeueReusableCellWithIdentifier:photoCellIdentifier];
  if (photoCell == nil && [container->contentType hasPrefix: @"image/"]) {
    CGRect cellFrame = CGRectMake(0, 0, 300, 75);
    photoCell = [[[ThumbnailCell alloc] initWithFrame:cellFrame reuseIdentifier:photoCellIdentifier] autorelease];
  } else if (photoCell && [container->contentType hasPrefix: @"image/"]) {
    AsyncImageView *oldImage = (AsyncImageView *)[photoCell.contentView 
          viewWithTag:ASYNC1_TAG];
    if (oldImage != nil)
      [oldImage removeFromSuperview];
    oldImage = (AsyncImageView *)[photoCell.contentView viewWithTag:ASYNC2_TAG];
    if (oldImage != nil)
      [oldImage removeFromSuperview];
    oldImage = (AsyncImageView *)[photoCell.contentView viewWithTag:ASYNC3_TAG];
    if (oldImage != nil)
      [oldImage removeFromSuperview];
    oldImage = (AsyncImageView *)[photoCell.contentView viewWithTag:ASYNC4_TAG];
    if (oldImage != nil)
      [oldImage removeFromSuperview];

    if (oldImage)
      syslog(LOG_DEBUG, "oldImage was removed..");
  }

  UITableViewCell *unknownCell = [tableView dequeueReusableCellWithIdentifier:@"UnknownCell"];
  if (unknownCell == nil) {
    CGRect cellFrame = CGRectMake(0, 0, 300, 60);
    unknownCell = [[[UITableViewCell alloc] initWithFrame:cellFrame reuseIdentifier:@"UnknownCell"] autorelease];
    titleLabel = [[[UILabel alloc] initWithFrame:CGRectMake(80,5,220,35)] autorelease];
    titleLabel.lineBreakMode = UILineBreakModeWordWrap;
    titleLabel.tag = TITLE_TAG;

    [unknownCell.contentView addSubview: titleLabel];
    [unknownCell setText: @""];
  }

  int row = [indexPath row];
  if (container->totalItems > 0) {
    TiVoItem *item;

    if ([container->contentType hasPrefix: @"image/"])
      item = [container->items objectAtIndex:row*4];
    else
      item = [container->items objectAtIndex:row];

    if ([item->contentType hasPrefix: @"x-tivo-container/"] ||
        [item->contentType hasPrefix: @"x-container/"]) {
      cell = folderCell;

      titleLabel = (UILabel *)[cell.contentView viewWithTag: TITLE_TAG];
      titleLabel.minimumFontSize = 14.0;
      titleLabel.text = item->title;
      titleLabel.adjustsFontSizeToFitWidth = YES;
    } else if ([item->contentType hasPrefix:@"video/"]) {
      cell = videoCell;

      descrLabel = (UILabel *)[cell.contentView viewWithTag: DESCR_TAG];
      descrLabel.text = [NSString stringWithFormat: @"%d Minutes", 
             [(item->duration) intValue]/(1000*60)];
      descrLabel.minimumFontSize = 12.0;
      descrLabel.textColor = [UIColor lightGrayColor];
      descrLabel.adjustsFontSizeToFitWidth = YES;

      titleLabel = (UILabel *)[cell.contentView viewWithTag: TITLE_TAG];
      titleLabel.minimumFontSize = 14.0;
      if (item->episodeTitle) {
        titleLabel.text = item->episodeTitle;
      } else {
        titleLabel.text = item->title;
      }
      titleLabel.adjustsFontSizeToFitWidth = YES;
    } else if ([item->contentType hasPrefix: @"audio/"]) {
      cell = audioCell;

      titleLabel = (UILabel *)[cell.contentView viewWithTag: TITLE_TAG];
      titleLabel.text = item->title;
      titleLabel.minimumFontSize = 14.0;
      titleLabel.adjustsFontSizeToFitWidth = YES;
    } else if ([item->contentType hasPrefix: @"image/"]) {
      cell = photoCell;
      int i;
      for (i = row * 4; (i < container->totalItems) && (i < row*4+4); i++) {
        item = [container->items objectAtIndex: i];
        /* fetch this image thumbnail from the server */
        NSString *url;
        if ([item->url hasPrefix: @"/"])
          url = [NSString stringWithFormat: @"http://%@:%d%@?Height=75&Width=75", 
                  tivo->address, servicePort, item->url];
        else
          url = [NSString stringWithFormat: @"http://%@:%d/%@?Height=75&Width=75", 
                  tivo->address, servicePort, item->url];

        CGRect frame;
        AsyncImageView *asyncImage;
        if (i % 4 == 0) {
          frame = CGRectMake(0, 0, 75, 75);
          asyncImage = [[[AsyncImageView alloc] initWithFrame:frame] autorelease];
          asyncImage.tag = ASYNC1_TAG;
        } else if (i % 4 == 1) {
          frame = CGRectMake(80, 0, 75, 75);
          asyncImage = [[[AsyncImageView alloc] initWithFrame:frame] autorelease];
          asyncImage.tag = ASYNC2_TAG;
        } else if (i % 4 == 2) {
          frame = CGRectMake(160, 0, 75, 75);
          asyncImage = [[[AsyncImageView alloc] initWithFrame:frame] autorelease];
          asyncImage.tag = ASYNC3_TAG;
        } else {
          frame = CGRectMake(240, 0, 75, 75);
          asyncImage = [[[AsyncImageView alloc] initWithFrame:frame] autorelease];
          asyncImage.tag = ASYNC4_TAG;
        }

        NSURL *fetchUrl = [NSURL URLWithString: url];
        syslog(LOG_DEBUG, "fetching photo from: [%s]", [url UTF8String]);

        [asyncImage loadImageFromURL: fetchUrl];
        [cell.contentView addSubview: asyncImage];
      }
    } else {
      cell = unknownCell;

      titleLabel = (UILabel *)[cell.contentView viewWithTag: TITLE_TAG];
      titleLabel.text = item->title;
      titleLabel.minimumFontSize = 14.0;
      titleLabel.adjustsFontSizeToFitWidth = YES;
    }
  }

  return cell;
}

-(NSIndexPath *) tableView:(UITableView *)tableView
      willSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
  return indexPath;
}

-(void)tableView:(UITableView *)tableView 
      didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
  int row = [indexPath row];
  if (container) {
    TiVoItem *item = [container->items objectAtIndex: row];
    if ([item->contentType hasPrefix:@"x-tivo-container/"] ||
        [item->contentType hasPrefix:@"x-container/"]) {
      NSArray *uriList = [item->url componentsSeparatedByString:@"Container="];
      if (uriList && [uriList count] > 1) {
        NSString *newUri = [uriList objectAtIndex:1];

        /* expand to new container */
        TivoNowPlayingViewController *tivoNowPlayingView = 
               [[TivoNowPlayingViewController alloc] autorelease];
        [tivoNowPlayingView setTivoDevice: tivo];
        [tivoNowPlayingView setDVRMobilePrefs: prefs];

        [tivoNowPlayingView setUri: newUri];
  
        [self.navigationController pushViewController: tivoNowPlayingView animated:YES];
      }
    } else if ([item->contentType hasPrefix:@"video/"]) {
      VideoDetailsController *videoDetails = [[VideoDetailsController alloc] autorelease];
      [videoDetails setTiVoItem: item]; 

      [self.navigationController pushViewController: videoDetails animated:YES];
    } else if ([item->contentType hasPrefix:@"image/"]) {
      ImageDetailsController *imageView = [[ImageDetailsController alloc] autorelease];

      [imageView setTivoDevice: tivo];
      [imageView setServicePort: servicePort];
      [imageView setItems: container->items];
      [imageView setItemIndex: row];

      [self.navigationController pushViewController: imageView animated:YES];
    }
  }
}

-(CGFloat)tableView:(UITableView*)tableView heightForRowAtIndexPath:(NSIndexPath*)indexPath
{
  return 80.0;
}

- (void)viewWillAppear:(BOOL)animated 
{
  [super viewWillAppear:animated];

  if (container == nil) {
    [spinningGear show];

    [NSThread detachNewThreadSelector:@selector(LoadData:)
        toTarget:self withObject:nil];
  }

  //[self.tableView reloadData];
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
