
#include "Photos.h"

#include <dirent.h>
#include <syslog.h>
#include <unistd.h>

#import <UIKit/UIKit.h>

#import <GraphicsServices/GraphicsServices.h>
#import <UIKit/UITransformAnimation.h>
#import <UIKit/UIAnimator.h>
#include "PhotoLibrary.h"


@implementation FileEntry
{

}
@end

@implementation Photos

-(void)setRootContainer:(NSString*)root
{
  ROOT_CONTAINER        = root;
  _ROOT_CONTAINER       = [@"/" stringByAppendingString:root];
  CAMERAROLL_PATH       = [ROOT_CONTAINER stringByAppendingString:@"/Camera Roll"];
  _CAMERAROLL_PATH      = [_ROOT_CONTAINER stringByAppendingString:@"/Camera Roll"];
  PHOTOLIB_PATH         = [ROOT_CONTAINER stringByAppendingString:@"/Photo Library"];
  PHOTO_PATH            = @"/var/mobile/Media/DCIM";
}

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

-(NSMutableArray *)Shuffle: (NSMutableArray*)list withSeed:(int)seed withStart:(NSString*)start
{
  NSMutableArray *shuffle = [[[NSMutableArray alloc] initWithCapacity: [list count]] autorelease];
  NSMutableArray *temp = [[[NSMutableArray alloc] initWithCapacity: [list count]] autorelease];

  int i = 0;
  for (i = 0; i < [list count]; i++) {
    FileEntry *entry = [list objectAtIndex: i];
    [temp addObject: entry];
  }

  srand(seed);

  i = random() % [list count];
  while ([temp count] > 0) {
    FileEntry *entry = [temp objectAtIndex: i];
    [temp removeObjectAtIndex: i];

    if ([entry->path isEqualToString: start])
      [shuffle insertObject: entry atIndex:0];
    else
      [shuffle addObject: entry];

    i = random() % [temp count];
  }

  return shuffle;
}

-(void)setResourceCache: (Cache*)cache
{
  resourceCache = cache;
}

-(void)setGraphicsLock: (id)lock
{
  graphicsLock = lock;
}

-(void)setJPEGQuality: (float)j
{
  if (j < 0 || j > 1)
    jpegQuality = 0.5;
  else
    jpegQuality = j;
}

-(void) LoadDirectory: (NSString *)path withArray: (NSMutableArray *)list
{
  DIR *dir;
  char buf[1024];
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
    if ((dirp->d_type != DT_DIR) && ![name hasSuffix:@".JPG"]
        && ![name hasSuffix:@".PNG"] && ![name hasSuffix:@".GIF"])
      continue;

    if (dirp->d_type == DT_DIR)
      type = 0;
    else
      type = 1;

    FileEntry *entry = [[FileEntry alloc] autorelease];
    entry->name = name;
    entry->type = type;

    char filepath[512];
    sprintf(filepath, "%s/%s", [path UTF8String], dirp->d_name);
    entry->path = [[[NSString alloc] initWithCString: filepath] autorelease];

    [list addObject: entry];
    [allFileSystemEntries addObject: entry];
    [allFileEntries addObject: entry];

    if (type == 0) {
      entry->children = [[[NSMutableArray alloc] initWithCapacity:50] autorelease];
      NSString *newPath = [path stringByAppendingString:@"/"];
      newPath = [newPath stringByAppendingString:name];
      [self LoadDirectory: newPath withArray: entry->children];
    }
  }

  closedir(dir);
}

