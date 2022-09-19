//
//  ImageMemeGeneratorProtocol.h
//  iMessageMemeGenerator
//
//  Created by Derek Buchanan on 9/17/22.
//

#import "CaptionGeneratorDelegate.h"
@import UIKit;

#ifndef ImageMemeGeneratorProtocol_h
#define ImageMemeGeneratorProtocol_h

@protocol ImageMemeGeneratorProtocol <NSObject>
@required
/// Add meme captions on images. A default recommended output size is applied if input is too small. Output is always a GIF if input is more than one frame or PNG otherwise.
/// @param text The meme text to be placed above the image.
/// @param imageData The image data to be captioned.
- (void)generateCaption:(NSString*)text toImageData:(NSData*)imageData;

/// Add meme captions to images. Output is always a GIF if input is more than one frame or PNG otherwise.
/// @param text The meme text to be placed above the image.
/// @param imageData The image data to be captioned.
/// @param desiredMinWidth The minimum output width resolution
- (void)generateCaption:(NSString*)text toImageData:(NSData*)imageData withMinOutputResolutionWidth:(CGFloat)desiredMinWidth;

@property (nonatomic, weak) id<CaptionGeneratorDelegate> delegate;

@end

#endif /* ImageMemeGeneratorProtocol_h */
