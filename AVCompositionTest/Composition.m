
@import UIKit;
@import AVFoundation;
@import MediaPlayer;

#import "Composition.h"

@interface Composition ()
@property (nonatomic, copy) void (^handler)(NSURL *url);
@end


@implementation Composition

- (void)create:(void (^)(NSURL *url))handler
{
    self.handler = handler;
    
    /////////////////////////////////////////////////////////////////////////////
    // 手順1
    
    // Compositionを生成
    AVMutableComposition *mutableComposition = [AVMutableComposition composition];
    
    /////////////////////////////////////////////////////////////////////////////
    // 手順2
    
    // AVAssetをURLから取得
    AVURLAsset *videoAsset1 = [[AVURLAsset alloc] initWithURL:self.movieFile1 options:nil];
    AVURLAsset *videoAsset2 = [[AVURLAsset alloc] initWithURL:self.movieFile2 options:nil];
    
    // アセットから動画・音声トラックをそれぞれ取得
    AVAssetTrack *videoAssetTrack1 = [videoAsset1 tracksWithMediaType:AVMediaTypeVideo][0];
    AVAssetTrack *audioAssetTrack1 = [videoAsset1 tracksWithMediaType:AVMediaTypeAudio][0];
    
    AVAssetTrack *videoAssetTrack2 = [videoAsset2 tracksWithMediaType:AVMediaTypeVideo][0];
    AVAssetTrack *audioAssetTrack2 = [videoAsset2 tracksWithMediaType:AVMediaTypeAudio][0];
    
    /////////////////////////////////////////////////////////////////////////////
    // 手順3
    
    // 動画合成用の`AVMutableCompositionTrack`を生成
    AVMutableCompositionTrack *compositionVideoTrack = [mutableComposition addMutableTrackWithMediaType:AVMediaTypeVideo
                                                                                       preferredTrackID:kCMPersistentTrackID_Invalid];
    // 音声合成用の`AVMutableCompositionTrack`を生成
    AVMutableCompositionTrack *compositionAudioTrack = [mutableComposition addMutableTrackWithMediaType:AVMediaTypeAudio
                                                                                       preferredTrackID:kCMPersistentTrackID_Invalid];
    
    /////////////////////////////////////////////////////////////////////////////
    // 手順4
    
    // ひとつめの動画をトラックに追加
    // `videoAssetTrack1`の動画の長さ分を`kCMTimeZero`の位置に挿入
    [compositionVideoTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, videoAssetTrack1.timeRange.duration)
                                   ofTrack:videoAssetTrack1
                                    atTime:kCMTimeZero
                                     error:nil];
    // ひとつめの音声をトラックに追加
    [compositionAudioTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, audioAssetTrack1.timeRange.duration)
                                   ofTrack:audioAssetTrack1
                                    atTime:kCMTimeZero
                                     error:nil];
    
    // ふたつめの動画を追加
    // `videoAssetTrack2`の動画の長さ分を`videoAssetTrack1`の終了時間の後ろに挿入
    [compositionVideoTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, videoAssetTrack2.timeRange.duration)
                                   ofTrack:videoAssetTrack2
                                    atTime:videoAssetTrack1.timeRange.duration
                                     error:nil];
    // ふたつめの音声を追加
    [compositionAudioTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, audioAssetTrack2.timeRange.duration)
                                   ofTrack:audioAssetTrack2
                                    atTime:audioAssetTrack1.timeRange.duration
                                     error:nil];
    
    /////////////////////////////////////////////////////////////////////////////
    // 手順5
    
    // Video1の合成命令用オブジェクトを生成
    AVMutableVideoCompositionInstruction *mutableVideoCompositionInstruction1 = [AVMutableVideoCompositionInstruction videoCompositionInstruction];
    mutableVideoCompositionInstruction1.timeRange = CMTimeRangeMake(kCMTimeZero,
                                                                    videoAssetTrack1.timeRange.duration);
    mutableVideoCompositionInstruction1.backgroundColor = UIColor.redColor.CGColor;
    
    // Video1のレイヤーの合成命令を生成
    AVMutableVideoCompositionLayerInstruction *videoLayerInstruction1;
    videoLayerInstruction1= [AVMutableVideoCompositionLayerInstruction videoCompositionLayerInstructionWithAssetTrack:compositionVideoTrack];
    mutableVideoCompositionInstruction1.layerInstructions = @[videoLayerInstruction1];
    
    // Video2の合成命令用オブジェクトを生成
    AVMutableVideoCompositionInstruction *mutableVideoCompositionInstruction2 = [AVMutableVideoCompositionInstruction videoCompositionInstruction];
    mutableVideoCompositionInstruction2.timeRange = CMTimeRangeMake(videoAssetTrack1.timeRange.duration,
                                                                    CMTimeAdd(videoAssetTrack1.timeRange.duration, videoAssetTrack2.timeRange.duration));
    mutableVideoCompositionInstruction2.backgroundColor = UIColor.blueColor.CGColor;
    
    // Video2のレイヤーの合成命令を生成
    AVMutableVideoCompositionLayerInstruction *videoLayerInstruction2;
    videoLayerInstruction2= [AVMutableVideoCompositionLayerInstruction videoCompositionLayerInstructionWithAssetTrack:compositionVideoTrack];
    mutableVideoCompositionInstruction2.layerInstructions = @[videoLayerInstruction2];
    
    /////////////////////////////////////////////////////////////////////////////
    // 手順6
    
    // AVMutableVideoCompositionを生成
    AVMutableVideoComposition *mutableVideoComposition = [AVMutableVideoComposition videoComposition];
    mutableVideoComposition.instructions = @[mutableVideoCompositionInstruction1, mutableVideoCompositionInstruction2];
    
    /////////////////////////////////////////////////////////////////////////////
    // 手順7
    
    // Audioの合成パラメータオブジェクトを生成
    AVMutableAudioMixInputParameters *audioMixInputParameters;
    audioMixInputParameters = [AVMutableAudioMixInputParameters audioMixInputParametersWithTrack:compositionAudioTrack];
    [audioMixInputParameters setVolumeRampFromStartVolume:1.0
                                              toEndVolume:1.0
                                                timeRange:CMTimeRangeMake(kCMTimeZero, mutableComposition.duration)];
    
    /////////////////////////////////////////////////////////////////////////////
    // 手順8
    
    // AVMutableAudioMixを生成
    AVMutableAudioMix *mutableAudioMix = [AVMutableAudioMix audioMix];
    mutableAudioMix.inputParameters = @[audioMixInputParameters];
    
    /////////////////////////////////////////////////////////////////////////////
    // 手順9
    
    // 動画の回転情報を取得する
    CGAffineTransform transform1 = videoAssetTrack1.preferredTransform;
    BOOL isVideoAssetPortrait = ( transform1.a == 0 &&
                                  transform1.d == 0 &&
                                 (transform1.b == 1.0 || transform1.b == -1.0) &&
                                 (transform1.c == 1.0 || transform1.c == -1.0));
    
    /////////////////////////////////////////////////////////////////////////////
    // 手順10
    
    CGSize naturalSize1 = CGSizeZero;
    CGSize naturalSize2 = CGSizeZero;
    if (isVideoAssetPortrait) {
        naturalSize1 = CGSizeMake(videoAssetTrack1.naturalSize.height, videoAssetTrack1.naturalSize.width);
        naturalSize2 = CGSizeMake(videoAssetTrack2.naturalSize.height, videoAssetTrack2.naturalSize.width);
    }
    else {
        naturalSize1 = videoAssetTrack1.naturalSize;
        naturalSize2 = videoAssetTrack2.naturalSize;
    }
    
    CGFloat renderWidth  = MAX(naturalSize1.width, naturalSize2.width);
    CGFloat renderHeight = MAX(naturalSize1.height, naturalSize2.height);
    
    /////////////////////////////////////////////////////////////////////////////
    // 手順11
    
    // 書き出す動画のサイズ設定
    mutableVideoComposition.renderSize = CGSizeMake(renderWidth, renderHeight);
    
    // 書き出す動画のフレームレート（30FPS）
    mutableVideoComposition.frameDuration = CMTimeMake(1, 30);
    
    /////////////////////////////////////////////////////////////////////////////
    // 手順12
    
    // AVMutableCompositionを元にExporterの生成
    AVAssetExportSession *assetExportSession = [[AVAssetExportSession alloc] initWithAsset:mutableComposition
                                                                                presetName:AVAssetExportPreset1280x720];
    // 動画合成用のオブジェクトを指定
    assetExportSession.videoComposition = mutableVideoComposition;
    assetExportSession.audioMix         = mutableAudioMix;
    
    // エクスポートファイルの設定
    NSString *composedMovieDirectory = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES)[0];
    NSString *composedMoviePath      = [NSString stringWithFormat:@"%@/%@", composedMovieDirectory, @"test.mp4"];
    
    // すでに合成動画が存在していたら消す
    NSFileManager *fileManager = NSFileManager.defaultManager;
    if ([fileManager fileExistsAtPath:composedMoviePath]) {
        [fileManager removeItemAtPath:composedMoviePath error:nil];
    }
    
    // 保存設定
    NSURL *composedMovieUrl = [NSURL fileURLWithPath:composedMoviePath];
    assetExportSession.outputFileType              = AVFileTypeQuickTimeMovie;
    assetExportSession.outputURL                   = composedMovieUrl;
    assetExportSession.shouldOptimizeForNetworkUse = YES;
    
    // 動画をExport
    [assetExportSession exportAsynchronouslyWithCompletionHandler:^{
        switch (assetExportSession.status) {
            case AVAssetExportSessionStatusFailed: {
                NSLog(@"生成失敗");
                break;
            }
            case AVAssetExportSessionStatusCancelled: {
                NSLog(@"生成キャンセル");
                break;
            }
            default: {
                NSLog(@"生成完了");
                if (self.handler) {
                    self.handler(composedMovieUrl);
                }
                break;
            }
        }
    }];
}


/**
 *  合成するひとつめの動画ファイル
 */
- (NSURL *)movieFile1
{
    NSBundle *bundle = NSBundle.mainBundle;
    NSString *path   = [bundle pathForResource:@"URLHookmark" ofType:@"mp4"];
    NSURL *url       = [NSURL fileURLWithPath:path];
    return url;
}


/**
 *  合成するふたつめの動画ファイル
 */
- (NSURL *)movieFile2
{
    NSBundle *bundle = NSBundle.mainBundle;
    NSString *path   = [bundle pathForResource:@"FurShader" ofType:@"mp4"];
    NSURL *url       = [NSURL fileURLWithPath:path];
    return url;
}

@end


