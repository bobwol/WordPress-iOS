//
//  PanelNavigationControllerViewController.m
//  WordPress
//
//  Created by Jorge Bernal on 5/21/12.
//  Copyright (c) 2012 WordPress. All rights reserved.
//

#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>
#import "PanelNavigationController.h"

#define IS_IPAD   ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad)
#define IS_IPHONE   (!IS_IPAD)
#define DETAIL_LEDGE 44.0f
#define DETAIL_LEDGE_OFFSET (320.0f - DETAIL_LEDGE)
#define DURATION_FAST 0.3
#define DURATION_SLOW 0.3
#define SLIDE_DURATION(animated,duration) ((animated) ? (duration) : 0)
#define OPEN_SLIDE_DURATION(animated) SLIDE_DURATION(animated,DURATION_FAST)
#define CLOSE_SLIDE_DURATION(animated) SLIDE_DURATION(animated,DURATION_SLOW)

#define IPHONE_DETAIL_OFFSET 0
#define IPHONE_DETAIL_HEIGHT self.view.frame.size.height
#define IPHONE_DETAIL_WIDTH self.view.frame.size.width
#define IPAD_DETAIL_OFFSET DETAIL_LEDGE
#define IPAD_DETAIL_HEIGHT IPHONE_DETAIL_HEIGHT
#define IPAD_DETAIL_WIDTH ((IPHONE_DETAIL_WIDTH - IPAD_DETAIL_OFFSET) / 2)
#define DETAIL_OFFSET (IS_IPAD ? IPAD_DETAIL_OFFSET : IPHONE_DETAIL_OFFSET)
#define DETAIL_HEIGHT (IS_IPAD ? IPAD_DETAIL_HEIGHT : IPHONE_DETAIL_HEIGHT)
#define DETAIL_WIDTH (IS_IPAD ? IPAD_DETAIL_WIDTH : IPHONE_DETAIL_WIDTH)

#pragma mark -

@interface PanelNavigationController () <UIGestureRecognizerDelegate>
@property (nonatomic, retain) UINavigationController *navigationController;
@property (nonatomic, retain) UIView *detailView;
@property (nonatomic, readonly) UIView *masterView;
@property (nonatomic, readonly) UIView *rootView;
@property (nonatomic, retain) NSMutableArray *detailViewControllers;
@property (nonatomic, retain) UIButton *detailTapper;
@property (nonatomic, retain) UIPanGestureRecognizer *panner;
@property (nonatomic, retain) UIImageView *backgroundImageView;
- (void)showSidebar;
- (void)showSidebarAnimated:(BOOL)animated;
- (void)closeSidebar;
- (void)closeSidebarAnimated:(BOOL)animated;
- (void)disableDetailView;
- (void)enableDetailView;
- (void)addShadowTo:(UIView *)view;
- (void)removeShadowFrom:(UIView *)view;
- (void)applyShadows;
- (void)addPanner;
- (void)removePanner;
- (void)setDetailViewOffset:(CGFloat)offset;
@end

@interface UIViewController (PanelNavigationController_Internal)
- (void)setPanelNavigationController:(PanelNavigationController *)panelNavigationController;
@end

#pragma mark -

@implementation PanelNavigationController {
    CGFloat _panOrigin;
}
@synthesize detailViewController = _detailViewController;
@synthesize masterViewController = _masterViewController;
@synthesize navigationController = _navigationController;
@synthesize detailView = _detailView;
@synthesize detailViewControllers = _detailViewControllers;
@synthesize detailTapper = _detailTapper;
@synthesize panner = _panner;
@synthesize backgroundImageView = _backgroundImageView;

- (void)dealloc {
    self.detailViewController.panelNavigationController = nil;
    self.detailViewController = nil;
    self.masterViewController = nil;
    self.navigationController = nil;
    self.detailViewControllers = nil;
    self.detailTapper = nil;
    self.panner = nil;

    [super dealloc];
}

- (id)init
{
    self = [super init];
    if (self) {
        if (IS_IPHONE) {
            _navigationController = [[UINavigationController alloc] init];
            _detailViewControllers = [[NSMutableArray alloc] init];
        }
    }
    return self;
}

- (id)initWithDetailController:(UIViewController *)detailController masterViewController:(UIViewController *)masterController {
    self = [self init];
    if (self) {
        self.detailViewController = detailController;
        self.masterViewController = masterController;
        
        if (IS_IPHONE) {
            [self.navigationController pushViewController:detailController animated:NO];
        }
    }
    return self;
}

