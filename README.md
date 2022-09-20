# iMessageMemes
Demo for making memes inside of an iMessage extension app. Anyone can add the popular top border captions to photos, gifs and videos.

Here is an example:

![Example](demo.gif)

Implement ```ImageMemeGeneratorProtocol``` or ```VideoMemeGeneratorProtocol``` and use ```ModernImageCaptionGenerator``` or ```ModernVideoCaptionGenerator``` as a guide to design your own memes.

```ModernImageCaptionGenerator``` and ```ModernVideoCaptionGenerator``` were written in Objective C primarily to demonstrate some of the hurdles of working with swift-obj c code bases. The ImageMagick version I used was compiled for use with Objective C. This ImageMagick version also does not support some of the newer image formats such as heic, so a conversion to a format like png needs to take place. Implementing those two protocols above leaves open the opportunity to use whatever you desire to make your own memes.

This demo makes notable use of: 

* [ImageMagick](https://imagemagick.org/)
Why ImageMagick? I love ImageMagick despite how primitive it is. The docs website gives off a 90's vibe and image-wise, I don't think there's anything ImageMagick cannot do. It's great for manipulating gifs and optimizing the transparencies of frames.
* [TLPhotos](https://github.com/tilltue/TLPhotoPicker)
Probably my favorite photo picker.
* [Tenor](https://tenor.com/gifapi/documentation)
Why Tenor and not Giphy? Giphy does not allow the editing or manipulation of their gifs. They work with advertisers and I would imagine they do not want gifs made by their partners getting altered for their end user campaigns.

I added a Spanish localization as a bonus. I don't speak Spanish personally, so I used Google Translate.

Happy coding!
