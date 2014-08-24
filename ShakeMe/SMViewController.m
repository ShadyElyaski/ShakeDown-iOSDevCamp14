//
//  SMViewController.m
//  ShakeMe
//
//  Created by Shady A. Elyaski on 8/23/14.
//  Copyright (c) 2014 Elyaski. All rights reserved.
//

#import "SMViewController.h"
#import <AudioToolbox/AudioServices.h>
#import "NSTimer+BlocksKit.h"
#import "SoundManager.h"

@interface SMViewController (){
    BOOL hasVibrated, hasVibrated2;
    BOOL isHomeDevice;
    double curScore;
    double MAX_SCORE;
    int homeCount, awayCount;
    BOOL isPlaying;
}

#define CUR_MAX_SCORE (MAX_SCORE*(MIN(homeCount, awayCount)==0?1:MIN(homeCount, awayCount)))

@property (weak, nonatomic) IBOutlet UISegmentedControl *segmentCntl;
@property (weak, nonatomic) IBOutlet UILabel *countLbl;
@property (weak, nonatomic) IBOutlet UIView *opponentView;
@property(strong) CMMotionManager *motionManager;
@property(strong) CMAccelerometerData* lastAcceleration;
@property(strong) NSTimer *simTimer;
@property (weak, nonatomic) IBOutlet UIButton *playBtn;
@property(strong) Firebase *myRootRef, *startRef, *oppRef, *winnerRef;
@end

@implementation SMViewController
@synthesize motionManager, lastAcceleration, simTimer, myRootRef, oppRef, homeRef, startRef, winnerRef;

- (IBAction)segChanged:(UISegmentedControl *)sender {
    NSString *counterToInc = isHomeDevice?@"homeCount":@"awayCount";
    
    [homeRef updateChildValues:@{counterToInc: [NSNumber numberWithInt:isHomeDevice?--homeCount:--awayCount]} withCompletionBlock:^(NSError *error, Firebase *ref) {
        //        [homeRef removeAllObservers];
        //        [self updateCountLbl];
        isHomeDevice=sender.selectedSegmentIndex==0;
        [self startSocket];
    }];
    
}

-(void)updateCountLbl{
    [_countLbl setText:[NSString stringWithFormat:@"%d vs %d", homeCount, awayCount]];
}

-(void)startGame{
    curScore = CUR_MAX_SCORE/2;
    [self updateView];
    [_playBtn setHidden:YES];
    [_segmentCntl setHidden:YES];
    
    UILabel *lbl = [[UILabel alloc] initWithFrame:self.view.frame];
    
    [lbl setBackgroundColor:[UIColor clearColor]];
    [lbl setTextColor:[UIColor whiteColor]];
    [lbl setFont:[UIFont systemFontOfSize:50]];
    [lbl setTextAlignment:NSTextAlignmentCenter];
    [lbl setTag:5544];
    [lbl setText:@"3"];
    [self.view addSubview:lbl];
    
    [[SoundManager sharedManager] playSound:@"Bananas.aiff"];
    
    [NSTimer bk_scheduledTimerWithTimeInterval:.8 block:^(NSTimer *timer) {
        [lbl setText:@"2"];
        [NSTimer bk_scheduledTimerWithTimeInterval:1. block:^(NSTimer *timer) {
            [lbl setText:@"1"];
            [NSTimer bk_scheduledTimerWithTimeInterval:1.8 block:^(NSTimer *timer) {
                [lbl setText:@"GO Bananas!"];
                [NSTimer bk_scheduledTimerWithTimeInterval:1. block:^(NSTimer *timer) {
                    [lbl setAlpha:0];
                    [[SoundManager sharedManager] playSound:@"Celebration.m4a" looping:YES fadeIn:YES];
                    [self startDeviceMotion];
                } repeats:NO];
            } repeats:NO];
        } repeats:NO];
    } repeats:NO];
}

