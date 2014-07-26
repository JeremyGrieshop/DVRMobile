

#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>
#import <UIKit/UIKit.h>

#include <MediaPlayer/MPMediaLibrary.h>
#include <MediaPlayer/MPMediaQuery.h>
#include <MediaPlayer/MPMediaItem.h>
#include <MediaPlayer/MPMediaPlaylist.h>

#import <AudioToolbox/AudioQueue.h>
#import <AudioToolbox/AudioToolbox.h>
#import <GraphicsServices/GraphicsServices.h>
#import <UIKit/UITransformAnimation.h>
#import <UIKit/UIAnimator.h>
#import "PhotoLibrary.h"
#import "TiVoHTTPServer.h"
#import "HttpClient.h"
#import "TiVoHTTPClient.h"

@class MusicLibrary;
@class MLQuery;
@class MLPlaylist;
@class MLTrack;

#include <dirent.h>
#include <unistd.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <sys/socket.h>
#include <netdb.h>
#include <syslog.h>
#include <stdio.h>

#include <libxml/parser.h>
#include <libxml/tree.h>
//#include <itdb.h>
#include <openssl/ssl.h>
#include <openssl/md5.h>

UIImage *scaleAndRotateImage(UIImage *image, int w, int h, UIImageOrientation orient);

UIImage* resizeImage(UIImage* theImage, int w, int h) {
 
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

  CGRect rect = CGRectMake(0.0, 0.0, newWidth, newHeight);
  UIGraphicsBeginImageContext(rect.size);
  [bigImage drawInRect:rect];
  theImage = UIGraphicsGetImageFromCurrentImageContext();
  UIGraphicsEndImageContext();
 
  return theImage;
}

static CGImageRef GYImageCreateScaledDown(CGImageRef source, size_t width, size_t height)
{
  CGSize imageSize = CGSizeMake(CGImageGetWidth(source), CGImageGetHeight(source));

  CGFloat xRatio = imageSize.width / width;
  CGFloat yRatio = imageSize.height / height;
  CGFloat ratio = MAX(1, MAX(xRatio, yRatio));

  CGSize thumbSize = CGSizeMake(imageSize.width / ratio, imageSize.height / ratio);

  CGContextRef context = CGBitmapContextCreate(NULL, thumbSize.width, thumbSize.height,
      CGImageGetBitsPerComponent(source), 4 * thumbSize.width, CGImageGetColorSpace(source),
      kCGImageAlphaPremultipliedFirst);

  CGContextDrawImage(context, CGRectMake(0, 0, thumbSize.width, thumbSize.height), source);
  CGImageRef result = CGBitmapContextCreateImage(context);
  CGContextRelease(context);

  return result;
}

typedef struct {
  AudioQueueRef queue;
} CustomData;

static void AQRecordCallback(void *out, AudioQueueRef outQ, AudioQueueBufferRef outBuffer,
         const AudioTimeStamp *outStartTime, UInt32 outNumPackets,
         const AudioStreamPacketDescription *outPacketsDesc)
{
  printf("AQRecordCallback invoked..\n");
  syslog(LOG_INFO, "AQRecordCallback invoked..");
}

