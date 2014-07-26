
#include <syslog.h>
#include <unistd.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>

#import "TiVoHTTPServer.h"
#import "Photos.h"
#import "Music.h"
#import "Cache.h"

@implementation TiVoHTTPServer

-(void)initialize
{
  stopFlag = NO;
  isStopped = NO;
  isStarted = NO;
  graphicsLock = self;
  isRunning = YES;

  resourceCache = [[Cache alloc] autorelease];
  [resourceCache initialize];
}

-(void)stop
{
  stopFlag = YES;

  if (sock >= 0)
    close(sock);

  sock = -1;
}

-(BOOL)isStarted
{
  return isStarted;
}

-(BOOL)isStopped
{
  return isStopped;
}

-(BOOL)isRunning
{
  return isRunning;
}

-(void)ServeForever
{
  struct sockaddr_in name;
  struct sockaddr_in client;
  unsigned int size;
  int rc;

  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

  syslog(LOG_INFO, "TiVoHTTPServer entering server loop..");
  stopFlag = NO;
  int port = [[prefs GetNetworkPort] intValue];

  /* create a listening socket */
  sock = socket(AF_INET, SOCK_STREAM, 0);
  if (sock > 0) {
    name.sin_family = AF_INET;
    name.sin_port = htons(port);
    name.sin_addr.s_addr = htonl(INADDR_ANY);
  }

  int value = 1;
  setsockopt(sock, SOL_SOCKET, SO_REUSEADDR, &value, sizeof(value));

  rc = bind(sock, (struct sockaddr *)&name, sizeof(name));
  if (rc < 0) {
    syslog(LOG_ERR, "TiVoHTTPServer initialize, bind error binding, sock=%d, errno=%d", rc, errno);
    isStarted = NO; isStopped = YES; isRunning = NO;
    [pool release];
    return;
  } 

  rc = listen(sock, 20);
  if (rc < 0) {
    syslog(LOG_ERR, "TiVoHTTPServer initialize, listen error, sock=%d, errno=%d", rc, errno);
    isStarted = NO; isStopped = YES; isRunning = NO;
    [pool release];
    return;
  }

  /* setup our Photos configuration */
  photos = [[Photos alloc] autorelease];
  [photos setGraphicsLock: graphicsLock];
  [photos setResourceCache: resourceCache];
  [photos setRootContainer: [prefs GetPhotosContainer]];
  [photos setJPEGQuality: [[prefs GetPhotosJPEGQuality] floatValue]];

  /* setup our Music configuration */
  music = [[Music alloc] autorelease];
  [music setResourceCache: resourceCache];
  [music setRootContainer: [prefs GetMusicContainer]];
  [music setSpinningGearView: spinningGear];

  video = [[Video alloc] autorelease];
  [video setResourceCache: resourceCache];
  [video setRootContainer: [prefs GetVideoContainer]];

  syslog(LOG_INFO, "Loading Multimedia entries.");
  [spinningGear setText: @"Loading Photos"];
  [photos LoadPhotoEntries];
  [spinningGear setText: @"Loading Music"];
  [music LoadMusicEntries];

  syslog(LOG_INFO, "Accepting clients on TCP port %d.", port);

  /* accept clients until we shutdown */
  while (stopFlag == NO) {
    syslog(LOG_DEBUG, "HTTP Server, accepting clients.");

    isStarted = YES;
    clientSock = accept(sock, (struct sockaddr *) &client, &size);
    if (clientSock < 0) {
      if (errno == ECONNABORTED)
        syslog(LOG_DEBUG, "accept aborted");
      else
        syslog(LOG_ERR, "accept error, sock=%d, errno=%d", clientSock, errno);
      isStarted = NO; isStopped = YES; isRunning = NO;
      [pool release];
      return;
    }

    syslog(LOG_DEBUG, "HTTP Server, accepted client.");

    TiVoHTTPHandler *httpHandler = [TiVoHTTPHandler alloc];
    [httpHandler initialize];
    [httpHandler setBeacon: beacon];
    [httpHandler setClientSock: clientSock];
    [httpHandler setResourceCache: resourceCache];
    [httpHandler setDVRMobilePrefs: prefs];
    [httpHandler setPhotos: photos];
    [httpHandler setMusic: music];
    [httpHandler setVideo: video];

    /* handle this process in a new worker thread */
    [NSThread detachNewThreadSelector: @selector(ProcessRequest)
       toTarget:httpHandler withObject:nil];

    /* add this handler to a list of running threads? */

  }

  isStopped = YES; isStarted = NO; isRunning = NO;
  [pool release];
}

