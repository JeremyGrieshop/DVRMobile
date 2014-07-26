
#include "Beacon.h"

#include <syslog.h>
#include <unistd.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <sys/socket.h>
#include <netdb.h>
#include <time.h>

@implementation TivoDevice
{

}
@end


@implementation Beacon

-(void) setDVRMobilePrefs: (DVRMobilePrefs*)p
{
  prefs = p;
}

-(NSMutableArray *) NewBeacon: (NSString*)connType
{
  NSMutableArray *b = [[NSMutableArray alloc] initWithCapacity:10];
  NSString *guid = [prefs GetGUID];
  NSString *conntype = connType;
  NSString *host = [prefs GetName];

  [b insertObject:
    [NSString stringWithFormat:@"tivoconnect=%d", 1] atIndex:0];
  [b insertObject:
    [NSString stringWithFormat:@"swversion=%d", 1] atIndex:1];
  [b insertObject:
    [NSString stringWithFormat:@"method=%@", conntype] atIndex:2];
  [b insertObject:
    [NSString stringWithFormat:@"identity=%@", guid] atIndex:3];
  [b insertObject:
    [NSString stringWithFormat:@"machine=%@", host] atIndex:4];
  [b insertObject:
    [NSString stringWithFormat:@"platform=%s", "pc/iphone"] atIndex:5];

  if ([services count] > 0) {
    syslog(LOG_DEBUG, "FormatBeacon, found service [%s]", [services objectAtIndex:0]);
    [b insertObject:
      [NSString stringWithFormat:@"services=%s", [[services objectAtIndex:0] UTF8String]] atIndex:6
    ];
  } else {
    syslog(LOG_DEBUG, "FormatBeacon, found no services");
    [b insertObject:
      [NSString stringWithFormat:@"services=TiVoMediaServer:%@/http", 
        [prefs GetNetworkPort]] atIndex:6];
  }

  return b;
}

-(BOOL) SendBeacon
{
  int opt = 1;
  struct sockaddr_in dest;
  char msg[512];
  int len, nbytes;
  BOOL success = NO;

  syslog(LOG_DEBUG, "Beacon SendBeacon.");

  /* create our UDP socket */ 
  UDPSock = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP);
  if (UDPSock > 0) {
    /* set socket options for broadcast */
    setsockopt(UDPSock, SOL_SOCKET, SO_BROADCAST, &opt, sizeof(opt));

    /* setup the destination socket */
    dest.sin_family = AF_INET;
    dest.sin_port = htons(2190);
    //dest.sin_addr.s_addr = htonl(INADDR_BROADCAST);
    struct hostent *hostent = gethostbyname([[prefs GetNetworkBroadcast] UTF8String]);
    memcpy(&(dest.sin_addr.s_addr), hostent->h_addr, hostent->h_length);

    NSMutableArray *beacon = [self NewBeacon:@"broadcast"];

    sprintf(msg, "%s\n%s\n%s\n%s\n%s\n%s\n%s",
       [[beacon objectAtIndex:0] UTF8String],
       [[beacon objectAtIndex:1] UTF8String],
       [[beacon objectAtIndex:2] UTF8String],
       [[beacon objectAtIndex:3] UTF8String],
       [[beacon objectAtIndex:4] UTF8String],
       [[beacon objectAtIndex:5] UTF8String],
       [[beacon objectAtIndex:6] UTF8String]
    );
    len = strlen(msg);

    /* now send the beacon */
    nbytes = sendto(UDPSock, msg, len, 0, (struct sockaddr *)&dest, sizeof(dest));
    if (nbytes < len) {
      syslog(LOG_ERR, "unable to send all beacon data, nbytes = %d, errno = %d.", nbytes, errno);
      success = NO;
    } else {
      success = YES;
    }

    close(UDPSock);

    [beacon release];
  }

  return success;
}

