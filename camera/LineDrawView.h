#import <UIKit/UIKit.h>
@interface LineDrawView : UIView
{
    NSMutableArray *lines;
    CGPoint pointA, pointB;
    BOOL activeLine;
    CGImageRef image;
    NSNumber *fct;//[NSNumber numberWithFloat:0];
}
- (void)setPoints:(CGPoint)A B:(CGPoint)B;
- (void)clearPoints;
- (void)setImage:(CGImageRef)im;
- (void)setFct:(NSNumber *)fct;
@end
