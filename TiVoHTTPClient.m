
#import "HttpClient.h"
#import "TiVoHTTPClient.h"

#include <libxml/parser.h>
#include <libxml/tree.h>
#include <libxml/xpath.h>
#include <libxml/xpathInternals.h>
#include <syslog.h>


@implementation TiVoItem
{
}
@end

@implementation TiVoContainer
{
}
@end

@implementation TiVoHTTPClient
{
}

-(void)initialize: (NSString *)h port:(int)p secure:(BOOL)s 
    user:(NSString*)u password:(NSString*)pass
{
  host = h;
  port = p;
  secure = s;
  user = u;
  password = pass;
  errorCode = ERROR_UNKNOWN;
}

-(TiVoContainer *) QueryContainer: (NSString *)container
{
  TiVoContainer *tivoContainer = nil;
  xmlXPathContextPtr xpathCtx;
  xmlXPathObjectPtr xpathObj;
  xmlChar *xpathExpr;

  httpClient = [HttpClient alloc];
  [httpClient initializeSSL];
  [httpClient setAuth: user password: password];

  NSString *uri = [NSString stringWithFormat: 
        @"/TiVoConnect?Command=QueryContainer&Container=%@", container];

  [httpClient getRequest:host port:port uri:uri secure:secure];
  errorCode = [httpClient getErrorCode];
  if (errorCode != ERROR_NONE) {
    syslog(LOG_DEBUG, "Error in http request, returning code %d", errorCode);
    [httpClient release];
    return nil;
  }

  xmlDoc *responseXML = [httpClient GetResponseXML];
  if (!responseXML) {
    [httpClient release];
    errorCode = ERROR_XML_PARSE;
    return nil;
  }

  syslog(LOG_DEBUG, "TiVoHTTPClient parsed an XML response.");

  xpathCtx = xmlXPathNewContext(responseXML);
  if (xpathCtx == NULL) {
    syslog(LOG_ERR, "TiVoHTTClient: unable to create XPath context!");
    [httpClient release];
    xmlFreeDoc(responseXML);
    errorCode = ERROR_XML_XPATH;
    return nil;
  }

  /* register default namespace of "tivo" */
  xmlXPathRegisterNs(xpathCtx, "tivo", "http://www.tivo.com/developer/calypso-protocol-1.6/");

  xpathExpr = BAD_CAST "/tivo:TiVoContainer/tivo:Details/tivo:Title/text()";
  xpathObj = xmlXPathEvalExpression(xpathExpr, xpathCtx);
  if (xmlXPathNodeSetIsEmpty(xpathObj->nodesetval)) {
    xpathExpr = BAD_CAST "/TiVoContainer/Details/Title/text()";
    xpathObj = xmlXPathEvalExpression(xpathExpr, xpathCtx);
  }

  if (xmlXPathNodeSetIsEmpty(xpathObj->nodesetval)) {
    syslog(LOG_ERR, "TiVoHTTClient: unable to find a container Title!");
    [httpClient release];
    xmlXPathFreeContext(xpathCtx);
    xmlFreeDoc(responseXML);
    errorCode = ERROR_XML_NO_TITLE;
    return nil;
  }

  tivoContainer = [TiVoContainer alloc];
  tivoContainer->title = [NSString stringWithCString: xpathObj->nodesetval->nodeTab[0]->content];

  /* find all Item elements */
  xpathExpr = BAD_CAST "/tivo:TiVoContainer/tivo:Item";
  xpathObj = xmlXPathEvalExpression(xpathExpr, xpathCtx);
  if (xmlXPathNodeSetIsEmpty(xpathObj->nodesetval)) {
    xpathExpr = BAD_CAST "/TiVoContainer/Item";
    xpathObj = xmlXPathEvalExpression(xpathExpr, xpathCtx);
  }

  if (xmlXPathNodeSetIsEmpty(xpathObj->nodesetval)) {
    syslog(LOG_DEBUG, "TiVoHTTClient: unable to find Items!");
    [httpClient release];
    xmlXPathFreeContext(xpathCtx);
    xmlFreeDoc(responseXML);
    errorCode = ERROR_XML_NO_ITEMS;
    return nil;
  }

  tivoContainer->totalItems = xpathObj->nodesetval->nodeNr;
  tivoContainer->items = [[NSMutableArray alloc] initWithCapacity: 
        tivoContainer->totalItems];
  xmlXPathFreeObject(xpathObj);

  syslog(LOG_DEBUG, "Parsing %d items\n", tivoContainer->totalItems);
  int i;
  for (i = 1; i < tivoContainer->totalItems+1; i++) {
    TiVoItem *item = [TiVoItem alloc];
    char expr[256];

    sprintf(expr, "/tivo:TiVoContainer/tivo:Item[%d]/tivo:Details/tivo:Title/text()", i);
    xpathExpr = BAD_CAST expr;
    xpathObj = xmlXPathEvalExpression(xpathExpr, xpathCtx);
    if (xmlXPathNodeSetIsEmpty(xpathObj->nodesetval)) {
      sprintf(expr, "/TiVoContainer/Item[%d]/Details/Title/text()", i);
      xpathExpr = BAD_CAST expr;
      xpathObj = xmlXPathEvalExpression(xpathExpr, xpathCtx);
    }

    if (!xmlXPathNodeSetIsEmpty(xpathObj->nodesetval))
      item->title = [NSString stringWithCString: xpathObj->nodesetval->nodeTab[0]->content]; 
    xmlXPathFreeObject(xpathObj);

    sprintf(expr, "/tivo:TiVoContainer/tivo:Item[%d]/tivo:Details/tivo:ContentType/text()", i);
    xpathExpr = BAD_CAST expr;
    xpathObj = xmlXPathEvalExpression(xpathExpr, xpathCtx);
    if (xmlXPathNodeSetIsEmpty(xpathObj->nodesetval)) {
      sprintf(expr, "/TiVoContainer/Item[%d]/Details/ContentType/text()", i);
      xpathExpr = BAD_CAST expr;
      xpathObj = xmlXPathEvalExpression(xpathExpr, xpathCtx);
    }

    if (!xmlXPathNodeSetIsEmpty(xpathObj->nodesetval)) {
      item->contentType = [NSString stringWithCString: 
             xpathObj->nodesetval->nodeTab[0]->content];
      tivoContainer->contentType = item->contentType;
    }
    xmlXPathFreeObject(xpathObj);

    sprintf(expr, "/tivo:TiVoContainer/tivo:Item[%d]/tivo:Details/tivo:SourceFormat/text()", i);
    xpathExpr = BAD_CAST expr;
    xpathObj = xmlXPathEvalExpression(xpathExpr, xpathCtx);
    if (xmlXPathNodeSetIsEmpty(xpathObj->nodesetval)) {
      sprintf(expr, "/TiVoContainer/Item[%d]/Details/SourceFormat/text()", i);
      xpathExpr = BAD_CAST expr;
      xpathObj = xmlXPathEvalExpression(xpathExpr, xpathCtx);
    }

    if (!xmlXPathNodeSetIsEmpty(xpathObj->nodesetval))
      item->sourceFormat = [NSString stringWithCString: xpathObj->nodesetval->nodeTab[0]->content];
    xmlXPathFreeObject(xpathObj);

    sprintf(expr, "/tivo:TiVoContainer/tivo:Item[%d]/tivo:Links/tivo:Content/tivo:Url/text()", i);
    xpathExpr = BAD_CAST expr;
    xpathObj = xmlXPathEvalExpression(xpathExpr, xpathCtx);
    if (xmlXPathNodeSetIsEmpty(xpathObj->nodesetval)) {
      sprintf(expr, "/TiVoContainer/Item[%d]/Links/Content/Url/text()", i);
      xpathExpr = BAD_CAST expr;
      xpathObj = xmlXPathEvalExpression(xpathExpr, xpathCtx);
    }

    if (!xmlXPathNodeSetIsEmpty(xpathObj->nodesetval))
      item->url = [NSString stringWithCString: xpathObj->nodesetval->nodeTab[0]->content];
    xmlXPathFreeObject(xpathObj);

    /* check for the item type */
    if ([item->contentType hasPrefix: @"video/"]) {
      sprintf(expr, "/tivo:TiVoContainer/tivo:Item[%d]/tivo:Details/tivo:SourceSize/text()", i);
      xpathExpr = BAD_CAST expr;
      xpathObj = xmlXPathEvalExpression(xpathExpr, xpathCtx);
      if (xmlXPathNodeSetIsEmpty(xpathObj->nodesetval)) {
        sprintf(expr, "/TiVoContainer/Item[%d]/Details/SourceSize/text()", i);
        xpathExpr = BAD_CAST expr;
        xpathObj = xmlXPathEvalExpression(xpathExpr, xpathCtx);
      }

      if (!xmlXPathNodeSetIsEmpty(xpathObj->nodesetval))
        item->sourceSize = [NSString stringWithCString: 
             xpathObj->nodesetval->nodeTab[0]->content];
      xmlXPathFreeObject(xpathObj);

      sprintf(expr, "/tivo:TiVoContainer/tivo:Item[%d]/tivo:Details/tivo:Duration/text()", i);
      xpathExpr = BAD_CAST expr;
      xpathObj = xmlXPathEvalExpression(xpathExpr, xpathCtx);
      if (xmlXPathNodeSetIsEmpty(xpathObj->nodesetval)) {
        sprintf(expr, "/TiVoContainer/Item[%d]/Details/Duration/text()", i);
        xpathExpr = BAD_CAST expr;
        xpathObj = xmlXPathEvalExpression(xpathExpr, xpathCtx);
      }

      if (!xmlXPathNodeSetIsEmpty(xpathObj->nodesetval))
        item->duration = [NSString stringWithCString: 
             xpathObj->nodesetval->nodeTab[0]->content];
      xmlXPathFreeObject(xpathObj);

      sprintf(expr, "/tivo:TiVoContainer/tivo:Item[%d]/tivo:Details/tivo:CaptureDate/text()", i);
      xpathExpr = BAD_CAST expr;
      xpathObj = xmlXPathEvalExpression(xpathExpr, xpathCtx);
      if (xmlXPathNodeSetIsEmpty(xpathObj->nodesetval)) {
        sprintf(expr, "/TiVoContainer/Item[%d]/Details/CaptureDate/text()", i);
        xpathExpr = BAD_CAST expr;
        xpathObj = xmlXPathEvalExpression(xpathExpr, xpathCtx);
      }

      if (!xmlXPathNodeSetIsEmpty(xpathObj->nodesetval))
        item->captureDate = [NSString stringWithCString: 
             xpathObj->nodesetval->nodeTab[0]->content];
      xmlXPathFreeObject(xpathObj);

      sprintf(expr, "/tivo:TiVoContainer/tivo:Item[%d]/tivo:Details/tivo:EpisodeTitle/text()", i);
      xpathExpr = BAD_CAST expr;
      xpathObj = xmlXPathEvalExpression(xpathExpr, xpathCtx);
      if (xmlXPathNodeSetIsEmpty(xpathObj->nodesetval)) {
        sprintf(expr, "/TiVoContainer/Item[%d]/Details/EpisodeTitle/text()", i);
        xpathExpr = BAD_CAST expr;
        xpathObj = xmlXPathEvalExpression(xpathExpr, xpathCtx);
      }

      if (!xmlXPathNodeSetIsEmpty(xpathObj->nodesetval))
        item->episodeTitle = [NSString stringWithCString: 
             xpathObj->nodesetval->nodeTab[0]->content];
      xmlXPathFreeObject(xpathObj);

      sprintf(expr, "/tivo:TiVoContainer/tivo:Item[%d]/tivo:Details/tivo:Description/text()", i);
      xpathExpr = BAD_CAST expr;
      xpathObj = xmlXPathEvalExpression(xpathExpr, xpathCtx);
      if (xmlXPathNodeSetIsEmpty(xpathObj->nodesetval)) {
        sprintf(expr, "/TiVoContainer/Item[%d]/Details/Description/text()", i);
        xpathExpr = BAD_CAST expr;
        xpathObj = xmlXPathEvalExpression(xpathExpr, xpathCtx);
      }

      if (!xmlXPathNodeSetIsEmpty(xpathObj->nodesetval))
        item->description = [NSString stringWithCString: 
             xpathObj->nodesetval->nodeTab[0]->content];
      xmlXPathFreeObject(xpathObj);

      sprintf(expr, "/tivo:TiVoContainer/tivo:Item[%d]/tivo:Details/tivo:SourceChannel/text()", i);
      xpathExpr = BAD_CAST expr;
      xpathObj = xmlXPathEvalExpression(xpathExpr, xpathCtx);
      if (xmlXPathNodeSetIsEmpty(xpathObj->nodesetval)) {
        sprintf(expr, "/TiVoContainer/Item[%d]/Details/SourceChannel/text()", i);
        xpathExpr = BAD_CAST expr;
        xpathObj = xmlXPathEvalExpression(xpathExpr, xpathCtx);
      }

      if (!xmlXPathNodeSetIsEmpty(xpathObj->nodesetval))
        item->sourceChannel = [NSString stringWithCString: 
             xpathObj->nodesetval->nodeTab[0]->content];
      xmlXPathFreeObject(xpathObj);

      sprintf(expr, "/tivo:TiVoContainer/tivo:Item[%d]/tivo:Details/tivo:SourceStation/text()", i);
      xpathExpr = BAD_CAST expr;
      xpathObj = xmlXPathEvalExpression(xpathExpr, xpathCtx);
      if (xmlXPathNodeSetIsEmpty(xpathObj->nodesetval)) {
        sprintf(expr, "/TiVoContainer/Item[%d]/Details/SourceStation/text()", i);
        xpathExpr = BAD_CAST expr;
        xpathObj = xmlXPathEvalExpression(xpathExpr, xpathCtx);
      }

      if (!xmlXPathNodeSetIsEmpty(xpathObj->nodesetval))
        item->sourceStation = [NSString stringWithCString: 
             xpathObj->nodesetval->nodeTab[0]->content];
      xmlXPathFreeObject(xpathObj);

      sprintf(expr, "/tivo:TiVoContainer/tivo:Item[%d]/tivo:Details/tivo:HighDefinition/text()", i);
      xpathExpr = BAD_CAST expr;
      xpathObj = xmlXPathEvalExpression(xpathExpr, xpathCtx);
      if (!xmlXPathNodeSetIsEmpty(xpathObj->nodesetval))
      item->highDef = [[NSString stringWithCString: 
               xpathObj->nodesetval->nodeTab[0]->content] boolValue];
      xmlXPathFreeObject(xpathObj);

      sprintf(expr, "/tivo:TiVoContainer/tivo:Item[%d]/tivo:Details/tivo:ProgramId/text()", i);
      xpathExpr = BAD_CAST expr;
      xpathObj = xmlXPathEvalExpression(xpathExpr, xpathCtx);
      if (!xmlXPathNodeSetIsEmpty(xpathObj->nodesetval))
        item->programId = [NSString stringWithCString: 
             xpathObj->nodesetval->nodeTab[0]->content];
      xmlXPathFreeObject(xpathObj);

      sprintf(expr, "/tivo:TiVoContainer/tivo:Item[%d]/tivo:Details/tivo:SeriesId/text()", i);
      xpathExpr = BAD_CAST expr;
      xpathObj = xmlXPathEvalExpression(xpathExpr, xpathCtx);
      if (!xmlXPathNodeSetIsEmpty(xpathObj->nodesetval))
        item->seriesId = [NSString stringWithCString: 
             xpathObj->nodesetval->nodeTab[0]->content];
      xmlXPathFreeObject(xpathObj);
    }

    [tivoContainer->items addObject: item];
  }
      

  xmlXPathFreeContext(xpathCtx);
  xmlFreeDoc(responseXML);

  [httpClient release];

  syslog(LOG_DEBUG, "TiVoHTTPClient returning with tivoContainer.");

  return tivoContainer;
}

-(int) GetErrorCode
{
  return errorCode;
}
@end
