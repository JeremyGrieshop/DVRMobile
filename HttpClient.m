
#import "HttpClient.h"
#import <CoreFoundation/CoreFoundation.h>
#import <Foundation/Foundation.h>

#include <unistd.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <sys/socket.h>
#include <netdb.h>
#include <syslog.h>
#include <stdio.h>
#include <openssl/ssl.h>
#include <openssl/md5.h>
#include <libxml/parser.h>
#include <libxml/tree.h>


@implementation HttpClient 
{
}

static int HTTP_OK             = 200;
static int HTTP_UNAUTHORIZED   = 401;
static int HTTP_FORBIDDEN      = 403;
static int HTTP_NOT_FOUND      = 404;
static int HTTP_INTERNAL_ERROR = 500;

-(void)initializeSSL
{
  /* init SSL libraries */
  SSL_library_init();
  SSL_load_error_strings();

  meth = SSLv23_method();
  ctx = SSL_CTX_new(meth);

  secure = YES;
}

-(int)getErrorCode
{
  syslog(LOG_DEBUG, "getErrorCode returning %d", errorCode);
  return errorCode;
}

-(void)setAuth: (NSString*)user password:(NSString*)pass
{
  authUser = user;
  authPass = pass;
}

-(void)Close
{
  if (secure) {
    if (ssl && !SSL_get_shutdown(ssl))
      SSL_shutdown(ssl);
  }

  close(sock);
}

-(BOOL)Connect: (NSString*)host port:(int)port secure:(BOOL)s
{
  struct sockaddr_in sock_sin;
  secure = s;

  sock = socket(AF_INET, SOCK_STREAM, 0);
  if (socket < 0) {
    syslog(LOG_ERR, "HttpClient unable to create socket, errno=%d", errno);
    errorCode = ERROR_SOCKET;
    return NO;
  }

  struct hostent *hostent = gethostbyname( [host UTF8String] );
  if (hostent == NULL) {
    syslog(LOG_ERR, "HttpClient unable to resolve host %s, errno=%d", [host UTF8String], errno);
    close(sock);
    errorCode = ERROR_GETHOST;
    return NO;
  }

  memset(&sock_sin, 0, sizeof(struct sockaddr_in));
  sock_sin.sin_family = AF_INET;
  memcpy(&(sock_sin.sin_addr.s_addr), hostent->h_addr, hostent->h_length);
  sock_sin.sin_port = htons(port);

  int rc = connect(sock, (struct sockaddr *)&sock_sin, sizeof(struct sockaddr_in));
  if (rc) {
    syslog(LOG_ERR, "HttpClient unable to connect to host %s:%d, errno=%d", [host UTF8String], port, errno);
    close(sock);
    errorCode = ERROR_TCP_CONNECT;
    syslog(LOG_DEBUG, "setting errorCode to %d", errorCode);
    return NO;
  }

  syslog(LOG_DEBUG, "HttpClient connected to %s:%d", [host UTF8String], port);

  if (secure) {
    ssl = SSL_new(ctx);
    SSL_set_fd(ssl, sock);

    rc = SSL_connect(ssl);
    if (rc <= 0) {
      syslog(LOG_ERR, "HttpClient unable to make SSL connection to %s:%d", [host UTF8String], port);
      close(sock);
      errorCode = ERROR_SSL_CONNECT;
      return NO;
    }

    syslog(LOG_DEBUG, "HttpClient connected (SSL) to %s:%d", [host UTF8String], port);
  }

  return YES;
}

-(BOOL)WriteData: (char*)buf size:(int)size
{
  int bytes_sent, bytes_left;
  char *ptr;

  bytes_left = size;
  ptr = buf;

  while (bytes_left > 0) {
    /* send in 8k chunks */
    int bytes_to_send = (bytes_left < 8192) ? bytes_left : 8192;

    if (secure) {
      bytes_sent = SSL_write(ssl, ptr, size);
    } else {
      bytes_sent = send(sock, ptr, bytes_to_send, 0);
    }

    if (bytes_sent < 0) {
      syslog(LOG_ERR, "Error sending bytes (%d of %d left) errno = %d",
          bytes_left, size, errno);
      errorCode = ERROR_WRITE;
      return NO;
    }

    bytes_left -= bytes_sent;
    ptr += bytes_sent;
  }

  return YES;
}

