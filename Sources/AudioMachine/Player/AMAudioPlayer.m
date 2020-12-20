//
//  AudioPlayer.m
//  AudioKit
//
//  Created by Gabriel Soria Souza on 20/06/20.
//  Copyright © 2020 Gabriel Sória Souza. All rights reserved.
//

#import "AMAudioPlayer.h"
#import "AMMetadata.h"

@interface AMAudioPlayer()

@property (atomic, readwrite) BOOL needsSchedule;
@property (atomic, readwrite) float currentFrame;
@property (atomic, readwrite) float seekFrame;
@property (atomic, readwrite) float audioSampleRate;
@property (atomic, readwrite) float minDB;
@property (nonatomic) float currentPosition;

- (void)scheduleAudioFile;

@end

@implementation AMAudioPlayer

@synthesize file = _file;
@synthesize rateEffect = _rateEffect;
@synthesize rateValue = _rateValue;

- (NSDictionary *)getMetadata {
    AMMetadata *metadata = [[AMMetadata alloc] init];
    return [metadata getFileMetadataAtURLString:self.fileURL];
}

- (void)setRateValue:(float)rateValue {
    self.rateEffect.rate = rateValue;
    _rateValue = rateValue;
}

- (void)setFile:(AVAudioFile *)newFile {
    _file = newFile;
    self.audioLengthSamples = newFile.length;
    self.format = newFile.processingFormat;
    self.audioSampleRate = self.format.sampleRate;
    self.audioLenghtSeconds = self.audioLengthSamples / self.audioSampleRate;
}

- (AVAudioFramePosition)playerCurrentFrame {
    AVAudioTime *lastRenderTime = self.player.lastRenderTime; //may return nil if not playing.
    AVAudioTime *playerTime = [self.player playerTimeForNodeTime:lastRenderTime];
    return playerTime.sampleTime;
}

- (instancetype)initWithAudioFileURL:(NSURL *)url {
    self = [super init];
    if (self == [super init]) {
        self.rateSliderValues = @[@0.5, @1.0, @1.25, @1.5, @1.75, @2.0, @2.5, @3.0];
        self.rateValue = 1.0;
        self.rateEffect = [[AVAudioUnitTimePitch alloc] init];
        self.rateEffect.rate = self.rateValue;
        self.updater = [CADisplayLink displayLinkWithTarget:self selector:@selector(progressUpdate)];
        [self.updater addToRunLoop:NSRunLoop.currentRunLoop forMode:NSDefaultRunLoopMode];
        [self.updater setPaused:YES];
        float position = 0.0;
        self.currentPosition = position;
        self.audioSampleRate = 0;
        self.seekFrame = 0;
        self.minDB = -80.0;
        [self setNeedsSchedule:YES];
        [self audioFileSetup:url];
    }
    return self;
}

- (BOOL)isPlaying {
    return self.player.isPlaying;
}

- (void)audioFileSetup:(NSURL *)url {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        NSError *engineError;
        NSError *fileError;
        NSError *audioSessionCategoryError;
        NSError *outputError;
        NSError *activationError;
        NSError *categoryError;
        
        [self setFileURL:url];
        AVAudioFile *localFile = [[AVAudioFile alloc] initForReading:url error:&fileError];
        self.file = localFile;
        
        self.audioSession = [AVAudioSession sharedInstance];
        [self.audioSession overrideOutputAudioPort:AVAudioSessionPortOverrideSpeaker error:&outputError];
        if (@available(iOS 11.0, *)) {
            [self.audioSession setCategory:AVAudioSessionCategoryPlayback
                                      mode:AVAudioSessionModeDefault
                        routeSharingPolicy:(AVAudioSessionRouteSharingPolicyLongForm)
                                   options:AVAudioSessionCategoryOptionAllowAirPlay
                                     error:&categoryError];
        } else {
            [self.audioSession setCategory:AVAudioSessionCategoryPlayback error:&audioSessionCategoryError];
        }
        [self.audioSession setActive:YES error:&activationError];
        self.player = [[AVAudioPlayerNode alloc] init];
        self.engine = [[AVAudioEngine alloc] init];
        self.rateEffect = [[AVAudioUnitTimePitch alloc]init];
        
        [self.engine attachNode:self.player];
        [self.engine attachNode:self.rateEffect];
        
        //arrange the parts so that output from one is input to another
        [self.engine connect:self.player to:self.rateEffect format:self.file.processingFormat];
        [self.engine connect:self.rateEffect to:self.engine.mainMixerNode format:self.file.processingFormat];
        [self.engine prepare];
        [self.engine startAndReturnError:&engineError];
        
        [self setupAudioFileInformation];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self progressUpdate];
        });
   });
}