-(void)LoadPhotoEntries
{
  PLPhotoLibrary *pl = [[[PLPhotoLibrary alloc] initWithPath:@"/var/mobile/Media/Photos"] autorelease];
  id albums = [pl albums];
  int numAlbums = [albums count];
  FileEntry *entry;

  fileEntries = [[[NSMutableArray alloc] initWithCapacity:20] autorelease];
  allFileEntries = [[[NSMutableArray alloc] initWithCapacity:50] autorelease];
  allFileSystemEntries = [[[NSMutableArray alloc] initWithCapacity:50] autorelease];
  
  int i, j;
  for (i = 0; i < numAlbums; i++) {
    id album = [[albums objectAtIndex:i] autorelease];
    
    entry = [[FileEntry alloc] autorelease];
    entry->name = [album name];
    entry->path = nil;
    entry->type = 0;

    /* allocate the children of this container */
    entry->children = [[[NSMutableArray alloc] initWithCapacity:20] autorelease];

    [fileEntries addObject: entry];
    [allFileEntries addObject: entry];
    if ([entry->name isEqualToString:@"Camera Roll"]) {
      [self LoadDirectory: PHOTO_PATH withArray: entry->children];
      fileSystemEntries = entry->children;
    } else {
      id imgs = [album images];
      for (j = 0; j < [imgs count]; j++) {
        id imgid = [NSNumber numberWithInt: [[imgs objectAtIndex:j] imageID]];
        
        FileEntry *childEntry = [[FileEntry alloc] autorelease];
        childEntry->name = [imgid stringValue];
     
        char filepath[512];
        sprintf(filepath, "%s/%s/%s", [ROOT_CONTAINER UTF8String], 
                   [entry->name UTF8String], [childEntry->name UTF8String]);
        childEntry->path = [[[NSString alloc] initWithCString: filepath] autorelease];
        childEntry->type = 1;
        [entry->children addObject: childEntry];
        [allFileEntries addObject: childEntry];
      }
    }
  }
}

-(UIImage*) scaleAndRotateImage: (UIImage *)image width:(int) w height:(int) h orient:(UIImageOrientation) orient
{
  CGSize size = image.size;

  float newWidth = 0.0;
  float newHeight = 0.0;

  float aspectRatio;
  aspectRatio = (1.0 * size.width ) / (1.0 * size.height);

  if (aspectRatio > 1.0) {
    /* the width becomes max */
    newWidth = 1.0 * w;
    newHeight = size.height / (size.width / (1.0 * w));
  } else {
    /* the height becomes max */
    newHeight = 1.0 * h;
    newWidth = size.width / (size.height / (1.0 * h));
  }

  CGImageRef imgRef = image.CGImage;
  
  CGFloat width = CGImageGetWidth(imgRef);
  CGFloat height = CGImageGetHeight(imgRef);
  
  CGAffineTransform transform = CGAffineTransformIdentity;
  CGRect bounds = CGRectMake(0, 0, newWidth, newHeight);
  
  CGFloat scaleRatio = bounds.size.width / width;

  CGSize imageSize = CGSizeMake(CGImageGetWidth(imgRef), CGImageGetHeight(imgRef));

  CGFloat boundHeight;
  switch(orient) {
      
    case UIImageOrientationUp: //EXIF = 1
      transform = CGAffineTransformIdentity;
      break;
      
    case UIImageOrientationUpMirrored: //EXIF = 2
      transform = CGAffineTransformMakeTranslation(imageSize.width, 0.0);
      transform = CGAffineTransformScale(transform, -1.0, 1.0);
      break;
      
    case UIImageOrientationDown: //EXIF = 3
      transform = CGAffineTransformMakeTranslation(imageSize.width, imageSize.height);
      transform = CGAffineTransformRotate(transform, M_PI);
      break;
      
    case UIImageOrientationDownMirrored: //EXIF = 4
      transform = CGAffineTransformMakeTranslation(0.0, imageSize.height);
      transform = CGAffineTransformScale(transform, 1.0, -1.0);
      break;
      
    case UIImageOrientationLeftMirrored: //EXIF = 5
      boundHeight = bounds.size.height;
      bounds.size.height = bounds.size.width;
      bounds.size.width = boundHeight;
      transform = CGAffineTransformMakeTranslation(imageSize.height, imageSize.width);
      transform = CGAffineTransformScale(transform, -1.0, 1.0);
      transform = CGAffineTransformRotate(transform, 3.0 * M_PI / 2.0);
      break;
      
    case UIImageOrientationLeft: //EXIF = 6
      boundHeight = bounds.size.height;
      bounds.size.height = bounds.size.width;
      bounds.size.width = boundHeight;
      transform = CGAffineTransformMakeTranslation(0.0, imageSize.width);
      transform = CGAffineTransformRotate(transform, 3.0 * M_PI / 2.0);
      break;
      
    case UIImageOrientationRightMirrored: //EXIF = 7
      boundHeight = bounds.size.height;
      bounds.size.height = bounds.size.width;
      bounds.size.width = boundHeight;
      transform = CGAffineTransformMakeScale(-1.0, 1.0);
      transform = CGAffineTransformRotate(transform, M_PI / 2.0);
      break;
      
    case UIImageOrientationRight: //EXIF = 8
      boundHeight = bounds.size.height;
      bounds.size.height = bounds.size.width;
      bounds.size.width = boundHeight;
      transform = CGAffineTransformMakeTranslation(imageSize.height, 0.0);
      transform = CGAffineTransformRotate(transform, M_PI / 2.0);
      break;
      
    default:
      [NSException raise:NSInternalInconsistencyException format:@"Invalid image orientation"];
      
  }
 
  UIImage *imageCopy = nil;
  @synchronized(graphicsLock) {
    UIGraphicsBeginImageContext(bounds.size);
  
    CGContextRef context = UIGraphicsGetCurrentContext();
  
    if (orient == UIImageOrientationRight || orient == UIImageOrientationLeft) {
      CGContextScaleCTM(context, -scaleRatio, scaleRatio);
      CGContextTranslateCTM(context, -height, 0);
    }
    else {
      CGContextScaleCTM(context, scaleRatio, -scaleRatio);
      CGContextTranslateCTM(context, 0, -height);
    }
  
    CGContextConcatCTM(context, transform);
  
    CGContextDrawImage(UIGraphicsGetCurrentContext(), CGRectMake(0, 0, width, height), imgRef);
    imageCopy = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
  }
  
  return imageCopy;
}