void parseMP3(FILE *mp3)
{
  unsigned char header[10];
  int read;

  /* read the Header (10 bytes) */
  memset(header, 0, 10);
  read = fread(header, 1, 10, mp3);
  if (read < 10) {
    printf("Error reading header.\n");
    return;
  }

  if (strncmp("ID3", header, 3)) {
    printf("Not a valid ID3v2 tag! %s\n", header);
    return;
  }

  printf("file identifier:  %3s\n", header);

  int verMajor = (int)(header[3]);
  int verMinor = (int)(header[4]);
  printf("version:         %2d %2d\n", verMajor, verMinor);

  int flags = (int)(header[5]);
  printf("flags:            %d\n", flags);
  
  int size = (header[6] << 24) | (header[7] << 16) | 
             (header[8] << 8) | (header[9]);
  printf("size:             %d\n", size);

  if (verMajor == 2) {
    /* ID3v2.2 */
    unsigned char frame_header[6];

    read = fread(frame_header, 1, 6, mp3);
    printf("\nFrame header identifier = %3s\n", frame_header);

    int size = (frame_header[3] << 16) | (frame_header[4] << 8) | (frame_header[5]);
    printf("Frame header size = %d\n", size);

    while (size > 0) {
      unsigned char *frame = malloc(size+1);
      memset(frame, 0, size+1);
      read = fread(frame, 1, size, mp3);
      if (read < size)
        printf("Unable to read entire frame!\n");

      printf("Frame: %s\n", frame+1);
    
      read = fread(frame_header, 1, 6, mp3);
      printf("\nFrame header identifier = %3s\n", frame_header);

      size = (frame_header[3] << 16) | (frame_header[4] << 8) | (frame_header[5]);
      printf("Frame header size = %d\n", size);
      free(frame);
    }

  } else if (verMajor == 3) {
    /* ID3v2.3 */
    if (flags & 0x40) {
      unsigned char frame_header[10];
      read = fread(frame_header, 1, 10, mp3);

      int size = (frame_header[0] << 24) | (frame_header[1] << 16) |
               (frame_header[2] << 8) | (frame_header[3]);
      printf("Extended header size = %d\n", size);
      printf("Extended Flags = %d %d\n", frame_header[4], frame_header[5]);

      int padding = (frame_header[6] << 24) | (frame_header[7] << 16) |
               (frame_header[8] << 8) | (frame_header[9]);
      printf("Size of padding = %d\n", padding);
    }

    unsigned char frame_header[10];
    memset(frame_header, 0, 10);
    read = fread(frame_header, 1, 10, mp3);

    printf("\nFrame header identifier = %4s\n", frame_header);

    int size = (frame_header[4] << 24) | (frame_header[5] << 16) | 
               (frame_header[6] << 8) | (frame_header[7]);
    printf("Frame header size = %d\n", size);
    printf("Frame flags = %d %d\n", frame_header[8], frame_header[9]);

    while (size > 0) {
      unsigned char *frame = malloc(size+1);
      memset(frame, 0, size+1);
      fread(frame, 1, size, mp3);

      /* may be unicode!! */
      printf("Frame: %s\n", frame+1);

      read = fread(frame_header, 1, 10, mp3);
      printf("\nFrame header identifier = %4s\n", frame_header);

      size = (frame_header[4] << 24) | (frame_header[5] << 16) | 
               (frame_header[6] << 8) | (frame_header[7]);
      printf("Frame header size = %d\n", size);
      printf("Frame flags = %d %d\n", frame_header[8], frame_header[9]);
      free(frame);
    }
    

  } else if (verMajor == 4) {
    /* ID3v2.4 */
    if (flags & 0x40) {
      unsigned char frame_header[4];
      read = fread(frame_header, 1, 4, mp3);

      int size = (frame_header[0] << 24) | (frame_header[1] << 16) |
               (frame_header[2] << 8) | (frame_header[3]);
      printf("Extended header size = %d\n", size);

      read = fread(frame_header, 1, 1, mp3);
      int num_flags = frame_header[0];

      int i;
      for (i = 0; i < num_flags; i++) {
        read = fread(frame_header, 1, 1, mp3);
        printf("Extended flag = %d\n", frame_header[0]);
      }
    }

    unsigned char frame_header[10];
    read = fread(frame_header, 1, 10, mp3);  

    printf("\nFrame header identifier = %4s\n", frame_header);

    int size = (frame_header[4] << 24) | (frame_header[5] << 16) |
               (frame_header[6] << 8) | (frame_header[7]);
    printf("Frame header size = %d\n", size);
    printf("Frame flags = %d %d\n", frame_header[8], frame_header[9]);

    while (size > 0) {
      unsigned char *frame = malloc(size+1);
      memset(frame, 0, size+1);
      fread(frame, 1, size, mp3);
      printf("Frame: %s\n", frame+1);

      read = fread(frame_header, 1, 10, mp3);
      printf("\nFrame header identifier = %4s\n", frame_header);

      size = (frame_header[4] << 24) | (frame_header[5] << 16) |
               (frame_header[6] << 8) | (frame_header[7]);
      printf("Frame header size = %d\n", size);
      printf("Frame flags = %d %d\n", frame_header[8], frame_header[9]);
      free(frame);
    }
  }
}

@interface NSNetDelegate : NSObject
{

}
- (void)netServiceBrowser:(NSNetServiceBrowser *)netServiceBrowser didFindDomain:(NSString *)domainName moreComing:(BOOL)moreDomainsComing;
- (void)netServiceBrowser:(NSNetServiceBrowser *)netServiceBrowser didFindService:(NSNetService *)netService moreComing:(BOOL)moreServicesComing;
- (void)netServiceBrowser:(NSNetServiceBrowser *)netServiceBrowser didNotSearch:(NSDictionary *)errorInfo;
- (void)netServiceBrowser:(NSNetServiceBrowser *)netServiceBrowser didRemoveDomain:(NSString *)domainName moreComing:(BOOL)moreDomainsComing;
- (void)netServiceBrowserDidStopSearch:(NSNetServiceBrowser *)netServiceBrowser;
- (void)netServiceBrowserWillSearch:(NSNetServiceBrowser *)netServiceBrowser;
@end

@implementation NSNetDelegate
{

}

- (void)netServiceBrowser:(NSNetServiceBrowser *)netServiceBrowser didFindDomain:(NSString *)domainName moreComing:(BOOL)moreDomainsComing
{
  printf("didFindDomain()\n");
}

- (void)netServiceBrowser:(NSNetServiceBrowser *)netServiceBrowser didFindService:(NSNetService *)netService moreComing:(BOOL)moreServicesComing
{
  printf("didFindService()\n");
}

