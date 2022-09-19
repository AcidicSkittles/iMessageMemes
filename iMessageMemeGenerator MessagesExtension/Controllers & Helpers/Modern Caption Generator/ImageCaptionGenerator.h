//
//  ModernImageCaptionGenerator.h
//  iMessageMemeGenerator MessagesExtension
//
//  Created by Derek Buchanan on 9/15/22.
//

#import <Foundation/Foundation.h>
#import "ImageMemeGeneratorProtocol.h"

NS_ASSUME_NONNULL_BEGIN

@interface ModernImageCaptionGenerator : NSObject <ImageMemeGeneratorProtocol>
//@property (nonatomic, weak) id<CaptionGeneratorDelegate> delegate;
//
///// Add meme captions on images. The default output resolution width is 480. Output is always a GIF if input is more than one frame or PNG otherwise.
///// @param text The meme text to be placed above the image.
///// @param imageData The image data to be captioned.
//- (void)generateCaption:(NSString*)text toImageData:(NSData*)imageData;
//
///// Add meme captions to images. Output is always a GIF if input is more than one frame or PNG otherwise.
///// @param text he meme text to be placed above the image.
///// @param imageData The image data to be captioned.
///// @param desiredMinWidth The minimum output width resolution
//- (void)generateCaption:(NSString*)text toImageData:(NSData*)imageData withMinOutputResolution:(int)desiredMinWidth;

@end

NS_ASSUME_NONNULL_END
