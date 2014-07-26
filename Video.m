
#include "Video.h"
//#include "VideoLibrary.h"

#include <dirent.h>
#include <syslog.h>
#include <unistd.h>

#import <UIKit/UIKit.h>


@class MusicLibrary;
@class MLQuery;
@class MLTrack;


@implementation VideoFileEntry
{
}
@end

@implementation Video

-(NSString*)xmlEncode: (NSString *)str
{
  /* convert all chars <32 and >126 into &#; codes */
  NSMutableString *encodedStr = [[[NSMutableString alloc] init] autorelease];
  int i;
  for (i = 0; i < [str length]; i++) {
    unichar c = [str characterAtIndex: i];
    if (c < 32 || c > 126) {
      [encodedStr appendFormat:@"&#%d;", (int)c];
    } else {
      [encodedStr appendFormat:@"%C", c];
    }
  }

  encodedStr = [encodedStr stringByReplacingOccurrencesOfString:@"&" withString:@"&amp;"];
  encodedStr = [encodedStr stringByReplacingOccurrencesOfString:@"<" withString:@"&lt;"];
  encodedStr = [encodedStr stringByReplacingOccurrencesOfString:@">" withString:@"&gt;"];

  return encodedStr;
}

-(NSString*)xmlDecode: (NSString *)str
{
  NSString *decodedStr = str;

  decodedStr = [decodedStr stringByReplacingOccurrencesOfString:@"&amp;" withString:@"&"];
  decodedStr = [decodedStr stringByReplacingOccurrencesOfString:@"&lt;" withString:@"<"];
  decodedStr = [decodedStr stringByReplacingOccurrencesOfString:@"&gt;" withString:@">"];

  return decodedStr;
}

