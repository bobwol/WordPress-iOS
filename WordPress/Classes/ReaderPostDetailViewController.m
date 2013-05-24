//
//  ReaderPostDetailViewController.m
//  WordPress
//
//  Created by Eric J on 3/21/13.
//  Copyright (c) 2013 WordPress. All rights reserved.
//

#import "ReaderPostDetailViewController.h"
#import <QuartzCore/QuartzCore.h>
#import <MessageUI/MFMailComposeViewController.h>
#import "UIImageView+Gravatar.h"
#import "WPActivities.h"
#import "WPWebViewController.h"
#import "PanelNavigationConstants.h"
#import "WordPressAppDelegate.h"
#import "WordPressComApi.h"
#import "ReaderComment.h"
#import "ReaderCommentTableViewCell.h"
#import "WPToast.h"
#import "ReaderPostDetailView.h"

@interface ReaderPostDetailViewController ()<ReaderPostDetailViewDelegate, UIActionSheetDelegate, MFMailComposeViewControllerDelegate, UITextViewDelegate>

@property (nonatomic, strong) ReaderPost *post;
@property (nonatomic, strong) ReaderPostDetailView *headerView;
@property (nonatomic, strong) UIBarButtonItem *commentButton;
@property (nonatomic, strong) UIBarButtonItem *likeButton;
@property (nonatomic, strong) UIBarButtonItem *followButton;
@property (nonatomic, strong) UIBarButtonItem *reblogButton;
@property (nonatomic, strong) UIBarButtonItem *shareButton;
@property (nonatomic, strong) UIBarButtonItem *sendCommentButton;
@property (nonatomic, strong) UIView *footerView;
@property (nonatomic, strong) UIView *commentFormPointer;
@property (nonatomic, strong) UILabel *commentFormLabel;
@property (nonatomic, strong) UILabel *commentPromptLabel;
@property (nonatomic, strong) UITextView *commentTextView;
@property (nonatomic, strong) UIButton *commentSubmitButton;
@property (nonatomic, strong) UIActivityIndicatorView *activityView;
@property (nonatomic, strong) UIActionSheet *linkOptionsActionSheet;
@property (nonatomic, strong) NSMutableArray *comments;
@property (nonatomic, strong) NSArray *rowHeights;
@property (nonatomic, strong) NSFetchedResultsController *resultsController;
@property (nonatomic) BOOL isShowingKeyboard;
@property (nonatomic) BOOL isReplying;

- (void)prepareComments;
- (void)updateRowHeightsForWidth:(CGFloat)width;
- (void)updateToolbar;

- (void)handleCommentButtonTapped:(id)sender;
- (void)handleFollowButtonTapped:(id)sender;
- (void)handleLikeButtonTapped:(id)sender;
- (void)handleReblogButtonTapped:(id)sender;
- (void)handleShareButtonTapped:(id)sender;
- (void)handleSendCommentButtonTapped:(id)sender;
- (void)handleCloseKeyboard:(id)sender;
- (void)handleFooterViewTapped:(id)sender;
- (BOOL)setMFMailFieldAsFirstResponder:(UIView*)view mfMailField:(NSString*)field;

@end

@implementation ReaderPostDetailViewController

@synthesize post;

#pragma mark - LifeCycle Methods

- (void)doBeforeDealloc {
	[super doBeforeDealloc];
	_resultsController.delegate = nil;
}


- (id)initWithPost:(ReaderPost *)apost {
	self = [super initWithStyle:UITableViewStylePlain];
	if(self) {
		self.post = apost;
		self.comments = [NSMutableArray array];
		self.rowHeights = [NSArray array];
	}
	return self;
}


- (id)initWithDictionary:(NSDictionary *)dict {
	self = [super initWithStyle:UITableViewStylePlain];
	if(self) {
		// TODO: for supporting Twitter cards.
	}
	return self;
}


