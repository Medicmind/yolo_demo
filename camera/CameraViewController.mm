#import <AssertMacros.h>
#import <AssetsLibrary/AssetsLibrary.h>
#import <CoreImage/CoreImage.h>
#import <ImageIO/ImageIO.h>
#import "CameraViewController.h"
#import "CameraAppDelegate.h"
#include <fstream>
#include <sys/time.h>
#include <queue>

#include "tensorflow_utils.h"

bool pauseu=false;  // should really replace with  if ([session isRunning]) {

// Yolo
const int INPUT_SIZE= 416; //608 for yolo; //416 for tiny-yolo-voc
float yolothreshold=0.03;
// Yolo end


static void *AVCaptureStillImageIsCapturingStillImageContext =
    &AVCaptureStillImageIsCapturingStillImageContext;

@interface CameraExampleViewController (InternalMethods) <UINavigationControllerDelegate,UIImagePickerControllerDelegate>
- (void)setupAVCapture;
- (void)teardownAVCapture;
@end

@implementation CameraExampleViewController

std::unique_ptr<tensorflow::Session> sessionu;

- (void)setupAVCapture {
   NSError *error = nil;

    // YOLO
   sessionu=createSession();
   session = [AVCaptureSession new];
   if ([[UIDevice currentDevice] userInterfaceIdiom] ==
      UIUserInterfaceIdiomPhone){
      
      [session setSessionPreset:AVCaptureSessionPresetHigh];//640x480];

   }else {
    [session setSessionPreset:AVCaptureSessionPresetPhoto];

   }
  AVCaptureDevice *device =
      [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
  AVCaptureDeviceInput *deviceInput =
      [AVCaptureDeviceInput deviceInputWithDevice:device error:&error];
  assert(error == nil);

  isUsingFrontFacingCamera = NO;
  if ([session canAddInput:deviceInput]) [session addInput:deviceInput];

  stillImageOutput = [AVCaptureStillImageOutput new];
  [stillImageOutput
      addObserver:self
       forKeyPath:@"capturingStillImage"
          options:NSKeyValueObservingOptionNew
          context:(void *)(AVCaptureStillImageIsCapturingStillImageContext)];
  if ([session canAddOutput:stillImageOutput])
    [session addOutput:stillImageOutput];

  videoDataOutput = [AVCaptureVideoDataOutput new];

  NSDictionary *rgbOutputSettings = [NSDictionary
      dictionaryWithObject:[NSNumber numberWithInt:kCMPixelFormat_32BGRA]
                    forKey:(id)kCVPixelBufferPixelFormatTypeKey];
  [videoDataOutput setVideoSettings:rgbOutputSettings];
  [videoDataOutput setAlwaysDiscardsLateVideoFrames:YES];
  videoDataOutputQueue =
      dispatch_queue_create("VideoDataOutputQueue", DISPATCH_QUEUE_SERIAL);
  [videoDataOutput setSampleBufferDelegate:self queue:videoDataOutputQueue];

  if ([session canAddOutput:videoDataOutput])
    [session addOutput:videoDataOutput];
  [[videoDataOutput connectionWithMediaType:AVMediaTypeVideo] setEnabled:YES];

  previewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:session];
  [previewLayer setBackgroundColor:[[UIColor blackColor] CGColor]];
  [previewLayer setVideoGravity:AVLayerVideoGravityResizeAspect];
  CALayer *rootLayer = [previewView layer];
  [rootLayer setMasksToBounds:YES];
  [previewLayer setFrame:[rootLayer bounds]];
  [rootLayer addSublayer:previewLayer];
    
   [session startRunning];

   drawLayer = [[LineDrawView alloc] init ];
    //copy bounds of preview
   [drawLayer setNeedsDisplay];
   [drawLayer setFrame:[previewView bounds]];
   [previewView addSubview:drawLayer];

  if (error) {
    NSString *title = [NSString stringWithFormat:@"Failed with error %d", (int)[error code]];
    UIAlertController *alertController =
        [UIAlertController alertControllerWithTitle:title
                                            message:[error localizedDescription]
                                     preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *dismiss =
        [UIAlertAction actionWithTitle:@"Dismiss" style:UIAlertActionStyleDefault handler:nil];
    [alertController addAction:dismiss];
    [self presentViewController:alertController animated:YES completion:nil];
    [self teardownAVCapture];
  }
    
   self.navigationController.navigationBar.hidden = YES;
    
}

- (IBAction)btLoadClick:(id)sender {
    [session stopRunning];

    pauseu=true;
    UIImagePickerController *imagePickerController = [[UIImagePickerController alloc]init];
    
    imagePickerController.delegate = self;
    NSArray *mediaTypesAllowed = [UIImagePickerController availableMediaTypesForSourceType:UIImagePickerControllerSourceTypePhotoLibrary];
    [imagePickerController setMediaTypes:mediaTypesAllowed];
    
    [self presentModalViewController:imagePickerController animated:YES];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    [self dismissModalViewControllerAnimated:YES];
    pauseu=false;
    [session startRunning];
}

- (CVPixelBufferRef) pixelBufferFromCGImage: (CGImageRef) image
{
    NSDictionary *options = @{
                              (NSString*)kCVPixelBufferCGImageCompatibilityKey : @YES,
                              (NSString*)kCVPixelBufferCGBitmapContextCompatibilityKey : @YES,
                              };
    
    CVPixelBufferRef pxbuffer = NULL;
    CVReturn status = CVPixelBufferCreate(kCFAllocatorDefault, CGImageGetWidth(image),
                                          CGImageGetHeight(image), kCVPixelFormatType_32ARGB, (__bridge CFDictionaryRef) options,
                                          &pxbuffer);
    if (status!=kCVReturnSuccess) {
        NSLog(@"Operation failed");
    }
    NSParameterAssert(status == kCVReturnSuccess && pxbuffer != NULL);
    
    CVPixelBufferLockBaseAddress(pxbuffer, 0);
    void *pxdata = CVPixelBufferGetBaseAddress(pxbuffer);
    
    CGColorSpaceRef rgbColorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(pxdata, CGImageGetWidth(image),
                                                 CGImageGetHeight(image), 8, 4*CGImageGetWidth(image), rgbColorSpace,
                                                 kCGImageAlphaNoneSkipFirst);
    NSParameterAssert(context);
    
    CGContextConcatCTM(context, CGAffineTransformMakeRotation(0));
    CGAffineTransform flipVertical = CGAffineTransformMake( 1, 0, 0, -1, 0, CGImageGetHeight(image) );
    CGContextConcatCTM(context, flipVertical);
    CGAffineTransform flipHorizontal = CGAffineTransformMake( -1.0, 0.0, 0.0, 1.0, CGImageGetWidth(image), 0.0 );
    CGContextConcatCTM(context, flipHorizontal);
    
    CGContextDrawImage(context, CGRectMake(0, 0, CGImageGetWidth(image),
                                           CGImageGetHeight(image)), image);
    CGColorSpaceRelease(rgbColorSpace);
    CGContextRelease(context);
    
    CVPixelBufferUnlockBaseAddress(pxbuffer, 0);
    return pxbuffer;
}


- (UIImage *)resizeImage:(UIImage *)image
{
    CGSize origImageSize = [image size];
    CGRect newRect = CGRectMake(0, 0, 299,299);
    float ratio = MAX(newRect.size.width / origImageSize.width,
                      newRect.size.height / origImageSize.height);
    UIGraphicsBeginImageContextWithOptions(newRect.size, NO, 0.0);
    UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:newRect
                                                    cornerRadius:5.0];
    [path addClip];
    CGRect imageRect;
    imageRect.size.width = ratio * origImageSize.width;
    imageRect.size.height = ratio * origImageSize.height;
    imageRect.origin.x = (newRect.size.width - imageRect.size.width) / 2.0;
    imageRect.origin.y = (newRect.size.height - imageRect.size.height) / 2.0;
    [image drawInRect:imageRect];
    UIImage *smallImage = UIGraphicsGetImageFromCurrentImageContext();
   // NSData *data = UIImagePNGRepresentation(smallImage);
    UIGraphicsEndImageContext();
    return smallImage;
}