-(int)ReadData: (char*)buf size:(int)max
{
  int rc = -1;
  int bytes_read = 0;

  if (secure) {
    rc = SSL_read(ssl, buf, max);
    bytes_read += rc;
    while (rc > 0 && (bytes_read < max)) {
      rc = SSL_read(ssl, buf+bytes_read, (max-bytes_read));
      if (rc > 0)
        bytes_read += rc;
    }

    if (rc < 0)
      errorCode = ERROR_READ;
  } else {
    rc = recv(sock, buf, max, 0);
    bytes_read += rc;
    while (rc > 0 && (bytes_read < max)) {
      rc = recv(sock, buf+bytes_read, (max-bytes_read), 0);
      if (rc > 0)
        bytes_read += rc;
    }

    if (rc < 0)
      errorCode = ERROR_READ;
  }

  return bytes_read;
}

-(void)ReadLine: (char*)buf size:(int)size
{
  int nbytes;
  char mybuf[2];
  char *ptr = buf;

  memset(buf, 0, size);

  if (secure)
    nbytes = SSL_read(ssl, mybuf, 1);
  else
    nbytes = recv(sock, mybuf, 1, 0);

  while (mybuf[0] != '\n' && nbytes == 1 && ptr < (buf+size)) {
    if (nbytes == 1 && mybuf[0] != '\r') {
      *ptr = mybuf[0];
      ptr++;
    }

    if (secure)
      nbytes = SSL_read(ssl, mybuf, 1);
    else
      nbytes = recv(sock, mybuf, 1, 0);
  }

  if (nbytes != 1)
    syslog(LOG_ERR, "ReadLine failed, errno=%d", errno);
}

-(void)ParseHeader: (char*)headerLine
{
  contentLength = 0;

  syslog(LOG_DEBUG, "parsing header: [%s]", headerLine);
  if (strncmp(headerLine, "HTTP/1.", 7) == 0) {
    /* parse the return code */
    char return_code[8];
    memset(return_code, 0, 8);
    strncpy(return_code, headerLine+9, 3);

    returnCode = atoi(return_code);
    syslog(LOG_DEBUG, "parsed return code [%d]", returnCode);
  } else if (strncmp(headerLine, "Server:", 7) == 0) {
    /* parse the server header */
  } else if (strncmp(headerLine, "Set-Cookie:", 11) == 0) {
    /* parse the set-cookie header */
  } else if (strncmp(headerLine, "WWW-Authenticate:", 17) == 0) {
    /* parse the www-authenticate header */
    char *ptr = headerLine + 18;
    if (strncmp(ptr, "Digest", 6) == 0) {
      /* for Digest authentication, we need the realm and nonce */
      ptr += 6;
      while (*ptr) {
        if (strncmp(ptr, "realm=\"", 7) == 0) {
          ptr += 7;
          char *ptr2 = ptr;
          while (*ptr2 && (*ptr2 != '"')) ptr2++;
     
          realm = malloc(ptr2-ptr+1);
          memset(realm, 0, ptr2-ptr+1);
          strncpy(realm, ptr, ptr2-ptr);
        } else if (strncmp(ptr, "nonce=\"", 7) == 0) {
          ptr += 7;
          char *ptr2 = ptr;
          while (*ptr2 && (*ptr2 != '"')) ptr2++;
     
          nonce = malloc(ptr2-ptr+1); 
          memset(nonce, 0, ptr2-ptr+1);
          strncpy(nonce, ptr, ptr2-ptr);
        }

        ptr++;
      }
    }
  } else if (strncmp(headerLine, "Content-Length:", 15) == 0) {
    char content_length[8];
    char *ptr = headerLine + 16;
    while (*ptr && *ptr != ' ' && *ptr != '\r') ptr++;
    memset(content_length, 0, 8);
    strncpy(content_length, headerLine+16, ptr - (headerLine+16));
    contentLength = atoi(content_length);
  } else if (strncmp(headerLine, "Content-Type:", 13) == 0) {
  } else if (strncmp(headerLine, "Connection:", 11) == 0) {
  }
}

