//
//  AudioPlayer.h
//  AudioKit
//
//  Created by Gabriel Soria Souza on 20/06/20.
//  Copyright © 2020 Gabriel Sória Souza. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <AVKit/AVKit.h>

NS_ASSUME_NONNULL_BEGIN

@protocol AMAudioPlayerDelegate <NSObject>

- (void)progressUpdateWithCurrentPosition:(float)currentPosition;
- (void)countdownUpWithTime:(NSString *)time;
- (void)countdownTimeWithTime:(NSString *)time;
- (void)meterLevelWithLevel:(double)level;
- (void)didDisconnectVolumeTap;
- (void)setUpdaterToPaused:(BOOL)paused;

@end

@interface AMAudioPlayer : NSObject <AVAudioPlayerDelegate>

@property (strong, atomic, readwrite) AVAudioPlayerNode *player;
@property (strong, atomic, readwrite) AVAudioEngine *engine;
@property (strong, atomic, readwrite) AVAudioUnitTimePitch *rateEffect;
@property (strong, atomic, readwrite) AVAudioSession *audioSession;
@property (nonatomic) AVAudioFile *file;
@property (strong, atomic, readwrite) AVAudioFormat *format;
@property (strong, atomic, readwrite) NSURL *fileURL;
@property (readwrite) AVAudioFramePosition audioLengthSamples;
@property float audioLenghtSeconds;
@property (weak) id <AMAudioPlayerDelegate> delegate;
@property (strong, atomic, readwrite) CADisplayLink *updater;
@property (nonatomic, readwrite) float rateValue;
@property (atomic, readwrite) NSArray *rateSliderValues;

- (instancetype)initWithAudioFileURL:(NSURL *)url;

- (void)stopPlayingAudio;
- (void)setPlayOrPause;
- (void)progressUpdate;
- (void)seek:(float)time;
- (void)audioFileSetup:(NSURL *)url;
- (BOOL)isPlaying;

@end

NS_ASSUME_NONNULL_END
