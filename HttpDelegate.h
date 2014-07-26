
#import <CoreFoundation/CoreFoundation.h>
#import <Foundation/Foundation.h>


@protocol HttpDelegate
-(BOOL) WriteData: (char*)data size:(int) size;
-(BOOL) WriteString: (char*)str;
-(BOOL) WriteLine: (char*)data;
-(void) ReadLine: (char*)buf size:(int)size;
-(void) SetStatus: (int)status;
-(NSString *)GetHeader: (NSString*) name;
@end

