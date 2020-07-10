//
//  MyClass.m
//  
//
//  Created by Gabriel Soria Souza on 04/07/20.
//

#import "AMStereoRecorder.h"

@implementation AMStereoRecorder

@synthesize recordingOptions = _recordingOptions;

- (NSMutableArray *)recordingOptions {
    NSString *front = AVAudioSessionOrientationFront;
    NSString *back = AVAudioSessionOrientationBack;
    NSString *bottom = AVAudioSessionOrientationBottom;
    
    AVAudioSession *session = [AVAudioSession sharedInstance];
    NSArray<AVAudioSessionDataSourceDescription *> *dataSources = session.preferredInput.dataSources;
    
    self.recordingOptions = [[NSMutableArray alloc] init];
    for (AVAudioSessionDataSourceDescription *i in dataSources) {
        if (i.dataSourceName == front) {
            RecordingOption OptionOne;
            OptionOne.name = @"Front Stereo";
            OptionOne.dataSourceName = front;
            NSValue *optionOne = [NSValue valueWithRecordingOption:OptionOne];
            [self.recordingOptions arrayByAddingObject:optionOne];
        } else if (i.dataSourceName == back) {
            RecordingOption OptionTwo;
            OptionTwo.name = @"Back Stereo";
            OptionTwo.dataSourceName = back;
            NSValue *optionTwo = [NSValue valueWithRecordingOption:OptionTwo];
            [self.recordingOptions arrayByAddingObject:optionTwo];
        } else if (i.dataSourceName == bottom) {
            RecordingOption OptionThree;
            OptionThree.name = @"Mono";
            OptionThree.dataSourceName = bottom;
            NSValue *optionThree = [NSValue valueWithRecordingOption:OptionThree];
            [self.recordingOptions arrayByAddingObject:optionThree];
        }
    }
    
    [self.recordingOptions sortUsingSelector:@selector(compare:)];
    return self.recordingOptions;
}

- (void)setupRecorder {
    NSURL *tempDirectory = [NSURL fileURLWithPath:NSTemporaryDirectory()];
    NSURL *fileURL = [tempDirectory URLByAppendingPathComponent:@"recording.wav"];
    
    NSDictionary *settings = @{
        AVFormatIDKey: [NSNumber numberWithInt:kAudioFormatLinearPCM],
        AVLinearPCMIsNonInterleaved: @NO,
        AVSampleRateKey: @44100.0,
        AVNumberOfChannelsKey: @2,
        AVLinearPCMBitDepthKey: @16
    };
    NSError *recorderError;
    self.recorder = [[AVAudioRecorder alloc] initWithURL:fileURL settings:settings error:&recorderError];
    
    if (recorderError == nil) {
        self.recorder.delegate = self;
        [self.recorder setMeteringEnabled:YES];
        [self.recorder prepareToRecord];
        return;
    }
    [self.delegate didReceiveAnErrorWhenPreparing:recorderError];
}

- (BOOL)record {
    BOOL started = [self.recorder record];
    self.state = AudioControllerStateRecording;
    return started;
}

- (void)stopRecording {
    [self.recorder stop];
    self.state = AudioControllerStateStopped;
}

- (void)audioRecorderDidFinishRecording:(AVAudioRecorder *)recorder successfully:(BOOL)flag {
    [self.delegate didFinishRecordingWithFileURL:recorder.url];
}

- (void)enableBuiltInMicrophone {
    AVAudioSession *session = [AVAudioSession sharedInstance];
    NSArray<AVAudioSessionPortDescription *> *availableInputs = session.availableInputs;
    AVAudioSessionPortDescription *builtInMicInput;
    for (AVAudioSessionPortDescription *i in availableInputs) {
        if (i.portType == AVAudioSessionPortBuiltInMic) {
            builtInMicInput = i;
            break;
        }
    }
    NSError *sessionError;
    [session setPreferredInput:builtInMicInput error:&sessionError];
}

- (AMStereoLayout)stereoLayoutOrientation:(AVAudioSessionOrientation)orientation stereoOrientation:(AVAudioStereoOrientation)stereoOrientation {
    
    if (orientation == AVAudioSessionOrientationFront && stereoOrientation == AVAudioStereoOrientationNone) {
        return MonoLayout;
    } else if (orientation == AVAudioSessionOrientationFront && stereoOrientation == AVAudioStereoOrientationLandscapeLeft) {
        return FrontLandscapeLeftLayout;
    } else if (orientation == AVAudioSessionOrientationFront && stereoOrientation == AVAudioStereoOrientationLandscapeRight) {
        return FrontLandspaceRightLayout;
    } else if (orientation == AVAudioSessionOrientationFront && stereoOrientation == AVAudioStereoOrientationPortrait) {
        return FrontPortraitLayout;
    } else if (orientation == AVAudioSessionOrientationFront && stereoOrientation == AVCaptureVideoOrientationPortraitUpsideDown) {
        return FrontPortraitUpsideDownLayout;
    } else if (orientation == AVAudioSessionOrientationBack && stereoOrientation == AVAudioStereoOrientationNone) {
        return MonoLayout;
    } else if (orientation == AVAudioSessionOrientationBack && stereoOrientation == AVAudioStereoOrientationLandscapeLeft) {
        return BackLandscapeLeftLayout;
    } else if (orientation == AVAudioSessionOrientationBack && stereoOrientation == AVAudioStereoOrientationLandscapeRight) {
        return BackLandscapeRightLayout;
    } else if (orientation == AVAudioSessionOrientationBack && stereoOrientation == AVAudioStereoOrientationPortrait) {
        return BackPortraitLayout;
    } else if (orientation == AVAudioSessionOrientationBack && stereoOrientation == AVCaptureVideoOrientationPortraitUpsideDown) {
        return BackPortraitUpsideDownLayout;
    } else {
        return NoneLayout;
    }
}

- (void)selectRecordingOption:(RecordingOption)option
            deviceOrientation:(AMStereoRecorderOrientation)orientation completion:(void(^)(AMStereoLayout))completion {
    AVAudioSession *session = [AVAudioSession sharedInstance];
    
    AVAudioSessionPortDescription *preferredInput = session.preferredInput;
    NSArray<AVAudioSessionDataSourceDescription *> *dataSources = preferredInput.dataSources;
    AVAudioSessionDataSourceDescription *source;
    
    for (AVAudioSessionDataSourceDescription *i in dataSources) {
        if (i.dataSourceName == option.dataSourceName) {
            source = i;
            break;
        }
    }
    
    NSArray<AVAudioSessionPolarPattern> *supportedPolarPatterns = source.supportedPolarPatterns;
    
    if (supportedPolarPatterns == nil) {
        completion(NoneLayout);
    }
    
    NSError *preferredPolarPatternError;
    if (@available(iOS 14.0, *)) {
        [source setPreferredPolarPattern:AVAudioSessionPolarPatternStereo error:&preferredPolarPatternError];
    } else {
        [source setPreferredPolarPattern:AVAudioSessionPolarPatternOmnidirectional error:&preferredPolarPatternError];
    }
    
    
    
}


@end