-(UIImage*) drawText:(NSString*) text
             inImage:(UIImage*)  image
             atPoint:(CGPoint)   point
           textColor:(UIColor *) textcolor{
    int fontsize=(int)(32*image.size.width/443.0f);
    UIFont *font = [UIFont boldSystemFontOfSize:fontsize];  ///443
    UIGraphicsBeginImageContext(image.size);
    [image drawInRect:CGRectMake(0,0,image.size.width,image.size.height)];
    CGRect rect = CGRectMake(point.x, point.y, image.size.width, image.size.height);
    [textcolor set];
    [text drawInRect:CGRectIntegral(rect) withFont:font];
    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return newImage;
}


- (void)imagePickerController:(UIImagePickerController *)picker
        didFinishPickingImage:(UIImage *)image
                  editingInfo:(NSDictionary *)info
{

    [picker dismissModalViewControllerAnimated:YES];
    // imGallery.image=image;
  
    pauseu=false;

    imGallery.contentMode = UIViewContentModeScaleAspectFit;

    
    [imGallery setBackgroundColor:[UIColor blackColor]];
    if (image!=nil) {
      
        CGImageRef img = image.CGImage;
      
        [self yolo:img];
        
        if (moleleft>=0) {
            UIGraphicsBeginImageContext(image.size);
            
            // Pass 1: Draw the original image as the background
            [image drawAtPoint:CGPointMake(0,0)];
            
            // Pass 2: Draw the line on top of original image
            CGContextRef context = UIGraphicsGetCurrentContext();
            CGContextSetLineWidth(context, 2.0);
            CGContextMoveToPoint(context, image.size.width-moleleft-1, image.size.height-moletop-1);
            CGContextAddLineToPoint(context, image.size.width-moleright-1,image.size.height-moletop-1);
            CGContextMoveToPoint(context, image.size.width-moleright-1, image.size.height-moletop-1);
            CGContextAddLineToPoint(context, image.size.width-moleright-1,image.size.height-molebottom-1);
            CGContextMoveToPoint(context, image.size.width-moleright-1, image.size.height-molebottom-1);
            CGContextAddLineToPoint(context, image.size.width-moleleft-1,image.size.height-molebottom-1);
            CGContextMoveToPoint(context, image.size.width-moleleft-1, image.size.height-molebottom-1);
            CGContextAddLineToPoint(context, image.size.width-moleleft-1,image.size.height-moletop-1);

            CGContextSetStrokeColorWithColor(context, [[UIColor blueColor] CGColor]);
            CGContextStrokePath(context);
            
            // Create new image
            UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
            UIGraphicsEndImageContext();
            imGallery.image=newImage;
        } else {
            image=[self drawText:@"Nothing found" inImage:image atPoint:CGPointMake(0, 0) textColor:[UIColor greenColor]];
            imGallery.image=image;
        }
        
        // Tidy up
        previewLayer.hidden=YES;
        imGallery.hidden=NO;
        [btFreeze setTitle:@"Return Camera" forState:UIControlStateNormal];
    }
    
}
- (void)teardownAVCapture {
  [stillImageOutput removeObserver:self forKeyPath:@"isCapturingStillImage"];
  [previewLayer removeFromSuperlayer];
}
bool forward=false;

