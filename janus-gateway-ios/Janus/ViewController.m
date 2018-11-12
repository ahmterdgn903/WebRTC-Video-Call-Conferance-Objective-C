
#import "ViewController.h"
#import "WebSocketChannel.h"
#import "WebRTC/WebRTC.h"
#import "RTCSessionDescription+JSON.h"
#import "JanusConnection.h"
@import WebRTC;


static NSString * const kARDMediaStreamId = @"ARDAMS";
static NSString * const kARDAudioTrackId = @"ARDAMSa0";
static NSString * const kARDVideoTrackId = @"ARDAMSv0";

@interface ViewController ()
@property (strong, nonatomic) RTCCameraPreviewView *localView;

@end

@implementation ViewController
WebSocketChannel *websocket;
NSMutableDictionary *peerConnectionDict;
RTCPeerConnection *publisherPeerConnection;
RTCVideoTrack *localTrack;
RTCAudioTrack *localAudioTrack;
CGSize screenSize;
//screenSize = [UIScreen mainScreen].bounds.size;

int height = 0;

@synthesize factory = _factory;
@synthesize localView = _localView;

- (void)viewDidLoad {
    [super viewDidLoad];

    screenSize = [UIScreen mainScreen].bounds.size;
    [_joinButtonO addTarget:self action:@selector(joinClicked:) forControlEvents:UIControlEventTouchUpInside];
    
//    _joinButtonO.center = CGPointMake(self.view.frame.size.width/2, self.view.frame.size.height/2); // not nececary
}
//+
//change, added joinButtonO and writed joinButtonO code
- (void) joinClicked:(UIButton*)button{
    self->_joinButtonO.hidden = YES;
//* change, moved in joinButtonO method
    _localView = [[RTCCameraPreviewView alloc] initWithFrame:CGRectMake(0, 0, 480, 360)];
    [self.view addSubview:_localView];
    
    NSURL *url = [[NSURL alloc] initWithString:@"ws://212.175.20.72:8188/janus"]; //changed: added hostname and port (with janus)
    websocket = [[WebSocketChannel alloc] initWithURL: url];
    websocket.delegate = self;
    
    peerConnectionDict = [NSMutableDictionary dictionary];
    _factory = [[RTCPeerConnectionFactory alloc] init];
    localTrack = [self createLocalVideoTrack];
    localAudioTrack = [self createLocalAudioTrack];
    //*
}
//+++
- (RTCEAGLVideoView *)createRemoteView {
    
    
    height += 180;
    RTCEAGLVideoView *remoteView = [[RTCEAGLVideoView alloc] initWithFrame:CGRectMake(0, height, 240, 180)];
    remoteView.delegate = self;
    [self.view addSubview:remoteView];
    return remoteView;
}
//+++
- (void)updateViews {
    
}
//+++
- (void)createPublisherPeerConnection {
    publisherPeerConnection = [self createPeerConnection];
    [self createAudioSender:publisherPeerConnection];
    [self createVideoSender:publisherPeerConnection];
}
//+++
- (RTCMediaConstraints *)defaultPeerConnectionConstraints {
    NSDictionary *mandatoryConstraints = @{
                                           @"OfferToReceiveAudio" : @"true",
                                           @"OfferToReceiveVideo" : @"true",
                                           };    //change: added mandatoryConstaraints(ff-t)/(tt-f)
    NSDictionary *optionalConstraints = @{ @"DtlsSrtpKeyAgreement" : @"true  " };
    RTCMediaConstraints* constraints = [[RTCMediaConstraints alloc] initWithMandatoryConstraints:mandatoryConstraints  optionalConstraints:optionalConstraints];//changed: "nil" to mandatoryConstraints
    return constraints;
}

//+++
// change, writed lastly stun and turn server
- (NSArray<RTCIceServer *> *)defaultSTUNServer {
    RTCIceServer* turn = [[RTCIceServer alloc] initWithURLStrings:@[@"turn:stun.liveswitch.fm:3478"] username:@"test" credential:@"pa55w0rd!"];
    RTCIceServer* stun = [[RTCIceServer alloc] initWithURLStrings:@[@"stun:stun.l.google.com:19302"] username:@"" credential:@""];
    return @[stun, turn];
}