-(void)setBeacon: (Beacon*)b
{
  beacon = b;
}

-(void)setDVRMobilePrefs: (DVRMobilePrefs *)p
{
  prefs = p;
  tivos = [prefs GetTivos];
}

-(void)setSpinningGearView: (CustomSpinningGearView *)v
{
  spinningGear = v;
}

@end


@implementation TiVoHTTPHandler

-(void)initialize
{
}

-(NSString*)GetAddressString
{
  return address;
}

-(void)setBeacon: (Beacon*)b
{
  beacon = b;
}

-(void)setClientSock: (int)sock
{
  clientSock = sock;
}

-(void)setResourceCache: (Cache*)cache
{
  resourceCache = cache;
}

-(void)setGraphicsLock: (id)lock
{
  graphicsLock = lock;
}

-(void)setDVRMobilePrefs: (DVRMobilePrefs *)p
{
  prefs = p;
  tivos = [prefs GetTivos];
}

-(void)setPhotos: (Photos *)p
{
  photos = p;
}

-(void)setMusic: (Music *)m
{
  music = m;
}

-(void)setVideo: (Video *)v
{
  video = v;
}

-(void)ReadLine: (char*)buf size:(int)size
{
  int nbytes;
  char mybuf[2];
  char *ptr = buf;

  memset(buf, 0, size);

  nbytes = recv(clientSock, mybuf, 1, 0);
  while (mybuf[0] != '\n' && nbytes == 1 && ptr < (buf+size)) {
    if (nbytes == 1 && mybuf[0] != '\r') {
      *ptr = mybuf[0];
      ptr++;
    }

    nbytes = recv(clientSock, mybuf, 1, 0);
  }
}

-(void) SetStatus: (int)status
{
  if (status == 200) {
    [self WriteString: "HTTP/1.0 200 OK\n"];
  } else if (status == 404) {
    [self WriteString: "HTTP/1.0 404 Not Found\r\n"];
  } else if (status == 401) {

  }
}

-(NSString *)GetHeader: (NSString*) name
{
  int i;

  for (i = 0; i < [headerNames count]; i++) {
    NSString *n = [headerNames objectAtIndex:i];
    if ([n isEqualToString:name] && i < [headerValues count]) 
      return [headerValues objectAtIndex:i];
  }

  return nil;
}

-(BOOL)WriteData: (char*)data size:(int)size
{
  int bytes_sent, bytes_left;
  char *ptr;

  bytes_left = size;
  ptr = data;

  while (bytes_left > 0 && stopFlag == NO) {
    /* send in 8k chunks */
    int bytes_to_send = (bytes_left < 8192) ? bytes_left : 8192;

    bytes_sent = send(clientSock, ptr, bytes_to_send, 0);
    if (bytes_sent < 0) {
      syslog(LOG_ERR, "Error sending bytes (%d of %d left), errno = %d", 
           bytes_left, size, errno);
      return false;
    }

    bytes_left -= bytes_sent;
    ptr += bytes_sent;
  }

  return (bytes_left == 0);
}

-(BOOL)WriteString: (char*)data
{
  int sz = strlen(data);

  return [self WriteData:data size:sz ];
}

-(BOOL)WriteLine: (char*)data
{
  int sz = strlen(data);
  BOOL ok = [self WriteData:data size:sz ];
  if (!ok)
    return ok;

  return [self WriteData:"\r\n" size:2 ];
}