- (void)netServiceBrowser:(NSNetServiceBrowser *)netServiceBrowser didNotSearch:(NSDictionary *)errorInfo
{
  printf("didNotSearch()\n");
  for (id key in errorInfo) {
    printf("key: %s, value %d\n", key, [errorInfo objectForKey:key]);
  }
}


- (void)netServiceBrowser:(NSNetServiceBrowser *)netServiceBrowser didRemoveDomain:(NSString *)domainName moreComing:(BOOL)moreDomainsComing
{
  printf("didRemoveDomain()\n");
}


- (void)netServiceBrowserDidStopSearch:(NSNetServiceBrowser *)netServiceBrowser
{
  printf("DidStopSearch()\n");
}

- (void)netServiceBrowserWillSearch:(NSNetServiceBrowser *)netServiceBrowser
{
  printf("WillSearch()\n");
}

@end

int main(int argc, char **argv)
{
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

  /* try reading iTunes playlists first */
  MPMediaLibrary *mLib = [MPMediaLibrary defaultMediaLibrary];
  if (mLib) {
    MPMediaQuery *mQuery = [MPMediaQuery playlistsQuery];
    if (mQuery) {
      printf("got a mQuery\n");
      NSArray *playlists = [mQuery collections];
      for (MPMediaItem *pl in playlists) {
        printf("Playlist:   %s\n", [[pl valueForProperty: MPMediaPlaylistPropertyName] UTF8String]);

        NSArray *songs = [pl items];
        for (MPMediaItem *song in songs) {
          printf("   Song:  %s\n", [[song valueForProperty: MPMediaItemPropertyTitle] UTF8String]);
          printf("   Album:  %s\n", [[song valueForProperty: MPMediaItemPropertyAlbumTitle] UTF8String]);
          printf("   Artist:  %s\n", [[song valueForProperty: MPMediaItemPropertyArtist] UTF8String]);
          printf("   Album Artist:  %s\n", [[song valueForProperty: MPMediaItemPropertyAlbumArtist] UTF8String]);
        }
      }
    }
  }





#if 0
  printf("loading file..\n");
  UIImage *image = [UIImage imageWithContentsOfFile:@"/private/var/mobile/Media/DCIM/100APPLE/IMG_0008.THM"];
  if (image)
    printf("good image!\n");
  else
    printf("can't find image!\n");

  UIImage *resize = scaleAndRotateImage(image, 640, 640,  UIImageOrientationLeft);
  printf("resized and rotated\n");

  NSData *jpeg = UIImageJPEGRepresentation(resize, 0.5);
  printf("converted to JPEG\n");


  FILE *f = fopen("img_0008_resize.jpg", "w");
  char *rawBytes = (char*) [jpeg bytes];
  fwrite(rawBytes, [jpeg length], 1, f);
#endif



#if 0
  NSString *bad = @"Israël Kamakawiwo'ole";

  printf("bad = %s\n", [bad UTF8String]);
  NSString *adding = [bad stringByAddingPercentEscapesUsingEncoding: NSUTF8StringEncoding];
  printf("adding = %s\n", [adding UTF8String]);
  NSString *replacing = [adding stringByReplacingPercentEscapesUsingEncoding: NSUTF8StringEncoding];
  printf("replacing = %s\n", [replacing UTF8String]);
#endif


#if 0
  NSNetDelegate *delegate = [NSNetDelegate alloc];
  NSNetServiceBrowser *browser = [[NSNetServiceBrowser alloc] init];
  [browser setDelegate: delegate];
  [browser searchForBrowsableDomains];
  [browser searchForServicesOfType: @"_http._tcp" inDomain: @""];
#endif


#if 0
  TiVoHTTPClient *client = [TiVoHTTPClient alloc];
  [client initialize: @"192.168.1.3" port:443 secure:YES 
      user:@"tivo" password:@"6966950926"];
  TiVoContainer *container = [client QueryContainer: @"%2FNowPlaying"];

  int i;
  for (i = 0; i < container->totalItems; i++) {
    TiVoItem *item = [container->items objectAtIndex: i];

    printf("title = %s\n", [item->title UTF8String]);
    printf("contentType = %s\n", [item->contentType UTF8String]);
    printf("url = %s\n", [item->url UTF8String]);

    if ([item->contentType hasPrefix: @"video/"]) {
      printf("sourceFormat = %s\n", [item->sourceFormat UTF8String]);
      printf("sourceSize = %s\n", [item->sourceSize UTF8String]);
      printf("duration = %s\n", [item->duration UTF8String]);
      printf("captureDate = %s\n", [item->captureDate UTF8String]);
      printf("episodeTitle = %s\n", [item->episodeTitle UTF8String]);
      printf("description = %s\n", [item->description UTF8String]);
      printf("sourceChannel = %s\n", [item->sourceChannel UTF8String]);
      printf("sourceStation = %s\n", [item->sourceStation UTF8String]);
      //printf("highDef = %s\n", item->highDef);
      printf("programId = %s\n", [item->programId UTF8String]);
      printf("seriesId = %s\n", [item->seriesId UTF8String]);
    }

    printf("\n");
  }
#endif



#if 0
  HttpClient *https = [HttpClient alloc];
  [https initializeSSL];
  [https setAuth: @"tivo" password:@"6966950926"];
  [https getRequest: @"192.168.1.3" port:443 
      uri:@"/TiVoConnect?Command=QueryContainer&Container=%2FNowPlaying" secure:YES];

  xmlDoc *responseXML = [https GetResponseXML];
  xmlNode *root_element = NULL;
  if (responseXML) {
    printf("Got a responseXML!!\n");

    root_element = xmlDocGetRootElement(responseXML);
    printf("root_element is %s\n", root_element->name);

    xmlNode *cur_node = NULL;
    for (cur_node = root_element->children; cur_node; cur_node = cur_node->next)
      printf("child: %s\n", cur_node->name);
  }
#endif

#if 0 
  NSURL *url = [NSURL URLWithString: @"https://130.127.5.217:3451/"]; 
  NSURLRequest *request = [[NSURLRequest alloc] initWithURL: url];
  NSURLConnection *conn = [[NSURLConnection alloc] initWithRequest: request delegate: nil startImmediately: YES];
  if (conn) {
    printf("got a conn!\n");
  }
  exit(0);
#endif


#if 0
  /* init SSL libraries */
  SSL_library_init();
  SSL_load_error_strings();

  SSL_METHOD *meth = SSLv23_method();
  SSL_CTX *ctx = SSL_CTX_new(meth);
  struct sockaddr_in sin;

  int sock = socket(AF_INET, SOCK_STREAM, 0);
  memset(&sin, 0, sizeof(struct sockaddr_in));
  sin.sin_family = AF_INET;
  struct hostent *hostent = gethostbyname("192.168.1.3");
  memcpy(&(sin.sin_addr.s_addr), hostent->h_addr, hostent->h_length);
  sin.sin_port = htons(443);
  int rc = connect(sock, (struct sockaddr *)&sin, sizeof(struct sockaddr_in));

  char nonce[1024];
  char buffer[1024];
  char *ptr;
  if (rc == 0) {
    printf("connected.\n");

    SSL *ssl = SSL_new(ctx);
    SSL_set_fd(ssl, sock);

    rc = SSL_connect(ssl);
    if (rc > 0) {
      printf("SSL connected.\n");
    }

    rc = SSL_write(ssl, 
       "GET /TiVoConnect?Command=QueryContainer&Container=%2FNowPlaying HTTP/1.0\r\n", 
       strlen("GET /TiVoConnect?Command=QueryContainer&Container=%2FNowPlaying HTTP/1.0\r\n"));
    rc = SSL_write(ssl, "\r\n", 2);

    /* now, we should get back a 401 response */
    memset(buffer, 0, 1024);
    rc = SSL_read(ssl, buffer, 1024);
    printf("buffer=[%s]\n", buffer);

    /* find the nonce */
    ptr = buffer;
    while (*ptr && strncmp(ptr, "nonce=\"", 7))
      ptr++;
    ptr += 7;
    strcpy(nonce, ptr);
    ptr = nonce;
    while (*ptr && (*ptr != '"'))
      ptr++;
    *ptr = '\0';
  }

  sock = socket(AF_INET, SOCK_STREAM, 0);
  memset(&sin, 0, sizeof(struct sockaddr_in));
  sin.sin_family = AF_INET;
  hostent = gethostbyname("192.168.1.3");
  memcpy(&(sin.sin_addr.s_addr), hostent->h_addr, hostent->h_length);
  sin.sin_port = htons(443);
  rc = connect(sock, (struct sockaddr *)&sin, sizeof(struct sockaddr_in));
  if (rc == 0) {
    printf("connected.. again.\n");

    SSL *ssl = SSL_new(ctx);
    SSL_set_fd(ssl, sock);

    rc = SSL_connect(ssl);
    if (rc > 0)
      printf("SSL connected.. again.\n");
  
    rc = SSL_write(ssl,
       "GET /TiVoConnect?Command=QueryContainer&Container=%2FNowPlaying HTTP/1.0\r\n",
       strlen("GET /TiVoConnect?Command=QueryContainer&Container=%2FNowPlaying HTTP/1.0\r\n"));

    /* Calculate the digest response:  

         HA1 = MD5(username:realm:password) 
         HA2 = MD5(method:uri) = MD5(GET:/index.html)
         response = MD5(HA1:nonce:nc:cnonce:qop:HA2)
 
       Send back: 

         Authorization: Digest username="User", realm="realm", nonce="nonce", uri="/", \
                               [qop=auth, nc=00000001, cnonce="cnonce",] response="response" opaque="opaque"
     */
    char userRealmPassword[256];
    sprintf(userRealmPassword, "%s:%s:%s", "tivo", "TiVo DVR", "6966950926");
    unsigned char HA1[256];
    memset(HA1, 0, 256);

    EVP_MD_CTX mdctx;
    int length;
    EVP_MD *md = EVP_get_digestbyname("md5");

    EVP_MD_CTX_init(&mdctx);
    EVP_DigestInit_ex(&mdctx, md, NULL);
    EVP_DigestUpdate(&mdctx, userRealmPassword, strlen(userRealmPassword));
    EVP_DigestFinal_ex(&mdctx, HA1, &length);
    EVP_MD_CTX_cleanup(&mdctx);

    NSMutableString *ha1 = [[NSMutableString alloc] init];
    int i;
    for (i = 0; i < length; i++)
      [ha1 appendFormat:@"%02x", HA1[i]];

    char methodUri[256];
    sprintf(methodUri, "%s:%s", "GET", "/TiVoConnect?Command=QueryContainer&Container=%2FNowPlaying");
    unsigned char HA2[256];
    memset(HA2, 0, 256);
    EVP_MD_CTX_init(&mdctx);
    EVP_DigestInit_ex(&mdctx, md, NULL);
    EVP_DigestUpdate(&mdctx, methodUri, strlen(methodUri));
    EVP_DigestFinal_ex(&mdctx, HA2, &length);
    EVP_MD_CTX_cleanup(&mdctx);

    NSMutableString *ha2 = [[NSMutableString alloc] init];
    for (i = 0; i < length; i++)
      [ha2 appendFormat:@"%02x", HA2[i]];

    char responseBuf[1024];
    sprintf(responseBuf, "%s:%s:%s", [ha1 UTF8String], nonce, [ha2 UTF8String]);
    
    unsigned char RESPONSE[256];
    memset(RESPONSE, 0, 256);
    EVP_MD_CTX_init(&mdctx);
    EVP_DigestInit_ex(&mdctx, md, NULL);
    EVP_DigestUpdate(&mdctx, responseBuf, strlen(responseBuf));
    EVP_DigestFinal_ex(&mdctx, RESPONSE, &length);
    EVP_MD_CTX_cleanup(&mdctx);

    NSMutableString *response = [[NSMutableString alloc] init];
    for (i = 0; i < length; i++)
      [response appendFormat:@"%02x", RESPONSE[i]];

    char authDigestHeader[1024];
    memset(authDigestHeader, 0, 1024);
    sprintf(authDigestHeader, "Authorization: Digest username=\"%s\", realm=\"%s\", nonce=\"%s\", uri=\"%s\", response=\"%s\"\r\n", "tivo", "TiVo DVR", nonce, "/TiVoConnect?Command=QueryContainer&Container=%2FNowPlaying", [response UTF8String]);

    rc = SSL_write(ssl, authDigestHeader, strlen(authDigestHeader));
    printf("Writing auth header: [%s]\n", authDigestHeader);
    rc = SSL_write(ssl, "\r\n", 2);

    memset(buffer, 0, 1024);
    rc = SSL_read(ssl, buffer, 1024);
    printf("buffer = %s\n", buffer);
  } else {
    printf("Error, rc=%d, errno=%d\n", rc, errno);
  }
#endif



#if 0
  GError *err = 0;
  Itdb_iTunesDB *itdb = itdb_parse_file(argv[1], &err);
  if (itdb) {
    printf("OK!\n");
  }

  Itdb_Playlist *playlist;
#endif


#if 0
  int i;
  for (i = 0; i < 1000; i++) {
    NSAutoreleasePool *pool2 = [[NSAutoreleasePool alloc] init];

    PLPhotoLibrary *pl = [[[PLPhotoLibrary alloc] initWithPath:@"/var/mobile/Media/Photos"] autorelease];
    id album = [[[pl albums] objectAtIndex:2] autorelease];
    id imgs = [album images];
    id imgObj = [imgs objectAtIndex:1];
    int imgid_int = [imgObj imageID];
    id imgid = [NSNumber numberWithInt: imgid_int];
    id img = [[[album imageWithImageID:[imgid integerValue]] createFullScreenCGImageRef:0 properties:nil] autorelease];

    UIImage *image = [[[UIImage alloc] initWithCGImage: img] autorelease];
    UIImage *resize = resizeImage(image, 634, 432);

    NSData *jpeg = UIImageJPEGRepresentation(resize, 0.5);
    char *bytes = (char*) [jpeg bytes];

    NSDate *today = [NSDate date];

    [pool2 release];

    sleep(1);
  }
#endif



#if 0
  /* setup our Photos configuration */
  Photos *photos = [[Photos alloc] autorelease];

  /* setup our Music configuration */
  Music *music = [[Music alloc] autorelease];


  int i;
  for (i = 0; i < 500; i++) {

    TiVoHTTPHandler *httpHandler = [TiVoHTTPHandler alloc];
    [httpHandler initialize];
    [httpHandler setClientSock: -1];

    [httpHandler setPhotos: photos];
    [httpHandler setMusic: music];

    /* handle this process in a new worker thread */
    [NSThread detachNewThreadSelector: @selector(ProcessRequest)
       toTarget:httpHandler withObject:nil];

    sleep(1);
  }
#endif


#if 0
  FILE *f = fopen("/var/mobile/Media/Music/dTunes/01 Radiohead - 2 + 2 = 5 (The Lukewarm.).mp3", "r");
  if (f)
    printf("ok\n");
  else
    printf("NOT ok\n");
 
  fclose(f); 
#endif


#if 0
  printf("sizeof(char) = %d\n", sizeof(char));
  printf("sizeof(NSString) = %d\n", sizeof(NSString));
#endif

#if 0

  FILE *mp3 = fopen(argv[1], "rb");
  if (!mp3) {
    printf("Unable to open mp3 file\n");
    return -1; 
  }

  parseMP3(mp3);

  fclose(mp3);
#endif

#if 0
  char *document = "<doc><e1>v1</e1></doc>";
  xmlDocPtr doc = xmlReadMemory(document, strlen(document), "noname.xml", NULL, 0);
  if (doc == NULL) {
    printf("Failed to parse document\n");
    return -1;
  }

  printf("Document parsed\n");
  xmlNode *root = xmlDocGetRootElement(doc);
  xmlNode *currentNode;
  for (currentNode = root; currentNode; currentNode = currentNode->next) {
    printf("node name = %s\n", currentNode->name);
    
  }

  xmlFreeDoc(doc);
#endif 



#if 0
  OSStatus err;
  CustomData data;
  AudioQueueRef queue;

  AudioStreamBasicDescription descr;
/*
  descr.mSampleRate = 22500.0;
  descr.mFormatID = kAudioFormatMPEGLayer3;
  descr.mFormatFlags = 0;
  descr.mBytesPerPacket = 4;
  descr.mFramesPerPacket = 1;
  descr.mBytesPerFrame = 4;
  descr.mChannelsPerFrame = 2;
  descr.mBitsPerChannel = 16;
*/
  descr.mSampleRate                 = 44100;
  //descr.mFormatID                   = kAudioFormatLinearPCM;
  descr.mFormatID = kAudioFormatMPEGLayer3;
  //descr.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
  descr.mFormatFlags = 0;
  descr.mFramesPerPacket    = 1;
  descr.mChannelsPerFrame   = 1;
  descr.mBitsPerChannel             = 16;
  descr.mBytesPerPacket             = 2;
  descr.mBytesPerFrame              = 2;


  err = AudioQueueNewInput(&descr, AQRecordCallback, &data,
            NULL, NULL, 0, &data.queue);

  if (err)
    printf("NewInput err = %d\n", err);

  char buffer[4096];
  AudioQueueAllocateBuffer(data.queue, 4096, buffer);
  //HandleSignalGeneration (self, mAudioQueue, buffers[i]);

  AudioQueueSetParameter(data.queue, kAudioQueueParam_Volume, 1.0);
  err = AudioQueueStart(data.queue, NULL);
  if (err)
    printf("Start err = %d\n", err);

  sleep(3);
#endif



#if 0
  MusicLibrary *ml = [MusicLibrary sharedMusicLibrary];
  MLQuery *tracks = [[MLQuery alloc] init];

  int i;
  MLTrack *track;
  printf("tracks: %d\n", [tracks countOfEntities]);
  for (i = 0; i < [tracks countOfEntities]; i++) {
    track = [tracks entityAtIndex:i];
    if (track == nil)
      continue;

    
  }
#endif


#if 0
  MusicLibrary *ml = [MusicLibrary sharedMusicLibrary];
  printf("MusicLibrary: %@\n", ml);
  printf("MusicLibrary: %s\n", [ml UTF8String]);
  MLQuery *tracks = [[MLQuery alloc] init];

  int i;
  MLTrack *track;
  printf("tracks: %d\n", [tracks countOfEntities]);
  for (i = 0; i < [tracks countOfEntities]; i++) {
    track = [tracks entityAtIndex:i];

    printf("artist:%s\ntitle:%s\nalbum:%s\npath:%s\n", [[track artist] UTF8String], [[track title] UTF8String], 
           [[track album] UTF8String], [[track path] UTF8String]);
    printf("description:%s\n", [[track description] UTF8String]);
    printf("grouping:%s\n", [[track grouping] UTF8String]);
    printf("seriesDisplayName:%s\n", [[track seriesDisplayName] UTF8String]);
    printf("comments:%s\n", [[track comments] UTF8String]);
    printf("infoDescription:%s\n", [[track infoDescription] UTF8String]);
    printf("albumArtist:%s\n", [[track albumArtist] UTF8String]);
    printf("duration:%d\n", [track duration]);
    printf("mediaType:%d\n\n\n", [track mediaType]);
  }
#endif



#if 0
  UIDevice *device = [UIDevice currentDevice];
  int i = 0;
  for (i = 0; i < [device.name length]; i++) {
    unichar c = [device.name characterAtIndex:i];
    printf("c=%d\n", c);
  }
#endif


#if 0
  CFUUIDRef theUUID = CFUUIDCreate(NULL);
  //CFStringRef string = CFUUIDCreateString(NULL, theUUID);
  CFStringRef string = CFUUIDCreateString(NULL, [[UIDevice currentDevice] uniqueIdentifier]);
  CFRelease(theUUID);
  
  printf("uniqueID:  %s\n", [[[UIDevice currentDevice] uniqueIdentifier] UTF8String]);
  printf("GUID: %s\n", [(NSString*)string UTF8String]);
  //printf("uuid:  %s\n", [[[NSProcessInfo processInfo] globallyUniqueString] UTF8String]);
  //printf("hostName: %s\n", [[[NSProcessInfo processInfo] hostName] UTF8String]);
  //printf("operatingSystemName: %s\n", [[[NSProcessInfo processInfo] operatingSystemName] UTF8String]);
#endif


#if 0
  UIDevice *device = [UIDevice currentDevice];
  printf("uniqueIdentifier = %s\n", [device.uniqueIdentifier UTF8String]);
  printf("name = %s\n", [device.name UTF8String]);
  printf("systemName = %s\n", [device.systemName UTF8String]);
  printf("systemVersion = %s\n", [device.systemVersion UTF8String]);
  printf("model = %s\n", [device.model UTF8String]);
  printf("localizedModel = %s\n", [device.localizedModel UTF8String]);
#endif


#if 0
  int rc;
  unsigned int size;
  struct sockaddr_in name;
  struct sockaddr_in client;
  char buf[512];
  struct timeval timeout;

  printf("Beacon Scan()\n");

  int scanSock = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP);
  if (scanSock > 0) {
    name.sin_family = AF_INET;
    name.sin_port = htons(2190);
    name.sin_addr.s_addr = htonl(INADDR_ANY);

    printf("Beacon Scan, binding..\n");
    rc = bind(scanSock, (struct sockaddr *)&name, sizeof(name));
    if (rc < 0) {
      printf("Unable to bind on 2190");
      return;
    }

    memset(buf, 0, 512);
    size = sizeof(client);
    if (recvfrom(scanSock, buf, 512, MSG_WAITALL, &client, &size) == -1) {
      printf("unable to recvfrom\n");
      return;
    }

    printf("Scan found client! (%s)\n", inet_ntoa(client.sin_addr));

    NSString *bufStr = [NSString stringWithCString:buf];
    NSArray *parts = [bufStr componentsSeparatedByString:@"\n"];
    int i = 0;
    for (i = 0; i < [parts count]; i++) {
      NSString *nextPart = [parts objectAtIndex:i];
      printf("%s\n", [nextPart UTF8String]);
    }
  }
