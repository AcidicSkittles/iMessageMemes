//
//  CaptionGenerator.m
//  iMessageExtension
//
//  Created by Derek Buchanan on 4/12/22.
//  Copyright © 2022 Derek Buchanan. All rights reserved.
//

#import "CaptionGenerator.h"
#import "MagickWand.h"
#import "iMessageMemeGenerator_MessagesExtension-Swift.h"
@import AVFoundation;
@import ImageIO;

@implementation CaptionGenerator

NSString *const DEFAULT_MEME_FONT = @"HelveticaNeue-Light";
/**
 The more transparency a GIF has, the lower its file size. This setting is used
 by ImageMagick to compute the transparent pixels on the current frame based
 on this threshold value to the underlying pixels on the previous frame.
 */
static double const OPTIMIZED_GIF_TRANSPARENCY_FUZZ = 12;

- (void)generateCaption:(NSString*)text toImageData:(NSData*)imageData {
    [self generateCaption:text toImageData:imageData withMinOutputResolution:480];
}

- (void)generateCaption:(NSString*)text toImageData:(NSData*)imageData withMinOutputResolution:(int)desiredMinWidth {
    
    CGImageSourceRef source = CGImageSourceCreateWithData((CFDataRef)imageData, NULL);
    NSDictionary* imageHeader = (__bridge NSDictionary*) CGImageSourceCopyPropertiesAtIndex(source, 0, NULL);
    NSNumber *imageWidth = (NSNumber *)[imageHeader objectForKey: (__bridge NSString *)kCGImagePropertyPixelWidth];
    
    int maxLabelWidth = MAX(imageWidth.intValue, desiredMinWidth);
    
    int innerXPadding = 5;
    UILabel *label = [self captionedLabelWithText:text insetXSpacing:innerXPadding mediaWidth:maxLabelWidth];
    
    int innerYPadding = label.font.pointSize;
    
    UIView *labelShutterContainer = [[UIView alloc] init];
    labelShutterContainer.backgroundColor = [UIColor whiteColor];
    labelShutterContainer.frame = CGRectMake(0, 0, maxLabelWidth, label.frame.size.height+innerYPadding);
    label.frame = CGRectMake(innerXPadding/2, innerYPadding/2, maxLabelWidth - innerXPadding, label.frame.size.height);
    
    [labelShutterContainer addSubview:label];
    
    UIImage *caption = [UIImage imageWithView:labelShutterContainer];
    NSData *labelData = UIImagePNGRepresentation(caption);
    
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0ul);
    
    dispatch_async(queue, ^{
        MagickWand *base = NewMagickWand();
        MagickReadImageBlob(base, [imageData bytes], [imageData length]);
        
        BOOL isGif = MagickGetNumberImages(base) > 1;
        
        BOOL didCoalesce = false;
        // BackgroundDispose animated gifs do not contain transparency that depend on the previous frame
        if(isGif && MagickGetImageWidth(base) < desiredMinWidth && MagickGetImageDispose(base) != BackgroundDispose) {
            base = MagickCoalesceImages(base);
            didCoalesce = true;
        }
        
        MagickWand *frames = NewMagickWand();
        
        int borderWidthAdditionalOffset = 4;
        int borderW = label.font.pointSize/2 + borderWidthAdditionalOffset;
        int borderH = label.font.pointSize/2;
        
        DisposeType previousFrameDisposal = MagickGetImageDispose(base);
        
        for(int i = 0; i < MagickGetNumberImages(base); i++) {
            MagickSetIteratorIndex(base, i);
            MagickWand *localWand = MagickGetImage(base);
            
            if(MagickGetImageWidth(localWand) < desiredMinWidth)
                MagickScaleImage(localWand, desiredMinWidth, MagickGetImageHeight(localWand) * desiredMinWidth / MagickGetImageWidth(localWand));
            
            //insert at beginning while we are stacking
            MagickSetFirstIterator(localWand);
            
            ssize_t x, y;
            size_t w, h;
            MagickGetImagePage(base, &w, &h, &x, &y);
            
            NSLog(@"Frame: %i Disposal: %i Geometry: (x:%zi y:%zi w:%zu h:%zu)", i, MagickGetImageDispose(base), x, y, w, h);
            
            if(i == 0 || MagickGetImageDispose(base) == PreviousDispose ||
               (previousFrameDisposal == BackgroundDispose && MagickGetImageDispose(base) == NoneDispose)) {
                
                previousFrameDisposal = MagickGetImageDispose(base);
                
                MagickReadImageBlob(localWand, [labelData bytes], [labelData length]);
                MagickScaleImage(localWand, maxLabelWidth, caption.size.height * maxLabelWidth/caption.size.width);
                MagickSetImageFormat(localWand, isGif ? "gif" : "png");
                MagickResetIterator(localWand);
                
                MagickWand *appendWand = CloneMagickWand(localWand);
                localWand = DestroyMagickWand(localWand);
                localWand = MagickAppendImages(appendWand, MagickTrue);
                appendWand = DestroyMagickWand(appendWand);
                
                PixelWand *borderWand = NewPixelWand();
                PixelSetColor(borderWand, "white");
                MagickBorderImage(localWand, borderWand, borderW, borderH);
            }
            else {
                ssize_t localX, localY;
                size_t localW, localH;
                MagickGetImagePage(base, &localW, &localH, &localX, &localY);
                
                localY += caption.size.height;
                localH += caption.size.height;
                
                NSLog(@"New frame geometry: (x:%zi y:%zi w:%zu h:%zu)", localX+borderW, localY+borderH, localW, localH);
                MagickSetImagePage(localWand, localW, localH, localX+borderW, localY+borderH);
            }
            
            MagickAddImage(frames, localWand);
            MagickSetImageDelay(frames, MagickGetImageDelay(base));
            MagickSetImageDispose(frames, MagickGetImageDispose(base));
            // adding "fuzz" reduces quality, but also makes the resulting file size smaller
            MagickSetImageFuzz(frames, OPTIMIZED_GIF_TRANSPARENCY_FUZZ);
            MagickCommentImage(frames, (const char*)[label.text UTF8String]);
            
            localWand = DestroyMagickWand(localWand);
        }
        
        if(didCoalesce)
            MagickOptimizeImageTransparency(frames);
        
        size_t my_size;
        unsigned char * my_image = MagickGetImagesBlob(frames, &my_size);
        NSData* captionedImageData = [[NSData alloc] initWithBytes:my_image length:my_size];
        
        free(my_image);
        base = DestroyMagickWand(base);
        frames = DestroyMagickWand(frames);
        
        NSURL *tmpDirURL = [NSURL fileURLWithPath:NSTemporaryDirectory() isDirectory:YES];
        NSString *pathExtension = isGif ?  @"gif" : @"png";
        NSURL *captionedImagePath = [[tmpDirURL URLByAppendingPathComponent:@"final"] URLByAppendingPathExtension:pathExtension];
        [[NSFileManager defaultManager] removeItemAtPath:captionedImagePath.path error:nil];
        
        [captionedImageData writeToURL:captionedImagePath atomically:YES];
        
        dispatch_sync(dispatch_get_main_queue(), ^{
            [self.delegate finishedCaptionedImageAtPath:captionedImagePath];
        });
    });
}