- (void)updaterPauseToggle {
    if (self.updater.isPaused) {
        if (!self.player.isPlaying) {
            [self.updater setPaused:YES];
        } else {
            [self.updater setPaused:NO];
        }
    } else if (!self.updater.isPaused) {
        [self.updater setPaused:YES];
    }
}

- (void)progressUpdate {
    self.currentFrame = [self playerCurrentFrame];
    self.currentPosition = self.currentFrame + self.seekFrame;
    self.currentPosition = MAX(self.currentPosition, 0);
    self.currentPosition = MIN(self.currentPosition, self.audioLengthSamples);
    
    [self.delegate progressUpdateWithCurrentPosition: self.currentPosition / self.audioLengthSamples];
    float time = self.currentPosition / self.audioSampleRate;
    [self.delegate countdownUpWithTime: [self formattedTimeWithTime:time]];
    [self.delegate countdownTimeWithTime:[self formattedTimeWithTime:self.audioLenghtSeconds - time]];
    
    if (self.currentPosition >= self.audioLengthSamples) {
        [self.updater setPaused:YES];
        [self.player stop];
        [self.delegate setUpdaterToPaused:YES];
        //[self disconnectVolumeTap];
    }
}

- (float)scaledPowerWithPower:(float)power {
    if (power < self.minDB) {
        return 0.0;
    } else if (power >= 1.0) {
        return 1.0;
    } else {
        return (fabs(self.minDB) - fabs(power)) / fabs(self.minDB);
    }
}

- (void)connectVolumeTap {
    AVAudioFormat *format = [self.engine.mainMixerNode outputFormatForBus:0];
    
    [self.engine.mainMixerNode installTapOnBus:0 bufferSize:1024 format:format block:^(AVAudioPCMBuffer * _Nonnull buffer, AVAudioTime * _Nonnull when) {
        float *const _Nonnull * _Nullable channelData = buffer.floatChannelData;
        
        float *dataChannel = *channelData;
        NSMutableArray<NSNumber *> *channelDataValue = [NSMutableArray arrayWithCapacity:(int)dataChannel];
        //memset(&nbr, 0, sizeof(buffer.stride));
        //id channelDataValue = nbr.pointerValue;
        
        NSMutableArray *channelDataValueArray = [NSMutableArray arrayWithCapacity:buffer.stride];
        int frameLenght = buffer.frameLength;
        
        for (int i = 0; i < frameLenght; i += buffer.stride) {
            NSNumber *integerI = [NSNumber numberWithInt:i];
            [channelDataValueArray addObject:integerI];
        }
        
        [channelDataValueArray enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            [channelDataValue addObject:obj];
        }];
        
        NSMutableArray<NSNumber *> *newChannelDataValueArray = [NSMutableArray new];
        [channelDataValueArray enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            NSNumber *number = obj;
            int multiplication = [number intValue] * [number intValue];
            [newChannelDataValueArray addObject:[NSNumber numberWithInt:multiplication]];
        }];
        
        double counter = 0.0;
        for (NSNumber *i in newChannelDataValueArray) {
            counter += [i doubleValue];
        }
        
        double rms = sqrt(counter / buffer.frameLength);
        
        double avgPower = 20 * log10(rms);
        
        double meterLevel = [self scaledPowerWithPower:avgPower];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate meterLevelWithLevel:meterLevel];
        });
    }];
}