#endif



#if 0
  printf("loading file..\n");
  UIImage *image = [UIImage imageWithContentsOfFile:@"/private/var/mobile/Media/DCIM/100APPLE/IMG_0008.JPG"];
  if (image)
    printf("good image!\n");
  else
    printf("can't find image!\n");

  UIImage *resize = scaleAndRotateImage(image, 640, 640,  UIImageOrientationLeft);
  printf("resized and rotated\n");

  NSData *jpeg = UIImageJPEGRepresentation(resize, 0.5);
  printf("converted to JPEG\n");

 
  FILE *f = fopen("img_0008_resize.jpg", "w");
  char *rawBytes = (char*) [jpeg bytes];
  fwrite(rawBytes, [jpeg length], 1, f);
#endif


#if 0
  PLPhotoLibrary *pl = [[PLPhotoLibrary alloc] 
       initWithPath:@"/var/mobile/Media/Photos"];
  NSMutableDictionary *picList = [[NSMutableDictionary alloc] init];
  int num = [[pl albums] count];

  int i, j;
  for (i = 0; i < num; i++) {
    id album = [[pl albums] objectAtIndex:i];
    NSString *albumName = [album name];
    printf("album name = %s", [albumName UTF8String]);

    id imgs = [album images];
    printf(" has %d images\n", [imgs count]);

/*
    for (j = 0; j < [imgs count]; j++) {
      id imgid = [NSNumber numberWithInt: [[imgs objectAtIndex:j] imageID]];

      BOOL b = [[album imageWithImageID:[imgid integerValue]] hasFullSizeImage];
      if (b)
        printf("hasFullSizeImage\n");

      printf("description = %s\n", [[[album imageWithImageID:[imgid integerValue]] description] UTF8String]);
    }
*/

    if ([imgs count] > 1) {
      id imgid = [NSNumber numberWithInt: [[imgs objectAtIndex:1] imageID]];
      id img = [[album imageWithImageID:[imgid integerValue]] createLowResolutionFullScreenCGImageRef];
      //id img = [[album imageWithImageID:[imgid integerValue]] createFullSizeCGImageRef:0];
      //id img = [[album imageWithImageID:[imgid integerValue]] createFullScreenCGImageRef:0 properties:nil];

      BOOL b = [[album imageWithImageID:[imgid integerValue]] hasFullSizeImage];
      if (b)
        printf("hasFullSizeImage\n");
       
      printf("description = %s\n", [[[album imageWithImageID:[imgid integerValue]] description] UTF8String]);
      UIImage *image = [[UIImage alloc] initWithCGImage: img];
      NSData *jpeg = UIImageJPEGRepresentation(image, 0.5);
 
      FILE *f = fopen("pic1.jpg", "w");
      char *rawBytes = (char*) [jpeg bytes];
      fwrite(rawBytes, [jpeg length], 1, f);
      fclose(f);

      exit(0);
    }

/*
    for (j = 0; j < [imgs count]; j++) {
      id imgid = [NSNumber numberWithInt: [[imgs objectAtIndex:j] imageID]];
      //[picList setObject:album forKey:imgid];

      id img = [[album imageWithImageID:[imgid integerValue]] createLowResolutionFullScreenCGImageRef];
      UIImage *image = [[UIImage alloc] initWithCGImage: img];

      UIImage *scaledImage = resizeImage(image, 640, 480);

      UIImage *jpeg = UIImageJPEGRepresentation(scaledImage, 90);
      if (jpeg)
        printf("converted to JPEG!\n");
      else {
        printf("unable to convert to JPEG!\n");
        exit(-1);
      }
    }
*/
  }