- (void)loadView {
    self.view = [[[UIView alloc] init] autorelease];
    self.view.frame = [UIScreen mainScreen].applicationFrame;
    self.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.view.autoresizesSubviews = YES;
    self.view.clipsToBounds = YES;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.detailView = [[[UIView alloc] init] autorelease];
    self.detailView.autoresizingMask = UIViewAutoresizingFlexibleHeight;
    self.detailView.autoresizesSubviews = YES;
    self.detailView.clipsToBounds = YES;
    [self.view addSubview:self.detailView];
    
    if (self.navigationController) {
        [self.navigationController willMoveToParentViewController:self];
        [self addChildViewController:self.navigationController];
        [self.navigationController didMoveToParentViewController:self];
        self.detailViewController.navigationItem.leftBarButtonItem = [[[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"list"] style:UIBarButtonItemStyleBordered target:self action:@selector(showSidebar)] autorelease];
    }
    if (IS_IPAD) {
        self.backgroundImageView = [[[UIImageView alloc] initWithImage:[UIImage imageNamed:@"fabric"]] autorelease];
        self.backgroundImageView.frame = CGRectMake(DETAIL_LEDGE_OFFSET, 0, self.view.frame.size.width - DETAIL_LEDGE_OFFSET, DETAIL_HEIGHT);
        self.backgroundImageView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [self.view insertSubview:self.backgroundImageView belowSubview:self.detailView];

        self.detailView.frame = CGRectMake(0, 0, DETAIL_WIDTH, DETAIL_HEIGHT);
        [self showSidebarAnimated:NO];
    }
}

- (void)viewDidUnload {
    self.detailView = nil;
    self.backgroundImageView = nil;

    if (self.navigationController) {
        [self.navigationController willMoveToParentViewController:nil];
        [self.navigationController removeFromParentViewController];
        [self.navigationController didMoveToParentViewController:nil];
    }
    [super viewDidUnload];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    if (self.navigationController) {
        [self.navigationController.view removeFromSuperview];
        [self.detailView addSubview:self.navigationController.view];
        [self.navigationController viewWillAppear:animated];
    } else {
        [self.detailViewController.view removeFromSuperview];
        [self.detailView addSubview:self.detailViewController.view];        
        [self.detailViewController viewWillAppear:animated];
    }
    [self.masterViewController.view removeFromSuperview];
    self.masterView.frame = CGRectMake(0, 0, DETAIL_LEDGE_OFFSET, self.view.frame.size.height);
    [self.view insertSubview:self.masterViewController.view belowSubview:self.detailView];
    // FIXME: keep sliding status
    self.detailViewController.view.frame = CGRectMake(0, 0, DETAIL_WIDTH, DETAIL_HEIGHT);

    [self addPanner];
    [self applyShadows];
}

- (void) viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];

    [self removePanner];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
	return YES;
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation {
    if (self.detailView.frame.origin.x > 0.0f) {
        [self showSidebarAnimated:NO];
    }
}

#pragma mark - Memory management

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];

    [self.navigationController didReceiveMemoryWarning];
    [self.masterViewController didReceiveMemoryWarning];
    [self.detailViewController didReceiveMemoryWarning];
}

#pragma mark - Property accessors

- (UIView *)masterView {
    return self.masterViewController.view;
}

- (UIView *)rootView {
    return self.rootViewController.view;
}

- (UIViewController *)topViewController {
    if (self.navigationController) {
        return self.navigationController.topViewController;
    } else {
        return self.detailViewController;
    }
}

- (UIViewController *)visibleViewController {
    if (self.modalViewController) {
        return self.modalViewController;
    } else if (self.navigationController) {
        return self.navigationController.visibleViewController;
    } else {
        return self.detailViewController;
    }
}

-  (UIViewController *)rootViewController {
    if (self.navigationController) {
        return self.navigationController;
    } else {
        return self.detailViewController;
    }
}

- (NSArray *)viewControllers {
    if (self.navigationController) {
        return self.navigationController.viewControllers;
    } else {
        // FIXME: add extra view controllers when there are panels
        return [NSArray arrayWithObject:self.detailViewController];
    }
}

- (void)setDetailViewController:(UIViewController *)detailViewController {
    if (_detailViewController == detailViewController) return;

    if (_detailViewController) {
        [_detailViewController willMoveToParentViewController:nil];
        [_detailViewController setPanelNavigationController:nil];
        [_detailViewController removeFromParentViewController];
        [_detailViewController didMoveToParentViewController:nil];
        [_detailViewController release];
    }
    
    _detailViewController = detailViewController;
    
    if (_detailViewController) {
        [_detailViewController retain];
        [_detailViewController willMoveToParentViewController:self];
        [self addChildViewController:_detailViewController];
        [_detailViewController setPanelNavigationController:self];
        [_detailViewController didMoveToParentViewController:self];
    }
}