- (IBAction)playBtnPressed:(id)sender {
    if (homeCount>0&&awayCount>0){//&&homeCount==awayCount) {
        [startRef observeSingleEventOfType:FEventTypeValue withBlock:^(FDataSnapshot *snapshot) {
            if (!snapshot.value || ![snapshot.value isKindOfClass:[NSNumber class]] || ![snapshot.value boolValue]) {
                __block SMViewController *strongSelf = self;
                [startRef setValue:[NSNumber numberWithBool:YES] withCompletionBlock:^(NSError *error, Firebase *ref) {
                    [strongSelf startGame];
                }];
            }else{
                [[[UIAlertView alloc] initWithTitle:@"Error" message:@"Game already running" delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles: nil] show];
            }
        }];
    }
}

-(void)startSimTimer{
    simTimer = [NSTimer bk_scheduledTimerWithTimeInterval:.1 block:^(NSTimer *timer) {
        if(self.opponentView.frame.size.height<[UIScreen mainScreen].bounds.size.height){
            [UIView animateWithDuration:.2 animations:^{
                curScore-=10;
            }];
            [self checkStatus];
        }
    } repeats:YES];
}

- (void)startDeviceMotion {
    
    // Create a CMMotionManager
    
    isPlaying = YES;
    
    motionManager = [[CMMotionManager alloc] init];
    
    motionManager.accelerometerUpdateInterval = 1.0 / 30.0;
    
    // Attitude that is referenced to true north
    [motionManager startAccelerometerUpdatesToQueue:[NSOperationQueue mainQueue] withHandler:^(CMAccelerometerData *accelerometerData, NSError *error) {
        
        if(self.lastAcceleration){
            double
            deltaX = fabs(lastAcceleration.acceleration.x - accelerometerData.acceleration.x),
            deltaY = fabs(lastAcceleration.acceleration.y - accelerometerData.acceleration.y),
            deltaZ = fabs(lastAcceleration.acceleration.z - accelerometerData.acceleration.z);
            
            double total = deltaX + deltaY + deltaZ;
            if (total>.1) {
                [myRootRef setValue:[NSNumber numberWithFloat:total]];
            }
        }
        self.lastAcceleration = accelerometerData;
    }];
    
    //    [self startSimTimer];
}

-(void)updateView{
    [UIView animateWithDuration:.2 animations:^{
        [_opponentView setFrame:CGRectMake(0, 0, self.opponentView.frame.size.width, self.view.frame.size.height-((curScore * [UIScreen mainScreen].bounds.size.height)/CUR_MAX_SCORE))];
    }];
}

-(void)setWinner{
    [self stopDeviceMotion];
    UILabel *lbl = (UILabel *)[self.view viewWithTag:5544];
    [UIView animateWithDuration:.5 animations:^{
        [lbl setAlpha:1];
        [lbl setText:@"You Win!"];
        [[SoundManager sharedManager] stopAllSounds];
        [NSTimer bk_scheduledTimerWithTimeInterval:.7 block:^(NSTimer *timer) {
            [[SoundManager sharedManager] playSound:@"Winner.m4a"];
        } repeats:NO];
    }];
    [NSTimer bk_scheduledTimerWithTimeInterval:3. block:^(NSTimer *timer) {
        [lbl setAlpha:0];
        [_playBtn setTitle:@"Replay" forState:UIControlStateNormal];
        [_playBtn setHidden:NO];
        [_segmentCntl setHidden:NO];
    } repeats:NO];
    
    curScore = CUR_MAX_SCORE;
    
    [self updateView];
}

-(void)setLoser{
    [self stopDeviceMotion];
    UILabel *lbl = (UILabel *)[self.view viewWithTag:5544];
    [UIView animateWithDuration:.5 animations:^{
        [lbl setAlpha:1];
        [lbl setText:@"You Lose!"];
        [[SoundManager sharedManager] stopAllSounds];
        [[SoundManager sharedManager] playSound:@"Lose.m4a"];
    }];
    [NSTimer bk_scheduledTimerWithTimeInterval:3. block:^(NSTimer *timer) {
        [lbl setAlpha:0];
        [_playBtn setTitle:@"Replay" forState:UIControlStateNormal];
        [_playBtn setHidden:NO];
        [_segmentCntl setHidden:NO];
    } repeats:NO];
    curScore = 0;
    [self updateView];
}