#endif



#if 0
  printf("loading file..\n");
  UIImage *image = [UIImage imageWithContentsOfFile:@"/private/var/mobile/Media/DCIM/100APPLE/IMG_0008.JPG"];
  if (image)
    printf("good image!\n");
  else
    printf("can't find image!\n");

  CGImageRef resize = GYImageCreateScaledDown(image.CGImage, 640, 480);
  printf("resized!\n");

  UIImage *i = UIImageJPEGRepresentation([UIImage imageWithCGImage: resize], 90);
  printf("converted to JPEG!\n");
#endif



#if 0
  printf("loading file..\n");
  UIImage *image = [UIImage imageWithContentsOfFile:@"/private/var/mobile/Media/DCIM/100APPLE/IMG_0008.JPG"];
  if (image)
    printf("good image!\n");
  else
    printf("can't find image!\n");

  UIImage *resize = resizeImage(image, 640, 480);
  if (resize)
    printf("resized!\n");
  else
    printf("unable to resize\n");

  UIImage *i = UIImageJPEGRepresentation(resize, 50);
  printf("converted to JPEG!\n");

#endif



#if 0
  NSString *encodedPath = @"Photos%2FMyPhotos%2Fis%20a%20space";
  NSString *path;
  char buf[1024];
  //char path[1024];

  NSRange range = [encodedPath rangeOfString:@"Photos"];
  encodedPath = [encodedPath stringByReplacingOccurrencesOfString:@"Photos"
                      withString:@"/var/mobile/Media/DCIM/" 
                      options:NSCaseInsensitiveSearch 
                      range:range];
  //url_decode([encodedPath UTF8String], path);
  path = [encodedPath stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];

  if (path == nil) {
    printf("path is nil\n");
    exit(-1);
  }

  sprintf(buf, "%s", [path UTF8String]);
  printf("buf = %s\n", buf);

