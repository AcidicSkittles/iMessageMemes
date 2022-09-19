//
//  ModernImageCaptionGenerator.m
//  iMessageMemeGenerator MessagesExtension
//
//  Created by Derek Buchanan on 9/15/22.
//

#import "ModernImageCaptionGenerator.h"
#import "MagickWand.h"
#import "iMessageMemeGenerator_MessagesExtension-Swift.h"
@import ImageIO;

@implementation ModernImageCaptionGenerator

@synthesize delegate;
/**
 The more transparency a GIF has, the lower its file size. This setting is used
 by ImageMagick to compute the transparent pixels on the current frame based
 on this threshold value to the underlying pixels on the previous frame. There is
 a trade-off between file size and a visually appealing result.
 */
static double const OPTIMIZED_GIF_TRANSPARENCY_FUZZ = 12;
static CGFloat const DEFAULT_MIN_OUTPUT_WIDTH = 480;
static CGFloat const DEFAULT_INSET_PADDING = 20;

typedef NSString *ImageFormatExtension NS_STRING_ENUM;
ImageFormatExtension const GIF = @"gif";
ImageFormatExtension const PNG = @"png";

- (void)generateCaption:(NSString*)text toImageData:(NSData*)imageData {
    [self generateCaption:text toImageData:imageData withMinOutputResolutionWidth:DEFAULT_MIN_OUTPUT_WIDTH];
}

