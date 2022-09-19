//
//  ModernVideoCaptionGenerator.m
//  iMessageMemeGenerator MessagesExtension
//
//  Created by Derek Buchanan on 9/15/22.
//

#import "ModernVideoCaptionGenerator.h"
#import "iMessageMemeGenerator_MessagesExtension-Swift.h"
@import AVFoundation;

@implementation ModernVideoCaptionGenerator

@synthesize delegate;

static CGFloat const DEFAULT_MIN_OUTPUT_WIDTH = 640;
static CGFloat const DEFAULT_INSET_PADDING = 12;

- (void)generateCaption:(NSString*)text toVideoAtPath:(NSURL*)videoPath {
    [self generateCaption:text toVideoAtPath:videoPath withMinOutputResolutionWidth:DEFAULT_MIN_OUTPUT_WIDTH];
}

- (void)generateCaption:(NSString*)text toVideoAtPath:(NSURL*)videoPath withMinOutputResolutionWidth:(CGFloat)desiredMinWidth {
    
    AVURLAsset *asset = [[AVURLAsset alloc] initWithURL:videoPath options:@{AVURLAssetPreferPreciseDurationAndTimingKey : @YES}];
    if([asset tracksWithMediaType:AVMediaTypeAudio].count == 0) {
        [self notifyDelegateOfUnsupportedError];
        return;
    }
    
    AVAssetTrack *videoTrack = [[asset tracksWithMediaType:AVMediaTypeVideo] firstObject];
    CGSize outputVideoSize = [VideoHelpers uprightVideoSizeFromVideoTrack:videoTrack];
    
    // upscale to higher res so caption is readable
    if(outputVideoSize.width < desiredMinWidth)
        outputVideoSize = CGSizeMake(desiredMinWidth, outputVideoSize.height * (desiredMinWidth/outputVideoSize.width));
    
    // design our modern meme label
    CGFloat insetPadding = DEFAULT_INSET_PADDING * desiredMinWidth / DEFAULT_MIN_OUTPUT_WIDTH;
    UILabel *memeLabel = [ModernMemeLabelMaker captionedLabelWithText:text mediaWidth:outputVideoSize.width];
    UIImage *memeLabelImage = [UIImage imageWithView:memeLabel];
    
    // calculate the output full render size - video, borders, captions and all
    CGFloat memeLabelTopPadding = insetPadding,
            memeLabelBottomPadding = insetPadding,
            videoBottomPadding = insetPadding,
            videoLeftPadding = insetPadding,
            videoRightPadding = insetPadding;
    
    CGFloat renderWidth = floor(outputVideoSize.width + videoLeftPadding + videoRightPadding);
    CGFloat renderHeight = floor(outputVideoSize.height + memeLabelImage.size.height + memeLabelTopPadding + memeLabelBottomPadding + videoBottomPadding);
    CGSize outputRenderSize = CGSizeMake(renderWidth, renderHeight);
        
    AVMutableComposition *sourceComposition = [VideoHelpers defaultAVMutableCompositionFromAsset:asset];
    if(sourceComposition == nil) {
        [self notifyDelegateOfUnsupportedError];
        return;
    }
    
    AVMutableVideoComposition *memeComposition = [VideoHelpers defaultAVMutableVideoCompositionFromAsset:asset sourceComposition:sourceComposition outputRenderSize:outputRenderSize];
    if(memeComposition == nil) {
        [self notifyDelegateOfUnsupportedError];
        return;
    }
    
    // position our meme layers onto a base composition for rendering
    CALayer *memeLabelLayer = [CALayer layer];
    [memeLabelLayer setContents:(id)[memeLabelImage CGImage]];
    memeLabelLayer.frame = CGRectMake(videoLeftPadding, outputVideoSize.height + videoBottomPadding + memeLabelBottomPadding, memeLabelImage.size.width, memeLabelImage.size.height);
    
    CALayer *videoLayer = [CALayer layer];
    videoLayer.frame = CGRectMake(videoLeftPadding, videoBottomPadding, outputVideoSize.width, outputVideoSize.height);
    
    CALayer *parentLayer = [CALayer layer];
    [parentLayer setBackgroundColor:memeLabel.backgroundColor.CGColor];
    parentLayer.frame = CGRectMake(0, 0, memeComposition.renderSize.width, memeComposition.renderSize.height);
    [parentLayer addSublayer:videoLayer];
    [parentLayer addSublayer:memeLabelLayer];
    
    memeComposition.animationTool = [AVVideoCompositionCoreAnimationTool videoCompositionCoreAnimationToolWithPostProcessingAsVideoLayer:videoLayer inLayer:parentLayer];
    
    // TODO: videoCompositionCoreAnimationToolWithPostProcessingAsVideoLayer crash EXC_BAD_INSTRUCTION in the Simulator, but not device
    if(TARGET_OS_SIMULATOR) {
        NSString *errorDescription = @"Important note: videoCompositionCoreAnimationToolWithPostProcessingAsVideoLayer will cause crash EXC_BAD_INSTRUCTION in the Simulator, but not device. Discussion: https://developer.apple.com/forums/thread/133681 (visit link in console). Alternatively, run on a device.";
        NSLog(@"%@", errorDescription);
        [self notifyDelegateOfErrorDescription:errorDescription];
    } else {
        __weak typeof(self) weakSelf = self;
        [VideoHelpers exportAsyncWithAssetComposition:sourceComposition videoComposition:memeComposition completion:^(NSURL * _Nullable ouputPath, NSError * _Nullable error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [weakSelf.delegate finishedCaptionedMediaAtPath:ouputPath withError:error];
            });
        }];
    }
}

- (void)notifyDelegateOfUnsupportedError {
    [self notifyDelegateOfErrorDescription:NSLocalizedString(@"UNSUPPORTED_FILE", @"Error")];
}

- (void)notifyDelegateOfErrorDescription:(NSString *)errorDescription {
    NSError *error = [NSError errorWithDomain:[NSString stringWithFormat:@"com.%@", NSStringFromClass([self class])] code:1 userInfo:@{NSLocalizedDescriptionKey : errorDescription}];
    [self.delegate finishedCaptionedMediaAtPath:nil withError:error];
}
@end