- (IBAction)btMedicmind:(id)sender {

    forward=true;
     self.navigationController.navigationBar.hidden =  NO;
    [self performSegueWithIdentifier:@"backToTable" sender:self];
    pauseu=true;

}


- (void)didMoveToParentViewController:(UIViewController *)parent
{

    if (!forward) {
        self.navigationController.navigationBar.hidden =  YES;
        pauseu=false;

    } else {
        self.navigationController.navigationBar.hidden =  NO;
    }

    forward=false;

}


- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context {
  if (context == AVCaptureStillImageIsCapturingStillImageContext) {
    BOOL isCapturingStillImage =
        [[change objectForKey:NSKeyValueChangeNewKey] boolValue];

    if (isCapturingStillImage) {
      // do flash bulb like animation
      flashView = [[UIView alloc] initWithFrame:[previewView frame]];
      [flashView setBackgroundColor:[UIColor whiteColor]];
      [flashView setAlpha:0.f];
      [[[self view] window] addSubview:flashView];

      [UIView animateWithDuration:.4f
                       animations:^{
                         [flashView setAlpha:1.f];
                       }];
    } else {
      [UIView animateWithDuration:.4f
          animations:^{
            [flashView setAlpha:0.f];
          }
          completion:^(BOOL finished) {
            [flashView removeFromSuperview];
            flashView = nil;
          }];
    }
  }
}

- (AVCaptureVideoOrientation)avOrientationForDeviceOrientation:
    (UIDeviceOrientation)deviceOrientation {
  AVCaptureVideoOrientation result =
      (AVCaptureVideoOrientation)(deviceOrientation);
  if (deviceOrientation == UIDeviceOrientationLandscapeLeft)
    result = AVCaptureVideoOrientationLandscapeRight;
  else if (deviceOrientation == UIDeviceOrientationLandscapeRight)
    result = AVCaptureVideoOrientationLandscapeLeft;
  return result;
}

- (IBAction)takePicture:(id)sender {
  if ([session isRunning]) {
    [session stopRunning];
    [sender setTitle:@"Continue" forState:UIControlStateNormal];

    flashView = [[UIView alloc] initWithFrame:[previewView frame]];
    [flashView setBackgroundColor:[UIColor whiteColor]];
    [flashView setAlpha:0.f];
    [[[self view] window] addSubview:flashView];

    [UIView animateWithDuration:.2f
        animations:^{
          [flashView setAlpha:1.f];
        }
        completion:^(BOOL finished) {
          [UIView animateWithDuration:.2f
              animations:^{
                [flashView setAlpha:0.f];
              }
              completion:^(BOOL finished) {
                [flashView removeFromSuperview];
                flashView = nil;
              }];
        }];

  } else {
      imGallery.hidden=YES;
      imGallery.image=nil;
      pauseu=false;
      previewLayer.hidden=NO;
      [session startRunning];
      [sender setTitle:@"Freeze Frame" forState:UIControlStateNormal];
  }
}


