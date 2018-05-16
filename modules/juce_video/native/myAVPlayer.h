// this subclass disables the scroll wheel from causing the video to ff/rewind

@interface MyAVPlayerView : AVPlayerView
@end

@implementation MyAVPlayerView

- (NSView *)hitTest:(NSPoint)aPoint
{
    return nil;
}

@end