-(TivoDevice *) ParseDevice: (char*)buf
{
  TivoDevice *device = [TivoDevice alloc];

  NSArray *beaconStr = [[NSString stringWithCString: buf] componentsSeparatedByString:@"\n"];
  int i;
  for (i = 0; i < [beaconStr count]; i++) {
    NSString *token = [beaconStr objectAtIndex:i];
 
    if ([token hasPrefix:@"swversion="]) {
      device->swversion = [[[NSString alloc] initWithString: [token substringFromIndex:10]] retain];
    } else if ([token hasPrefix:@"machine="]) {
      device->machine_name = [[[NSString alloc] initWithString: [token substringFromIndex:8]] retain];
    } else if ([token hasPrefix:@"Machine="]) {
      device->machine_name = [[[NSString alloc] initWithString: [token substringFromIndex:8]] retain];
    } else if ([token hasPrefix:@"identity="]) {
      device->identity = [[[NSString alloc] initWithString: [token substringFromIndex:9]] retain];
    } else if ([token hasPrefix:@"Identity="]) {
      device->identity = [[[NSString alloc] initWithString: [token substringFromIndex:9]] retain];
    } else if ([token hasPrefix:@"platform="]) {
      device->platform = [[[NSString alloc] initWithString: [token substringFromIndex:9]] retain];
    } else if ([token hasPrefix:@"Platform="]) {
      device->platform = [[[NSString alloc] initWithString: [token substringFromIndex:9]] retain];
    } else if ([token hasPrefix:@"services="]) {
      device->services = [[[NSString alloc] initWithString: [token substringFromIndex:9]] retain];
    } else if ([token hasPrefix:@"Services="]) {
      device->services = [[[NSString alloc] initWithString: [token substringFromIndex:9]] retain];
    }
  }

  if (!device->machine_name || !device->identity) {
    [device release];
    device = nil;
  }

  return device;
}

-(TivoDevice*)Scan: (int)timeout
{
  int rc;
  unsigned int size;
  struct sockaddr_in name;
  struct sockaddr_in client;
  char buf[512];
  struct timeval selectTimeout;
  TivoDevice *device = nil;
  fd_set set;

  syslog(LOG_DEBUG, "Beacon Scan()");

  int scanSock = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP);
  if (scanSock > 0) {
    name.sin_family = AF_INET;
    name.sin_port = htons(2190);
    name.sin_addr.s_addr = htonl(INADDR_ANY);

    rc = bind(scanSock, (struct sockaddr *)&name, sizeof(name));
    if (rc < 0) {
      syslog(LOG_ERR, "Unable to bind on 2190");
      close(scanSock);
      return device;
    }

    /* perform a timed select on socket */
    FD_ZERO(&set);
    FD_SET(scanSock, &set);
    selectTimeout.tv_sec = timeout;
    selectTimeout.tv_usec = 0;
    rc = select(scanSock+1, &set, NULL, NULL, &selectTimeout);
    if (rc == 0) {
      /* timeout occurred */
      syslog(LOG_DEBUG, "select timed out..");
      close(scanSock);
      return device;
    }
 
    size = sizeof(client);
    memset(buf, 0, 512);
    if (recvfrom(scanSock, buf, 512, MSG_WAITALL, &client, &size) == -1) {
      syslog(LOG_ERR, "unable to recvfrom");
      close(scanSock);
      return device;
    }

    syslog(LOG_DEBUG, "Scan found client %s", inet_ntoa(client.sin_addr));
    syslog(LOG_DEBUG, "Client %s sent: [%s]", inet_ntoa(client.sin_addr), buf);

    device = [self ParseDevice: buf];
    if (device)
      device->address = [[NSString alloc] initWithCString:inet_ntoa(client.sin_addr)];

    close(scanSock);
  }

  return device;
}

-(void) listen 
{
  int rc, nbytes, len;
  unsigned int size;
  struct sockaddr_in name;
  struct sockaddr_in client;
  char buffer[256];
  char msg[512];
  NSMutableArray *beacon;

  syslog(LOG_DEBUG, "Beacon listen.");

  /* this function is used for direct-connect, TCP-style beacons */
  TCPSock = socket(AF_INET, SOCK_STREAM, 0);
  if (TCPSock > 0) {
    name.sin_family = AF_INET;
    name.sin_port = htons(2190);
    name.sin_addr.s_addr = htonl(INADDR_ANY);

    rc = bind(TCPSock, (struct sockaddr *)&name, sizeof(name));
    if (rc < 0) {
      syslog(LOG_ERR, "listen, error binding, %d", errno);
      return;
    }

    /* listen for 5 seconds */
    rc = listen(TCPSock, 5);
    if (rc < 0) {
      syslog(LOG_ERR, "listen, error listening, %d", errno);
      return;
    }

    /* accept the connection */
    rc = accept(TCPSock, (struct sockaddr *) &client, &size);
    if (rc >= 0) {
      nbytes = recv(TCPSock, buffer, sizeof(buffer), MSG_WAITALL);
      if (nbytes < 0) {
        syslog(LOG_ERR, "listen, error receiving bytes");
        return;
      }

      syslog(LOG_DEBUG, "listen, received %d bytes", nbytes);
      beacon = [self NewBeacon:@"connected"];

      sprintf(msg, "%s\n%s\n%s\n%s\n%s\n%s\n%s",
         [[beacon objectAtIndex:0] UTF8String],
         [[beacon objectAtIndex:1] UTF8String],
         [[beacon objectAtIndex:2] UTF8String],
         [[beacon objectAtIndex:3] UTF8String],
         [[beacon objectAtIndex:4] UTF8String],
         [[beacon objectAtIndex:5] UTF8String],
         [[beacon objectAtIndex:6] UTF8String]
      );
      len = strlen(msg);

      nbytes = sendto(TCPSock, msg, len, 0, (struct sockaddr *)&client, sizeof(client));

      [beacon release];
    }

    close(TCPSock);
  }
}