- (void)disconnectVolumeTap {
    [self.engine.mainMixerNode removeTapOnBus:0];
    [self.delegate didDisconnectVolumeTap];
}

- (NSString *)formattedTimeWithTime:(float)time {
    int secs = ceil(time);
    int hours = 0;
    int mins = 0;
    int seconcsPerHour = 60 * 60;
    int secondsPerminute = 60;
    
    if (secs > seconcsPerHour) {
        hours = secs / seconcsPerHour;
        secs -= hours * secondsPerminute;
    }
    
    if (secs > secondsPerminute) {
        mins = secs / secondsPerminute;
        secs -= mins * seconcsPerHour;
    }
    
    NSMutableString *formattedString = [NSMutableString stringWithString:@""];
    if (hours > 0) {
        formattedString = [NSMutableString stringWithFormat:@"%02d", hours];
    }
    NSString *returnMinutes = [NSString stringWithFormat:@"%02d", mins];
    NSString *returnSeconds = [NSString stringWithFormat:@":%02d", secs];
    
    [formattedString appendString:returnMinutes];
    [formattedString appendString:returnSeconds];
    
    return formattedString;
}

- (void)setPlayOrPause {
    
    if (self.currentPosition >= self.audioLengthSamples) {
        [self progressUpdate];
    }
    
    if (self.player.isPlaying) {
        //[self disconnectVolumeTap];
        [self.updater setPaused:YES];
        [self.player pause];
    } else {
        [self.updater setPaused:NO];
        //[self connectVolumeTap];
        if (self.needsSchedule) {
            [self setNeedsSchedule:NO];
            [self scheduleAudioFile];
        }
        [self.player play];
    }
}

- (void)scheduleAudioFile {
    __weak AMAudioPlayer *weakSelf = self;
    [self.player scheduleFile:self.file atTime:nil completionHandler:^{
        weakSelf.needsSchedule = YES;
    }];
}


- (void)setupAudioFileInformation {
    self.audioLengthSamples = self.file.length;
    float sampleFloat = self.audioLengthSamples;
    double sampleRate = self.file.processingFormat.sampleRate;
    self.audioLenghtSeconds = sampleFloat / sampleRate;
}

- (void)stopPlayingAudio {
    [self.updater setPaused:YES];
    
    [self setCurrentPosition:0.0];
    [self setSeekFrame:0.0];
    
    float time = self.currentPosition / self.audioSampleRate;
    [self.delegate progressUpdateWithCurrentPosition:0.0];
    [self.delegate countdownUpWithTime: [self formattedTimeWithTime:time]];
    
    [self.player stop];
    
    [self setNeedsSchedule:NO];
    [self scheduleAudioFile];
}

- (void)seek:(float)time {
    self.seekFrame = self.currentPosition + time * self.audioSampleRate;
    self.seekFrame = MAX(self.seekFrame, 0);
    self.seekFrame = MIN(self.seekFrame, self.audioLengthSamples);
    self.currentPosition = self.seekFrame;
    
    [self.player stop];
    
    if (self.currentPosition < self.audioLengthSamples) {
        [self progressUpdate];
        
        float position =  self.currentPosition;
        [self.delegate progressUpdateWithCurrentPosition:position];
        self.needsSchedule = NO;
        
        unsigned int samples = (unsigned int)self.audioLengthSamples;
        unsigned int seek = (unsigned int)self.seekFrame;
        
        __weak AMAudioPlayer *weakSelf = self;
        [self.player scheduleSegment:self.file startingFrame:(self.seekFrame) frameCount:((AVAudioFrameCount)samples - seek) atTime:nil completionHandler:^{
            weakSelf.needsSchedule = YES;
        }];
        if (!self.updater.isPaused) {
            [self.player play];
        }
    }
}

- (void)updateProgress {
    self.currentPosition = self.currentFrame + self.seekFrame;
}

//MARK: - AVAudioPlayerDelegate

- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag {
    [self stopPlayingAudio];
}

- (void)audioPlayerDecodeErrorDidOccur:(AVAudioPlayer *)player error:(NSError *)error {
    NSLog(@"Erro CARAIO");
}

@end
