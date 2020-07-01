//
//  AudioPlayer.m
//  AudioKit
//
//  Created by Gabriel Soria Souza on 20/06/20.
//  Copyright © 2020 Gabriel Sória Souza. All rights reserved.
//

#import "AudioKitAudioPlayer.h"

@interface AudioKitAudioPlayer()

@property BOOL needsSchedule;
@property (nonatomic) AVAudioFramePosition currentPosition;
@property AVAudioFramePosition currentFrame;
@property AVAudioFramePosition seekFrame;
@property float audioSampleRate;
@property float minDB;

- (void)scheduleAudioFile;

@end

@implementation AudioKitAudioPlayer

@synthesize file = _file;

- (void)setFile:(AVAudioFile *)file {
    _file = file;
    self.audioLengthSamples = file.length;
    self.format = file.processingFormat;
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
        self.currentPosition = 0;
        self.audioSampleRate = 0;
        self.seekFrame = 0;
        self.minDB = -80.0;
        [self setNeedsSchedule:YES];
        [self audioFileSetup:url];
    }
    return self;
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
    
    NSString *formattedString = [NSString new];
    if (hours > 0) {
        formattedString = [NSString stringWithFormat:@"%02d", hours];
    }
    NSString *returnMinutes = [NSString stringWithFormat:@"%02d", mins];
    NSString *returnSeconds = [NSString stringWithFormat:@": %02d", secs];
    
    [formattedString stringByAppendingString:returnMinutes];
    [formattedString stringByAppendingString:returnSeconds];
    
    return formattedString;
}

- (void)setPlayOrPause {
    float position = [[NSNumber numberWithInt:(int)self.currentPosition] floatValue];
    
    if ( position >= self.audioLengthSamples) {
        [self progressUpdate];
    }
    
    if (self.player.isPlaying) {
        //[self disconnectVolumeTap];
        [self.delegate setUpdaterToPaused:YES];
        [self.player pause];
    } else {
        [self.delegate setUpdaterToPaused:NO];
        //[self connectVolumeTap];
        if (self.needsSchedule) {
            [self setNeedsSchedule:NO];
            [self scheduleAudioFile];
        }
        [self.player play];
    }
}

- (void)scheduleAudioFile {
    __weak AudioKitAudioPlayer *weakSelf = self;
    [self.player scheduleFile:self.file atTime:nil completionHandler:^{
        weakSelf.needsSchedule = YES;
    }];
}

- (void)audioFileSetup:(NSURL *)url {
    NSError *engineError;
    NSError *fileError;
    
    [self setFileURL:url];
    
    self.file = [[AVAudioFile alloc] initForReading:self.fileURL error:&fileError];
    self.player = [[AVAudioPlayerNode alloc] init];
    self.engine = [[AVAudioEngine alloc] init];
    self.speedControl = [[AVAudioUnitVarispeed alloc]init];
    self.pitchControl = [[AVAudioUnitTimePitch alloc]init];
    
    [self.engine attachNode:self.player];
    [self.engine attachNode:self.speedControl];
    [self.engine attachNode:self.pitchControl];
    
    //arrange the parts so that output from one is input to another
    [self.engine connect:self.player to:self.speedControl format:self.file.processingFormat];
    [self.engine connect:self.speedControl to:self.pitchControl format:self.file.processingFormat];
    [self.engine connect:self.pitchControl to:self.engine.mainMixerNode format:self.file.processingFormat];
    [self.engine prepare];
    [self.engine startAndReturnError:&engineError];
    
    [self setupAudioFileInformation];
}

- (void)setupAudioFileInformation {
    self.audioLengthSamples = self.file.length;
    float sampleFloat = self.audioLengthSamples;
    double sampleRate = self.file.processingFormat.sampleRate;
    self.audioLenghtSeconds = sampleFloat / sampleRate;
    
}

- (void)stopPlayingAudio {
    [self.player stop];
}

- (BOOL)isPlaying {
    return self.player.isPlaying;
}

- (void)seek:(float)time {
    self.seekFrame = self.currentPosition + (AVAudioFramePosition)time * self.audioSampleRate;
    self.seekFrame = MAX(self.seekFrame, 0);
    self.seekFrame = MIN(self.seekFrame, self.audioLengthSamples);
    self.currentPosition = self.seekFrame;
    
    [self.player stop];
    
    if (self.currentPosition < self.audioLengthSamples) {
        [self progressUpdate];
        
        float position = self.currentPosition;
        [self.delegate progressUpdateWithCurrentPosition:position];
        self.needsSchedule = NO;
        
        unsigned int samples = (unsigned int)self.audioLengthSamples;
        unsigned int seek = (unsigned int)self.seekFrame;
        
        __weak AudioKitAudioPlayer *weakSelf = self;
        [self.player scheduleSegment:self.file startingFrame:(self.seekFrame) frameCount:((AVAudioFrameCount)samples - seek) atTime:nil completionHandler:^{
            weakSelf.needsSchedule = YES;
        }];
        [self.delegate setUpdaterToPaused:NO];
        if (!self.player.isPlaying) {
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
