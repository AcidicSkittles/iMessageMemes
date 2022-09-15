//
//  ImageCaptionGenerator.m
//  iMessageMemeGenerator MessagesExtension
//
//  Created by Derek Buchanan on 9/15/22.
//

#import "ImageCaptionGenerator.h"
#import "MagickWand.h"
#import "iMessageMemeGenerator_MessagesExtension-Swift.h"
@import ImageIO;

@implementation ImageCaptionGenerator

/**
 The more transparency a GIF has, the lower its file size. This setting is used
 by ImageMagick to compute the transparent pixels on the current frame based
 on this threshold value to the underlying pixels on the previous frame. There is
 a trade-off between file size and a visually appealing result.
 */
static double const OPTIMIZED_GIF_TRANSPARENCY_FUZZ = 12;
static double const DEFAULT_MIN_OUTPUT_WIDTH = 480;

- (void)generateCaption:(NSString*)text toImageData:(NSData*)imageData {
    [self generateCaption:text toImageData:imageData withMinOutputResolution:DEFAULT_MIN_OUTPUT_WIDTH];
}

- (void)generateCaption:(NSString*)text toImageData:(NSData*)imageData withMinOutputResolution:(int)desiredMinWidth {
    
    CGImageSourceRef source = CGImageSourceCreateWithData((CFDataRef)imageData, NULL);
    NSDictionary* imageHeader = (__bridge NSDictionary*) CGImageSourceCopyPropertiesAtIndex(source, 0, NULL);
    NSNumber *imageWidth = (NSNumber *)[imageHeader objectForKey: (__bridge NSString *)kCGImagePropertyPixelWidth];
    
    int maxLabelWidth = MAX(imageWidth.intValue, desiredMinWidth);
    
    const float defaultInnerXPadding = 5;
    int innerXPadding = (int)((float)defaultInnerXPadding * (float)desiredMinWidth/(float)DEFAULT_MIN_OUTPUT_WIDTH);
    UILabel *label = [MemeLabelMaker captionedLabelWithText:text insetXSpacing:innerXPadding mediaWidth:maxLabelWidth];
    
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
            [self.delegate finishedCaptionedMediaAtPath:captionedImagePath withError:nil];
        });
    });
}

@end