-(void)ParseRequest
{
  char *ptr, *c_cmd, *c_uri, *c_version;
  char line[1024];
  NSString *headerName, *headerValue;

  /* read the first line, the request */
  [self ReadLine: line size:1024];

  /* we have a get request */
  if (strstr(line, "GET ") == line) {
    c_cmd = line;
    for (ptr = line; *ptr != ' ' && *ptr; ptr++) ;
    *ptr = '\0';

    c_uri = ptr + 1;
    for (ptr = ptr+1; *ptr != ' ' && *ptr; ptr++) ;
    *ptr = '\0';

    c_version = ptr + 1;

    cmd = [NSString stringWithCString: c_cmd];
    uri = [NSString stringWithCString: c_uri];
    version = [NSString stringWithCString: c_version];

    syslog(LOG_INFO, "%s - %s %s", [address UTF8String],
           [cmd UTF8String], [uri UTF8String]);
  }

  headerNames = [[[NSMutableArray alloc] initWithCapacity:10] autorelease];
  headerValues = [[[NSMutableArray alloc] initWithCapacity:10] autorelease];

  /* parse headers */
  while (1) {
    [self ReadLine: line size:1024];

    /* empty line means request finished */
    if (strlen(line) == 0)
      return;

    if (strstr(line, ":") > line) {
      /* HTTP header detected */
      for (ptr = line; *ptr != ':'; ptr++)
        ;

      *ptr = '\0';
      ptr+=2;

      headerName = [NSString stringWithCString: line];
      [headerNames addObject: headerName];

      headerValue = [NSString stringWithCString: ptr];
      [headerValues addObject: headerValue];
    }
  }
}

-(void)ProcessRequest
{
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  unsigned int size;
  struct sockaddr_in client;
  int rc;

  syslog(LOG_DEBUG, "ProcessRequest, worker thread has been started.");
  stopFlag = NO;

  if ((rc = getpeername(clientSock, (struct sockaddr *)&client, &size)) == 0) {
    address = [NSString stringWithCString:inet_ntoa(client.sin_addr)];
    syslog(LOG_INFO, "Client connected from %s", [address UTF8String]);
  } else {
    syslog(LOG_INFO, "Unknown client connected, rc = [%d].", rc);
  }

  /* process this http request */
  [self ParseRequest];

  if ([cmd isEqualToString: @"GET"]) {
    [self doGET];
  }

  [pool release];
  [self release];
}

-(void)AddTivoDevice:(TivoDevice*)tivo 
{
  syslog(LOG_INFO, "adding tivo (%s) with identity %s", 
        [tivo->machine_name UTF8String], [tivo->identity UTF8String]);

  TivoDevice *newTivo = [[TivoDevice alloc] retain];
  if (tivo->address)
    newTivo->address = [[[NSString alloc] initWithString:tivo->address] retain];
  if (tivo->swversion)
    newTivo->swversion = [[[NSString alloc] initWithString:tivo->swversion] retain];
  if (tivo->identity)
    newTivo->identity = [[[NSString alloc] initWithString:tivo->identity] retain];
  if (tivo->machine_name)
    newTivo->machine_name = [[[NSString alloc] initWithString:tivo->machine_name] retain];
  if (tivo->platform)
    newTivo->platform = [[[NSString alloc] initWithString:tivo->platform] retain];
  if (tivo->services)
    newTivo->services = [[[NSString alloc] initWithString:tivo->services] retain];
  if (tivo->mak)
    newTivo->mak = [[[NSString alloc] initWithString:tivo->mak] retain];

  [tivos addObject: newTivo];
}

-(NSString*)GetTivoName:(NSString*)identity
{
  int i;
  for (i = 0; i < [tivos count]; i++) {
    TivoDevice *d = [tivos objectAtIndex:i];
    if ([d->identity isEqualToString:identity])
      return d->machine_name;
  }

  return nil;
}

