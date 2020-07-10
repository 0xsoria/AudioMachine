//
//  MyClass.h
//  
//
//  Created by Gabriel Soria Souza on 04/07/20.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, AMStereoRecorderOrientation) {
    UnknownOrientation,
    PortraitOrientation,
    PortraitUpsideDownOrientation,
    LandscapeLeftOrientation,
    LasdscapeRightOrientation
};

typedef NS_ENUM(NSInteger, AudioControllerState) {
    AudioControllerStateStopped,
    AudioControllerStatePlaying,
    AudioControllerStateRecording
};

typedef NS_ENUM(NSInteger, AMStereoLayout) {
    NoneLayout,
    MonoLayout,
    FrontLandscapeLeftLayout,
    FrontLandspaceRightLayout,
    FrontPortraitLayout,
    FrontPortraitUpsideDownLayout,
    BackLandscapeLeftLayout,
    BackLandscapeRightLayout,
    BackPortraitLayout,
    BackPortraitUpsideDownLayout
};

@protocol AMStereoRecorderDelegate <NSObject>
- (void)didFinishRecordingWithFileURL:(NSURL *)url;
- (void)didReceiveAnErrorWhenPreparing:(NSError *)error;

@end

typedef struct {
    NSString *name;
    NSString *dataSourceName;
}RecordingOption;

@interface NSValue (RecordingOption)
+ (instancetype)valueWithRecordingOption:(RecordingOption)option;
@property (readonly) RecordingOption recordingOption;
@end

@implementation NSValue (RecordingOption)

+ (instancetype)valueWithRecordingOption:(RecordingOption)option {
    
    return [self valueWithBytes:&option objCType:@encode(RecordingOption)];
}

- (RecordingOption) recordingOption; {
    RecordingOption option;
    [self getValue: &option];
    return option;
}

@end

@interface AMStereoRecorder : NSObject <AVAudioRecorderDelegate>

@property AVAudioRecorder *recorder;
@property (weak) id <AMStereoRecorderDelegate> delegate;
@property AudioControllerState state;
@property AMStereoRecorderOrientation recordOrientation;
@property (nonatomic) NSMutableArray *recordingOptions;

- (void)setupRecorder;

@end

NS_ASSUME_NONNULL_END
