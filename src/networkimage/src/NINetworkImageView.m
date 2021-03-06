//
// Copyright 2011 Jeff Verkoeyen
//
// Forked from Three20 June 15, 2011 - Copyright 2009-2011 Facebook
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

#import "NINetworkImageView.h"

#import "NimbusCore.h"
#import "ASIHTTPRequest.h"
#import "ASIDownloadCache.h"

#import "NIHTTPImageRequest.h"



///////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////
@interface NINetworkImageView()

@property (nonatomic, readwrite, retain) NSOperation* operation;

@property (nonatomic, readwrite, copy) NSString* lastPathToNetworkImage;

@end


///////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////
@implementation NINetworkImageView

@synthesize operation               = _operation;
@synthesize sizeForDisplay          = _sizeForDisplay;
@synthesize scaleOptions            = _scaleOptions;
@synthesize interpolationQuality    = _interpolationQuality;
@synthesize imageMemoryCache        = _imageMemoryCache;
@synthesize imageDiskCache          = _imageDiskCache;
@synthesize networkOperationQueue   = _networkOperationQueue;
@synthesize maxAge                  = _maxAge;
@synthesize diskCacheLifetime       = _diskCacheLifetime;
@synthesize initialImage            = _initialImage;
@synthesize memoryCachePrefix       = _memoryCachePrefix;
@synthesize lastPathToNetworkImage  = _lastPathToNetworkImage;
@synthesize delegate                = _delegate;


///////////////////////////////////////////////////////////////////////////////////////////////////
- (void)cancelOperation {
  if ([self.operation isKindOfClass:[ASIHTTPRequest class]]) {
    ASIHTTPRequest* request = (ASIHTTPRequest *)self.operation;
    // Clear the delegate so that we don't receive a didFail notification when we cancel the
    // operation.
    request.delegate = nil;
  }
  [self.operation cancel];
}


///////////////////////////////////////////////////////////////////////////////////////////////////
- (void)dealloc {
  [self cancelOperation];

  NI_RELEASE_SAFELY(_operation);

  NI_RELEASE_SAFELY(_initialImage);

  NI_RELEASE_SAFELY(_imageMemoryCache);
  NI_RELEASE_SAFELY(_imageDiskCache);
  NI_RELEASE_SAFELY(_networkOperationQueue);

  NI_RELEASE_SAFELY(_memoryCachePrefix);

  NI_RELEASE_SAFELY(_lastPathToNetworkImage);

  [super dealloc];
}


///////////////////////////////////////////////////////////////////////////////////////////////////
- (void)assignDefaults {
  self.sizeForDisplay = YES;
  self.scaleOptions = NINetworkImageViewScaleToFitLeavesExcessAndScaleToFillCropsExcess;
  self.interpolationQuality = kCGInterpolationDefault;
  
  self.diskCacheLifetime = NINetworkImageViewDiskCacheLifetimePermanent;
  
  self.imageMemoryCache = [Nimbus imageMemoryCache];
  self.networkOperationQueue = [Nimbus networkOperationQueue];
  self.imageDiskCache = [ASIDownloadCache sharedCache];
}


///////////////////////////////////////////////////////////////////////////////////////////////////
- (id)initWithImage:(UIImage *)image {
  if ((self = [super initWithImage:image])) {
    [self assignDefaults];

    // Retain the initial image.
    self.initialImage = image;
  }
  return self;
}


///////////////////////////////////////////////////////////////////////////////////////////////////
- (id)initWithFrame:(CGRect)frame {
  if ((self = [self initWithImage:nil])) {
    self.frame = frame;
  }
  return self;
}


///////////////////////////////////////////////////////////////////////////////////////////////////
- (id)initWithCoder:(NSCoder *)aDecoder {
  if ((self = [super initWithCoder:aDecoder])) {
    [self assignDefaults];
  }
  return self;
}


///////////////////////////////////////////////////////////////////////////////////////////////////
- (id)init {
  return [self initWithImage:nil];
}


///////////////////////////////////////////////////////////////////////////////////////////////////
- (NSString *)cacheKeyForURL: (NSURL *)URL
                   imageSize: (CGSize)imageSize
                 contentMode: (UIViewContentMode)contentMode
                scaleOptions: (NINetworkImageViewScaleOptions)scaleOptions {
  NSString* cacheKey = [URL absoluteString];

  // Prefix cache key to create a namespace.
  if (nil != self.memoryCachePrefix) {
    cacheKey = [self.memoryCachePrefix stringByAppendingString:cacheKey];
  }

  // Append the size to the key. This allows us to differentiate cache keys by image dimension.
  // If the display size ever changes, we want to ensure that we're fetching the correct image
  // from the cache.
  if (self.sizeForDisplay) {
    cacheKey = [cacheKey stringByAppendingFormat:@"%@{%d,%d}",
                NSStringFromCGSize(imageSize), contentMode, scaleOptions];
  }

  // The resulting cache key will look like:
  // (memoryCachePrefix)/path/to/image({width,height}{contentMode,cropImageForDisplay})

  return cacheKey;
}


