#import "LineDrawView.h"
@implementation LineDrawView
- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self)
    {
       // self.backgroundColor = [UIColor blackColor];
        self.opaque=NO;
        lines = [[NSMutableArray alloc] init];
        fct=[NSNumber numberWithFloat:1];
      //  pointA=CGPointMake(5,5);
      //  pointB=CGPointMake(100,100);
        
      //  pointB = [[touches anyObject] locationInView:self];
      //  [lines addObject:[NSArray arrayWithObjects:[NSValue valueWithCGPoint:pointA], [NSValue valueWithCGPoint:pointB], nil]];
       // pointA = pointB;
       // pointB = CGPointZero;
        activeLine = NO;
    }
    return self;
}
- (void)dealloc
{
  //  [lines release];
  //  [super dealloc];
}

- (void) setFct:(NSNumber *)fcti
{
    fct=fcti;
}

- (void) clearPoints
{
    [lines removeAllObjects];
}
- (void) setPoints:(CGPoint)A B:(CGPoint)B
{
    [lines removeAllObjects];
   // printf("mm%f\n",A.y);
    CGPoint A2=CGPointMake(A.x, B.y);
    CGPoint B2=CGPointMake(B.x, A.y);
    [lines addObject:[NSArray arrayWithObjects:[NSValue valueWithCGPoint:A], [NSValue valueWithCGPoint:A2], nil]];
    [lines addObject:[NSArray arrayWithObjects:[NSValue valueWithCGPoint:A2], [NSValue valueWithCGPoint:B], nil]];
    [lines addObject:[NSArray arrayWithObjects:[NSValue valueWithCGPoint:B], [NSValue valueWithCGPoint:B2], nil]];
    [lines addObject:[NSArray arrayWithObjects:[NSValue valueWithCGPoint:B2], [NSValue valueWithCGPoint:A], nil]];
}

- (void) setImage:(CGImageRef) im
{
    image=CGImageCreateCopy(im);
}
/*
- (void) setRecti:(NSValue*)x y:(NSValue*)y x2:(NSValue*)x2 y2:(NSValue*)y2
{
    [lines removeAllObjects];
    // printf("mm%f\n",A.y);
   // [lines addObject:[NSArray arrayWithObjects:[NSValue valueWithCGPoint:A], [NSValue valueWithCGPoint:B], nil]];
}*/

/*
- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    [super touchesBegan:touches withEvent:event];
    CGPoint point = [[touches anyObject] locationInView:self];
    if ([lines count] == 0) pointA = point;
    else pointB = point;
    activeLine = YES;
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    [super touchesMoved:touches withEvent:event];
    pointB = [[touches anyObject] locationInView:self];
    [self setNeedsDisplay];
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    [super touchesEnded:touches withEvent:event];
    pointB = [[touches anyObject] locationInView:self];
    [lines addObject:[NSArray arrayWithObjects:[NSValue valueWithCGPoint:pointA], [NSValue valueWithCGPoint:pointB], nil]];
    pointA = pointB;
    pointB = CGPointZero;
    activeLine = NO;
    [self setNeedsDisplay];
}
*/
static inline double radians (double degrees) {return degrees * M_PI/180;}

- (void)drawRect:(CGRect)rect
{
    CGContextRef c = UIGraphicsGetCurrentContext();
    CGContextSetLineWidth(c, 2);
    CGContextSetLineCap(c, kCGLineCapRound);
    CGContextSetLineJoin(c, kCGLineJoinRound);
    CGContextSetStrokeColorWithColor(c, [UIColor blueColor].CGColor);
    for (NSArray *line in lines)
    {
        CGPoint points[2] = { [[line objectAtIndex:0] CGPointValue], [[line objectAtIndex:1] CGPointValue] };
        CGContextAddLines(c, points, 2);
    }


    CGContextStrokePath(c);
    CGContextSetStrokeColorWithColor(c, [UIColor whiteColor].CGColor);
    float fctu=[fct floatValue];//0.6;
    CGRect bounds=[self bounds];
    int top;
    int left;
    int height;
    if (bounds.size.width<bounds.size.height) {
        height=bounds.size.width*fctu;
        left=(bounds.size.width-bounds.size.width*fctu) /2;
        top=left+(bounds.size.height-bounds.size.width)/2;
    } else {
        height=bounds.size.height* fctu;
        top=(bounds.size.height-bounds.size.height*fctu) /2;;
        left=top+(bounds.size.width-bounds.size.height)/2;
    }
    //CGContextMoveToPoint(c,left,top);
    CGPoint points[2] = { {left,top}, {left,top+height-1}};//};
    CGContextAddLines(c, points, 2);
    CGPoint points2[2] = { {left,top+height-1}, {left+height-1,top+height-1}};//};
    CGContextAddLines(c, points2, 2);
    CGPoint points3[2] = { {left+height-1,top+height-1}, {left+height-1,top}};//};
    CGContextAddLines(c, points3, 2);
    CGPoint points4[2] = { {left+height-1,top}, {left,top}};//};
    CGContextAddLines(c, points4, 2);
    
    //  CGPoint points2[2] = { 50,100};//};
  //  CGContextAddLines(c, points2, 2);
    CGContextStrokePath(c);
    /*
    if (activeLine)
    {
        CGContextSetStrokeColorWithColor(c, [UIColor whiteColor].CGColor);
        CGPoint points2[2] = { pointA, pointB };
        CGContextAddLines(c, points2, 2);
        CGContextStrokePath(c);
    }*/
    
    if (image) {
        //[self bounds.]
       // CGContextRotateCTM (c, radians(90));
        CGContextDrawImage( c, CGRectMake(20,40,rect.size.width/3,rect.size.width/3), image);
    }
}
@end