- (void)viewDidLoad {
	[super viewDidLoad];
	
	self.tableView.backgroundColor = [UIColor colorWithHexString:@"EFEFEF"];
	self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
	
	self.title = self.post.postTitle;
	
	if ([[UIButton class] respondsToSelector:@selector(appearance)]) {
		UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
		
		[btn setImage:[UIImage imageNamed:@"navbar_actions.png"] forState:UIControlStateNormal];
		[btn setImage:[UIImage imageNamed:@"navbar_actions.png"] forState:UIControlStateHighlighted];
		
		UIImage *backgroundImage = [[UIImage imageNamed:@"navbar_button_bg"] stretchableImageWithLeftCapWidth:4 topCapHeight:0];
		[btn setBackgroundImage:backgroundImage forState:UIControlStateNormal];
		
		backgroundImage = [[UIImage imageNamed:@"navbar_button_bg_active"] stretchableImageWithLeftCapWidth:4 topCapHeight:0];
		[btn setBackgroundImage:backgroundImage forState:UIControlStateHighlighted];
		btn.frame = CGRectMake(0.0f, 0.0f, 44.0f, 30.0f);
		[btn addTarget:self action:@selector(handleShareButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
		
		self.shareButton = [[UIBarButtonItem alloc] initWithCustomView:btn];
	} else {
		self.shareButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction
																		   target:self
																		   action:@selector(handleShareButtonTapped:)];
	}
	self.navigationItem.rightBarButtonItem = _shareButton;

	UIColor *color = [UIColor colorWithHexString:@"3478E3"];
	CGFloat fontSize = 16.0f;
	
	UIButton *commentBtn = [UIButton buttonWithType:UIButtonTypeCustom];
	[commentBtn.titleLabel setFont:[UIFont systemFontOfSize:fontSize]];
//	[commentBtn setTitle:NSLocalizedString(@"Comment", @"") forState:UIControlStateNormal];
	[commentBtn setTitleColor:color forState:UIControlStateNormal];
	[commentBtn setImage:[UIImage imageNamed:@"note_icon_comment"] forState:UIControlStateNormal];
	commentBtn.frame = CGRectMake(0.0f, 0.0f, 100.0f, 40.0f);
	[commentBtn addTarget:self action:@selector(handleCommentButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
	
	UIButton *likeBtn = [UIButton buttonWithType:UIButtonTypeCustom];
	[likeBtn.titleLabel setFont:[UIFont systemFontOfSize:fontSize]];
//	[likeBtn setTitle:NSLocalizedString(@"Like", @"") forState:UIControlStateNormal];
	[likeBtn setTitleColor:color forState:UIControlStateNormal];
	[likeBtn setImage:[UIImage imageNamed:@"note_icon_like"] forState:UIControlStateNormal];
	likeBtn.frame = CGRectMake(0.0f, 0.0f, 100.0f, 40.0f);
	likeBtn.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
	[likeBtn addTarget:self action:@selector(handleLikeButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
	
	UIButton *followBtn = [UIButton buttonWithType:UIButtonTypeCustom];
	[followBtn.titleLabel setFont:[UIFont systemFontOfSize:fontSize]];
//	[followBtn setTitle:NSLocalizedString(@"Follow", @"") forState:UIControlStateNormal];
	[followBtn setTitleColor:color forState:UIControlStateNormal];
	[followBtn setImage:[UIImage imageNamed:@"note_icon_follow"] forState:UIControlStateNormal];
	followBtn.frame = CGRectMake(0.0f, 0.0f, 100.0f, 40.0f);
	[followBtn addTarget:self action:@selector(handleFollowButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
	
	UIButton *reblogBtn = [UIButton buttonWithType:UIButtonTypeCustom];
	[reblogBtn.titleLabel setFont:[UIFont systemFontOfSize:fontSize]];
//	[reblogBtn setTitle:NSLocalizedString(@"Reblog", @"") forState:UIControlStateNormal];
	[reblogBtn setTitleColor:color forState:UIControlStateNormal];
	[reblogBtn setImage:[UIImage imageNamed:@"note_icon_reblog"] forState:UIControlStateNormal];
	reblogBtn.frame = CGRectMake(0.0f, 0.0f, 100.0f, 40.0f);
	reblogBtn.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
	[reblogBtn addTarget:self action:@selector(handleReblogButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
	
	self.commentButton = [[UIBarButtonItem alloc] initWithCustomView:commentBtn];
	self.likeButton = [[UIBarButtonItem alloc] initWithCustomView:likeBtn];
	self.followButton = [[UIBarButtonItem alloc] initWithCustomView:followBtn];
	self.reblogButton = [[UIBarButtonItem alloc] initWithCustomView:reblogBtn];
	[self updateToolbar];
	
	self.headerView = [[ReaderPostDetailView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, self.tableView.frame.size.width, 190.0f) post:self.post delegate:self];
	_headerView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	_headerView.backgroundColor = [UIColor whiteColor];
	[self.tableView setTableHeaderView:_headerView];
	
	[self prepareComments];
	[self updateRowHeightsForWidth:self.tableView.frame.size.width];
}


- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	
	self.panelNavigationController.delegate = self;
	[self.navigationController setToolbarHidden:NO animated:YES];
}


- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
	
    self.panelNavigationController.delegate = nil;
	[self.navigationController setToolbarHidden:YES animated:YES];
}


- (void)viewDidUnload {
	[super viewDidUnload];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}


- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return [super shouldAutorotateToInterfaceOrientation:interfaceOrientation];
}


- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {
	[super willRotateToInterfaceOrientation:toInterfaceOrientation duration:duration];
	
	CGFloat width;
	// The new width should be the window
	if (IS_IPAD) {
		width = IPAD_DETAIL_WIDTH;
	} else {
		CGRect frame = self.view.window.frame;
		width = UIInterfaceOrientationIsLandscape(toInterfaceOrientation) ? frame.size.height : frame.size.width;
	}
	
	[self updateRowHeightsForWidth:width];
}


- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation {
	[super didRotateFromInterfaceOrientation:fromInterfaceOrientation];
	[_headerView updateLayout];
}


#pragma mark - Instance Methods

- (void)prepareComments {
	self.resultsController = nil;
	[_comments removeAllObjects];
	
	__block void(__weak ^flattenComments)(NSArray *) = ^void (NSArray *comments) {
		// Ensure the array is correctly sorted. 
		comments = [comments sortedArrayUsingComparator: ^(id obj1, id obj2) {
			ReaderComment *a = obj1;
			ReaderComment *b = obj2;
			if ([[a dateCreated] timeIntervalSince1970] > [[b dateCreated] timeIntervalSince1970]) {
				return (NSComparisonResult)NSOrderedDescending;
			}
			if ([[a dateCreated] timeIntervalSince1970] < [[b dateCreated] timeIntervalSince1970]) {
				return (NSComparisonResult)NSOrderedAscending;
			}
			return (NSComparisonResult)NSOrderedSame;
		}];
		
		for (ReaderComment *comment in comments) {
			[_comments addObject:comment];
			if([comment.childComments count] > 0) {
				flattenComments([comment.childComments allObjects]);
			}
		}
	};
	
	flattenComments(self.resultsController.fetchedObjects);
}


- (void)updateRowHeightsForWidth:(CGFloat)width {
	self.rowHeights = [ReaderCommentTableViewCell cellHeightsForComments:_comments
																   width:width
															  tableStyle:UITableViewStylePlain
															   cellStyle:UITableViewCellStyleDefault
														 reuseIdentifier:@"ReaderCommentCell"];
}


- (void)updateToolbar {
	if (!self.post) return;

	UIColor *activeColor = [UIColor colorWithHexString:@"F1831E"];
	UIColor *inactiveColor = [UIColor colorWithHexString:@"3478E3"];
	
	UIImage *img = nil;
	UIColor *color;
	UIButton *btn;
	if (self.post.isLiked.boolValue) {
		img = [UIImage imageNamed:@"note_navbar_icon_like"];
		color = activeColor;
	} else {
		img = [UIImage imageNamed:@"note_icon_like"];
		color = inactiveColor;
	}
	btn = (UIButton *)_likeButton.customView;
	[btn.imageView setImage:img];
	[btn setTitleColor:color forState:UIControlStateNormal];
	
	if (self.post.isReblogged.boolValue) {
		img = [UIImage imageNamed:@"note_navbar_icon_reblog"];
		color = activeColor;
	} else {
		img = [UIImage imageNamed:@"note_icon_reblog"];
		color = inactiveColor;
	}
	btn = (UIButton *)_reblogButton.customView;
	[btn.imageView setImage:img];
	[btn setTitleColor:color forState:UIControlStateNormal];
	
	if (self.post.isFollowing.boolValue) {
		img = [UIImage imageNamed:@"note_navbar_icon_follow"];
		color = activeColor;
	} else {
		img = [UIImage imageNamed:@"note_icon_follow"];
		color = inactiveColor;
	}
	btn = (UIButton *)_followButton.customView;
	[btn.imageView setImage:img];
	[btn setTitleColor:color forState:UIControlStateNormal];
	
	UIBarButtonItem *placeholder = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
	[self setToolbarItems:@[_commentButton, placeholder, _likeButton, placeholder, _followButton, placeholder, _reblogButton] animated:YES];
	self.navigationController.toolbarHidden = NO;

}


- (void)handleCommentButtonTapped:(id)sender {
	if([[self.tableView visibleCells] count] == 0) {
		if ([self.comments count] > 0) {
			[self.tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0]
								  atScrollPosition:UITableViewScrollPositionBottom animated:YES];
		}
	}
}


- (void)handleFollowButtonTapped:(id)sender {
	NSLog(@"Follow tapped");
	[self.post toggleFollowingWithSuccess:^{
		
	} failure:^(NSError *error) {
		[self updateToolbar];
	}];
	[self updateToolbar];
}


- (void)handleLikeButtonTapped:(id)sender {
	NSLog(@"Like Tapped");
	[self.post toggleLikedWithSuccess:^{
		
	} failure:^(NSError *error) {
		[self updateToolbar];
	}];
	[self updateToolbar];
}


- (void)handleReblogButtonTapped:(id)sender {
	NSLog(@"Reblog tapped");
	[self.post reblogPostToSite:nil success:^{
		
	} failure:^(NSError *error) {
		[self updateToolbar];
	}];
	[self updateToolbar];
}


- (void)handleSendCommentButtonTapped:(id)sender {
	[self handleCloseKeyboard:nil];
	
	NSString *str = [_commentTextView.text trim];
	if ([str length] == 0) {
		return;
	}

	_commentTextView.editable = NO;
	_commentSubmitButton.enabled = NO;
	[_activityView startAnimating];
	NSString *path;
	if ([self.tableView indexPathForSelectedRow] != nil) {
		ReaderComment *comment = [_comments objectAtIndex:[self.tableView indexPathForSelectedRow].row];
		path = [NSString stringWithFormat:@"sites/%@/comments/%@/replies/new", self.post.siteID, comment.commentID];
	} else {
		path = [NSString stringWithFormat:@"sites/%@/posts/%@/replies/new", self.post.siteID, self.post.postID];
	}

	NSDictionary *params = @{@"content":str};
	[[WordPressComApi sharedApi] postPath:path parameters:params success:^(AFHTTPRequestOperation *operation, id responseObject) {
		
		NSDictionary *params = @{@"number":@100};
		
		[ReaderPost getCommentsForPost:[self.post.postID integerValue]
							  fromSite:[self.post.siteID stringValue]
						withParameters:params
							   success:^(AFHTTPRequestOperation *operation, id responseObject) {
								   
								   _commentTextView.editable = YES;
								   _commentTextView.text = nil;
								   [_activityView stopAnimating];
								   
								   [WPToast showToastWithMessage:NSLocalizedString(@"Replied", @"User replied to a comment")
														andImage:[UIImage imageNamed:@"action_icon_replied"]];
								   
								   self.post.dateCommentsSynced = [NSDate date];
								   
								   NSDictionary *resp = (NSDictionary *)responseObject;
								   NSArray *commentsArr = [resp objectForKey:@"comments"];
								   
								   [ReaderComment syncAndThreadComments:commentsArr
																forPost:self.post
															withContext:[[WordPressAppDelegate sharedWordPressApplicationDelegate] managedObjectContext]];
								   
								   [self prepareComments];
								   [self updateRowHeightsForWidth:self.tableView.frame.size.width];
								   [self.tableView reloadData];
								   [self hideRefreshHeader];
								   
							   } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
								   [self hideRefreshHeader];
								   _commentSubmitButton.enabled = YES;
								   _commentTextView.editable = YES;
								   [_activityView stopAnimating];
							   }];
		
	} failure:^(AFHTTPRequestOperation *operation, NSError *error) {
		_commentSubmitButton.enabled = YES;
		_commentTextView.editable = YES;
		[_activityView stopAnimating];
		
	}];
	
}


- (void)handleShareButtonTapped:(id)sender {
	
	if (self.linkOptionsActionSheet) {
        [self.linkOptionsActionSheet dismissWithClickedButtonIndex:-1 animated:NO];
        self.linkOptionsActionSheet = nil;
    }
    NSString* permaLink = self.post.permaLink;
    	
    if (NSClassFromString(@"UIActivity") != nil) {
        NSString *title = self.post.postTitle;
        SafariActivity *safariActivity = [[SafariActivity alloc] init];
        InstapaperActivity *instapaperActivity = [[InstapaperActivity alloc] init];
        PocketActivity *pocketActivity = [[PocketActivity alloc] init];
		
        NSMutableArray *activityItems = [NSMutableArray array];
        if (title) {
            [activityItems addObject:title];
        }
		
        [activityItems addObject:[NSURL URLWithString:permaLink]];
        UIActivityViewController *activityViewController = [[UIActivityViewController alloc] initWithActivityItems:activityItems applicationActivities:@[safariActivity, instapaperActivity, pocketActivity]];
        [self presentViewController:activityViewController animated:YES completion:nil];
        return;
    }
	
    self.linkOptionsActionSheet = [[UIActionSheet alloc] initWithTitle:permaLink delegate:self cancelButtonTitle:NSLocalizedString(@"Cancel", @"Cancel") destructiveButtonTitle:nil otherButtonTitles:NSLocalizedString(@"Open in Safari", @"Open in Safari"), NSLocalizedString(@"Mail Link", @"Mail Link"),  NSLocalizedString(@"Copy Link", @"Copy Link"), nil];
    self.linkOptionsActionSheet.actionSheetStyle = UIActionSheetStyleDefault;
    if(IS_IPAD ){
        [self.linkOptionsActionSheet showFromBarButtonItem:_shareButton animated:YES];
    } else {
        [self.linkOptionsActionSheet showInView:self.view];
    }
	
}


- (void)handleCloseKeyboard:(id)sender {
	[self.view endEditing:YES];
}


- (void)handleFooterViewTapped:(id)sender {
	if (_isShowingKeyboard) {
		if([self.tableView indexPathForSelectedRow]) {
			[self.tableView scrollToRowAtIndexPath:[self.tableView indexPathForSelectedRow] atScrollPosition:UITableViewScrollPositionTop animated:YES];
		}
	}
}


#pragma mark - Sync methods

- (void)syncWithUserInteraction:(BOOL)userInteraction {
	
	NSDictionary *params = @{@"number":@100};
	
	[ReaderPost getCommentsForPost:[self.post.postID integerValue]
						  fromSite:[self.post.siteID stringValue]
					withParameters:params
						   success:^(AFHTTPRequestOperation *operation, id responseObject) {
							   self.post.dateCommentsSynced = [NSDate date];
							   
							   NSDictionary *resp = (NSDictionary *)responseObject;
							   NSArray *commentsArr = [resp objectForKey:@"comments"];
							   
							   [ReaderComment syncAndThreadComments:commentsArr
															forPost:self.post
														withContext:[[WordPressAppDelegate sharedWordPressApplicationDelegate] managedObjectContext]];
							   
							   [self prepareComments];
							   [self updateRowHeightsForWidth:self.tableView.frame.size.width];
							   [self.tableView reloadData];
							   [self hideRefreshHeader];
							   
						   } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
							   [self hideRefreshHeader];
							   
						   }];
}


- (NSDate *)lastSyncDate {
	return self.post.dateCommentsSynced;
}


#pragma mark - UITableView Delegate Methods

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
	return [[_rowHeights objectAtIndex:indexPath.row] floatValue];
}


- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
	return 100.0f;
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return [_comments count];
}


- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return 1;
}


- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section {
	if (section > 0)
		return nil;
	
	if (_footerView == nil) {
		CGFloat width = self.tableView.frame.size.width;
		CGFloat height = 100.0f;
		CGRect frame = CGRectMake(0.0f, 0.0f, width, height);
		self.footerView = [[UIView alloc] initWithFrame:frame];
		_footerView.backgroundColor = [UIColor colorWithHexString:@"1E8CBE"];
		
		UIButton *footerButton = [UIButton buttonWithType:UIButtonTypeCustom];
		footerButton.frame = frame;
		[footerButton addTarget:self action:@selector(handleFooterViewTapped:) forControlEvents:UIControlEventTouchUpInside];
		[_footerView addSubview:footerButton];

		self.commentFormLabel = [[UILabel alloc] initWithFrame:CGRectMake(10.0f, 7.0f, width - 20.0f, 18.0f)];
		_commentFormLabel.text = [NSString stringWithFormat:@"Commenting on %@", self.post.postTitle];
		_commentFormLabel.textColor = [UIColor whiteColor];
		_commentFormLabel.font = [UIFont systemFontOfSize:14.0f];
		_commentFormLabel.backgroundColor = [UIColor clearColor];
		[_footerView addSubview:_commentFormLabel];

		UIImageView *imgView = [[UIImageView alloc] initWithImage:[[UIImage imageNamed:@"note-reply-field"] resizableImageWithCapInsets:UIEdgeInsetsMake(6.0f, 6.0f, 6.0f, 6.0f)]];
		imgView.frame = CGRectMake(10.0f, 30.0f, width - 20.0f, 60.0f);
		imgView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		[_footerView addSubview:imgView];
		
		self.commentTextView = [[UITextView alloc] initWithFrame:CGRectMake(15.0f, 35.0f, width - 30.0, 50.0f)];
		_commentTextView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		_commentTextView.font = [UIFont systemFontOfSize:14.0f];
		_commentTextView.delegate = self;
		_commentTextView.backgroundColor = [UIColor clearColor];
		[_footerView addSubview:_commentTextView];
		
		self.commentPromptLabel = [[UILabel alloc] initWithFrame:CGRectMake(15.0f, 35.0f, width - 30.0f, 20.0f)];
		_commentPromptLabel.text = NSLocalizedString(@"Tap to reply", @"");
		_commentPromptLabel.backgroundColor = [UIColor clearColor];
		_commentPromptLabel.textColor = [UIColor grayColor];
		_commentPromptLabel.font = [UIFont systemFontOfSize:14.0f];
		[_footerView addSubview:_commentPromptLabel];
		
		self.activityView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
		frame = _activityView.frame;
		frame.origin.x = (width / 2.0f) - (frame.size.width / 2.0f);
		frame.origin.y = (height / 2.0f) - (frame.size.height / 2.0f);
		_activityView.frame = frame;
		_activityView.hidesWhenStopped = YES;
		_activityView.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
		[_footerView addSubview:_activityView];
	}
	
	return _footerView;
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	NSString *cellIdentifier = @"ReaderCommentCell";
    ReaderCommentTableViewCell *cell = (ReaderCommentTableViewCell *)[self.tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    if (cell == nil) {
        cell = [[ReaderCommentTableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
    }
	cell.accessoryType = UITableViewCellAccessoryNone;
		
	ReaderComment *comment = [_comments objectAtIndex:indexPath.row];
	[cell configureCell:comment];

	return cell;	
}


- (NSIndexPath *)tableView:(UITableView *)tableView willSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
	if ([cell isSelected]) {
		[tableView deselectRowAtIndexPath:indexPath animated:NO];
		[tableView.delegate tableView:tableView didDeselectRowAtIndexPath:indexPath];
		return nil;
	}
	return indexPath;
}


- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	ReaderComment *comment = [_comments objectAtIndex:indexPath.row];
	_commentFormLabel.text = [NSString stringWithFormat:@"Replying to %@", comment.author];
	
	if(_isShowingKeyboard) {
		[self.tableView scrollToRowAtIndexPath:indexPath atScrollPosition:UITableViewScrollPositionTop animated:YES];
	}
}


- (void)tableView:(UITableView *)tableView didDeselectRowAtIndexPath:(NSIndexPath *)indexPath {
	if ([tableView indexPathForSelectedRow]) {
		return;
	}
	_commentFormLabel.text = [NSString stringWithFormat:@"Commenting on %@", self.post.postTitle];
}


- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath {
    return UITableViewCellEditingStyleNone;
}


- (BOOL)tableView:(UITableView *)tableView shouldIndentWhileEditingRowAtIndexPath:(NSIndexPath *)indexPath {
    return NO;
}


#pragma mark - UIScrollView Delegate Methods

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
	if ([self.tableView.visibleCells count] == 0 && _isShowingKeyboard) {
		[self handleCloseKeyboard:nil];
	}
}


