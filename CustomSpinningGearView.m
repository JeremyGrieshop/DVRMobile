
#import "CustomSpinningGearView.h"

#include <syslog.h>

@implementation CustomSpinningGearView 
{
}

-(void)initialize
{
  [self initWithFrame: CGRectMake(65, 120, 190, 165)];
  super.backgroundColor = [UIColor clearColor];
  super.opaque = NO;
  self.alpha = 0.8;

  spinningGear = [[[UIActivityIndicatorView alloc] 
       initWithFrame:CGRectMake(70,40,50,50)] autorelease];
  spinningGear.activityIndicatorViewStyle = UIActivityIndicatorViewStyleWhite;
  [spinningGear setBackgroundColor: [UIColor clearColor]];
  spinningGear.alpha = 1.0;
  spinningGear.opaque = NO;

  customLabel = [[[UILabel alloc] initWithFrame:CGRectMake(0,80,190,90)] autorelease];
  [customLabel setBackgroundColor: [UIColor clearColor]];
  customLabel.font = [UIFont boldSystemFontOfSize:22];
  customLabel.textColor = [UIColor whiteColor];
  customLabel.lineBreakMode = UILineBreakModeWordWrap;
  customLabel.numberOfLines = 0;
  customLabel.alpha = 1.0;
  customLabel.opaque = NO;
  customLabel.textAlignment = UITextAlignmentCenter;

  self.hidden = YES;
  [self addSubview: customLabel];
  [self addSubview: spinningGear];
}

-(void)setText: (NSString *)text
{
  [customLabel performSelectorOnMainThread: @selector(setText:) withObject:text waitUntilDone:NO];
  [self setNeedsDisplay];
}

-(void)show
{
  self.hidden = NO;
  [spinningGear startAnimating];
}

-(void)stop
{
  self.hidden = YES;
  [spinningGear stopAnimating];
}

-(void)setBackgroundColor: (UIColor *)newBGColor
{
  // Ignore any attempt to set the background color
  //[super setBackgroundColor: [UIColor clearColor]];
}

-(void)setOpaque:(BOOL)b
{
  // ignore any attempt to set the opaque to YES
  //self.opaque = NO;
}

-(void)drawRect: (CGRect)rect
{
  int corner_radius = 30;

  UIColor *black = [UIColor blackColor];

  CGContextRef context = UIGraphicsGetCurrentContext();
  CGContextBeginPath(context);
  CGContextSetLineWidth(context, 1.0);
  CGContextSetStrokeColorWithColor(context, [black CGColor]);
  CGContextSetFillColorWithColor(context, [black CGColor]);

  CGRect rrect = self.bounds;
  
  CGFloat radius = 25;
  CGFloat width = CGRectGetWidth(rrect);
  CGFloat height = CGRectGetHeight(rrect);
  
  // Make sure corner radius isn't larger than half the shorter side
  if (radius > width/2.0)
      radius = width/2.0;
  if (radius > height/2.0)
      radius = height/2.0;    
  
  CGFloat minx = CGRectGetMinX(rrect);
  CGFloat midx = CGRectGetMidX(rrect);
  CGFloat maxx = CGRectGetMaxX(rrect);
  CGFloat miny = CGRectGetMinY(rrect);
  CGFloat midy = CGRectGetMidY(rrect);
  CGFloat maxy = CGRectGetMaxY(rrect);
  CGContextMoveToPoint(context, minx, midy);
  CGContextAddArcToPoint(context, minx, miny, midx, miny, radius);
  CGContextAddArcToPoint(context, maxx, miny, maxx, midy, radius);
  CGContextAddArcToPoint(context, maxx, maxy, midx, maxy, radius);
  CGContextAddArcToPoint(context, minx, maxy, minx, midy, radius);
  CGContextClosePath(context);
  CGContextDrawPath(context, kCGPathFillStroke);
  CGContextClip(context);
}
@end
