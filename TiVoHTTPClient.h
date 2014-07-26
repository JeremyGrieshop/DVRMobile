
#import "HttpClient.h"

#include <libxml/parser.h>
#include <libxml/tree.h>

@interface TiVoItem : NSObject
{
@public
  NSString *contentType;
  NSString *sourceFormat;
  NSString *title;
  NSString *sourceSize;
  NSString *duration;
  NSString *captureDate;
  NSString *episodeTitle;
  NSString *description;
  NSString *sourceChannel;
  NSString *sourceStation;
  BOOL highDef;
  NSString *programId;
  NSString *seriesId;
  NSString *url;
}
@end

@interface TiVoContainer : NSObject
{
@public
  NSString *title;
  int totalItems;
  NSMutableArray *items;
  NSString *contentType;
}
@end

@interface TiVoHTTPClient : NSObject
{
  NSString *host;
  int port;
  NSString *user, *password;
  BOOL secure;
  HttpClient *httpClient;
  int errorCode;
}

static int ERROR_XML_PARSE     = 30;
static int ERROR_XML_XPATH     = 31;
static int ERROR_XML_NO_TITLE  = 32;
static int ERROR_XML_NO_ITEMS  = 33;

-(void)initialize: (NSString *)host port:(int)port secure:(BOOL)s 
     user:(NSString*)u password:(NSString*)p;
-(TiVoContainer *) QueryContainer: (NSString *)container;
-(int) GetErrorCode;
@end