#pragma mark - ReaderPostDetailView Delegate Methods

- (void)readerPostDetailViewLayoutChanged {
	self.tableView.tableHeaderView = _headerView;
}


#pragma mark - UITextView Delegate Methods

- (void)textViewDidBeginEditing:(UITextView *)textView {
	UIBarButtonItem *cancelButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(handleCloseKeyboard:)];
	if (!_sendCommentButton) {
		_sendCommentButton = [[UIBarButtonItem alloc] initWithTitle:@"Send" style:UIBarButtonItemStyleBordered target:self action:@selector(handleSendCommentButtonTapped:)];
	}
	[self.navigationItem setLeftBarButtonItem:cancelButton animated:NO];
	[self.navigationItem setRightBarButtonItem:_sendCommentButton animated:NO];
	
	_sendCommentButton.enabled = (_commentTextView.text.length == 0) ? NO : YES;
	_isShowingKeyboard = YES;
	_commentPromptLabel.hidden = YES;
	
	[self.tableView scrollToRowAtIndexPath:[self.tableView indexPathForSelectedRow] atScrollPosition:UITableViewScrollPositionTop animated:YES];
}


- (void)textViewDidChange:(UITextView *)textView {
	_sendCommentButton.enabled = (_commentTextView.text.length == 0) ? NO : YES;
}