///////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Internal consistent implementation of state changes


///////////////////////////////////////////////////////////////////////////////////////////////////
- (void)_didStartLoading {
  if ([self.delegate respondsToSelector:@selector(networkImageViewDidStartLoad:)]) {
    [self.delegate networkImageViewDidStartLoad:self];
  }

  [self networkImageViewDidStartLoading];
}


///////////////////////////////////////////////////////////////////////////////////////////////////
- (void)_didFinishLoadingWithImage: (UIImage *)image
                               URL: (NSURL *)url
                       displaySize: (CGSize)displaySize
                       contentMode: (UIViewContentMode)contentMode
                      scaleOptions: (NINetworkImageViewScaleOptions)scaleOptions
                    expirationDate: (NSDate *)expirationDate {
  // Store the result image in the memory cache.
  if (nil != self.imageMemoryCache) {
    NSString* cacheKey = [self cacheKeyForURL: url
                                    imageSize: displaySize
                                  contentMode: contentMode
                                 scaleOptions: scaleOptions];

    // Store the image in the memory cache, possibly with an expiration date.
    [self.imageMemoryCache storeObject: image
                              withName: cacheKey
                          expiresAfter: expirationDate];
  }

  // Display the new image.
  [self setImage:image];

  self.operation = nil;

  if ([self.delegate respondsToSelector:@selector(networkImageView:didLoadImage:)]) {
    [self.delegate networkImageView:self didLoadImage:self.image];
  }

  [self networkImageViewDidLoadImage:image];
}


///////////////////////////////////////////////////////////////////////////////////////////////////
- (void)_didFailToLoadWithError:(NSError *)error {
  self.operation = nil;

  [self networkImageViewDidFailToLoad:error];
}


///////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark ASIHTTPRequestDelegate


///////////////////////////////////////////////////////////////////////////////////////////////////
- (void)requestStarted:(NIHTTPImageRequest *)request {
  [self _didStartLoading];
}


///////////////////////////////////////////////////////////////////////////////////////////////////
- (void)requestDidFinish:(NIHTTPImageRequest *)request {
  // Get the expiration date from the response headers for the request.
  NSDate* expirationDate = [ASIHTTPRequest expiryDateForRequest:request maxAge:self.maxAge];

  [self _didFinishLoadingWithImage: request.imageCroppedAndSizedForDisplay
                               URL: request.url
                       displaySize: request.imageDisplaySize
                       contentMode: request.imageContentMode
                      scaleOptions: request.scaleOptions
                    expirationDate: expirationDate];
}


///////////////////////////////////////////////////////////////////////////////////////////////////
- (void)requestDidFail:(NIHTTPImageRequest *)request {
  [self _didFailToLoadWithError:request.error];
}


///////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Utility Methods


///////////////////////////////////////////////////////////////////////////////////////////////////
- (ASICacheStoragePolicy)cacheStoragePolicy {
  switch (self.diskCacheLifetime) {
    case NINetworkImageViewDiskCacheLifetimeSession: {
      return ASICacheForSessionDurationCacheStoragePolicy;
    }
    default:
    case NINetworkImageViewDiskCacheLifetimePermanent: {
      return ASICachePermanentlyCacheStoragePolicy;
    }
  }
}


///////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Subclassing


///////////////////////////////////////////////////////////////////////////////////////////////////
- (void)networkImageViewDidStartLoading {
  // No-op. Meant to be overridden.
}


///////////////////////////////////////////////////////////////////////////////////////////////////
- (void)networkImageViewDidLoadImage:(UIImage *)image {
  // No-op. Meant to be overridden.
}


///////////////////////////////////////////////////////////////////////////////////////////////////
- (void)networkImageViewDidFailToLoad:(NSError *)error {
  // No-op. Meant to be overridden.
}


///////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Public Methods


///////////////////////////////////////////////////////////////////////////////////////////////////
- (void)setPathToNetworkImage:(NSString *)pathToNetworkImage {
  [self setPathToNetworkImage: pathToNetworkImage
               forDisplaySize: CGSizeZero
                  contentMode: self.contentMode
                     cropRect: CGRectZero];
}


///////////////////////////////////////////////////////////////////////////////////////////////////
- (void)setPathToNetworkImage:(NSString *)pathToNetworkImage forDisplaySize:(CGSize)displaySize {
  [self setPathToNetworkImage: pathToNetworkImage
               forDisplaySize: displaySize
                  contentMode: self.contentMode
                     cropRect: CGRectZero];
}


///////////////////////////////////////////////////////////////////////////////////////////////////
- (void)setPathToNetworkImage:(NSString *)pathToNetworkImage forDisplaySize:(CGSize)displaySize contentMode:(UIViewContentMode)contentMode {
  [self setPathToNetworkImage: pathToNetworkImage
               forDisplaySize: displaySize
                  contentMode: contentMode
                     cropRect: CGRectZero];
}