-(void)doGET
{
  NSString *identity = [self GetHeader: @"TiVo_TCD_ID"];
  if (identity == nil)
    identity = [self GetHeader: @"tsn"];

  if (identity != nil) {
    NSString *ip = [self GetAddressString];
    NSString *name = [self GetTivoName:identity];
    TivoDevice *device = nil;

    if (nil != ip && nil == name) {
      /* we have a new identity and IP address */
      device = [beacon GetTivoDevice: ip];
      if (device != nil) {
        device->identity = [[[NSString alloc] initWithString:identity] retain];
        device->address = [[[NSString alloc] initWithString:ip] retain];
        name = device->machine_name;

        [self AddTivoDevice: device];
        syslog(LOG_DEBUG, "Successful connection with %s (%s), identity %s", 
           [name UTF8String], [ip UTF8String], [identity UTF8String]);
      }
    }

    if (ip == nil || name == nil) {
      syslog(LOG_ERR, "doGET could not exchange beacons.");
    }
  } else {
    syslog(LOG_DEBUG, "got a nil identity");
  }

  /* split around the ? (/TiVoConnect?Command...) */
  NSArray *uriList = [uri componentsSeparatedByString:@"?"];
  NSArray *commandList = nil;

  /* split around the & (name=value&name2=value2...) */
  if ([uriList count] > 1) {
    commandList = [[uriList objectAtIndex:1] componentsSeparatedByString:@"&"];
    if ([commandList count] < 1) {
      close(clientSock);
      syslog(LOG_ERR, "received invalid uri (no & separator)");
      return;
    }
  }

  /* if file is requested, determine the right plugin for it and send */
  NSString *sendFilePath = [uriList objectAtIndex:0];
  if ([photos isPhotoFilePrefix: sendFilePath]) {
    /* calculate width, height */
    int width = 0, height = 0, rotation = 0;
    int i;
    for (i = 0; i < [commandList count]; i++) {
      NSString *next = [commandList objectAtIndex:i];
      if ([next hasPrefix:@"Height="]) {
        height = [[next substringFromIndex:7] intValue];
      } else if ([next hasPrefix:@"Width="]) {
        width = [[next substringFromIndex:6] intValue];
      } else if ([next hasPrefix:@"Rotation="]) {
        rotation = [[next substringFromIndex:9] intValue];
      }
    }

    [photos SendFile: sendFilePath width:width height:height rotation:rotation httpDelegate:self];

    close(clientSock);
    syslog(LOG_DEBUG, "sent photo");
    return;
  } else if ([music isMusicFilePrefix: sendFilePath]) {

    [music SendFile: sendFilePath  httpDelegate:self];
    close(clientSock);
    syslog(LOG_DEBUG, "sent music");
    return;
  }

  /* make sure it's a TiVoConnect command */
  if (![uri hasPrefix: @"/TiVoConnect"]) {
    syslog(LOG_DEBUG, "Not a TiVoConnect command.");

    [self WriteString: "HTTP/1.0 200 OK\n"];
    [self WriteString: "Content-Type: text/html\n"];
    [self WriteString: "\n"];
    [self WriteString: "<html><h1>TiVoConnect for the iPhone</h1></html>\n"];
   
    close(clientSock); 
    return;
  }

  NSString *Command = [commandList objectAtIndex:0];
  if ([Command isEqualToString:@"Command=QueryContainer"]) {
    /* QueryContainer request */
    syslog(LOG_DEBUG, "Received QueryContainer command.");

    [self QueryContainer: commandList];

    close(clientSock);
    return;
  } else if ([Command isEqualToString:@"Command=QueryItem"]) {
    syslog(LOG_DEBUG, "Received QueryItem command.");

/*
    [self QueryItem: commandList];

    close(clientSock);
    return;
*/
  } else if ([Command isEqualToString:@"Command=FlushServer"]) {
    syslog(LOG_DEBUG, "Received FlushServer command.");

    /* not sure what to do here, yet */
  }

  syslog(LOG_INFO, "Unsupported command: %s.", [Command UTF8String]);

  /* if we've made it here, unsupported */
  [self WriteString: "HTTP/1.0 404 Not Found\r\n"];
  [self WriteString: "Content-Type: text/html\r\n"];
  [self WriteString: "\r\n"];
  [self WriteString: "<html><h1>TiVoConnect Unsupported Command</h1></html>\r\n"];

  close(clientSock);    
  return;

}