- (UIImage *) imageFromSampleBuffer:(CMSampleBufferRef) sampleBuffer
{
    // Get a CMSampleBuffer's Core Video image buffer for the media data
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    // Lock the base address of the pixel buffer
    CVPixelBufferLockBaseAddress(imageBuffer, 0);
    
    // Get the number of bytes per row for the pixel buffer
    void *baseAddress = CVPixelBufferGetBaseAddress(imageBuffer);
    
    // Get the number of bytes per row for the pixel buffer
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer);
    // Get the pixel buffer width and height
    size_t width = CVPixelBufferGetWidth(imageBuffer);
    size_t height = CVPixelBufferGetHeight(imageBuffer);
    
    // Create a device-dependent RGB color space
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    
    // Create a bitmap graphics context with the sample buffer data
    CGContextRef context = CGBitmapContextCreate(baseAddress, width, height, 8,
                                                 bytesPerRow, colorSpace, kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);
    // Create a Quartz image from the pixel data in the bitmap graphics context
    CGImageRef quartzImage = CGBitmapContextCreateImage(context);
    // Unlock the pixel buffer
    CVPixelBufferUnlockBaseAddress(imageBuffer,0);
    
    // Free up the context and color space
    CGContextRelease(context);
    CGColorSpaceRelease(colorSpace);
    
    // Create an image object from the Quartz image
    UIImage *image = [UIImage imageWithCGImage:quartzImage];
    
    // Release the Quartz image
    CGImageRelease(quartzImage);
    
    return (image);
}

- (UIImage *)imageRotatedByDegrees:(UIImage*)oldImage deg:(CGFloat)degrees{
    // calculate the size of the rotated view's containing box for our drawing space
    UIView *rotatedViewBox = [[UIView alloc] initWithFrame:CGRectMake(0,0,oldImage.size.width, oldImage.size.height)];
    CGAffineTransform t = CGAffineTransformMakeRotation(degrees * M_PI / 180);
    rotatedViewBox.transform = t;
    CGSize rotatedSize = rotatedViewBox.frame.size;
    // Create the bitmap context
    UIGraphicsBeginImageContext(rotatedSize);
    CGContextRef bitmap = UIGraphicsGetCurrentContext();
    
    // Move the origin to the middle of the image so we will rotate and scale around the center.
    CGContextTranslateCTM(bitmap, rotatedSize.width/2, rotatedSize.height/2);
    
    //   // Rotate the image context
    CGContextRotateCTM(bitmap, (degrees * M_PI / 180));
    
    // Now, draw the rotated/scaled image into the context
    CGContextScaleCTM(bitmap, 1.0, -1.0);
    CGContextDrawImage(bitmap, CGRectMake(-oldImage.size.width / 2, -oldImage.size.height / 2, oldImage.size.width, oldImage.size.height), [oldImage CGImage]);
    
    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return newImage;
}

- (void)yolo:(CGImageRef)imageRefi
{
    CVPixelBufferRef pixelBuffer;
    pixelBuffer= [self pixelBufferFromCGImage:imageRefi];
    
    image_width = (int)CVPixelBufferGetWidth(pixelBuffer);
    fullHeight = (int)CVPixelBufferGetHeight(pixelBuffer);

    int image_channels=4;
    assert(pixelBuffer != NULL);
    
    OSType sourcePixelFormat = CVPixelBufferGetPixelFormatType(pixelBuffer);
    int doReverseChannels;
    if (kCVPixelFormatType_32ARGB == sourcePixelFormat) {
        doReverseChannels = 1;
    } else if (kCVPixelFormatType_32BGRA == sourcePixelFormat) {
        doReverseChannels = 0;
    } else {
        assert(false);  // Unknown source format
    }
    
    const int sourceRowBytes = (int)CVPixelBufferGetBytesPerRow(pixelBuffer);
    
    CVPixelBufferLockFlags unlockFlags = kNilOptions;
    CVPixelBufferLockBaseAddress(pixelBuffer, unlockFlags);
    
    
    unsigned char *sourceBaseAddr =
    (unsigned char *)(CVPixelBufferGetBaseAddress(pixelBuffer));
    int image_heightu;
    unsigned char *sourceStartAddr;
    if (fullHeight <= image_width) {
        image_heightu = fullHeight;
        sourceStartAddr = sourceBaseAddr;
    } else {
        image_heightu = image_width;
        const int marginY = ((fullHeight - image_width) / 2);
        sourceStartAddr = (sourceBaseAddr + (marginY * sourceRowBytes));
    }

    BOOL inference_result = runInferenceOnImage(sourceBaseAddr, image_width, fullHeight, image_channels);
    
    if (inference_result&&moleleft>0) {
        //[session stopRunning];
        
        float grow=0.3; // Make cut slightly out

        int w=moleright-moleleft;
        int h=molebottom-moletop;
        // Make it squre
        int top=moletop;
        // int bottom;
        int left=moleleft;
        if (grow!=0) {
            // Make the squre a bit bigger
            left=left-(w*grow/2);
            if (left<0)
                left=0;
            top=top-(h*grow/2);
            if (top<0)
                top=0;
            w*=(1.0+grow);
            h*=(1.0+grow);
            if (top+h>fullHeight-1)
                top=fullHeight-h-1;
            if (left+w>image_width-1)
                left=image_width-w-1;
        }
        // This is to make it square
        if (w>h) {
            top=top-(w-h)/2;
            if (top<0)
                top=0;
            h=w;
            if (top+h>fullHeight-1)
                top=fullHeight-h-1;
        } else {

            left=left-(h-w)/2;
            if (left<0)
                left=0;

            w=h;
            if (left+w>image_width-1)
                left=image_width-w-1;
            
            
        }
        
        // You have to add newleft because imageRefi is just a pointer of original
        printf("rect %d %d %d %d\n",image_width-left-h-1,fullHeight-top-1-w,w,h);
        CGRect rect = CGRectMake(image_width-left-h-1,fullHeight-top-1-w,w,h);

        CGImageRef imageRefo = CGImageCreateWithImageInRect(imageRefi, rect);
        // CGImageRef imageRefo = CGImageCreateWithImageInRect(image.CGImage, rect);
        UIImage *imagecut= [[UIImage alloc]  initWithCGImage:imageRefo];
        imagecut = [self imageRotatedByDegrees:imagecut deg:-90];

        [drawLayer setImage:imagecut.CGImage];
        CVPixelBufferRef pixelBufferi= [self pixelBufferFromCGImage:imageRefo];

        CGImageRelease(imageRefo);
        CFRelease(pixelBufferi);
        
    } else if (moleleft>0) {
        moleleft=-100;
    }
    CFRelease(pixelBuffer);
    
    

}