///////////////////////////////////////////////////////////////////////////////////////////////////
- (void)setPathToNetworkImage:(NSString *)pathToNetworkImage cropRect:(CGRect)cropRect {
  [self setPathToNetworkImage: pathToNetworkImage
               forDisplaySize: CGSizeZero
                  contentMode: self.contentMode
                     cropRect: cropRect];
}


///////////////////////////////////////////////////////////////////////////////////////////////////
- (void)setPathToNetworkImage:(NSString *)pathToNetworkImage contentMode:(UIViewContentMode)contentMode {
  [self setPathToNetworkImage: pathToNetworkImage
               forDisplaySize: CGSizeZero
                  contentMode: contentMode
                     cropRect: CGRectZero];
}


///////////////////////////////////////////////////////////////////////////////////////////////////
- (void)setPathToNetworkImage:(NSString *)pathToNetworkImage forDisplaySize:(CGSize)displaySize contentMode:(UIViewContentMode)contentMode cropRect:(CGRect)cropRect {
  [self cancelOperation];

  if (NIIsStringWithAnyText(pathToNetworkImage)) {
    self.lastPathToNetworkImage = pathToNetworkImage;

    // We explicitly do not allow negative display sizes. Check the call stack to figure
    // out who is providing a negative display size. It's possible that displaySize is an
    // uninitialized CGSize structure.
    NIDASSERT(displaySize.width >= 0);
    NIDASSERT(displaySize.height >= 0);

    // If an invalid display size is provided, use the image view's frame instead.
    if (0 >= displaySize.width || 0 >= displaySize.height) {
      displaySize = self.frame.size;
    }

    NSURL* url = nil;

    // Check for file URLs.
    if ([pathToNetworkImage hasPrefix:@"/"]) {
      // If the url starts with / then it's likely a file URL, so treat it accordingly.
      url = [NSURL fileURLWithPath:pathToNetworkImage];

    } else {
      // Otherwise we assume it's a regular URL.
      url = [NSURL URLWithString:pathToNetworkImage];
    }

    // If the URL failed to be created, there's not much we can do here.
    if (nil == url) {
      return;
    }

    UIImage* image = nil;

    // Attempt to load the image from memory first.
    if (nil != self.imageMemoryCache) {
      NSString* cacheKey = [self cacheKeyForURL: url
                                      imageSize: displaySize
                                    contentMode: contentMode
                                   scaleOptions: self.scaleOptions];
      image = [self.imageMemoryCache objectWithName:cacheKey];
    }

    if (nil != image) {
      // We successfully loaded the image from memory.
      [self setImage:image];

      if ([self.delegate respondsToSelector:@selector(networkImageView:didLoadImage:)]) {
        [self.delegate networkImageView:self didLoadImage:self.image];
      }

    } else {
      // Unable to load the image from memory, fire off the load request (which will load
      // the image from the disk if possible and fall back to loading from the network).

      // NIHTTPImageRequest handles file urls by simply loading the image from the disk and firing
      // off the necessary delegate notifications. No network objects are created in the
      // image request thread when this happens.

      NIHTTPImageRequest* request =
      [NIHTTPImageRequest requestWithURL: url
                              usingCache: self.imageDiskCache];

      [request setDelegate:self];
      [request setDidFinishSelector:@selector(requestDidFinish:)];
      [request setDidFailSelector:@selector(requestDidFail:)];

      [request setCacheStoragePolicy:self.cacheStoragePolicy];

      [request setImageCropRect:cropRect];
      [request setScaleOptions:self.scaleOptions];
      [request setInterpolationQuality:self.interpolationQuality];
      if (self.sizeForDisplay) {
        [request setImageDisplaySize:displaySize];
        [request setImageContentMode:contentMode];
      }

      self.operation = request;

      [self.networkOperationQueue addOperation:self.operation];
    }
  }
}


///////////////////////////////////////////////////////////////////////////////////////////////////
- (void)prepareForReuse {
  [self cancelOperation];

  [self setImage:self.initialImage];
}


///////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Properties


///////////////////////////////////////////////////////////////////////////////////////////////////
- (void)setInitialImage:(UIImage *)initialImage {
  if (_initialImage != initialImage) {
    BOOL updateViewImage = (_initialImage == self.image);
    [_initialImage release];
    _initialImage = [initialImage retain];

    if (updateViewImage) {
      [self setImage:_initialImage];
    }
  }
}


///////////////////////////////////////////////////////////////////////////////////////////////////
- (BOOL)isLoading {
  return nil != self.operation;
}


///////////////////////////////////////////////////////////////////////////////////////////////////
- (void)setNetworkOperationQueue:(NSOperationQueue *)queue {
  // Don't allow a nil network operation queue.
  NIDASSERT(nil != queue);
  if (nil == queue) {
    queue = [Nimbus networkOperationQueue];
  }
  if (queue != _networkOperationQueue) {
    [_networkOperationQueue release];
    _networkOperationQueue = [queue retain];
  }
}


@end