-(UIImage*)resizeImage:(UIImage*)theImage width:(int)w height:(int)h{
  
  UIImage * bigImage = theImage;
  CGSize size = bigImage.size;

  float aspectRatio = (1.0 * size.width ) / (1.0 * size.height);
  float newWidth = 0.0;
  float newHeight = 0.0;

  if (aspectRatio > 1.0) {
    /* the width becomes max */
    newWidth = 1.0 * w;
    newHeight = size.height / (size.width / (1.0 * w));
  } else {
    /* the height becomes max */
    newHeight = 1.0 * h;
    newWidth = size.width / (size.height / (1.0 * h));
  }

  @synchronized(graphicsLock) {
    CGRect rect = CGRectMake(0.0, 0.0, newWidth, newHeight);
    UIGraphicsBeginImageContext(rect.size);
    [bigImage drawInRect:rect];
    theImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
  }
  
  return theImage;
}

/*
 * Loads the low-res image version (120x60) 
 */
-(UIImage*)LoadLibraryLowResImage: (NSString*) path
{
  UIImage *image = nil;
  NSString *name;

  PLPhotoLibrary *pl = [[[PLPhotoLibrary alloc] initWithPath:@"/var/mobile/Media/Photos"] autorelease];
  int numAlbums = [[pl albums] count];

  int i, j;
  for (i = 0; i < numAlbums; i++) {
    id album = [[[pl albums] objectAtIndex:i] autorelease];

    name = [album name];
    NSRange range = [path rangeOfString:name];
    if (range.location != NSNotFound) {
      /* we found the album, now list the images */
      id imgs = [album images];
      for (j = 0; j < [imgs count]; j++) {
        id imgid = [NSNumber numberWithInt: [[imgs objectAtIndex:j] imageID]];
        NSString *imgidStr = [imgid stringValue];
        NSRange range2 = [path rangeOfString:imgidStr];
        if (range2.location != NSNotFound) {
          CGImageRef imageRef = [[[album imageWithImageID:[imgid integerValue]] 
              createLowResolutionFullScreenCGImageRef] autorelease];

          image = [[[UIImage alloc] initWithCGImage: imageRef] autorelease];
          return image;
        }
      }
    }
  }

  return nil;
}