UIImage *resultu;

int newleft=0;
int newtop=0;
int newheight=0;
int image_widthorig=0;

- (void)captureOutput:(AVCaptureOutput *)captureOutput
didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
       fromConnection:(AVCaptureConnection *)connection {
    
    if (pauseu)
        return;
    

    UIImage *image = [self imageFromSampleBuffer:sampleBuffer];

    float fct=0.8;  // The size of the box as a percentage of screen width
    [drawLayer setFct:[NSNumber numberWithFloat: fct]];
    image_widthorig=int(image.size.width);
    newheight=fct*image.size.height;
    newleft=(image.size.width-newheight)/2;
    newtop=(image.size.height-newheight)/2;
    CGRect rect = CGRectMake(newleft,newtop,newheight,newheight);
   
    CGImageRef imageRefi = CGImageCreateWithImageInRect(image.CGImage, rect);
    
    //UIImage *imagecuti= [[UIImage alloc]  initWithCGImage:imageRefi];
    //UIImageWriteToSavedPhotosAlbum(imagecuti, nil, nil, nil);
    [self yolo:imageRefi];
    
    CGImageRelease(imageRefi);

    [self performSelectorOnMainThread:@selector(drawBoxes) withObject:nil waitUntilDone:YES];
  
}

- (void)drawBoxes {

    if (moleleft==-100) {
        moleleft=-1;
        [drawLayer clearPoints];
        [drawLayer setNeedsDisplay];

    } else  if (moleleft>0&& fullHeight>0) {
        int width=fullHeight;
        int height=image_widthorig;
        float ratim=float(width)/float(height);
        CGRect bounds=[previewLayer bounds];
        int scrwidth=bounds.size.width;
        int scrheight=bounds.size.height;
        float ratscr=float(scrwidth)/float(scrheight);
        int imwidth;
        int imheight;
        if (ratim<ratscr) {
            // will have x margin  ipad
            imheight=scrheight;
            imwidth=int(width*(float(scrheight)/float(height)));
        } else {
            imwidth=scrwidth;
            imheight=int(height*(float(scrwidth)/float(width)));
        }

        float fct=float(imwidth)/float(width);
        float fcth=float(imheight)/float(height);
        CGPoint pointA=CGPointMake(int(fct*(moletop))+(scrwidth-imwidth)/2,   scrheight-int(fcth*(moleleft+newleft)) +(scrheight-imheight)/2-1);
        CGPoint pointB=CGPointMake(int(fct*(molebottom))+(scrwidth-imwidth)/2,scrheight-int(fcth*(moleright+newleft))+(scrheight-imheight)/2-1); //

        printf("mole %d %d %d %d sc %d %d wh %d %d im %d %d n %d %d\n",moleleft,moletop,moleright,molebottom,scrwidth, scrheight,width,height,imwidth,imheight,newleft,newtop);

        [drawLayer setPoints:pointA B:pointB];
        [drawLayer setNeedsDisplay];
    }


}

- (void)dealloc {
  [self teardownAVCapture];
}


- (void)didReceiveMemoryWarning {
  [super didReceiveMemoryWarning];
}

- (void)viewDidLoad {
  [super viewDidLoad];
  square = [UIImage imageNamed:@"squarePNG"];
  synth = [[AVSpeechSynthesizer alloc] init];

  [self setupAVCapture];
}