//+++
- (RTCPeerConnection *)createPeerConnection {
    RTCMediaConstraints *constraints = [self defaultPeerConnectionConstraints];
    RTCConfiguration *config = [[RTCConfiguration alloc] init];
    NSArray *iceServers = [self defaultSTUNServer];
    config.iceServers = iceServers;
    config.iceTransportPolicy = RTCIceTransportPolicyRelay;
    RTCPeerConnection *peerConnection = [_factory peerConnectionWithConfiguration:config
                                         constraints:constraints
                                            delegate:self];
    return peerConnection;
}

- (void)offerPeerConnection: (NSNumber*) handleId {
    [self createPublisherPeerConnection];
    JanusConnection *jc = [[JanusConnection alloc] init];
    jc.connection = publisherPeerConnection;
    jc.handleId = handleId;
    peerConnectionDict[handleId] = jc;

    [publisherPeerConnection offerForConstraints:[self defaultOfferConstraints]
                       completionHandler:^(RTCSessionDescription *sdp,
                                           NSError *error) {
                           [publisherPeerConnection setLocalDescription:sdp completionHandler:^(NSError * _Nullable error) {
                               [websocket publisherCreateOffer: handleId sdp:sdp];
                           }];
                       }];
}

- (RTCMediaConstraints *)defaultMediaAudioConstraints {
    NSDictionary *mandatoryConstraints = @{ kRTCMediaConstraintsLevelControl : kRTCMediaConstraintsValueFalse };
    RTCMediaConstraints *constraints =
    [[RTCMediaConstraints alloc] initWithMandatoryConstraints:mandatoryConstraints
                                          optionalConstraints:nil];
    return constraints;
}
//change added answerConstraints
//-(RTCMediaConstraints *)answerConstraints
//{
//    NSDictionary *mandatoryConstraints = @{
//                                           @"OfferToReceiveAudio":@"true",
//                                           @"OfferToReceiveVideo":@"true"
//                                           };
//    RTCMediaConstraints *constraints = [[RTCMediaConstraints alloc]
//                                        initWithMandatoryConstraints:mandatoryConstraints
//                                        optionalConstraints:nil];
//    return constraints;
//}


- (RTCMediaConstraints *)defaultOfferConstraints {
    NSDictionary *mandatoryConstraints = @{
                                           @"OfferToReceiveAudio" : @"false",
                                           @"OfferToReceiveVideo" : @"false"
                                           };
    NSDictionary *optionalConstraints = @{ @"DtlsSrtpKeyAgreement" : @"true" };//changed: added optionalConstaints (ff-t)/(tt-f)

    RTCMediaConstraints* constraints = [[RTCMediaConstraints alloc] initWithMandatoryConstraints:mandatoryConstraints optionalConstraints:optionalConstraints];//changed: "nil" to "optionalconstraints"
    return constraints;
}

- (RTCAudioTrack *)createLocalAudioTrack {

    RTCMediaConstraints *constraints = [self defaultMediaAudioConstraints];
    RTCAudioSource *source = [_factory audioSourceWithConstraints:constraints];
    RTCAudioTrack *track = [_factory audioTrackWithSource:source trackId:kARDAudioTrackId];

    return track;
}

- (RTCRtpSender *)createAudioSender:(RTCPeerConnection *)peerConnection {
    RTCRtpSender *sender = [peerConnection senderWithKind:kRTCMediaStreamTrackKindAudio streamId:kARDMediaStreamId];
    if (localAudioTrack) {
        sender.track = localAudioTrack;
    }
    return sender;
}

- (RTCVideoTrack *)createLocalVideoTrack {
    RTCMediaConstraints *cameraConstraints = [[RTCMediaConstraints alloc]
                                              initWithMandatoryConstraints:[self currentMediaConstraint]
                                              optionalConstraints: nil];

    RTCAVFoundationVideoSource *source = [_factory avFoundationVideoSourceWithConstraints:cameraConstraints];
    RTCVideoTrack *localVideoTrack = [_factory videoTrackWithSource:source trackId:kARDVideoTrackId];
    _localView.captureSession = source.captureSession;

    return localVideoTrack;
}

- (RTCRtpSender *)createVideoSender:(RTCPeerConnection *)peerConnection {
    RTCRtpSender *sender = [peerConnection senderWithKind:kRTCMediaStreamTrackKindVideo
                                                 streamId:kARDMediaStreamId];
    if (localTrack) {
        sender.track = localTrack;
    }

    return sender;
}

