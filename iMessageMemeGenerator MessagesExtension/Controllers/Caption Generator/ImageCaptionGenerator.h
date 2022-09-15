//
//  ImageCaptionGenerator.h
//  iMessageMemeGenerator MessagesExtension
//
//  Created by Derek Buchanan on 9/15/22.
//

#import <Foundation/Foundation.h>
#import "CaptionGeneratorDelegate.h"
NS_ASSUME_NONNULL_BEGIN

@interface ImageCaptionGenerator : NSObject
@property (nonatomic, weak) id<CaptionGeneratorDelegate> delegate;

/// Add meme captions on images. The default output resolution width is 480.
/// @param text The meme text to be placed above the image.
/// @param imageData The image data to be captioned.
- (void)generateCaption:(NSString*)text toImageData:(NSData*)imageData;

/// Add meme captions to images.
/// @param text he meme text to be placed above the image.
/// @param imageData The image data to be captioned.
/// @param desiredMinWidth The minimum output width resolution
- (void)generateCaption:(NSString*)text toImageData:(NSData*)imageData withMinOutputResolution:(int)desiredMinWidth;

@end

NS_ASSUME_NONNULL_END