- (void)generateCaption:(NSString*)text toVideoAtPath:(NSURL*)videoPath {
    [self generateCaption:text toVideoAtPath:videoPath withMinOutputResolution:640];
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
    
    // label creation must be done on ui thread
    int innerXPadding = 12;
    UILabel *label = [self captionedLabelWithText:text insetXSpacing:innerXPadding mediaWidth:videoSize.width];
    
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
                NSError *error = [NSError errorWithDomain:@"" code:1 userInfo:@{NSLocalizedDescriptionKey : errorDescription}];
                NSLog(@"%@", error.localizedDescription);
                [self.delegate finishedCaptionedVideoAtPath:nil withError:error];
            });
        } else {
            [assetExport exportAsynchronouslyWithCompletionHandler:^(void) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    
                    [self.delegate finishedCaptionedVideoAtPath:captionedVideoPath withError: assetExport.error];
                });
            }];
        }
    });
}

-(UILabel*)captionedLabelWithText:(NSString*)text insetXSpacing:(int)insetXSpacing mediaWidth:(int)width {
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, width - insetXSpacing*2, 1000)];
    label.text = text;
    label.textAlignment = NSTextAlignmentLeft;
    label.textColor = [UIColor colorWithRed:25.0/255.0 green:25.0/255.0 blue:25.0/255.0 alpha:1];
    label.numberOfLines = 0;
    label.font = [UIFont fontWithName:DEFAULT_MEME_FONT size:MAX(12, width/15.0)];
    [label sizeToFit];
    
    return label;
}

@end