- (void)setMasterViewController:(UIViewController *)masterViewController {
    /*
     When replacing the master view controller:
     
     - Call the right UIViewController containment methods
     - Set/restore scrollsToTop. Only one scroll view can have it enabled if we
     want to be able to scroll by tapping on the status bar
     - Replace the master view with the new one
     */
    if (_masterViewController == masterViewController) return;

    if (_masterViewController) {
        if ([_masterViewController.view respondsToSelector:@selector(setScrollsToTop:)]) {
            [(UIScrollView *)_masterViewController.view setScrollsToTop:YES];
        }
        [_masterViewController willMoveToParentViewController:nil];
        [_masterViewController setPanelNavigationController:nil];
        [_masterViewController removeFromParentViewController];
        [_masterViewController didMoveToParentViewController:nil];
        [_masterViewController release];
    }

    _masterViewController = masterViewController;

    if (_masterViewController) {
        [_masterViewController retain];
        [_masterViewController willMoveToParentViewController:self];
        [self addChildViewController:_masterViewController];
        [_masterViewController setPanelNavigationController:self];
        [_masterViewController didMoveToParentViewController:self];
        if ([_masterViewController.view respondsToSelector:@selector(setScrollsToTop:)]) {
            [(UIScrollView *)_masterViewController.view setScrollsToTop:NO];
        }
    }
}

#pragma mark - Sidebar control

- (void)showSidebar {
    [self showSidebarAnimated:YES];
}

- (void)showSidebarAnimated:(BOOL)animated {
    [UIView animateWithDuration:OPEN_SLIDE_DURATION(animated) delay:0 options:0 | UIViewAnimationOptionLayoutSubviews | UIViewAnimationOptionBeginFromCurrentState animations:^{
        [self applyShadows];
        self.masterViewController.view.hidden = NO;
        [self setDetailViewOffset:DETAIL_LEDGE_OFFSET];
        [self disableDetailView];
    } completion:^(BOOL finished) {
    }];
}

- (void)closeSidebar {
    [self closeSidebarAnimated:YES];
}

- (void)closeSidebarAnimated:(BOOL)animated {
    [UIView animateWithDuration:OPEN_SLIDE_DURATION(animated) delay:0 options:0 | UIViewAnimationOptionLayoutSubviews | UIViewAnimationOptionBeginFromCurrentState animations:^{
        self.detailView.frame = self.rootViewController.view.bounds;
    } completion:^(BOOL finished) {
        [self applyShadows];
        [self enableDetailView];
    }];
}

- (void)centerTapped {
    [self closeSidebar];
}