- (void)textViewDidEndEditing:(UITextView *)textView {
	[self.navigationItem setLeftBarButtonItem:nil animated:NO];
	[self.navigationItem setRightBarButtonItem:self.shareButton animated:NO];
	_isShowingKeyboard = NO;
	_commentPromptLabel.hidden = (_commentTextView.text.length > 0) ? YES : NO;
}


#pragma mark - DetailView Delegate Methods

- (void)resetView {
	
}


#pragma mark -
#pragma mark Fetched results controller

- (NSFetchedResultsController *)resultsController {
    if (_resultsController != nil) {
        return _resultsController;
    }
	
	NSString *entityName = @"ReaderComment";
	NSManagedObjectContext *moc = [[WordPressAppDelegate sharedWordPressApplicationDelegate] managedObjectContext];
	
	NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    [fetchRequest setEntity:[NSEntityDescription entityForName:@"ReaderComment" inManagedObjectContext:moc]];
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"(post = %@) && (parentID = 0)", self.post];
    [fetchRequest setPredicate:predicate];
    NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"dateCreated" ascending:YES];
    [fetchRequest setSortDescriptors:[NSArray arrayWithObject:sortDescriptor]];
    
	_resultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest
                                                             managedObjectContext:moc
                                                               sectionNameKeyPath:nil
                                                                        cacheName:nil];
	
    NSError *error = nil;
    if (![_resultsController performFetch:&error]) {
        WPFLog(@"%@ couldn't fetch %@: %@", self, entityName, [error localizedDescription]);
        _resultsController = nil;
    }
    
    return _resultsController;
}


