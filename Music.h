
#import <CoreFoundation/CoreFoundation.h>
#import <Foundation/Foundation.h>

#import "Cache.h"
#import "HttpDelegate.h"
#import "CustomSpinningGearView.h"

@interface MusicFileEntry: NSObject
{
@public
  NSString *name;
  NSString *title;
  NSString *album;
  NSString *artist;
  NSString *year;
  NSString *genre;
  NSString *path;
  int duration;
  NSMutableArray *trackEntries;
  NSMutableArray *albumEntries;
  NSMutableArray *children;
  int type;
}
@end

@interface Music: NSObject
{
  BOOL stopFlag;
  Cache *resourceCache;
  NSMutableArray *trackEntries, *albumEntries, *artistEntries;
  NSMutableArray *downloadEntries, *allDownloadEntries;
  NSMutableArray *playlistsEntries, *recordingEntries;
  CustomSpinningGearView *spinningGear;

  NSString *ROOT_CONTAINER;
  NSString *_ROOT_CONTAINER;
  NSString *_DOWNLOADS;
  NSString *DOWNLOADS;
  NSString *_RECORDINGS;
  NSString *RECORDINGS;
  NSString *_PLAYLISTS;
  NSString *PLAYLISTS;
  NSString *DOWNLOADS_PATH;
  NSString *PLAYLISTS_PATH;
  NSString *ITUNES_PATH;
  NSString *ITUNES_ALBUM_PATH;
  NSString *ITUNES_ARTIST_PATH;
  NSString *ITUNES_SONG_PATH;
  NSString *ITUNES_PLAYLIST_PATH;
  NSString *ITUNES_FS_PATH;
  NSString *PWNPLAYER_PATH;
  NSString *RECORDINGS_PATH;
}
-(void)setRootContainer:(NSString*)root;
-(void)setResourceCache: (Cache*)cache;
-(void)setSpinningGearView: (CustomSpinningGearView *)view;
-(void)LoadMusicEntries;
-(void)QueryItem: (NSString*)url;
-(void)QueryContainer: (NSString*)symbolicPath itemCount:(int)itemCount
         anchorItem:(NSString*)anchor anchorOffset:(int)anchorOffset
         recursive:(BOOL)recurse sortOrder:(NSString*)sortOrder 
         randomSeed:(int)randomSeed randomStart:(NSString*)randomStart
         filter:(NSString*)filter httpDelegate:(id)delegate;
-(BOOL)isMusicFilePrefix:(NSString*)path;
-(void)SendFile: (NSString *)path httpDelegate:(id)delegate; 
-(NSString*)TranslateSymbolicPath: (NSString*)symbolicPath;
-(NSMutableArray*)ListDownloads: (NSString*)path recursive:(BOOL)recurse;
@end