-(void)checkStatus{
    if (curScore <= 0){
        [winnerRef setValue:[NSNumber numberWithBool:!isHomeDevice]];
    }else if (curScore < 150){
        if (!hasVibrated) {
            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
            hasVibrated = YES;
        }
    }else if (curScore >= CUR_MAX_SCORE){
        [winnerRef setValue:[NSNumber numberWithBool:isHomeDevice]];
    }else if (curScore > CUR_MAX_SCORE - 150){
        if (!hasVibrated2) {
            [[SoundManager sharedManager] playSound:@"Roll.m4a"];
            hasVibrated2 = YES;
        }
    }else{
        hasVibrated = NO;
        hasVibrated2 = NO;
    }
    
    [self updateView];
}

- (void)stopDeviceMotion {
    isPlaying = NO;
    [motionManager stopAccelerometerUpdates];
    [myRootRef cancelDisconnectOperations];
    [oppRef cancelDisconnectOperations];
    [self stopSimTimer];
    
    [startRef setValue:[NSNumber numberWithBool:NO]];
    [winnerRef removeValue];
}

-(void)stopSimTimer{
    [simTimer invalidate];
}

BOOL firstPoint, firstPoint2;

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    isHomeDevice = YES;
    
    MAX_SCORE = 1200;
    // Do any additional setup after loading the view, typically from a nib.
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(background) name:UIApplicationDidEnterBackgroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(background) name:UIApplicationWillTerminateNotification object:nil];
    
    startRef = [[Firebase alloc] initWithUrl:@"https://shakeme.firebaseio.com/start"];
    [startRef observeEventType:FEventTypeValue withBlock:^(FDataSnapshot *snapshot) {
        if (firstPoint) {
            if ([snapshot.value isKindOfClass:[NSNumber class]] && [snapshot.value boolValue]) {
                [self startGame];
            }
        }else{
            if ([snapshot.value isKindOfClass:[NSNumber class]] && [snapshot.value boolValue]) {
                [[[UIAlertView alloc] initWithTitle:@"Error" message:@"Sorry but the party has began! Check back later." delegate:nil cancelButtonTitle:nil otherButtonTitles: nil] show];
            }else{
                [self startSocket];
            }
        }
        firstPoint = YES;
    }];
}

-(void)background{
    if (homeRef) {
        NSString *counterToInc = isHomeDevice?@"homeCount":@"awayCount";
        [homeRef updateChildValues:@{counterToInc: [NSNumber numberWithInt:isHomeDevice?--homeCount:--awayCount]} withCompletionBlock:^(NSError *error, Firebase *ref) {
            //Terminate the App
            if (homeCount==0&&awayCount==0) {
                [startRef setValue:[NSNumber numberWithBool:NO] withCompletionBlock:^(NSError *error, Firebase *ref) {
                    exit(0);
                }];
            }else{
                exit(0);
            }
        }];
    }else{
        exit(0);
    }
}