/*
 * For Digest Authentication, we send back:
 *
 *    Authorization: Digest username="user", realm="realm", nonce="nonce"
 *           uri="uri", response="response"
 *
 *       Where response is calculated as:
 *
 *         HA1 = MD5(username:realm:password)
 *         HA2 = MD5(method:uri)
 *         response = MD5(HA1:nonce:HA2)
 *
 */
-(NSString *)GenerateAuthHeader: (NSString*)uri method:(NSString*)method
{
  char userRealmPass[256], methodUri[512], responseBuf[512];
  unsigned char HA1[512], HA2[512], RESPONSE[512];
  NSMutableString *ha1, *ha2, *response;
  NSString *responseHeader;
  EVP_MD_CTX mdctx;
  EVP_MD *md;
  unsigned int length;
  int i;

  md = EVP_get_digestbyname("md5");
  
  memset(HA1, 0, 512);
  sprintf(userRealmPass, "%s:%s:%s", [authUser UTF8String], realm, [authPass UTF8String]);
  EVP_MD_CTX_init(&mdctx);
  EVP_DigestInit_ex(&mdctx, md, NULL);
  EVP_DigestUpdate(&mdctx, userRealmPass, strlen(userRealmPass));
  EVP_DigestFinal_ex(&mdctx, HA1, &length);
  EVP_MD_CTX_cleanup(&mdctx);

  ha1 = [[[NSMutableString alloc] init] autorelease];
  for (i = 0; i < length; i++)
    [ha1 appendFormat:@"%02x", HA1[i]];

  memset(HA2, 0, 512);
  sprintf(methodUri, "%s:%s", [method UTF8String], [uri UTF8String]);
  EVP_MD_CTX_init(&mdctx);
  EVP_DigestInit_ex(&mdctx, md, NULL);
  EVP_DigestUpdate(&mdctx, methodUri, strlen(methodUri));
  EVP_DigestFinal_ex(&mdctx, HA2, &length);
  EVP_MD_CTX_cleanup(&mdctx);

  ha2 = [[[NSMutableString alloc] init] autorelease];
  for (i = 0; i < length; i++)
    [ha2 appendFormat:@"%02x", HA2[i]];

  memset(RESPONSE, 0, 512);
  sprintf(responseBuf, "%s:%s:%s", [ha1 UTF8String], nonce, [ha2 UTF8String]); 
  EVP_MD_CTX_init(&mdctx);
  EVP_DigestInit_ex(&mdctx, md, NULL);
  EVP_DigestUpdate(&mdctx, responseBuf, strlen(responseBuf));
  EVP_DigestFinal_ex(&mdctx, RESPONSE, &length);
  EVP_MD_CTX_cleanup(&mdctx); 

  response = [[[NSMutableString alloc] init] autorelease];
  for (i = 0; i < length; i++)
    [response appendFormat:@"%02x", RESPONSE[i]];

  responseHeader = [NSString stringWithFormat: 
       @"Authorization: Digest username=\"%@\", realm=\"%s\", nonce=\"%s\", uri=\"%@\", response=\"%@\"\r\n",
       authUser, realm, nonce, uri, response];

  return responseHeader;
}

