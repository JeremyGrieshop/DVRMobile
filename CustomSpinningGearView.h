
#import <UIKit/UIKit.h>

@interface CustomSpinningGearView : UIView
{
  UIActivityIndicatorView *spinningGear;
  UILabel *customLabel;
}
-(void)initialize;
-(void)setText: (NSString *)text;
-(void)show;
-(void)stop;
-(void)drawRect: (CGRect)rect;
@end