- (void)disableDetailView {
    if (IS_IPAD) return;

    // TODO: remove pan recognizer?
    if (!self.detailTapper) {
        self.detailTapper = [UIButton buttonWithType:UIButtonTypeCustom];
        self.detailTapper.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        self.detailTapper.frame = self.detailView.bounds;
        [self.detailView addSubview:self.detailTapper];
        [self.detailTapper addTarget:self action:@selector(centerTapped) forControlEvents:UIControlEventTouchUpInside];
        self.detailTapper.backgroundColor = [UIColor clearColor];
        UIPanGestureRecognizer *panner = [[[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(panned:)] autorelease];
        panner.cancelsTouchesInView = YES;
        panner.delegate = self;
        [self.detailTapper addGestureRecognizer:panner];
    }
    
    self.detailTapper.frame = self.detailView.bounds;
}

- (void)enableDetailView {
    if (IS_IPAD) return;

    if (self.detailTapper) {
        [self.detailTapper removeTarget:self action:@selector(centerTapped) forControlEvents:UIControlEventTouchUpInside];
        [self.detailTapper removeFromSuperview];
    }

    self.detailTapper = nil;
}

- (void)addShadowTo:(UIView *)view {
    view.layer.masksToBounds = NO;
    view.layer.shadowRadius = 10.0f;
    view.layer.shadowOpacity = 0.5f;
    view.layer.shadowColor = [[UIColor blackColor] CGColor];
    view.layer.shadowOffset = CGSizeZero;
    view.layer.shadowPath = [[UIBezierPath bezierPathWithRect:view.bounds] CGPath];
}

- (void)removeShadowFrom:(UIView *)view {
    view.layer.shadowOpacity = 0.0f;
}

- (void)applyShadows {
    if (self.detailView.frame.origin.x > 0) {
        [self addShadowTo:self.detailView];
    } else {
        [self removeShadowFrom:self.detailView];
    }
}

#pragma mark - Panning

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer {
    [self applyShadows];
    return YES;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
    _panOrigin = self.detailView.frame.origin.x;
    return YES;
}

- (void)panned:(UIPanGestureRecognizer *)sender {
    CGPoint p = [sender translationInView:self.rootViewController.view];
    CGFloat x = p.x + _panOrigin;
    CGFloat lx = MIN(MAX(0,x),DETAIL_LEDGE_OFFSET);
    CGFloat dx = ABS(x) - ABS(lx);
    if (dx > 0) {
        dx = dx / logf(dx + 1) * 2;
        x = lx + (x < 0 ? -dx : dx);
    }
    CGFloat w = self.rootViewController.view.bounds.size.width;
    [self setDetailViewOffset:x];
    
    if (sender.state == UIGestureRecognizerStateEnded) {
        CGFloat velocity = [sender velocityInView:self.rootViewController.view].x;
        if (ABS(velocity) < 100) {
            if (x > w / 3) {
                [self showSidebar];
            } else {
                [self closeSidebar];
            }
        } else if (velocity > 0) {
            // Going right
            [self showSidebar];
        } else {
            [self closeSidebar];
        }
    }
}

- (void)addPanner {
    [self removePanner];
    
    UIPanGestureRecognizer *panner = [[[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(panned:)] autorelease];
    panner.cancelsTouchesInView = YES;
    panner.delegate = self;
    self.panner = panner;
    [self.navigationController.navigationBar addGestureRecognizer:panner];
}

- (void)removePanner {
    if (self.panner) {
        [self.panner.view removeGestureRecognizer:self.panner];
    }
    self.panner = nil;
}

- (void)setDetailViewOffset:(CGFloat)offset {
    CGRect frame = self.detailView.frame;
    frame.origin.x = MAX(0,offset);
    self.detailView.frame = frame;
}

#pragma mark - Navigation methods

- (void)pushViewController:(UIViewController *)viewController animated:(BOOL)animated {
    if (self.navigationController) {
        [self.navigationController pushViewController:viewController animated:animated];
    } else {
        // TODO
    }
}

- (UIViewController *)popViewControllerAnimated:(BOOL)animated {
    if (self.navigationController) {
        return [self.navigationController popViewControllerAnimated:animated];
    } else {
        // TODO
    }
    return nil;
}

- (NSArray *)popToViewController:(UIViewController *)viewController animated:(BOOL)animated {
    if (self.navigationController) {
        return [self.navigationController popToViewController:viewController animated:animated];
    } else {
        // TODO
    }
    return nil;
}

- (NSArray *)popToRootViewControllerAnimated:(BOOL)animated {
    if (self.navigationController) {
        return [self.navigationController popToRootViewControllerAnimated:animated];
    } else {
        // TODO;
    }
    return nil;
}


@end

@implementation UIViewController (PanelNavigationController)

@dynamic panelNavigationController;

static const char *panelNavigationControllerKey = "PanelNavigationController";

- (PanelNavigationController *)panelNavigationController {
    return objc_getAssociatedObject(self, panelNavigationControllerKey);
}

- (void)setPanelNavigationController:(PanelNavigationController *)panelNavigationController {
    objc_setAssociatedObject(self, panelNavigationControllerKey, panelNavigationController, OBJC_ASSOCIATION_ASSIGN);
}

@end

@implementation UIViewController (PanelNavigationController_ViewContainmentEmulation)

#define OBJC_ADD_METHOD_IF_MISSING(selector,fakeSelector,args)     if (!class_getInstanceMethod(self, selector)) { \
    class_addMethod([UIViewController class], selector, method_getImplementation(class_getInstanceMethod(self, fakeSelector)), args); }


+ (void)load {
    [super load];
    OBJC_ADD_METHOD_IF_MISSING(@selector(addChildViewController:), @selector(fake_addChildViewController:), "v@:@");
    OBJC_ADD_METHOD_IF_MISSING(@selector(removeFromParentViewController), @selector(fake_removeFromParentViewController), "v@:");
    OBJC_ADD_METHOD_IF_MISSING(@selector(willMoveToParentViewController:), @selector(fake_willMoveToParentViewController:), "v@:@");
    OBJC_ADD_METHOD_IF_MISSING(@selector(didMoveToParentViewController:), @selector(fake_didMoveToParentViewController:), "v@:@");
}

- (void)fake_addChildViewController:(UIViewController *)childController {
}

- (void)fake_removeFromParentViewController {
}

- (void)fake_willMoveToParentViewController:(UIViewController *)parent {
}

- (void)fake_didMoveToParentViewController:(UIViewController *)parent {
}

@end