/*
 * Loads the full-screen image version (640x480) 
 */
-(UIImage*)LoadLibraryFullScreenImage: (NSString*) path
{
  UIImage *image = nil;
  NSString *name;  

  PLPhotoLibrary *pl = [[[PLPhotoLibrary alloc] initWithPath:@"/var/mobile/Media/Photos"] autorelease];
  int numAlbums = [[pl albums] count];

  int i, j;
  for (i = 0; i < numAlbums; i++) {
    id album = [[[pl albums] objectAtIndex:i] autorelease];

    name = [album name];    
    NSRange range = [path rangeOfString:name];
    if (range.location != NSNotFound) {
      /* we found the album, now list the images */
      id imgs = [album images];
      for (j = 0; j < [imgs count]; j++) {
        id imgid = [NSNumber numberWithInt: [[imgs objectAtIndex:j] imageID]];
        NSString *imgidStr = [imgid stringValue];
        NSRange range2 = [path rangeOfString:imgidStr];
        if (range2.location != NSNotFound) {
          CGImageRef imageRef = [[[album imageWithImageID:[imgid integerValue]]
              createFullScreenCGImageRef:0 properties:nil] autorelease];

          image = [[[UIImage alloc] initWithCGImage: imageRef] autorelease];
          return image;
        }
      }
    }
  }

  return nil;
}

-(BOOL)isPhotoFilePrefix:(NSString*)path
{
  NSString *realPath = [path stringByReplacingOccurrencesOfString:@"%252F" withString:@"%2F"];
  realPath = [realPath stringByReplacingOccurrencesOfString:@"%2520" withString:@"%20"];
  realPath = [realPath stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];

  syslog(LOG_DEBUG, "isPhotoFilePrefix:%s", [path UTF8String]);
  if ([realPath hasPrefix: PHOTO_PATH])
    return YES;
  if ([realPath hasPrefix: _ROOT_CONTAINER])
    return YES;
  else if ([realPath hasPrefix: ROOT_CONTAINER])
    return YES;
  else
    return NO;
}

