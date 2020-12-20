//
//  AMAudioFileConverter.h
//  
//
//  Created by Gabriel Soria Souza on 07/09/20.
//

#import <Foundation/Foundation.h>
@import AudioToolbox;

NS_ASSUME_NONNULL_BEGIN

@protocol AMAudioFileConverterDelegate;

@interface AMAudioFileConverter : NSOperation

- (instancetype)initWithSourceURL:(NSURL *)sourceURL destinationURL:(NSURL *)destinationURL sampleRate:(Float64)sampleRate outputFormat:(AudioFormatID)outputFormat;

@property (readonly, nonatomic, strong) NSURL *sourceURL;
@property (readonly, nonatomic, strong) NSURL *destinationURL;
@property (readonly, nonatomic, assign) Float64 sampleRate;
@property (readonly, nonatomic, assign) AudioFormatID outputFormat;
@property (nonatomic, weak) id<AMAudioFileConverterDelegate> delegate;

- (void)startConverting;

@end

@protocol AMAudioFileConverterDelegate <NSObject>

- (void)audioFileConvertOperation:(AMAudioFileConverter *)audioFileConvertOperation didEncounterError:(NSError *)error;
- (void)audioFileConvertOperation:(AMAudioFileConverter *)audioFileConvertOperation didCompleteWithURL:(NSURL *)destinationURL;

@end

NS_ASSUME_NONNULL_END