-(void) startWithTimer
{
  BOOL ok;

  syslog(LOG_DEBUG, "startWithTimer..");
  ok = [self SendBeacon];
  if (!ok) {
    /* try one more time */
    ok = [self SendBeacon];
  }
}

-(void) start
{
  stopFlag = NO;

  [self startWithTimer];
  timer = [NSTimer scheduledTimerWithTimeInterval:30.0 target:self 
      selector:@selector(startWithTimer) userInfo:nil repeats:YES];
}

-(void) stop 
{
  stopFlag = YES;

  [timer invalidate];
  timer = nil;
}

-(void)addService: (NSString*)service
{
  [services addObject:service];

  BOOL ok = [self SendBeacon];
  if (!ok)
    ok = [self SendBeacon];
}

-(TivoDevice*)GetTivoDevice: (NSString *)address
{
  struct sockaddr_in peer;
  struct hostent *hostent = gethostbyname([address UTF8String]);
  int nbytes;
  unsigned int len;
  char msg[1024];
  TivoDevice *tivo;

  if (hostent == nil) {
    syslog(LOG_ERR, "Unable to gethostbyname.");
    return nil;
  }
  
  /* TODO!!  we need to tell FormatBeacon to exclude services */
  NSMutableArray *beacon = [self NewBeacon: @"connected"];

  int tsock = socket(AF_INET, SOCK_STREAM, 0);
  if (tsock < 0) {
    syslog(LOG_ERR, "socket() failed for beacon exchange.");
    return nil;
  }

  memset(&peer, 0, sizeof(struct sockaddr_in));

  memcpy(&(peer.sin_addr.s_addr), hostent->h_addr, hostent->h_length);
  peer.sin_family = AF_INET;
  peer.sin_port = htons(2190);

  /* connect to TiVo client and exchange connected beacons */
  if (connect(tsock, (struct sockaddr *)&peer, sizeof(peer)) < 0) {
    syslog(LOG_ERR, "connect() failed for beacon exchange.");
    close(tsock);
    [beacon release];
    return nil;
  }

  sprintf(msg, "%s\n%s\n%s\n%s\n%s\n%s\n%s",
     [[beacon objectAtIndex:0] UTF8String],
     [[beacon objectAtIndex:1] UTF8String],
     [[beacon objectAtIndex:2] UTF8String],
     [[beacon objectAtIndex:3] UTF8String],
     [[beacon objectAtIndex:4] UTF8String],
     [[beacon objectAtIndex:5] UTF8String],
     "services=TiVoMediaServer:0/http"
  );
  len = strlen(msg);

  syslog(LOG_DEBUG, "get_name(), sending beacon %s", msg);

  /* now send our beacon length + beacon */
  len = (len << 24);
  nbytes = send(tsock, &len, sizeof(len), 0);
  nbytes = send(tsock, msg, strlen(msg), 0);

  syslog(LOG_DEBUG, "get_name(), sent beacon (%d) of (%d)", nbytes, (len >> 24));

  /* receive their beacon */
  memset(msg, 0, 1024);
  nbytes = recv(tsock, &len, sizeof(len), MSG_WAITALL);
  len = (len >> 24);
  nbytes = recv(tsock, &msg, len, MSG_WAITALL);

  [beacon release];
  close(tsock);

  tivo = [self ParseDevice: msg];

  syslog(LOG_DEBUG, "get_name(), beacon received %s", [tivo->machine_name UTF8String]);

  return tivo;
}

@end