-(void)QueryItem: (NSArray*)parameters
{
  int i;
  NSString *url = nil;

  if (nil != parameters) {
    for (i = 1; i < [parameters count]; i++) {
      NSString *next = [parameters objectAtIndex:i];
      if ([next hasPrefix:@"Url="])
        url = [next substringFromIndex:4];
    }

    [photos QueryItem: url];
  }
}

-(void)QueryContainer: (NSArray*)parameters
{
  NSString *container = nil;
  NSString *anchorItem = nil;
  NSString *sortOrder = nil;
  NSString *randomStart = nil;
  NSString *filter = nil;
  int itemCount = 0, anchorOffset = 0;
  int randomSeed = 0;
  int width = 0, height = 0;
  BOOL recurse = NO;

  if (nil != parameters) {
    int i;
    for (i = 1; i < [parameters count]; i++) {
      NSString *next = [parameters objectAtIndex:i];
      if ([next hasPrefix:@"Container="])
        container = [next substringFromIndex:10];
      if ([next hasPrefix:@"Height="])
        height = [[next substringFromIndex:7] intValue];
      else if ([next hasPrefix:@"Width="])
        width = [[next substringFromIndex:6] intValue];
      else if ([next hasPrefix:@"AnchorItem="])
        anchorItem = [next substringFromIndex:11];
      else if ([next hasPrefix:@"Recurse=Yes"])
        recurse = YES;
      else if ([next hasPrefix:@"SortOrder="])
        sortOrder = [next substringFromIndex:10];
      else if ([next hasPrefix:@"RandomSeed="])
        randomSeed = [[next substringFromIndex:11] intValue];
      else if ([next hasPrefix:@"RandomStart="])
        randomStart = [next substringFromIndex:12];
      else if ([next hasPrefix:@"ItemCount="])
        itemCount = [[next substringFromIndex:10] intValue];
      else if ([next hasPrefix:@"AnchorOffset="])
        anchorOffset = [[next substringFromIndex:13] intValue];
      else if ([next hasPrefix:@"Filter="])
        filter = [next substringFromIndex:7];
    }
  }

  if ([container isEqualToString:@"%2F"]) {
    /* query for the "/" container */
    [self RootContainer];
  } else if ([photos isPhotoFilePrefix: container]) {
    /* invoke the photo query container */
    [photos QueryContainer:container withItemCount:itemCount 
        withAnchorItem:anchorItem withAnchorOffset:anchorOffset
        recursive:recurse sortOrder:sortOrder randomSeed:randomSeed 
        randomStart:randomStart filter:filter httpDelegate:self
    ];
  } else if ([music isMusicFilePrefix: container]) {
    [music QueryContainer:container itemCount:itemCount
        anchorItem:anchorItem anchorOffset:anchorOffset
        recursive:recurse sortOrder:sortOrder randomSeed:randomSeed
        randomStart:randomStart filter:filter httpDelegate:self
    ];
  } else if ([video isVideoFilePrefix: container]) {
    [video QueryContainer:container itemCount:itemCount
        anchorItem:anchorItem anchorOffset:anchorOffset
        recursive:recurse sortOrder:sortOrder randomSeed:randomSeed
        randomStart:randomStart filter:filter httpDelegate:self
    ];
  } else {
    [self WriteString: "HTTP/1.0 404 Not Found\r\n"];
    [self WriteString: "Server: DVRMobile/1.2\r\n"];
    [self WriteString: "\r\n"];

    syslog(LOG_ERR, "QueryContainer for an unknown Container: %s", [container UTF8String]);
  }
}