-(void)startSocket{
    
    [oppRef removeAllObservers];
    [myRootRef removeAllObservers];
    [winnerRef removeAllObservers];
    [homeRef removeAllObservers];
    
    if (isHomeDevice) {
        [self.view setBackgroundColor:[UIColor colorWithRed:26/255. green:149/255. blue:201/255. alpha:1.f]];
        [self.opponentView setBackgroundColor:[UIColor colorWithRed:255/255. green:130/255. blue:0/255. alpha:1.f]];
        
        // Create a reference to a Firebase location
        myRootRef = [[Firebase alloc] initWithUrl:@"https://shakeme.firebaseio.com/home"];
        // Write data to Firebase
        
        oppRef = [[Firebase alloc] initWithUrl:@"https://shakeme.firebaseio.com/away"];
    }else{
        [self.view setBackgroundColor:[UIColor colorWithRed:255/255. green:130/255. blue:0/255. alpha:1.f]];
        [self.opponentView setBackgroundColor:[UIColor colorWithRed:26/255. green:149/255. blue:201/255. alpha:1.f]];
        
        // Create a reference to a Firebase location
        myRootRef = [[Firebase alloc] initWithUrl:@"https://shakeme.firebaseio.com/away"];
        // Write data to Firebase
        
        oppRef = [[Firebase alloc] initWithUrl:@"https://shakeme.firebaseio.com/home"];
    }
    
    winnerRef = [[Firebase alloc] initWithUrl:@"https://shakeme.firebaseio.com/winner"];
    [winnerRef observeEventType:FEventTypeValue withBlock:^(FDataSnapshot *snapshot) {
        if (firstPoint2) {
            if ([snapshot.value isKindOfClass:[NSNumber class]] && isPlaying) {
                if ([snapshot.value boolValue]) {
                    if (isHomeDevice) {
                        [self setWinner];
                    }else{
                        [self setLoser];
                    }
                }else{
                    if (!isHomeDevice) {
                        [self setWinner];
                    }else{
                        [self setLoser];
                    }
                }
            }
        }
        firstPoint2 = YES;
    }];
    
    __block SMViewController *strongSelf = self;
    [myRootRef observeEventType:FEventTypeValue withBlock:^(FDataSnapshot *snapshot) {
        NSLog(@"%@ -> %@", snapshot.name, snapshot.value);
        if ([snapshot.value isKindOfClass:[NSNumber class]] && isPlaying) {
            curScore += [snapshot.value doubleValue];
            [strongSelf checkStatus];
        }
    }];
    
    [oppRef observeEventType:FEventTypeValue withBlock:^(FDataSnapshot *snapshot) {
        NSLog(@"%@ -> %@", snapshot.name, snapshot.value);
        if ([snapshot.value isKindOfClass:[NSNumber class]] && isPlaying) {
            curScore -= [snapshot.value doubleValue];
            [strongSelf checkStatus];
        }
    }];
    
    [[[Firebase alloc] initWithUrl:@"https://shakeme.firebaseio.com/MAX_SCORE"] observeSingleEventOfType:FEventTypeValue withBlock:^(FDataSnapshot *snapshot) {
        if ([snapshot.value isKindOfClass:[NSNumber class]]) {
            MAX_SCORE = [snapshot.value doubleValue];
            curScore = MAX_SCORE/2;
        }
    }];
    
    homeRef = [[Firebase alloc] initWithUrl:@"https://shakeme.firebaseio.com/count"];
    [homeRef observeSingleEventOfType:FEventTypeValue withBlock:^(FDataSnapshot *snapshot) {
        
        NSString *counterToInc = isHomeDevice?@"homeCount":@"awayCount";
        
        NSNumber *countToIncrement = [snapshot.value isKindOfClass:[NSDictionary class]]?[snapshot.value objectForKey:counterToInc]:nil;
        
        [homeRef updateChildValues:@{counterToInc: [NSNumber numberWithInt:countToIncrement?[countToIncrement intValue]+1:1]}];
    }];
    
    [homeRef observeEventType:FEventTypeValue withBlock:^(FDataSnapshot *snapshot) {
        if ([snapshot.value isKindOfClass:[NSDictionary class]]) {
            homeCount = [[snapshot.value objectForKey:@"homeCount"] intValue];
            awayCount = [[snapshot.value objectForKey:@"awayCount"] intValue];
            [self updateCountLbl];
        }
    }];
}

-(void)viewDidAppear:(BOOL)animated{
    [super viewDidAppear:animated];
    
    curScore = CUR_MAX_SCORE/2;
    [self updateView];
    [self updateCountLbl];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end