#endif

#if 0
  DIR *dir, *subdir;
  struct dirent *dirp, *subdirp;
  char buf[512];

  if ((dir = opendir("/var/mobile/Media/DCIM")) == NULL) {
    fprintf(stderr, "error opening directory.");
    exit(-1);
  }

  /* look for *APPLE directories */
  while ((dirp = readdir(dir)) != NULL) {
    NSString *s = [NSString stringWithCString: dirp->d_name];
    if ([s hasSuffix: @"APPLE"]) {
      /* we have an APPLE directory */
      sprintf(buf, "/var/mobile/Media/DCIM/%s", dirp->d_name);
      subdir = opendir(buf);
      if (subdir != NULL) {
        while ((subdirp = readdir(subdir)) != NULL) {
          NSString *s2 = [NSString stringWithCString: subdirp->d_name];
          if ([s2 hasSuffix: @"JPG"]) {
            fprintf(stderr, "%s\n", [s2 UTF8String]);
          }
        }
      }

      closedir(subdir); 
    }
  }

  closedir(dir);
#endif

  [pool release];

  exit(0);
}

UIImage *scaleAndRotateImage(UIImage *image, int w, int h, UIImageOrientation orient)  
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
  UIImage *imageCopy = UIGraphicsGetImageFromCurrentImageContext();
  UIGraphicsEndImageContext();
  
  return imageCopy;
}
