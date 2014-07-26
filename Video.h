
#import <CoreFoundation/CoreFoundation.h>
#import <Foundation/Foundation.h>

#import "Cache.h"
#import "HttpDelegate.h"

@interface VideoFileEntry: NSObject
{
@public
  NSString *name;
  NSString *title;
  NSString *year;
  NSString *path;
  int duration;
  NSMutableArray *children;
  int type;
}
@end

@interface Video: NSObject
{
  BOOL stopFlag;
  Cache *resourceCache;
  NSMutableArray *podcastEntries;
  NSMutableArray *downloadEntries, *allDownloadEntries;

  NSString *ROOT_CONTAINER;
  NSString *_ROOT_CONTAINER;
  NSString *PODCASTS_PATH, *MXTUBE_PATH, *CYCORDER_PATH, *DOWNLOADS_PATH;
  NSString *PODCASTS, *MXTUBE, *CYCORDER, *DOWNLOADS;
  NSString *_PODCASTS, *_MXTUBE, *_CYCORDER, *_DOWNLOADS;
}
-(void)setRootContainer:(NSString*)root;
-(void)setResourceCache: (Cache*)cache;
-(void)LoadVideoEntries;
-(void)QueryItem: (NSString*)url;
-(void)QueryContainer: (NSString*)symbolicPath itemCount:(int)itemCount
         anchorItem:(NSString*)anchor anchorOffset:(int)anchorOffset
         recursive:(BOOL)recurse sortOrder:(NSString*)sortOrder 
         randomSeed:(int)randomSeed randomStart:(NSString*)randomStart
         filter:(NSString*)filter httpDelegate:(id)delegate;
-(BOOL)isVideoFilePrefix:(NSString*)path;
-(void)SendFile: (NSString *)path httpDelegate:(id)delegate; 
-(NSString*)TranslateSymbolicPath: (NSString*)symbolicPath;
-(NSMutableArray*)ListDownloads: (NSString*)path recursive:(BOOL)recurse;
@end