-(NSString*)urlEncode: (NSString *)url
{
  NSString *escapedUrl = [url stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
  escapedUrl = [escapedUrl stringByReplacingOccurrencesOfString:@"+" withString:@"%2B"]; 

  escapedUrl = [self xmlEncode: escapedUrl];

  return escapedUrl;
}

-(NSString*)urlDecode: (NSString *)url
{
  NSString *decodedUrl = url;

  /* unescape the url % codes */
  decodedUrl = [decodedUrl stringByReplacingOccurrencesOfString:@"%252F" withString:@"%2F"];
  decodedUrl = [decodedUrl stringByReplacingOccurrencesOfString:@"%2520" withString:@"%20"];
  decodedUrl = [decodedUrl stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];

  /* make sure to preserve XML-encoding */
  decodedUrl = [self xmlEncode: decodedUrl];

  return decodedUrl;
}

-(void)setRootContainer:(NSString*)root
{
  ROOT_CONTAINER        = root;
  _ROOT_CONTAINER       = [@"/" stringByAppendingString:root];
  DOWNLOADS		= [ROOT_CONTAINER stringByAppendingString:@"/Downloads"];
  _DOWNLOADS		= [_ROOT_CONTAINER stringByAppendingString:@"/Downloads"];
  PODCASTS              = [ROOT_CONTAINER stringByAppendingString:@"/Podcasts"];
  _PODCASTS             = [_ROOT_CONTAINER stringByAppendingString:@"/Podcasts"];
  MXTUBE                = [ROOT_CONTAINER stringByAppendingString:@"/MxTube"];
  _MXTUBE               = [_ROOT_CONTAINER stringByAppendingString:@"/MxTube"];
  CYCORDER              = [ROOT_CONTAINER stringByAppendingString:@"/Cycorder"];
  _CYCORDER             = [_ROOT_CONTAINER stringByAppendingString:@"/Cycorder"];

  DOWNLOADS_PATH        = @"/var/mobile/Library/Downloads";
  PODCASTS_PATH         = @"/var/mobile/Media/Podcasts";
  MXTUBE_PATH           = @"/var/mobile/Media/MxTube";
  CYCORDER_PATH         = @"/var/mobile/Media/Videos";
}

-(void)setResourceCache: (Cache*)cache
{
  resourceCache = cache;
}

-(void)LoadVideoEntries
{
  MusicLibrary *ml;
  MLQuery *query;
  VideoFileEntry *entry;

  syslog(LOG_INFO, "Loading video entries..");

  podcastEntries = [[[NSMutableArray alloc] initWithCapacity:50] autorelease];

  ml = [MusicLibrary sharedMusicLibrary];
  query = [[[MLQuery alloc] init] autorelease];

  int i;
  for (i = 0; i < [query countOfEntities]; i++) {
    MLTrack *track = [query entityAtIndex: i];
    if (track == nil)
      continue;

    /* we have a good track */
    entry = [[VideoFileEntry alloc] autorelease];
    entry->name = [[[NSString alloc] initWithString: [track title]] autorelease];
    entry->title = entry->name;
    entry->path = [[[NSString alloc] initWithString: [track path]] autorelease];
    entry->duration = [track durationInMS];
    entry->type = 1;

    /* always add a new track, alphabetically */
    int j;
    for (j = 0; j < [podcastEntries count]; j++) {
      VideoFileEntry *e = [podcastEntries objectAtIndex: j];
      if ([e->title compare: entry->title] == NSOrderedDescending)
        break;
    }
    [podcastEntries insertObject: entry atIndex: j];
  }

  /* log some messages */
  syslog(LOG_INFO, "Video LoadEntries loaded %d Podcasts.", [podcastEntries count]);

  /* load Downloads */
  downloadEntries = [[[NSMutableArray alloc] initWithCapacity:10] autorelease];
  allDownloadEntries = [[[NSMutableArray alloc] initWithCapacity:20] autorelease];
  [self ListDownloadsInternal: DOWNLOADS_PATH withArray:downloadEntries];

  syslog(LOG_INFO, "Video LoadEntries loaded %d downloads.", [downloadEntries count]);


  /* list cycorder videos */


  /* list mxtube videos */

}

-(BOOL)isVideoFilePrefix:(NSString*)path
{
  NSString *realPath = [path stringByReplacingOccurrencesOfString:@"%252F" withString:@"%2F"];
  realPath = [realPath stringByReplacingOccurrencesOfString:@"%2520" withString:@"%20"];
  realPath = [realPath stringByReplacingOccurrencesOfString:@"%252B" withString:@"%2B"];
  realPath = [realPath stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];

  syslog(LOG_DEBUG, "isVideoFilePrefix: %s", [realPath UTF8String]);

  if ([realPath hasPrefix: _ROOT_CONTAINER])
    return YES;
  else if ([realPath hasPrefix: ROOT_CONTAINER])
    return YES;
  else if ([realPath hasPrefix: DOWNLOADS_PATH])
    return YES;
  else if ([realPath hasPrefix: CYCORDER_PATH])
    return YES;
  else if ([realPath hasPrefix: MXTUBE_PATH])
    return YES;
  else if ([realPath hasPrefix: PODCASTS_PATH])
    return YES;
  else
    return NO;
}

-(void)SendFile: (NSString *)symbolicPath httpDelegate:(id)delegate
{
  char tmp[256];

  syslog(LOG_DEBUG, "Video SendFile for file = %s", [symbolicPath UTF8String]);

  NSString *realPath = [symbolicPath stringByReplacingOccurrencesOfString:@"%252F" withString:@"%2F"];
  realPath = [realPath stringByReplacingOccurrencesOfString:@"%2520" withString:@"%20"];
  realPath = [realPath stringByReplacingOccurrencesOfString:@"%252B" withString:@"%2B"];
  realPath = [realPath stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];

  NSString *path = [self TranslateSymbolicPath:symbolicPath];
  FILE *f = fopen([path UTF8String], "r");
  if (!f) {
    syslog(LOG_ERR, "Unable to open file [%s]", [path UTF8String]);
    return;
  }

  [delegate WriteString: "HTTP/1.0 200 OK\r\n" ];
  [delegate WriteString: "Server: DVRMobile/1.0\r\n" ];

  NSDate *today = [NSDate date];
  sprintf(tmp, "Date: %s\r\n", [[today description] UTF8String]);
  [delegate WriteString: tmp ];

  fseek(f, 0, SEEK_END);
  int fileSize = ftell(f);
  rewind(f);

  sprintf(tmp, "Content-Length: %d\r\n", fileSize);
  [delegate WriteString: tmp ];
  [delegate WriteString: "Content-Type: video/mpeg\r\n" ];
  [delegate WriteString: "Connection: close\r\n" ];
  [delegate WriteString: "\r\n" ];

  syslog(LOG_DEBUG, "Video request sending file..");
  char buf[4096];
  BOOL ok = YES;
  while (!feof(f) && ok) {
    int bytes = fread(buf, 1, 4096, f);
    if (bytes > 0) {
      ok = [delegate WriteData: buf size:bytes];
      syslog(LOG_DEBUG, "Video SendFile wrote %d bytes", bytes);
    }
  }

  fclose(f);

  syslog(LOG_DEBUG, "Video SendFile request ended.");
}

-(void)QueryItem: (NSString *)url
{

}

/*
 * Translates:
 *    "Downloads" to "/var/mobile/Downloads/"
 */
-(NSString*)TranslateSymbolicPath: (NSString *)symbolicPath
{
  NSString *realPath = symbolicPath;

  if (realPath == nil)
    return nil;

  /* unescape the url % codes */
  realPath = [realPath stringByReplacingOccurrencesOfString:@"%252F" withString:@"%2F"];
  realPath = [realPath stringByReplacingOccurrencesOfString:@"%2520" withString:@"%20"];
  realPath = [realPath stringByReplacingOccurrencesOfString:@"%252B" withString:@"%2B"];
  realPath = [realPath stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];

  NSRange range = [realPath rangeOfString:_DOWNLOADS];
  if (range.location != NSNotFound) {
    realPath = [realPath stringByReplacingOccurrencesOfString: _DOWNLOADS
                    withString:DOWNLOADS_PATH options:0 range:range];
  }

  range = [realPath rangeOfString:DOWNLOADS];
  if (range.location != NSNotFound) {
    realPath = [realPath stringByReplacingOccurrencesOfString:DOWNLOADS withString:DOWNLOADS_PATH];
  }

  return realPath;
}

-(void)ListVideo:(NSString*)path recursive:(BOOL)recurse withArray:(NSMutableArray*)list
{

  VideoFileEntry *entry;

  entry = [[VideoFileEntry alloc] autorelease];
  entry->name = @"Cycorder";
  entry->type = 0;
  entry->path = nil;
  [list addObject: entry];

  if (recurse) {
  }


  entry = [[VideoFileEntry alloc] autorelease];
  entry->name = @"Downloads";
  entry->type = 0;
  entry->path = nil;
  [list addObject: entry];

  if (recurse) {
    NSMutableArray *downloadList;
    downloadList = [self ListDownloads: DOWNLOADS_PATH recursive:recurse];
    int i = 0;
    for (i = 0; i < [downloadList count]; i++)
      [list addObject: [downloadList objectAtIndex:i]];
  }


  entry = [[VideoFileEntry alloc] autorelease];
  entry->name = @"MxTube";
  entry->type = 0;
  entry->path = nil;
  [list addObject: entry];

  if (recurse) {
  }


  entry = [[VideoFileEntry alloc] autorelease];
  entry->name = @"Podcasts";
  entry->type = 0;
  entry->path = nil;
  [list addObject: entry];

  if (recurse) {
  }
}

-(void)ListDownloadsInternal: (NSString*)path withArray:(NSMutableArray*)list
{
  DIR *dir;
  char buf[512];
  struct dirent *dirp;
  int type;

  sprintf(buf, "%s", [path UTF8String]);    
  if ((dir = opendir(buf)) == NULL) {
    syslog(LOG_ERR, "LoadDirectory: unable to open directory %s", buf);
    return;    
  }

  /* begin reading the directory */
  while ((dirp = readdir(dir)) != NULL) {
    NSString *name = [NSString stringWithCString: dirp->d_name];
    /* skip the hidden . dirs */
    if ([name hasPrefix:@"."])
      continue;

    /* for now only look for .mpeg files */
    if ((dirp->d_type != DT_DIR) && ![name hasSuffix:@".mpeg"] && ![name hasSuffix:@".MPEG"])
      continue;

    if (dirp->d_type == DT_DIR)
      type = 0;
    else
      type = 1;

    VideoFileEntry *entry = [[VideoFileEntry alloc] autorelease];
    entry->name = name;
    entry->type = type;
    entry->path = [[path stringByAppendingString:@"/"] stringByAppendingString:name];

    entry->title = nil; 

    [list addObject: entry];
    [allDownloadEntries addObject: entry];

    if (type == 0) {
      NSString *newPath = [path stringByAppendingString:@"/"];
      newPath = [newPath stringByAppendingString:name];
 
      entry->children = [[[NSMutableArray alloc] initWithCapacity:10] autorelease];
      [self ListDownloadsInternal: newPath withArray: entry->children];
    }
  }

  closedir(dir);
}

-(void)ListMxTubeInternal: (NSString*)path withArray:(NSMutableArray*)list
{
  DIR *dir;
  char buf[512];
  struct dirent *dirp;
  int type;

  sprintf(buf, "%s", [path UTF8String]);
  if ((dir = opendir(buf)) == NULL) {
    syslog(LOG_ERR, "LoadDirectory: unable to open directory %s", buf);
    return;
  }

  /* begin reading the directory */
  while ((dirp = readdir(dir)) != NULL) {
    NSString *name = [NSString stringWithCString: dirp->d_name];
    /* skip the hidden . dirs */
    if ([name hasPrefix:@"."])
      continue;

    /* for now only look for .mpeg files */
    if ((dirp->d_type != DT_DIR))
      continue;

    if (dirp->d_type == DT_DIR)
      type = 0;
    else
      type = 1;

    VideoFileEntry *entry = [[VideoFileEntry alloc] autorelease];
    entry->name = name;
    entry->type = type;
    entry->path = [[path stringByAppendingString:@"/"] stringByAppendingString:name];

    entry->title = nil;

    [list addObject: entry];
    [allDownloadEntries addObject: entry];

    if (type == 0) {
      NSString *newPath = [path stringByAppendingString:@"/"];
      newPath = [newPath stringByAppendingString:name];

      entry->children = [[[NSMutableArray alloc] initWithCapacity:10] autorelease];
      [self ListDownloadsInternal: newPath withArray: entry->children];
    }
  }

  closedir(dir);
}

-(void)ListCycorderInternal: (NSString*)path withArray:(NSMutableArray*)list   
{
  DIR *dir;
  char buf[512];
  struct dirent *dirp;
  int type;

  sprintf(buf, "%s", [path UTF8String]);
  if ((dir = opendir(buf)) == NULL) {
    syslog(LOG_ERR, "LoadDirectory: unable to open directory %s", buf);
    return;
  }

  /* begin reading the directory */
  while ((dirp = readdir(dir)) != NULL) {
    NSString *name = [NSString stringWithCString: dirp->d_name];
    /* skip the hidden . dirs */
    if ([name hasPrefix:@"."])
      continue;

    /* for now only look for .mov files */
    if ((dirp->d_type != DT_DIR))                                                            
      continue;

    if (dirp->d_type == DT_DIR)
      type = 0;
    else
      type = 1;

    VideoFileEntry *entry = [[VideoFileEntry alloc] autorelease];
    entry->name = name;
    entry->type = type;
    entry->path = [[path stringByAppendingString:@"/"] stringByAppendingString:name];

    entry->title = nil;

    [list addObject: entry];
    [allDownloadEntries addObject: entry];

    if (type == 0) {
      NSString *newPath = [path stringByAppendingString:@"/"];
      newPath = [newPath stringByAppendingString:name];

      entry->children = [[[NSMutableArray alloc] initWithCapacity:10] autorelease];
      [self ListDownloadsInternal: newPath withArray: entry->children];
    }
  }

  closedir(dir);
}


-(NSMutableArray *) ListDownloads: (NSString*)path recursive:(BOOL)recurse
{
  NSString *name;
  VideoFileEntry *entry;

  if ([path isEqualToString: DOWNLOADS_PATH] && recurse) {
    return allDownloadEntries;
  } else if ([path isEqualToString: DOWNLOADS_PATH]) {
    return downloadEntries;
  }

  int i;
  for (i = 0; i < [allDownloadEntries count]; i++) {
    entry = [allDownloadEntries objectAtIndex:i];
    name = entry->name;

    NSRange range = [path rangeOfString: name];
    if (range.location != NSNotFound) {
      return entry->children;
    }
  }

  return nil;
}

-(NSMutableArray *)Shuffle: (NSMutableArray*)list withSeed:(int)seed withStart:(NSString*)start
{
  NSMutableArray *shuffle = [[[NSMutableArray alloc] initWithCapacity: [list count]] autorelease];
  NSMutableArray *temp = [[[NSMutableArray alloc] initWithCapacity: [list count]] autorelease];

  int i = 0;
  for (i = 0; i < [list count]; i++) {
    VideoFileEntry *entry = [list objectAtIndex: i];
    [temp addObject: entry]; 
  }

  srand(seed);

  i = random() % [list count];
  while ([temp count] > 0) {
    VideoFileEntry *entry = [temp objectAtIndex: i];
    [temp removeObjectAtIndex: i];

    if ([entry->path isEqualToString: start])
      [shuffle insertObject: entry atIndex:0];
    else
      [shuffle addObject: entry]; 

    i = random() % [temp count];
  }

  return shuffle;
}

-(void)QueryContainer: (NSString*)symbolicPath itemCount:(int)itemCount
         anchorItem:(NSString*)anchor anchorOffset:(int)anchorOffset
         recursive:(BOOL)recurse sortOrder:(NSString*)sortOrder 
         randomSeed:(int)randomSeed randomStart:(NSString*)randomStart
         filter:(NSString*)filter httpDelegate:(id)delegate
{
  char tmp[512];
  syslog(LOG_DEBUG, "Video QueryContainer: %s", [symbolicPath UTF8String]);

  NSString *realPath = [symbolicPath stringByReplacingOccurrencesOfString:@"%252F" withString:@"%2F"];
  realPath = [realPath stringByReplacingOccurrencesOfString:@"%2520" withString:@"%20"];
  realPath = [realPath stringByReplacingOccurrencesOfString:@"%252B" withString:@"%2B"];
  realPath = [realPath stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];

  NSRange range = [realPath rangeOfString:ROOT_CONTAINER];
  if (range.location == NSNotFound) {
    syslog(LOG_ERR, "QueryContainer, invalid path!");
    return;
  }

  NSString *path = [self TranslateSymbolicPath: symbolicPath];
  syslog(LOG_DEBUG, "Video QueryContainer, path = %s", [path UTF8String]);

  NSString *anchorItem = nil;
  if (anchor != nil) {
    syslog(LOG_DEBUG, "QueryContainer, anchor = %s", [anchor UTF8String]);

    NSString *realAnchor = [anchor  stringByReplacingOccurrencesOfString:@"%252F" withString:@"%2F"];
    realAnchor = [realAnchor stringByReplacingOccurrencesOfString:@"%2520" withString:@"%20"];
    realPath = [realPath stringByReplacingOccurrencesOfString:@"%252B" withString:@"%2B"];
    realAnchor = [realAnchor stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];

    /* if it's a file anchor, we'll find the anchorItem of the form _ROOT_CONTAINER/path/.. */
    NSRange range2 = [realAnchor rangeOfString:_ROOT_CONTAINER];
    if (range2.location == NSNotFound) {
      /* otherwise, we'll get an anchorItem:  /TiVoConnect?Command=QueryContainer&Container=.. */
      anchorItem = [realAnchor
        stringByReplacingOccurrencesOfString:@"/TiVoConnect?Command=QueryContainer&Container="
        withString:@""];
      /* replace "ROOT_CONTAINER" with "/var/mobile/Media/Downloads" */
      anchorItem = [self TranslateSymbolicPath: anchorItem];
      syslog(LOG_DEBUG, "QueryContainer, anchorItem = %s", [anchorItem UTF8String]);
    } else {
      /* replace "_ROOT_CONTAINER" with "/var/mobile/Media/DCIM" */
      anchorItem = [self TranslateSymbolicPath: anchor];
      syslog(LOG_DEBUG, "QueryContainer, anchorItem = %s", [anchorItem UTF8String]);
    }
  }

  /* list the container */
  NSMutableArray *list = nil;
  if ([path hasPrefix: DOWNLOADS_PATH]) {
    /* list the file entries inside downloads */
    list = [self ListDownloads:path recursive:recurse];
  } else if ([path isEqualToString: ROOT_CONTAINER]) {
    /* list all file entries */
    list = [[[NSMutableArray alloc] initWithCapacity:20] autorelease];
    [self ListVideo:path recursive:recurse withArray:list];
  }

  /* apply a filter, if it exists */
  NSMutableArray *filterList;
  if ([filter isEqualToString: @"video%2F*"]) {
    filterList = [[[NSMutableArray alloc] initWithCapacity: [list count]] autorelease];
    int i = 0;
    for (i = 0; i < [list count]; i++) {
      VideoFileEntry *entry = [list objectAtIndex:i];
      if (entry->type == 0)
        continue;

      [filterList addObject: entry];
    }

    list = filterList;
  }

  /* shuffle, if necessary */
  if ([sortOrder isEqualToString: @"Random"]) {
    list = [self Shuffle: list withSeed:randomSeed withStart:randomStart];
  }

  [delegate WriteString: "HTTP/1.0 200 OK\r\n" ];
  [delegate WriteString: "Server: DVRMobile/1.0\r\n" ];
 
  NSDate *today = [NSDate date];
  sprintf(tmp, "Date: %s\r\n", [[today description] UTF8String]);
  [delegate WriteString: tmp ];

  [delegate WriteString: "Content-Type: text/xml\r\n" ];
  [delegate WriteString: "Connection: close\r\n" ];
  [delegate WriteString: "\r\n" ];

  int i = 0;
  BOOL foundAnchor = NO;
  /* determine if the query contains an AnchorItem */
  if (nil != anchorItem) {
    /* skip through the list to find our anchor */
    for (i = 0; (i < [list count]) && !foundAnchor; i++) {
      VideoFileEntry *item = [list objectAtIndex:i];
      if (item->path != nil) {
        /* file anchor */
        if ([[@"/" stringByAppendingString: item->path] isEqualToString: anchorItem])
          foundAnchor = YES;
        if ([item->path isEqualToString: anchorItem])
          foundAnchor = YES;
      } else {
        /* folder anchor */
        if ([anchorItem isEqualToString: DOWNLOADS_PATH] && [item->name isEqualToString: @"Downloads"])
          foundAnchor = YES;

        NSString *url = [path stringByAppendingString:@"/"];
        url = [url stringByAppendingString:item->name];

        if ([url isEqualToString: anchorItem])
          foundAnchor = YES;

        if ([url hasPrefix: ROOT_CONTAINER])
          url = [@"/" stringByAppendingString: url];

        if ([url isEqualToString: anchorItem])
          foundAnchor = YES;
      }
    }
  }

  if (anchor && !foundAnchor) {
    syslog(LOG_ERR, "Unable to find anchor!  %s", [anchorItem UTF8String]);
  }

  if (itemCount < 0) {
    /* we're walking backwards from the anchor, use absolute value for item count */
    i = (i + itemCount < 0) ? 0 : (i + itemCount);
    itemCount = -1 * itemCount; 
  } else {
    if (foundAnchor)
      i += anchorOffset;
    if (i < 0)
      i = 0;
  }

  /* if unspecified, let itemCount return all items */
  if (itemCount == 0)
    itemCount = [list count];

  [delegate WriteString: "<?xml version=\"1.0\" encoding=\"UTF-8\" ?>\r\n" ];
  [delegate WriteString: "<TiVoContainer>\r\n" ];
  sprintf(tmp,        "    <ItemStart>%d</ItemStart>\r\n", i);
  [delegate WriteString: tmp ];
  sprintf(tmp,        "    <ItemCount>%d</ItemCount>\r\n",
               [list count] < itemCount ? [list count] : itemCount);
  [delegate WriteString: tmp ];
  [delegate WriteString: "    <Details>\r\n" ];
  sprintf(tmp,        "       <Title>%s</Title>\r\n", [[self urlDecode: symbolicPath] UTF8String]);
  [delegate WriteString: tmp ];
  [delegate WriteString: "        <ContentType>x-container/tivo-videos</ContentType>\r\n" ];
  [delegate WriteString: "        <SourceFormat>x-container/folder</SourceFormat>\r\n" ];
  sprintf(tmp,        "        <TotalItems>%d</TotalItems>\r\n", [list count]);
  [delegate WriteString: tmp ];
  [delegate WriteString: "    </Details>\r\n" ];


  syslog(LOG_DEBUG, "Writing XML entries (%d-%d of %d)...", i, i+itemCount, [list count]);
  int j = 0;
  for (j = 0; i < [list count] && j < itemCount; i++, j++) {
    VideoFileEntry *item = [list objectAtIndex:i];

    [delegate WriteString: "    <Item>\r\n" ];
    [delegate WriteString: "        <Details>\r\n" ];
    sprintf(tmp,           "            <Title>%s</Title>\r\n", 
              [[self urlDecode: item->name] UTF8String]);
    [delegate WriteString: tmp ];

    /* check if directory or file */
    if (item->type == 0) {
      [delegate WriteString: "          <ContentType>x-tivo-container/folder</ContentType>\r\n" ];
    } else if (item->type == 1) {
      [delegate WriteString: "          <ContentType>video/mpeg</ContentType>\r\n" ];

      if ([item->title length] > 0)
        sprintf(tmp,           "          <SongTitle>%s</SongTitle>\r\n", 
              [[self urlDecode: item->title] UTF8String]);
      else
        sprintf(tmp,           "          <SongTitle>%s</SongTitle>\r\n", 
              [[self urlDecode: item->name] UTF8String]);
      [delegate WriteString: tmp ];

      if ([item->year length] > 0) {
        sprintf(tmp,         "          <AlbumYear>%s</AlbumYear>\r\n", [item->year UTF8String]);
        [delegate WriteString: tmp ];
      }

      if (item->duration > 0) {
        sprintf(tmp,         "          <Duration>%d</Duration>\r\n", item->duration);
        [delegate WriteString: tmp ];
      }
    }

    [delegate WriteString: "       </Details>\r\n" ];
    [delegate WriteString: "       <Links>\r\n" ];
    [delegate WriteString: "           <Content>\r\n" ];

    if (item->type == 0) {
      sprintf(tmp, "               <Url>/TiVoConnect?Command=QueryContainer&amp;Container=%s/%s</Url>\r\n",
          [[self urlEncode: realPath] UTF8String],
          [[self urlEncode: item->name] UTF8String]);
      [delegate WriteString: tmp ];
      [delegate WriteString: "               <ContentType>x-tivo-container/folder</ContentType>\r\n" ];
    } else if (item->type == 1) {
      [delegate WriteString: "               <ContentType>video/mpeg</ContentType>\r\n" ];
      [delegate WriteString: "               <AcceptsParams>Yes</AcceptsParams>\r\n" ];

      if (item->path)
        sprintf(tmp, "               <Url>%s</Url>\r\n",
            [[self urlEncode: item->path] UTF8String]);
      else
        sprintf(tmp, "               <Url>/%s/%s</Url>\r\n",
            [[self urlEncode: realPath] UTF8String],
            [[self urlEncode: item->name] UTF8String]);
      [delegate WriteString: tmp ];
    }

    [delegate WriteString: "           </Content>\r\n" ];
    [delegate WriteString: "       </Links>\r\n" ];
    [delegate WriteString: "    </Item>\r\n" ];
  }

  [delegate WriteString: "</TiVoContainer>\r\n" ];

  syslog(LOG_DEBUG, "Video QueryContainer finished.");
}

@end;




