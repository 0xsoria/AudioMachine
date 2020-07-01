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

@property AVAudioPlayerNode *player;
@property AVAudioEngine *engine;
@property AVAudioUnitVarispeed *speedControl;
@property AVAudioUnitTimePitch *pitchControl;
@property AVAudioSession *audioSession;
@property (nonatomic) AVAudioFile *file;
@property AVAudioFormat *format;
@property NSURL *fileURL;
@property AVAudioFramePosition audioLengthSamples;
@property float audioLenghtSeconds;
@property (weak) id <AMAudioPlayerDelegate> delegate;

- (instancetype)initWithAudioFileURL:(NSURL *)url;

- (void)stopPlayingAudio;
- (void)setPlayOrPause;
- (void)progressUpdate;
- (void)seek:(float)time;

@end

NS_ASSUME_NONNULL_END