- (void)viewDidUnload {
  [super viewDidUnload];
}

- (void)viewWillAppear:(BOOL)animated {
  [super viewWillAppear:animated];
}

- (void)viewDidAppear:(BOOL)animated {
  [super viewDidAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated {
  [super viewWillDisappear:animated];
}

- (void)viewDidDisappear:(BOOL)animated {
  [super viewDidDisappear:animated];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:
    (UIInterfaceOrientation)interfaceOrientation {
  return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

- (BOOL)prefersStatusBarHidden {
  return YES;
}


float sigmoid(float x) {
    return 1.0 / (1.0 + exp(-x));
}

void softmax(float vals[], int count) {
    float max = -FLT_MAX;
    for (int i=0; i<count; i++) {
        max = fmax(max, vals[i]);
    }
    float sum = 0.0;
    for (int i=0; i<count; i++) {
        vals[i] = exp(vals[i] - max);
        sum += vals[i];
    }
    for (int i=0; i<count; i++) {
        vals[i] /= sum;
    }
}



const char* LABELS[] = {
    // for yolo.pb and tiny-yolo(coco).pb:
    "object","fake"  // Cannot handle a single class so add fake
};

static int moleleft=-1;
static int moletop=-1;
static int moleright=-1;
static int molebottom=-1;
static int image_width = -1;
static int fullHeight = -1;

static void YoloPostProcess(const Eigen::TensorMap<Eigen::Tensor<float, 1, Eigen::RowMajor>,
                            Eigen::Aligned>& output, std::vector<std::pair<float, int> >* top_results) {
    const int NUM_CLASSES = 2;//80; //20 - for tiny-yolo-voc; //80 - for yolo and tiny-yolo coco;
    const int NUM_BOXES_PER_BLOCK = 5;
    double ANCHORS[] = {
        // for tiny-yolo-voc.pb: 20 classes
        1.08, 1.19, 3.42, 4.41, 6.63, 11.38, 9.42, 5.11, 16.62, 10.52
        
        // for tiny-yolo(coco).pb: 80 classes
        // 0.738768, 0.874946, 2.42204, 2.65704, 4.30971, 7.04493, 10.246, 4.59428, 12.6868, 11.8741
    };
    
    // 13 for tiny-yolo-voc, 19 for yolo
    const int gridHeight = 13;///19;
    const int gridWidth = 13;//19;
    const int blockSize = 32;
    
    std::priority_queue<std::pair<float, int>, std::vector<std::pair<float, int>>, std::greater<std::pair<float, int>>> top_result_pq;
    
    std::priority_queue<std::pair<float, int>, std::vector<std::pair<float, int>>, std::greater<std::pair<float, int>>> top_rect_pq;
    
    NSMutableDictionary *idxRect = [NSMutableDictionary dictionary];
    NSMutableDictionary *idxDetectedClass = [NSMutableDictionary dictionary];
    int i=0;
    for (int y = 0; y < gridHeight; ++y) {
        for (int x = 0; x < gridWidth; ++x) {
            for (int b = 0; b < NUM_BOXES_PER_BLOCK; ++b) {
                int offset = (gridWidth * (NUM_BOXES_PER_BLOCK * (NUM_CLASSES + 5))) * y
                + (NUM_BOXES_PER_BLOCK * (NUM_CLASSES + 5)) * x
                + (NUM_CLASSES + 5) * b;
                
                // implementation based on the TF Android TFYoloDetector.java
                // also in http://machinethink.net/blog/object-detection-with-yolo/
                float xPos = (x + sigmoid(output(offset + 0))) * blockSize;
                float yPos = (y + sigmoid(output(offset + 1))) * blockSize;
                
                float w = (float) (exp(output(offset + 2)) * ANCHORS[2 * b + 0]) * blockSize;
                float h = (float) (exp(output(offset + 3)) * ANCHORS[2 * b + 1]) * blockSize;
                
                // Now xPos and yPos represent the center of the bounding box in the 416×416 image that we used as input to the neural network; w and h are the width and height of the box in that same image space.
                CGRect rect = CGRectMake(
                                         fmax(0, (xPos - w / 2) * image_width/*imgSize.width*/ / INPUT_SIZE),
                                         fmax(0, (yPos - h / 2) * fullHeight/*imgSize.height*/ / INPUT_SIZE),
                                         w* image_width/* imgSize.width *// INPUT_SIZE, h* fullHeight/*imgSize.height*/ / INPUT_SIZE);
                
                float confidence = sigmoid(output(offset + 4));
                
                float classes[NUM_CLASSES];
                for (int c = 0; c < NUM_CLASSES; ++c) {
                    classes[c] = output(offset + 5 + c);
                }
                softmax(classes, NUM_CLASSES);
                
                int detectedClass = -1;
                float maxClass = 0;
                for (int c = 0; c < NUM_CLASSES; ++c) {
                    if (classes[c] > maxClass) {
                        detectedClass = c;
                        maxClass = classes[c];
                    }
                }
                
                float confidenceInClass = maxClass * confidence;
                if (confidenceInClass > yolothreshold) {//.25) {
                    //NSLog(@"%s (%d) %f %d, %d, %d, %@", LABELS[detectedClass], detectedClass, confidenceInClass, y, x, b, NSStringFromCGRect(rect));
                    top_result_pq.push(std::pair<float, int>(confidenceInClass, detectedClass));
                    top_rect_pq.push(std::pair<float, int>(confidenceInClass, i));
                    //printf("voot %f %f %f %f\n",rect.origin.x,rect.origin.y,w,h);
                    [idxRect setObject:NSStringFromCGRect(rect) forKey:[NSNumber numberWithInt:i]];
                    [idxDetectedClass setObject:[NSNumber numberWithInt:detectedClass] forKey:[NSNumber numberWithInt:i++]];
                }
            }
        }
    }
    
    
    std::vector<std::pair<float, int> > top_rects;
    while (!top_rect_pq.empty()) {
        top_rects.push_back(top_rect_pq.top());
        top_rect_pq.pop();
    }
    std::reverse(top_rects.begin(), top_rects.end());
    
    
    // Start with the box that has the highest score.
    // Remove any remaining boxes - with the same class? - that overlap it more than the given threshold
    // amount. If there are any boxes left (i.e. these did not overlap with any
    // previous boxes), then repeat this procedure, until no more boxes remain
    // or the limit has been reached.
    std::vector<std::pair<float, int> > nms_rects;
    while (!top_rects.empty()) {
        auto& first = top_rects.front();
        CGRect rect_first = CGRectFromString([idxRect objectForKey:[NSNumber numberWithInt:first.second]]);
        int detectedClass = [[idxDetectedClass objectForKey:[NSNumber numberWithInt:first.second]] intValue];
       // NSLog(@"first class: %s", LABELS[detectedClass]);
        
        for (unsigned long i = top_rects.size()-1; i>=1; i--) {
            auto& item = top_rects.at(i);
            int detectedClass = [[idxDetectedClass objectForKey:[NSNumber numberWithInt:item.second]] intValue];
            
            CGRect rect_item = CGRectFromString([idxRect objectForKey:[NSNumber numberWithInt:item.second]]);
            CGRect rectIntersection = CGRectIntersection(rect_first, rect_item);
            if (CGRectIsNull(rectIntersection)) {
                //NSLog(@"no intesection");
                //NSLog(@"no intesection - class: %s", LABELS[detectedClass]);
            }
            else {
                float areai = rect_first.size.width * rect_first.size.height;
                float ratio = rectIntersection.size.width * rectIntersection.size.height / areai;
               // NSLog(@"found intesection - class: %s", LABELS[detectedClass]);
                
                if (ratio > 0.23) {
                    top_rects.erase(top_rects.begin() + i);
                }
            }
        }
        nms_rects.push_back(first);
        top_rects.erase(top_rects.begin());
    }
    
    while (!nms_rects.empty()) {
        auto& front = nms_rects.front();
        int detectedClass = [[idxDetectedClass objectForKey:[NSNumber numberWithInt:front.second]] intValue];
        top_results->push_back(std::pair<float, int>(front.first, detectedClass));
        
        if (detectedClass==0) {
            

            CGRect rect = CGRectFromString([idxRect objectForKey:[NSNumber numberWithInt:front.second]]);

            moleleft=rect.origin.x;
            moletop=rect.origin.y;
            moleright=rect.origin.x+rect.size.width;
            molebottom=rect.origin.y+rect.size.height;

            
        }
        nms_rects.erase(nms_rects.begin());
    }
    
}

NSString* FilePathForResourceNameu(NSString* name, NSString* extension) {
    NSString* file_path = [[NSBundle mainBundle] pathForResource:name ofType:extension];
    if (file_path == NULL) {
        LOG(FATAL) << "Couldn't find '" << [name UTF8String] << "."
        << [extension UTF8String] << "' in bundle.";
    }
    return file_path;
}

using tensorflow::uint8;

namespace {
    class IfstreamInputStream : public ::google::protobuf::io::CopyingInputStream {
    public:
        explicit IfstreamInputStream(const std::string& file_name)
        : ifs_(file_name.c_str(), std::ios::in | std::ios::binary) {}
        ~IfstreamInputStream() { ifs_.close(); }
        
        int Read(void* buffer, int size) {
            if (!ifs_) {
                return -1;
            }
            ifs_.read(static_cast<char*>(buffer), size);
            return ifs_.gcount();
        }
        
    private:
        std::ifstream ifs_;
    };
}  // namespace


bool uuPortableReadFileToProto(const std::string& file_name,
                             ::google::protobuf::MessageLite* proto) {
    ::google::protobuf::io::CopyingInputStreamAdaptor stream(
                                                             new IfstreamInputStream(file_name));
    stream.SetOwnsCopyingStream(true);
    // TODO(jiayq): the following coded stream is for debugging purposes to allow
    // one to parse arbitrarily large messages for MessageLite. One most likely
    // doesn't want to put protobufs larger than 64MB on Android, so we should
    // eventually remove this and quit loud when a large protobuf is passed in.
    ::google::protobuf::io::CodedInputStream coded_stream(&stream);
    // Total bytes hard limit / warning limit are set to 1GB and 512MB
    // respectively.
    coded_stream.SetTotalBytesLimit(1024LL << 20, 512LL << 20);
    return proto->ParseFromCodedStream(&coded_stream);
}

std::unique_ptr<tensorflow::Session> createSession()
{
    tensorflow::SessionOptions options;
    
    tensorflow::Session* session_pointer = nullptr;
    tensorflow::Status session_status = tensorflow::NewSession(options, &session_pointer);
    if (!session_status.ok()) {
        std::string status_string = session_status.ToString();
        return nullptr;
    }
    std::unique_ptr<tensorflow::Session> session(session_pointer);
    LOG(INFO) << "Session created.";
    
    tensorflow::GraphDef tensorflow_graph;
    LOG(INFO) << "Graph created.";


    NSString* network_path = FilePathForResourceNameu(@"frozen_model", @"pb");

    uuPortableReadFileToProto([network_path UTF8String], &tensorflow_graph);
    
    LOG(INFO) << "Creating session.";
    tensorflow::Status s = session->Create(tensorflow_graph);
    if (!s.ok()) {
        LOG(ERROR) << "Could not create TensorFlow Graph: " << s;
        return nullptr;//@"";
    }
    return session;

}

BOOL runInferenceOnImage(unsigned char *indata , int image_width, int image_height, int image_channels) {

    const int wanted_width = INPUT_SIZE; //416;
    const int wanted_height = INPUT_SIZE; //416;
    const int wanted_channels = 3;
    
    
    // YOLO’s convolutional layers downsample the image by a factor of 32 so by using an input image of 416 we get an output feature map of 13x13.
    
    assert(image_channels >= wanted_channels);
    
    tensorflow::Tensor image_tensor(
                                    tensorflow::DT_FLOAT,
                                    tensorflow::TensorShape({
        1, wanted_height, wanted_width, wanted_channels}));
    auto image_tensor_mapped = image_tensor.tensor<float, 4>();
   // tensorflow::uint8* indata = image_data.data();
    tensorflow::uint8* in_end = (indata + (image_height * image_width * image_channels));
    float* out = image_tensor_mapped.data();
    for (int y = 0; y < wanted_height; ++y) {
        const int in_y = (y * image_height) / wanted_height;
        tensorflow::uint8* in_row = indata + (in_y * image_width * image_channels);
        float* out_row = out + (y * wanted_width * wanted_channels);
        for (int x = 0; x < wanted_width; ++x) {
            const int in_x = (x * image_width) / wanted_width;
            tensorflow::uint8* in_pixel = in_row + (in_x * image_channels);
            float* out_pixel = out_row + (x * wanted_channels);
            for (int c = 0; c < wanted_channels; ++c) {
                //out_pixel[c] = (in_pixel[c] - input_mean) / input_std;
                out_pixel[c] = in_pixel[c] / 255.0f; // in Android's TensorFlowYoloDetector.java, no std and mean is used for input values - "We also need to scale the pixel values from integers that are between 0 and 255 to the floating point values that the graph operates on. We control the scaling with the input_mean and input_std flags: we first subtract input_mean from each pixel value, then divide it by input_std." https://www.tensorflow.org/tutorials/image_recognition#usage_with_the_c_api
            }
        }
    }
    
    std::string input_layer = "input";
    std::string output_layer = "output";
    std::vector<tensorflow::Tensor> outputs;
    tensorflow::Status run_status = sessionu->Run({{input_layer, image_tensor}},
                                                     {output_layer}, {}, &outputs);

    if (!run_status.ok()) {
        LOG(ERROR) << "Running model failed: " << run_status;
       // result = @"Error running model";
        return FALSE;
    }
    tensorflow::string status_string = run_status.ToString();
  //  result = [NSString stringWithFormat: @"%@ - %s", result, status_string.c_str()];
    
    tensorflow::Tensor* output = &outputs[0];
    std::vector<std::pair<float, int> > top_results;
    

    YoloPostProcess(output->flat<float>(), &top_results);
   
    for (const auto& r : top_results) {
        const float confidence = r.first;
        const int index = r.second;
       // result = [NSString stringWithFormat: @"%@\n%f: %s", result, confidence, LABELS[index]];
      //  std::cout << confidence << ": " << LABELS[index] << "\n";
    }
    
    return top_results.size()>0;

}

@end