#pragma mark - UIActionSheet Delegate Methods

- (void)actionSheet:(UIActionSheet *)actionSheet didDismissWithButtonIndex:(NSInteger)buttonIndex {
	
	NSString *permaLink = self.post.permaLink;
	
	if (buttonIndex == 0) {
		NSURL *permaLinkURL;
		permaLinkURL = [[NSURL alloc] initWithString:(NSString *)permaLink];
        [[UIApplication sharedApplication] openURL:(NSURL *)permaLinkURL];
		
    } else if (buttonIndex == 1) {
        MFMailComposeViewController* controller = [[MFMailComposeViewController alloc] init];
        controller.mailComposeDelegate = self;
        
        NSString *title = self.post.postTitle;
        [controller setSubject: [title trim]];
        
        NSString *body = [permaLink trim];
        [controller setMessageBody:body isHTML:NO];
        
        if (controller)
            [self.panelNavigationController presentModalViewController:controller animated:YES];
		
        [self setMFMailFieldAsFirstResponder:controller.view mfMailField:@"MFRecipientTextField"];
		
    } else if ( buttonIndex == 2 ) {
        UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
        pasteboard.string = permaLink;
    }
}


#pragma mark - MFMailComposeViewControllerDelegate

- (void)mailComposeController:(MFMailComposeViewController*)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError*)error {
	[self dismissModalViewControllerAnimated:YES];
}

//Returns true if the ToAddress field was found any of the sub views and made first responder
//passing in @"MFComposeSubjectView"     as the value for field makes the subject become first responder
//passing in @"MFComposeTextContentView" as the value for field makes the body become first responder
//passing in @"RecipientTextField"       as the value for field makes the to address field become first responder
- (BOOL)setMFMailFieldAsFirstResponder:(UIView*)view mfMailField:(NSString*)field {
    for (UIView *subview in view.subviews) {
        
        NSString *className = [NSString stringWithFormat:@"%@", [subview class]];
        if ([className isEqualToString:field]) {
            //Found the sub view we need to set as first responder
            [subview becomeFirstResponder];
            return YES;
        }
        
        if ([subview.subviews count] > 0) {
            if ([self setMFMailFieldAsFirstResponder:subview mfMailField:field]){
                //Field was found and made first responder in a subview
                return YES;
            }
        }
    }
    
    //field not found in this view.
    return NO;
}


@end
