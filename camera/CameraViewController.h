// Copyright 2015 Google Inc. All rights reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>

#include <memory>
#include "tensorflow/core/public/session.h"
#include "tensorflow/core/util/memmapped_file_system.h"
#include "LineDrawView.h"

@interface CameraExampleViewController
    : UIViewController<UIGestureRecognizerDelegate,
                       AVCaptureVideoDataOutputSampleBufferDelegate> {
  IBOutlet UIView *previewView;
  IBOutlet UISegmentedControl *camerasControl;
                           __weak IBOutlet UIImageView *imMole;
                           __weak IBOutlet UIButton *btLoad;
                       
                           IBOutlet UIView *mainView;
                           AVCaptureVideoPreviewLayer *previewLayer;
                           __weak IBOutlet UIImageView *imGallery;
                           AVCaptureVideoDataOutput *videoDataOutput;
  dispatch_queue_t videoDataOutputQueue;
  AVCaptureStillImageOutput *stillImageOutput;
  UIView *flashView;
  UIImage *square;
  BOOL isUsingFrontFacingCamera;
                           __weak IBOutlet UIButton *btFreeze;
                           AVSpeechSynthesizer *synth;
  /*NSMutableDictionary *oldPredictionValues1;
  NSMutableDictionary *oldPredictionValues2;
  NSMutableDictionary *oldPredictionValues3;
  NSMutableArray *labelLayers;*/
  AVCaptureSession *session;
  //std::unique_ptr<tensorflow::Session> tf_session;
  //std::unique_ptr<tensorflow::MemmappedEnv> tf_memmapped_env;
  std::vector<std::string> labels;
 //CAShapeLayer *drawLayer;
  LineDrawView *drawLayer;
  //UIImageView *drawLayer;
                       }
@property(strong, nonatomic) CATextLayer *predictionTextLayer;

- (IBAction)takePicture:(id)sender;
- (IBAction)switchCameras:(id)sender;

@end