-(void)RootContainer
{
  syslog(LOG_DEBUG, "RootContainer, processing root container request.");
  char str[512];

  NSDate *today = [NSDate date];
  sprintf(str, "Date: %s\r\n", [[today description] UTF8String]); 

  /* for now, we'll return a hard-coded static container list */
  [self WriteString: "HTTP/1.0 200 OK\r\n"];
  [self WriteString: "Server: DVRMobile/1.2\r\n"];
  [self WriteString: str];
  [self WriteString: "\r\n"];
  [self WriteString: "<?xml version=\"1.0\" encoding=\"ISO-8859-1\" ?>\r\n"];
  [self WriteString: "<TiVoContainer>\r\n"];
  [self WriteString: "    <Details>\r\n"];
  [self WriteString: "        <Title>localhost</Title>\r\n"];
  [self WriteString: "        <ContentType>x-container/tivo-server</ContentType>\r\n"];
  [self WriteString: "        <SourceFormat>x-container/folder</SourceFormat>\r\n"];
  [self WriteString: "        <TotalItems>3</TotalItems>\r\n"];
  [self WriteString: "    </Details>\r\n"];
  [self WriteString: "\r\n"];

  [self WriteString: "    <Item>\r\n"];
  [self WriteString: "        <Details>\r\n"];
  
  sprintf(str,        "            <Title>%s</Title>\r\n", [[prefs GetVideoContainer] UTF8String]);
  [self WriteString: str];
  [self WriteString: "            <ContentType>x-container/tivo-videos</ContentType>\r\n"];
  [self WriteString: "            <SourceFormat>x-container/folder</SourceFormat>\r\n"];
  [self WriteString: "        </Details>\r\n"];
  [self WriteString: "        <Links>\r\n"];
  [self WriteString: "            <Content>\r\n"];
  [self WriteString: "                <ContentType>x-container/tivo-photos</ContentType>\r\n"];

  sprintf(str,        "                <Url>/TiVoConnect?Command=QueryContainer&amp;Container=%s</Url>\r\n", [[[prefs GetVideoContainer] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding] UTF8String]);
  [self WriteString: str];
  [self WriteString: "                <ContentType>x-container/tivo-videos</ContentType>\r\n"];
  [self WriteString: "            </Content>\r\n"];
  [self WriteString: "        </Links>\r\n"];
  [self WriteString: "    </Item>\r\n"];

  [self WriteString: "    <Item>\r\n"];
  [self WriteString: "        <Details>\r\n"];
  
  sprintf(str,        "            <Title>%s</Title>\r\n", [[prefs GetPhotosContainer] UTF8String]);
  [self WriteString: str];
  [self WriteString: "            <ContentType>x-container/tivo-photos</ContentType>\r\n"];
  [self WriteString: "            <SourceFormat>x-container/folder</SourceFormat>\r\n"];
  [self WriteString: "        </Details>\r\n"];
  [self WriteString: "        <Links>\r\n"];
  [self WriteString: "            <Content>\r\n"];
  
  sprintf(str,        "                <Url>/TiVoConnect?Command=QueryContainer&amp;Container=%s</Url>\r\n", [[[prefs GetPhotosContainer] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding] UTF8String]);
  [self WriteString: str];
  [self WriteString: "                <ContentType>x-container/tivo-photos</ContentType>\r\n"];
  [self WriteString: "            </Content>\r\n"];
  [self WriteString: "        </Links>\r\n"];
  [self WriteString: "    </Item>\r\n"];

  [self WriteString: "    <Item>\r\n"];
  [self WriteString: "        <Details>\r\n"];
  sprintf(str,        "            <Title>%s</Title>\r\n", [[prefs GetMusicContainer] UTF8String]);
  [self WriteString: str];
  [self WriteString: "            <ContentType>x-container/tivo-music</ContentType>\r\n"];
  [self WriteString: "            <SourceFormat>x-container/folder</SourceFormat>\r\n"];
  [self WriteString: "        </Details>\r\n"];
  [self WriteString: "        <Links>\r\n"];
  [self WriteString: "            <Content>\r\n"];
  sprintf(str,        "                <Url>/TiVoConnect?Command=QueryContainer&amp;Container=%s</Url>\r\n", [[[prefs GetMusicContainer] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding] UTF8String]);
  [self WriteString: str];
  [self WriteString: "                <ContentType>x-container/tivo-music</ContentType>\r\n"];
  [self WriteString: "            </Content>\r\n"];
  [self WriteString: "        </Links>\r\n"];
  [self WriteString: "    </Item>\r\n"];
  [self WriteString: "\r\n"];
  [self WriteString: "    <ItemStart>0</ItemStart>\r\n"];
  [self WriteString: "    <ItemCount>2</ItemCount>\r\n"];
  [self WriteString: "</TiVoContainer>\r\n"];
}
@end
