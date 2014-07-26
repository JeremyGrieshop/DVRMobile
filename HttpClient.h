
#import <CoreFoundation/CoreFoundation.h>
#import <Foundation/Foundation.h>

#include <openssl/ssl.h>
#include <openssl/md5.h>
#include <libxml/parser.h>
#include <libxml/tree.h>


@interface HttpClient : NSObject
{
  SSL_METHOD *meth;
  SSL_CTX *ctx;
  SSL *ssl;
  int sock;
  BOOL secure;
  int errorCode;
  NSString *authUser, *authPass;
  NSMutableArray *responseHeaders;
  int returnCode, contentLength;
  char *realm, *nonce;
  char *serverResponse;
  xmlDocPtr responseXML;
}

static const int ERROR_UNKNOWN     = -1;
static const int ERROR_NONE        = 0;
static const int ERROR_TCP_CONNECT = 1;
static const int ERROR_SSL_CONNECT = 2;
static const int ERROR_SOCKET      = 3;
static const int ERROR_GETHOST     = 4;
static const int ERROR_WRITE       = 5;
static const int ERROR_READ        = 6;
static const int ERROR_UNAUTH      = 7;
static const int ERROR_FORBIDDEN   = 8;
static const int ERROR_HTTP        = 9;

-(void)initializeSSL;
-(int)getErrorCode;
-(void)setAuth: (NSString*)user password:(NSString*)pass;
-(BOOL)Connect: (NSString*)host port:(int)port secure:(BOOL)s;
-(BOOL)WriteData: (char*)buf size:(int)size;
-(int)ReadData: (char*)buf size:(int)max;
-(BOOL)getRequest: (NSString*)host port:(int)port uri:(NSString *)uri secure:(BOOL)s;
-(int) GetReturnCode;
-(char*) GetResponseBuffer;
-(xmlDocPtr) GetResponseXML;
@end