- (nullable NSDictionary *)currentMediaConstraint {
    NSDictionary *mediaConstraintsDictionary = nil;

    NSString *widthConstraint = @"480";
    NSString *heightConstraint = @"360";
    NSString *frameRateConstrait = @"20";
    if (widthConstraint && heightConstraint) {
        mediaConstraintsDictionary = @{
                                       kRTCMediaConstraintsMinWidth : widthConstraint,
                                       kRTCMediaConstraintsMaxWidth : widthConstraint,
                                       kRTCMediaConstraintsMinHeight : heightConstraint,
                                       kRTCMediaConstraintsMaxHeight : heightConstraint,
                                       kRTCMediaConstraintsMaxFrameRate: frameRateConstrait,
                                       };
    }
    return mediaConstraintsDictionary;
}

- (void)videoView:(RTCEAGLVideoView *)videoView didChangeVideoSize:(CGSize)size {
    CGRect rect = videoView.frame;
    rect.size = size;
    NSLog(@"========didChangeVideiSize %fx%f", size.width, size.height);
    videoView.frame = rect;
}


- (void)peerConnection:(RTCPeerConnection *)peerConnection didAddStream:(RTCMediaStream *)stream {
    NSLog(@"=========didAddStream");
    JanusConnection *janusConnection;

    for (NSNumber *key in peerConnectionDict) {
        JanusConnection *jc = peerConnectionDict[key];
        if (peerConnection == jc.connection) {
            janusConnection = jc;
            break;
        }
    }

    dispatch_async(dispatch_get_main_queue(), ^{ //move to main thread
        if (stream.videoTracks.count) {
            RTCVideoTrack *remoteVideoTrack = stream.videoTracks[0];

            RTCEAGLVideoView *remoteView = [self createRemoteView];
            [remoteVideoTrack addRenderer:remoteView];
            janusConnection.videoTrack = remoteVideoTrack;
            janusConnection.videoView = remoteView;
        }
    });
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection didRemoveStream:(RTCMediaStream *)stream {
    NSLog(@"=========didRemoveStream");
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection didOpenDataChannel:(RTCDataChannel *)dataChannel {
    
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection didChangeSignalingState:(RTCSignalingState)stateChanged {
     //change: added NSLOG/switch
    //NSLog(@"⭕️didChangeSignalingState %ld", (long)stateChanged);
    switch (stateChanged) {
        case RTCSignalingStateStable:
            NSLog(@"⭕️didChangeSignalingState RTCSignalingStateStable");
            break;
        case RTCSignalingStateHaveLocalOffer:
            NSLog(@"⭕️didChangeSignalingState RTCSignalingStateHaveLocalOffer");
            break;
        case RTCSignalingStateHaveLocalPrAnswer:
            NSLog(@"⭕️didChangeSignalingState RTCSignalingStateHaveLocalPrAnswer");
            break;
        case RTCSignalingStateHaveRemoteOffer:
            NSLog(@"⭕️didChangeSignalingState RTCSignalingStateHaveRemoteOffer");
            break;
        case RTCSignalingStateHaveRemotePrAnswer:
            NSLog(@"⭕️didChangeSignalingState RTCSignalingStateHaveRemotePrAnswer");
            break;
        case RTCSignalingStateClosed:
            NSLog(@"⭕️didChangeSignalingState RTCSignalingStateClosed");
            break;
    }
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection didGenerateIceCandidate:(RTCIceCandidate *)candidate {
    NSLog(@"=========didGenerateIceCandidate==%@", candidate.sdp);

    NSNumber *handleId;
    for (NSNumber *key in peerConnectionDict) {
        JanusConnection *jc = peerConnectionDict[key];
        if (peerConnection == jc.connection) {
            handleId = jc.handleId;
            break;
        }
    }
    if (candidate != nil) {
        [websocket trickleCandidate:handleId candidate:candidate];
    } else {
        [websocket trickleCandidateComplete: handleId];
    }
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection didChangeIceGatheringState:(RTCIceGatheringState)newState {
     //change: added NSLOG/switch
    //NSLog(@"⭕️didChangeIceGatheringState %ld", (long)newState);
    switch (newState) {
        case RTCIceGatheringStateNew:
             NSLog(@"⭕️didChangeIceGatheringState RTCIceGatheringStateNew" );
            break;
        case RTCIceGatheringStateGathering:
             NSLog(@"⭕️didChangeIceGatheringState RTCIceGatheringStateGathering");
            break;
        case RTCIceGatheringStateComplete:
             NSLog(@"⭕️didChangeIceGatheringState RTCIceGatheringStateComplete");
            break;
    }
}

- (void)peerConnectionShouldNegotiate:(RTCPeerConnection *)peerConnection {

}

- (void)peerConnection:(RTCPeerConnection *)peerConnection didChangeIceConnectionState:(RTCIceConnectionState)newState {
    //change: added NSLOG/switch
    //NSLog(@"⭕️didChangeIceConnectionState %ld", (long)newState);

    switch (newState) {
        case RTCIceConnectionStateNew:
            NSLog(@"⭕️didChangeIceConnectionState RTCIceConnectionStateNew");
            break;
        case RTCIceConnectionStateChecking:
            NSLog(@"⭕️didChangeIceConnectionState RTCIceConnectionStateChecking");
            break;
        case RTCIceConnectionStateConnected:
           NSLog(@"⭕️didChangeIceConnectionState RTCIceConnectionStateConnected");
            break;
        case RTCIceConnectionStateCompleted:
            NSLog(@"⭕️didChangeIceConnectionState RTCIceConnectionStateCompleted");
            break;
        case RTCIceConnectionStateFailed:
            NSLog(@"⭕️didChangeIceConnectionState RTCIceConnectionStateFailed");
            break;
        case RTCIceConnectionStateDisconnected:
            NSLog(@"⭕️didChangeIceConnectionState RTCIceConnectionStateDisconnected");
            break;
        case RTCIceConnectionStateClosed:
            NSLog(@"⭕️didChangeIceConnectionState RTCIceConnectionStateClosed");
            break;
        case RTCIceConnectionStateCount:
            NSLog(@"⭕️didChangeIceConnectionState RTCIceConnectionStateCount");
            break;
    }
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection didRemoveIceCandidates:(NSArray<RTCIceCandidate *> *)candidates {
    NSLog(@"=========didRemoveIceCandidates");
}


// mark: delegate

- (void)onPublisherJoined: (NSNumber*) handleId {
    [self offerPeerConnection:handleId];
}

- (void)onPublisherRemoteJsep:(NSNumber *)handleId dict:(NSDictionary *)jsep {
    JanusConnection *jc = peerConnectionDict[handleId];
    RTCSessionDescription *answerDescription = [RTCSessionDescription descriptionFromJSONDictionary:jsep];
    [jc.connection setRemoteDescription:answerDescription completionHandler:^(NSError * _Nullable error) {
    }];
}

- (void)subscriberHandleRemoteJsep: (NSNumber *)handleId dict:(NSDictionary *)jsep {
    RTCPeerConnection *peerConnection = [self createPeerConnection];

    JanusConnection *jc = [[JanusConnection alloc] init];
    jc.connection = peerConnection;
    jc.handleId = handleId;
    peerConnectionDict[handleId] = jc;

    RTCSessionDescription *answerDescription = [RTCSessionDescription descriptionFromJSONDictionary:jsep];
    [peerConnection setRemoteDescription:answerDescription completionHandler:^(NSError * _Nullable error) {
    }];
    NSDictionary *mandatoryConstraints = @{
                                           @"OfferToReceiveAudio" : @"true",
                                           @"OfferToReceiveVideo" : @"true",
                                           };
    NSDictionary *optionalConstraints = @{ @"DtlsSrtpKeyAgreement" : @"true" };//changed: added optionalconstraints (ff-t)/(tt-f)
    RTCMediaConstraints* constraints = [[RTCMediaConstraints alloc] initWithMandatoryConstraints:mandatoryConstraints optionalConstraints:optionalConstraints];//changed: "nil" to "optionalconstraints"

    [peerConnection answerForConstraints:constraints completionHandler:^(RTCSessionDescription * _Nullable sdp, NSError * _Nullable error) {
        [peerConnection setLocalDescription:sdp completionHandler:^(NSError * _Nullable error) {
        }];
        [websocket subscriberCreateAnswer:handleId sdp:sdp]; // change, commanded
    }];

}

- (void)onLeaving:(NSNumber *)handleId {
    JanusConnection *jc = peerConnectionDict[handleId];
    [jc.connection close];
    jc.connection = nil;
    RTCVideoTrack *videoTrack = jc.videoTrack;
    [videoTrack removeRenderer: jc.videoView];
    videoTrack = nil;
    [jc.videoView renderFrame:nil];
    [jc.videoView removeFromSuperview];

    [peerConnectionDict removeObjectForKey:handleId];
}

@end
