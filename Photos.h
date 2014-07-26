
#import <CoreFoundation/CoreFoundation.h>
#import <Foundation/Foundation.h>

#import "Cache.h"
#import "HttpDelegate.h"

@interface FileEntry : NSObject
{
@public
  NSString *name;
  NSString *path;
  int type;
  NSString *createDate;
  NSString *modifyDate;
  NSMutableArray *children;
}
@end

@interface Photos : NSObject
{
  BOOL stopFlag;
  id graphicsLock;
  Cache *resourceCache;
  float jpegQuality;
  NSMutableArray *fileEntries;
  NSMutableArray *allFileEntries;
  NSMutableArray *fileSystemEntries;
  NSMutableArray *allFileSystemEntries;
  NSMutableArray *photoLibEntries;

  NSString *ROOT_CONTAINER;
  NSString *_ROOT_CONTAINER;
  NSString *CAMERAROLL_PATH;
  NSString *_CAMERAROLL_PATH;
  NSString *PHOTOLIB_PATH;
  NSString *PHOTO_PATH;

}
-(void)setRootContainer:(NSString*)root;
-(void)setGraphicsLock: (id)lock;
-(void)setResourceCache: (Cache*)cache;
-(void)setJPEGQuality: (float)j;
-(void)LoadPhotoEntries;
-(void)QueryItem: (NSString*)url;
-(void)QueryContainer: (NSString*)symbolicPath withItemCount:(int)itemCount
         withAnchorItem:(NSString*)anchor withAnchorOffset:(int)anchorOffset
         recursive:(BOOL)recurse sortOrder:(NSString*)sortOrder 
         randomSeed:(int)randomSeed randomStart:(NSString*)randomStart
         filter:(NSString*)filter httpDelegate:(id)delegate;
-(NSMutableArray*)ListPhotoAlbum: (NSString *)path;
-(BOOL)isPhotoFilePrefix:(NSString*)path;
-(void)SendFile: (NSString *)path  width:(int)w height:(int)h rotation:(int)r httpDelegate:(id)delegate; 
-(NSString*)TranslateSymbolicPath: (NSString*)symbolicPath;

@end