- (void)generateCaption:(NSString*)text toImageData:(NSData*)imageData withMinOutputResolutionWidth:(CGFloat)desiredMinWidth {
    CGSize uprightImageSize = [ImageHelpers uprightImageSizeFromImageData:imageData];
    CGFloat outputImageWidth = MAX(uprightImageSize.width, desiredMinWidth);
    
    // design our modern meme label
    UILabel *memeCaptionLabel = [ModernMemeLabelMaker captionedLabelWithText:text mediaWidth:outputImageWidth];
    UIImage *memeCaptionLabelImage = [UIImage imageWithView:memeCaptionLabel];
    
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0ul);
    dispatch_async(queue, ^{
        // Image Magick is limited to a few image types and cannot handle types like heic
        NSData *uprightImageData = [ImageHelpers uprightPngOrGifDataFromImageData:imageData];
        NSData *memeCaptionLabelData = UIImagePNGRepresentation(memeCaptionLabelImage);
        
        MagickWand *outputFrames = NewMagickWand();
        MagickWand *sourceImage = NewMagickWand();
        MagickReadImageBlob(sourceImage, [uprightImageData bytes], [uprightImageData length]);
        
        // anything with more than one frame we will treat as a GIf
        BOOL isGif = MagickGetNumberImages(sourceImage) > 1;
        
        // coalescing the frames removes any transparency, page geometry, or other size optimizations and makes a simple
        // and easy to understand full frame-by-frame gif
        BOOL didCoalesce = false;
        // BackgroundDispose animated gifs do not contain transparency that depend on the previous frame
        if(isGif) {
            sourceImage = MagickCoalesceImages(sourceImage);
            didCoalesce = true;
        }
        
        int insetPadding = DEFAULT_INSET_PADDING * outputImageWidth / DEFAULT_MIN_OUTPUT_WIDTH;
        
        // we will add a boder via ImageMagick set to the color of the background of the meme label
        CGFloat labelBgRed = 0.0, labelBgGreen = 0.0, labelBgBlue = 0.0, labelBgAlpha = 0.0;
        [memeCaptionLabel.backgroundColor getRed:&labelBgRed green:&labelBgGreen blue:&labelBgBlue alpha:&labelBgAlpha];
        
        DisposeType previousFrameDisposal = MagickGetImageDispose(sourceImage);
        
        int totalFramesCount = (int)MagickGetNumberImages(sourceImage);
        for(int i = 0; i < totalFramesCount; i++) {
            MagickSetIteratorIndex(sourceImage, i);
            MagickWand *singleFrameWand = MagickGetImage(sourceImage);
            
            // upscale our image if it is not the min desired resolution width
            if(MagickGetImageWidth(singleFrameWand) < outputImageWidth)
                MagickScaleImage(singleFrameWand, outputImageWidth, MagickGetImageHeight(singleFrameWand) * outputImageWidth / MagickGetImageWidth(singleFrameWand));
            
            // point iterator to beginning to properly stack the label and frame top to bottom
            MagickSetFirstIterator(singleFrameWand);
            
            ssize_t x, y;
            size_t w, h;
            MagickGetImagePage(sourceImage, &w, &h, &x, &y);
            DisposeType currentFrameDisposal = MagickGetImageDispose(sourceImage);
            NSLog(@"Frame: %i Disposal: %i Geometry: (x:%zi y:%zi w:%zu h:%zu)", i, (int)currentFrameDisposal, x, y, w, h);
            
            if(i == 0 || currentFrameDisposal == PreviousDispose || previousFrameDisposal == BackgroundDispose) {
                
                // add the memelabel to the working single frame wand
                MagickReadImageBlob(singleFrameWand, [memeCaptionLabelData bytes], [memeCaptionLabelData length]);
                MagickSetImageFormat(singleFrameWand, isGif ? [GIF UTF8String] : [PNG UTF8String]);
                MagickResetIterator(singleFrameWand);
                
                // combine the two images: our meme label and source frame top to bottom style
                MagickWand *appendWand = CloneMagickWand(singleFrameWand);
                singleFrameWand = DestroyMagickWand(singleFrameWand);
                singleFrameWand = MagickAppendImages(appendWand, MagickTrue);
                appendWand = DestroyMagickWand(appendWand);
                
                // add a border to our image that matches the background of the meme caption
                PixelWand *borderWand = NewPixelWand();
                PixelSetRed(borderWand, labelBgRed);
                PixelSetGreen(borderWand, labelBgGreen);
                PixelSetBlue(borderWand, labelBgBlue);
                PixelSetAlpha(borderWand, labelBgAlpha);
                MagickBorderImage(singleFrameWand, borderWand, insetPadding, insetPadding);
            } else {
                // handle gif frames and set the new page geometry accordingly to handle a top label
                ssize_t localX, localY;
                size_t localW, localH;
                MagickGetImagePage(sourceImage, &localW, &localH, &localX, &localY);
                
                localY += memeCaptionLabelImage.size.height;
                localH += memeCaptionLabelImage.size.height;
                
                NSLog(@"New frame geometry: (x:%zi y:%zi w:%zu h:%zu)", localX+insetPadding, localY+insetPadding, localW, localH);
                MagickSetImagePage(singleFrameWand, localW, localH, localX+insetPadding, localY+insetPadding);
            }
            
            // add our compiled working frame to output frames and copy frame attributes
            MagickAddImage(outputFrames, singleFrameWand);
            MagickSetImageDelay(outputFrames, MagickGetImageDelay(sourceImage));
            MagickSetImageDispose(outputFrames, MagickGetImageDispose(sourceImage));
            
            // adding "fuzz" reduces quality, but also makes the resulting file size smaller
            MagickSetImageFuzz(outputFrames, OPTIMIZED_GIF_TRANSPARENCY_FUZZ);
            MagickCommentImage(outputFrames, (const char*)[memeCaptionLabel.text UTF8String]);
            
            singleFrameWand = DestroyMagickWand(singleFrameWand);
            
            previousFrameDisposal = MagickGetImageDispose(sourceImage);
        }
        
        if(didCoalesce)
            MagickOptimizeImageTransparency(outputFrames);
        
        size_t my_size;
        unsigned char * my_image = MagickGetImagesBlob(outputFrames, &my_size);
        NSData* captionedImageData = [[NSData alloc] initWithBytes:my_image length:my_size];
        
        free(my_image);
        sourceImage = DestroyMagickWand(sourceImage);
        outputFrames = DestroyMagickWand(outputFrames);
        
        __weak typeof(self) weakSelf = self;
        NSString *pathExtension = isGif ?  GIF : PNG;
        [ImageHelpers exportWithImageData:captionedImageData pathExtension:pathExtension completion:^(NSURL * _Nonnull captionedImagePath) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [weakSelf.delegate finishedCaptionedMediaAtPath:captionedImagePath withError:nil];
            });
        }];
    });
}

@end
