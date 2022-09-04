//
//  CaptionGenerator.h
//  iMessageExtension
//
//  Created by Derek Buchanan on 4/12/22.
//  Copyright © 2022 Derek Buchanan. All rights reserved.
//

#import <Foundation/Foundation.h>
@import UIKit;

NS_ASSUME_NONNULL_BEGIN

@protocol CaptionGeneratorDelegate <NSObject>
@required
- (void)finishedCaptionedImagePath:(NSURL*)captionedImagePath;
- (void)finishedCaptionedVideoPath:(NSURL*)captionedVideoPath;
@end

@interface CaptionGenerator : NSObject
@property (nonatomic, weak) id<CaptionGeneratorDelegate> delegate;


/// Default font name used in meme captions
+ (NSString*)defaultMemeFontName;

/// Add meme captions on images. The default output resolution width is 480.
/// @param text The meme text to be placed above the image.
/// @param imageData The image data to be captioned.
- (void)generateCaption:(NSString*)text toImageData:(NSData*)imageData;
- (void)generateCaption:(NSString*)text toImageData:(NSData*)imageData withMinOutputResolution:(int)desiredMinWidth;

/// Add meme captions to videos. The default output resolution width is 640.
/// @param text the meme text to be placed above the video.
/// @param videoPath file url path to the video on disk to be captioned.
- (void)generateCaption:(NSString*)text toVideoAtPath:(NSURL*)videoPath;
- (void)generateCaption:(NSString*)text toVideoAtPath:(NSURL*)videoPath withMinOutputResolution:(int)desiredMinWidth;

@end

NS_ASSUME_NONNULL_END