-(void)SendFile: (NSString *)symbolicPath width:(int)w height:(int)h rotation:(int)r httpDelegate:(id)delegate
{
  char tmp[256];
  BOOL scale = YES;

  syslog(LOG_DEBUG, "send_file for file = %s, [%dx%d]", [symbolicPath UTF8String], w, h);

  NSString *realPath = [symbolicPath stringByReplacingOccurrencesOfString:@"%252F" withString:@"%2F"];
  realPath = [realPath stringByReplacingOccurrencesOfString:@"%2520" withString:@"%20"];
  realPath = [realPath stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];

  NSString *path = [self TranslateSymbolicPath:symbolicPath];

  UIImage *image = nil;
  if ([path hasPrefix:PHOTO_PATH]) {
    /* load our image from the file system */
    if (w <= 100 && h <= 100 && w > 0 && h > 0) {
      /* load the thumbnail */
      NSString *thumbPath = [path stringByReplacingOccurrencesOfString:@".JPG" withString:@".THM"];
      image = [UIImage imageWithContentsOfFile:thumbPath];
      if (image == nil) {
        /* try the .MISC folder */
        thumbPath = [path stringByReplacingOccurrencesOfString:@"/IMG_" withString:@"/.MISC/IMG_"];
        thumbPath = [thumbPath stringByReplacingOccurrencesOfString:@".JPG" withString:@".THM"];
        image = [UIImage imageWithContentsOfFile:thumbPath];
      }
    } else {
      image = [UIImage imageWithContentsOfFile:path];
    }

    if (w == 75 && h == 75)
      scale = NO;
  } else {
    /* load image from the PhotoLibrary */
    if (w <= 120 && h <= 120 && w > 0 && h > 0)
      image = [self LoadLibraryLowResImage: path];
    else
      image = [self LoadLibraryFullScreenImage: path];

    if (w == 120 && h == 120)
      scale = NO;
  }

  if (nil == image) {
    syslog(LOG_ERR, "photo request could not find file = %s", [path UTF8String]);
    return;
  }

  UIImage *scaledImage;
  /* scaling the image is expensive- only do so if really needed */
  if (w > 0 && h > 0) {
    if (r == 90)
      scaledImage = [self scaleAndRotateImage: image width:w height:h orient:UIImageOrientationRight];
    else if (r == 180)
      scaledImage = [self scaleAndRotateImage: image width:w height:h orient:UIImageOrientationDown];
    else if (r == -90)
      scaledImage = [self scaleAndRotateImage: image width:w height:h orient:UIImageOrientationLeft];
    else if (scale)
      scaledImage = [self resizeImage:image width:w height:h];
    else
      scaledImage = image;
  } else {
    scaledImage = image;
  }

  if (nil == scaledImage) {
    syslog(LOG_ERR, "photo request could not scale image.");
    return;
  }

  NSData *imageData;
  imageData = UIImageJPEGRepresentation(scaledImage, jpegQuality);
  if (nil == imageData) {
    syslog(LOG_ERR, "photo request could not convert to JPEG.");
    return;
  }

  [delegate WriteString: "HTTP/1.0 200 OK\r\n" ];
  [delegate WriteString: "Server: DVRMobile/1.0\r\n" ];

  NSDate *today = [NSDate date]; 
  sprintf(tmp, "Date: %s\r\n", [[today description] UTF8String]); 
  [delegate WriteString: tmp ];
 
  int fileSize = [imageData length]; 
  sprintf(tmp, "Content-Length: %d\r\n", fileSize);
  [delegate WriteString: tmp ];
  [delegate WriteString: "Content-Type: image/jpeg\r\n" ];
  [delegate WriteString: "Connection: close\r\n" ];
  [delegate WriteString: "\r\n" ];

  syslog(LOG_DEBUG, "photo request sending file %s", [path UTF8String]);
  char *rawBytes = (char*) [imageData bytes];

  if (rawBytes == NULL || fileSize <= 0) {
    syslog(LOG_ERR, "Unable to get rawBytes, fileSize = %d", fileSize);
    return;
  }

  [delegate WriteData:rawBytes size:fileSize ];
  syslog(LOG_DEBUG, "send_file for file = %s complete, %d bytes sent", [path UTF8String], fileSize);

  return;
}

-(void)QueryItem: (NSString *)url
{

}

/*
 * Translates:
 *    "iPhone-Photos" to "/var/mobile/Media/"
 *    "/iPhone-Photos" to "/var/mobile/Media/"
 *    "Camera Roll" to "/var/mobile/Media/DCIM/"
 *    "Photo Library" to "/var/mobile/Media/Photos/"
 */
-(NSString*)TranslateSymbolicPath: (NSString *)symbolicPath
{
  NSString *realPath = symbolicPath;

  if (realPath == nil)
    return nil;

  /* unescape the url % codes */
  realPath = [realPath stringByReplacingOccurrencesOfString:@"%252F" withString:@"%2F"];
  realPath = [realPath stringByReplacingOccurrencesOfString:@"%2520" withString:@"%20"];
  realPath = [realPath stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];

  NSRange range = [realPath rangeOfString:_CAMERAROLL_PATH];
  if (range.location != NSNotFound) {
    /* Translate "/iPhone-Photos/Camera Roll" to "/var/mobile/Media/DCIM" */
    realPath = [realPath stringByReplacingOccurrencesOfString: _CAMERAROLL_PATH
                    withString:PHOTO_PATH options:0 range:range];
  }

  NSRange range2 = [realPath rangeOfString:CAMERAROLL_PATH];
  if (range2.location != NSNotFound) {
    /* Translate "iPhone-Photos/Camera Roll" to "/var/mobile/Media/DCIM" */
    realPath = [realPath stringByReplacingOccurrencesOfString:CAMERAROLL_PATH withString:PHOTO_PATH];
  }

  return realPath;
}

