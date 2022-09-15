//
//  VideoCaptionGenerator.m
//  iMessageMemeGenerator MessagesExtension
//
//  Created by Derek Buchanan on 9/15/22.
//

#import "VideoCaptionGenerator.h"
#import "iMessageMemeGenerator_MessagesExtension-Swift.h"
@import AVFoundation;

@implementation VideoCaptionGenerator

static double const DEFAULT_MIN_OUTPUT_WIDTH = 640;

- (void)generateCaption:(NSString*)text toVideoAtPath:(NSURL*)videoPath {
    [self generateCaption:text toVideoAtPath:videoPath withMinOutputResolution:DEFAULT_MIN_OUTPUT_WIDTH];
}

- (void)generateCaption:(NSString*)text toVideoAtPath:(NSURL*)videoPath withMinOutputResolution:(int)desiredMinWidth {
    
    AVURLAsset *asset = [[AVURLAsset alloc] initWithURL:videoPath options:@{AVURLAssetPreferPreciseDurationAndTimingKey : @YES}];
    NSLog(@"Asset duration %e", CMTimeGetSeconds(asset.duration));
    
    AVMutableComposition* mixComposition = [AVMutableComposition composition];
    
    AVMutableCompositionTrack *compositionVideoTrack = [mixComposition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
    
    AVAssetTrack * videoTrack = [[asset tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0];
    
    [compositionVideoTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, videoTrack.timeRange.duration) ofTrack:[[asset tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0] atTime:kCMTimeZero error:nil];
    
    // add audio track if it is present, not all videos have audio
    if([asset tracksWithMediaType:AVMediaTypeAudio].count) {
        AVMutableCompositionTrack *compositionAudioTrack = [mixComposition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];
        [compositionAudioTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, videoTrack.timeRange.duration) ofTrack:[[asset tracksWithMediaType:AVMediaTypeAudio] objectAtIndex:0] atTime:kCMTimeZero error:nil];
    }
    
    CGSize videoSize = [[[asset tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0] naturalSize];
    
    UIImageOrientation videoAssetOrientation  = UIImageOrientationUp;
    CGAffineTransform videoTransform = videoTrack.preferredTransform;
    if (videoTransform.a == 0 && videoTransform.b == 1.0 && videoTransform.c == -1.0 && videoTransform.d == 0) {
        videoAssetOrientation = UIImageOrientationLeft;
        videoSize = CGSizeMake(videoSize.height, videoSize.width);
    }
    if (videoTransform.a == 0 && videoTransform.b == -1.0 && videoTransform.c == 1.0 && videoTransform.d == 0) {
        videoAssetOrientation =  UIImageOrientationRight;
        videoSize = CGSizeMake(videoSize.height, videoSize.width);
    }
    if (videoTransform.a == 1.0 && videoTransform.b == 0 && videoTransform.c == 0 && videoTransform.d == 1.0) {
        videoAssetOrientation =  UIImageOrientationUp;
    }
    if (videoTransform.a == -1.0 && videoTransform.b == 0 && videoTransform.c == 0 && videoTransform.d == -1.0) {
        videoAssetOrientation = UIImageOrientationDown;
    }
    
    CGSize originalSize = videoSize;
    
    // upscale to higher res so caption is readable:
    if(videoSize.width < desiredMinWidth)
        videoSize = CGSizeMake(desiredMinWidth, videoSize.height * ((CGFloat)desiredMinWidth/(CGFloat)videoSize.width));
    
    const float defaultInnerXPadding = 12;
    int innerXPadding = (int)((float)defaultInnerXPadding * (float)desiredMinWidth/(float)DEFAULT_MIN_OUTPUT_WIDTH);
    UILabel *label = [MemeLabelMaker captionedLabelWithText:text insetXSpacing:innerXPadding mediaWidth:videoSize.width];
    
    int innerYPadding = label.font.pointSize;
    
    UIView *container = [[UIView alloc] init];
    container.backgroundColor = [UIColor whiteColor];
    container.frame = CGRectMake(0, 0, videoSize.width, label.frame.size.height+innerYPadding);
    
    label.frame = CGRectMake(innerXPadding, (container.frame.size.height - label.frame.size.height)/2, videoSize.width - innerXPadding*2, label.frame.size.height);
    
    [container addSubview:label];
    
    UIImage *caption = [UIImage imageWithView: container];
    
    CGFloat desiredLabelW = videoSize.width;
    if(caption.size.width != desiredLabelW)
        caption = [caption resizedImageWithNewSize:CGSizeMake(desiredLabelW, caption.size.height * desiredLabelW/caption.size.width)];
    
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0ul);
    
    dispatch_async(queue, ^{
        
        // create video instructions
        AVMutableVideoCompositionInstruction *mainInstruction = [AVMutableVideoCompositionInstruction videoCompositionInstruction];
        mainInstruction.timeRange = CMTimeRangeMake(kCMTimeZero, videoTrack.timeRange.duration);
        
        AVMutableVideoCompositionLayerInstruction *layerInstruction = [AVMutableVideoCompositionLayerInstruction videoCompositionLayerInstructionWithAssetTrack:compositionVideoTrack];
        
        /*
         videos can sometimes be transformed based on how the camera is held,
         despite the raw video frames being encoded as sideways, if the camera
         was held landscape, a transform can be applied to the frames.
         we need to remove this transform and re-encode upright in correct space
         */
        CGAffineTransform transformations = videoTrack.preferredTransform;
        if(videoAssetOrientation == UIImageOrientationRight) {
            transformations = CGAffineTransformMakeRotation(-90*(M_PI/180));
            transformations = CGAffineTransformTranslate(transformations, -videoSize.height,0);
        }
        else if(videoAssetOrientation == UIImageOrientationLeft) {
            transformations = CGAffineTransformMakeRotation(90*(M_PI/180));
            transformations = CGAffineTransformTranslate(transformations, 0, -videoSize.width);
        }
        else if(videoAssetOrientation == UIImageOrientationDown) {
            // rotate about the center for upside down
            CGPoint anchorPoint = CGPointMake((videoSize.width/2), (videoSize.height/2));
            transformations = CGAffineTransformMakeTranslation(anchorPoint.x, anchorPoint.y);
            transformations = CGAffineTransformRotate(transformations, 180*(M_PI/180));
            transformations = CGAffineTransformTranslate(transformations, -anchorPoint.x, -anchorPoint.y);
        }
        
        transformations = CGAffineTransformScale(transformations, (CGFloat)videoSize.width / (CGFloat)originalSize.width, (CGFloat)videoSize.height / (CGFloat)originalSize.height);
        
        [layerInstruction setTransform:transformations atTime:kCMTimeZero];
        [layerInstruction setOpacity:1.0 atTime:kCMTimeZero];
        
        mainInstruction.layerInstructions = [NSArray arrayWithObjects:layerInstruction, nil];
        
        // add all of our captions and layers to a composition
        AVMutableVideoComposition *mainComposition = [AVMutableVideoComposition videoComposition];
        mainComposition.renderSize = CGSizeMake(videoSize.width, videoSize.height+caption.size.height+innerXPadding);
        mainComposition.frameDuration = CMTimeMake(1, videoTrack.nominalFrameRate);
        mainComposition.instructions = [NSArray arrayWithObjects:mainInstruction, nil];
        
        CALayer *backgroundLayer = [CALayer layer];
        [backgroundLayer setContents:(id)[caption CGImage]];
        backgroundLayer.frame = CGRectMake(0, videoSize.height+innerXPadding, videoSize.width, caption.size.height);
        
        CALayer *videoLayer = [CALayer layer];
        videoLayer.frame = CGRectMake(innerXPadding, -caption.size.height+innerXPadding, videoSize.width-innerXPadding*2, videoSize.height+caption.size.height+innerXPadding);
        
        CALayer *bottomLayer = [CALayer layer];
        [bottomLayer setBackgroundColor:[UIColor whiteColor].CGColor];
        bottomLayer.frame = CGRectMake(0, 0, mainComposition.renderSize.width, innerXPadding*2);
        
        CALayer *parentLayer = [CALayer layer];
        [parentLayer setBackgroundColor:[UIColor whiteColor].CGColor];
        parentLayer.frame = CGRectMake(0, 0, mainComposition.renderSize.width, mainComposition.renderSize.height);
        [parentLayer addSublayer:videoLayer];
        [parentLayer addSublayer:backgroundLayer];
        [parentLayer addSublayer:bottomLayer];
        
        mainComposition.animationTool = [AVVideoCompositionCoreAnimationTool videoCompositionCoreAnimationToolWithPostProcessingAsVideoLayer:videoLayer inLayer:parentLayer];
        
        // export our creation
        NSURL *tmpDirURL = [NSURL fileURLWithPath:NSTemporaryDirectory() isDirectory:YES];
        NSURL *captionedVideoPath = [[tmpDirURL URLByAppendingPathComponent:@"final"] URLByAppendingPathExtension:@"mp4"];
        
        AVAssetExportSession* assetExport = [[AVAssetExportSession alloc] initWithAsset:mixComposition presetName:AVAssetExportPresetHighestQuality];
        assetExport.outputFileType = AVFileTypeMPEG4;
        assetExport.outputURL = captionedVideoPath;
        assetExport.videoComposition = mainComposition;
        assetExport.shouldOptimizeForNetworkUse = YES;
        
        [[NSFileManager defaultManager] removeItemAtPath:captionedVideoPath.path error:nil];
        
        // TODO: videoCompositionCoreAnimationToolWithPostProcessingAsVideoLayer will crash EXC_BAD_INSTRUCTION in the Simulator, but not device
        if(TARGET_OS_SIMULATOR) {
            dispatch_async(dispatch_get_main_queue(), ^{
                NSString *errorDescription = @"Important note: videoCompositionCoreAnimationToolWithPostProcessingAsVideoLayer will cause crash EXC_BAD_INSTRUCTION in the Simulator, but not device. Discussion: https://developer.apple.com/forums/thread/133681 (visit link in console). Alternatively, run on a device.";
                NSError *error = [NSError errorWithDomain:[NSString stringWithFormat:@"com.%@", NSStringFromClass([self class])] code:1 userInfo:@{NSLocalizedDescriptionKey : errorDescription}];
                NSLog(@"%@", error.localizedDescription);
                [self.delegate finishedCaptionedMediaAtPath:nil withError:error];
            });
        } else {
            [assetExport exportAsynchronouslyWithCompletionHandler:^(void) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    
                    [self.delegate finishedCaptionedMediaAtPath:captionedVideoPath withError:assetExport.error];
                });
            }];
        }
    });
}

@end