-(BOOL)getRequest: (NSString*)host port:(int)port uri:(NSString*)uri secure:(BOOL)s
{
  char buffer[1024];
  BOOL ok;

  serverResponse = NULL;
  responseXML = NULL;
  returnCode = 500;
  errorCode = ERROR_UNKNOWN;

  ok = [self Connect:host port:port secure:s];
  if (!ok) {
    return NO;
  }

  syslog(LOG_DEBUG, "HttpClient, getRequest for %s", [uri UTF8String]);
  sprintf(buffer, "GET %s HTTP/1.0\r\n", [uri UTF8String]);
  /* write out the GET line */
  ok = [self WriteData: buffer size:strlen(buffer)];
  if (!ok) {
    return NO;
  }

  ok = [self WriteData:"\r\n" size:2];
  if (!ok) {
    return NO;
  }

  /* now parse the response */
  memset(buffer, 0, 1024);
  [self ReadLine: buffer size:1024];
  while (strlen(buffer) > 0) {
    [self ParseHeader:buffer];

    memset(buffer, 0, 1024);
    [self ReadLine: buffer size:1024];
  }

  /* check the return code for unauthorized */
  if ((returnCode == HTTP_UNAUTHORIZED || returnCode == HTTP_FORBIDDEN) && 
          authUser && authPass) {
    syslog(LOG_DEBUG, "HttpClient: Got an unauthorized return code, trying %s/%s.", 
          [authUser UTF8String], [authPass UTF8String]);

    /* try authenticating */
    NSString *authHeader = [self GenerateAuthHeader:uri method:@"GET"];

    ok = [self Connect:host port:port secure:s];
    if (!ok) {
      return NO;
    }
   
    sprintf(buffer, "GET %s HTTP/1.0\r\n", [uri UTF8String]);
    ok = [self WriteData:buffer size:strlen(buffer)];
    if (!ok) {
      return NO;
    }

    ok = [self WriteData:[authHeader UTF8String] size:strlen([authHeader UTF8String])];
    if (!ok) {
      return NO;
    }

    ok = [self WriteData:"\r\n" size:2];
    if (!ok) {
      return NO;
    }

    /* now parse the response */
    memset(buffer, 0, 1024);
    [self ReadLine: buffer size:1024];
    while (strlen(buffer) > 0) {
      [self ParseHeader: buffer];

      memset(buffer, 0, 1024);
      [self ReadLine: buffer size:1024];
    }
  }

  /* if we got a HTTP_OK, parse the return doc */
  int maxSize = 16384;
  if (returnCode == HTTP_OK) {
    syslog(LOG_DEBUG, "HttpClient received HTTP_OK.");

    if (contentLength == 0)
      contentLength = maxSize;

    serverResponse = malloc(contentLength+1);
    memset(serverResponse, 0, contentLength+1);

    int read = [self ReadData:serverResponse size:contentLength];
    while (read == maxSize) {
      syslog(LOG_DEBUG, "HttpClient: Need more buffer to read!.");

      char *ptr = serverResponse;
      serverResponse = malloc(maxSize*2+1);
      memset(serverResponse, 0, maxSize*2+1);
      memcpy(serverResponse, ptr, maxSize);
      free(ptr);

      maxSize *= 2;
      contentLength = maxSize;
      read += [self ReadData:(serverResponse+read) size:(contentLength/2)];
    }
 
    errorCode = ERROR_NONE;
  } else {
    syslog(LOG_DEBUG, "HttpClient: Got a return code of %d.", returnCode);

    if (returnCode == HTTP_UNAUTHORIZED)
      errorCode = ERROR_UNAUTH;
    else if (returnCode == HTTP_FORBIDDEN)
      errorCode = ERROR_FORBIDDEN;
    else
      errorCode = ERROR_HTTP;
  }

  /* close the connection */
  [self Close];

  return YES;
}

-(int) GetReturnCode
{
  return returnCode;
}

-(char*) GetResponseBuffer
{
  return serverResponse;
}

-(xmlDocPtr) GetResponseXML
{
  if (responseXML == NULL && serverResponse && (returnCode == HTTP_OK))
    responseXML = xmlReadMemory(serverResponse, strlen(serverResponse),
            "ServerResponse.xml", NULL, 0);

  return responseXML;
}

-(void)dealloc
{
  if (realm)
    free(realm);
  if (nonce)
    free(nonce);
  if (serverResponse)
    free(serverResponse);

  [super dealloc];
}

@end