-(void)QueryContainer: (NSString*)symbolicPath withItemCount:(int)itemCount
         withAnchorItem:(NSString*)anchor withAnchorOffset:(int)anchorOffset
         recursive:(BOOL)recurse sortOrder:(NSString*)sortOrder
         randomSeed:(int)randomSeed randomStart:(NSString*)randomStart
         filter:(NSString*)filter httpDelegate:(id)delegate
{
  char tmp[512];

  syslog(LOG_DEBUG, "Photo QueryContainer executing, itemCount=%d.", itemCount);
  
  NSString *realPath = [symbolicPath stringByReplacingOccurrencesOfString:@"%252F" withString:@"%2F"];
  realPath = [realPath stringByReplacingOccurrencesOfString:@"%2520" withString:@"%20"];
  realPath = [realPath stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];

  NSRange range = [realPath rangeOfString:ROOT_CONTAINER];
  if (range.location == NSNotFound) {
    syslog(LOG_ERR, "QueryContainer, invalid path!");
    return;
  }

  NSString *path = [self TranslateSymbolicPath: symbolicPath];

  syslog(LOG_DEBUG, "QueryContainer, path = %s", [path UTF8String]);
  NSString *anchorItem = nil;
  if (nil != anchor) {
    /* if it's a file anchor, we'll find the anchorItem of the form _ROOT_CONTAINER/path/.. */
    NSRange range2 = [anchor rangeOfString:_ROOT_CONTAINER];
    if (range2.location == NSNotFound) {
      /* otherwise, we'll get a folder anchorItem:  /TiVoConnect?Command=QueryContainer&Container=.. */
      NSString *realAnchor = [anchor  stringByReplacingOccurrencesOfString:@"%252F" withString:@"%2F"];
      realAnchor = [realAnchor stringByReplacingOccurrencesOfString:@"%2520" withString:@"%20"];
      realAnchor = [realAnchor stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
      anchorItem = [realAnchor
        stringByReplacingOccurrencesOfString:@"/TiVoConnect?Command=QueryContainer&Container=" 
        withString:@""];
      /* replace "iPhone-Photos" with "/var/mobile/Media/DCIM" */
      anchorItem = [self TranslateSymbolicPath: anchorItem];
      syslog(LOG_DEBUG, "QueryContainer, anchorItem (dir) = %s", [anchorItem UTF8String]);
    } else {
      /* replace "/iPhone-Photos" with "/var/mobile/Media/DCIM" */
      anchorItem = [self TranslateSymbolicPath: anchor];
      syslog(LOG_DEBUG, "QueryContainer, anchorItem (file) = %s", [anchorItem UTF8String]);
    }
  }

  /* list the directory  */
  NSMutableArray *list;
  if ([path hasPrefix: PHOTO_PATH]) {
    /* list inside the photo file system */
    list = [self ListFileSystemEntries: path recurse:recurse];
  } else if ([path isEqualToString: ROOT_CONTAINER]) {
    /* list top-level directory */
    if (recurse)
      list = allFileEntries;
    else
      list = fileEntries;
  } else {
    /* list inside the photo library */
    list = [self ListPhotoAlbum: path];
  }

  /* apply a filter, if it exists */
  NSMutableArray *filterList;
  if ([filter isEqualToString: @"image%2F*"]) {
    filterList = [[[NSMutableArray alloc] initWithCapacity: [list count]] autorelease];
    int i = 0;
    for (i = 0; i < [list count]; i++) {
      FileEntry *entry = [list objectAtIndex:i];
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
      FileEntry *item = [list objectAtIndex:i];

      if ([item->path isEqualToString: anchorItem])
        foundAnchor = YES;

      if ([[[symbolicPath stringByAppendingString:@"/"] 
         stringByAppendingString:item->name] isEqualToString: anchorItem])
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
               ([list count]-i) < itemCount ? ([list count]-i) : itemCount);
  [delegate WriteString: tmp ];
  [delegate WriteString: "    <Details>\r\n" ];

  sprintf(tmp,           "        <Title>%s</Title>\r\n", [[self urlDecode: symbolicPath] UTF8String]);
  [delegate WriteString: tmp ];
  [delegate WriteString: "        <ContentType>x-container/folder</ContentType>\r\n" ];
  [delegate WriteString: "        <SourceFormat>x-container/folder</SourceFormat>\r\n" ];
  sprintf(tmp,        "        <TotalItems>%d</TotalItems>\r\n", [list count]);
  [delegate WriteString: tmp ];
  [delegate WriteString: "    </Details>\r\n" ];

  int j = 0;
  for (; i < [list count] && j < itemCount; i++, j++) {
    FileEntry *item = [list objectAtIndex:i];

    [delegate WriteString: "    <Item>\r\n" ];
    [delegate WriteString: "        <Details>\r\n" ];
    sprintf(tmp,        "           <Title>%s</Title>\r\n", [item->name UTF8String]);
    [delegate WriteString: tmp ];

    /* check if directory or file */
    if (item->type == 0) {
      [delegate WriteString: "           <ContentType>x-container/folder</ContentType>\r\n" ];
      [delegate WriteString: "           <SourceFormat>x-container/folder</SourceFormat>\r\n" ];
    } else {
      [delegate WriteString: "           <ContentType>image/jpeg</ContentType>\r\n" ];
      [delegate WriteString: "           <CaptureDate></CaptureDate>\r\n" ];
      [delegate WriteString: "           <CreationDate></CreationDate>\r\n" ];
      [delegate WriteString: "           <LastChangeDate></LastChangeDate>\r\n" ];
    }

    [delegate WriteString: "       </Details>\r\n" ];
    [delegate WriteString: "       <Links>\r\n" ];
    [delegate WriteString: "           <Content>\r\n" ];

    if (item->type == 0) {
      sprintf(tmp, "               <Url>/TiVoConnect?Command=QueryContainer&amp;Container=%s/%s</Url>\r\n", 
          [symbolicPath UTF8String], [[self urlEncode: item->name] UTF8String]);
      [delegate WriteString: tmp ];
      [delegate WriteString: "               <ContentType>x-container/folder</ContentType>\r\n" ];
    } else {
      [delegate WriteString: "               <ContentType>image/jpeg</ContentType>\r\n" ];
      [delegate WriteString: "               <AcceptsParams>Yes</AcceptsParams>\r\n" ];

      sprintf(tmp, "               <Url>%s</Url>\r\n", 
          [[item->path stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding] UTF8String]);
      [delegate WriteString: tmp ];
    }

    [delegate WriteString: "           </Content>\r\n" ];
    [delegate WriteString: "       </Links>\r\n" ];
    [delegate WriteString: "    </Item>\r\n" ];
  }

  [delegate WriteString: "</TiVoContainer>\r\n" ];

  syslog(LOG_DEBUG, "Photo QueryContainer finished.");
}

-(NSMutableArray*) ListFileSystemEntries: (NSString *)path recurse:(BOOL)recurse
{
  NSString *name;
  FileEntry *entry;  

  syslog(LOG_DEBUG, "ListFileSystemEntries(%s)", [path UTF8String]);

  if ([path isEqualToString: PHOTO_PATH] && recurse)
    return allFileSystemEntries;
  else if ([path isEqualToString: PHOTO_PATH])
    return fileSystemEntries;

  int i;
  for (i = 0; i < [allFileSystemEntries count]; i++) {  
    entry = [allFileSystemEntries objectAtIndex:i];
    name = entry->name;

    NSRange range = [path rangeOfString:name];
    if (range.location != NSNotFound) {
      /* we found the directory, now return the images */
      return entry->children;
    }
  }  

  return nil;
}

-(NSMutableArray*) ListPhotoAlbum: (NSString *)path
{
  NSString *name;
  FileEntry *entry;

  int i;
  for (i = 0; i < [fileEntries count]; i++) {
    entry = [fileEntries objectAtIndex:i];
    name = entry->name;

    NSRange range = [path rangeOfString:name];
    if (range.location != NSNotFound) {
      /* we found the album, now return the images */
      return entry->children;
    }
  }

  return nil;
}

@end;
