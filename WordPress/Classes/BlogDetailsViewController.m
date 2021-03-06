#import "BlogDetailsViewController.h"
#import "Blog+Jetpack.h"
#import "EditSiteViewController.h"
#import "PagesViewController.h"
#import "CommentsViewController.h"
#import "ThemeBrowserViewController.h"
#import "MediaBrowserViewController.h"
#import "StatsViewController.h"
#import "WPWebViewController.h"
#import "WPTableViewCell.h"
#import "ContextManager.h"
#import "BlogService.h"

static NSString *const BlogDetailsCellIdentifier = @"BlogDetailsCell";

typedef enum {
    BlogDetailsRowPosts = 0,
    BlogDetailsRowPages,
    BlogDetailsRowComments,
    BlogDetailsRowStats,
    BlogDetailsRowMedia,
    BlogDetailsRowViewSite,
    BlogDetailsRowViewAdmin,
    BlogDetailsRowEdit,
    BlogDetailsRowCount
} BlogDetailsRow;

NSString * const WPBlogDetailsRestorationID = @"WPBlogDetailsID";
NSString * const WPBlogDetailsBlogKey = @"WPBlogDetailsBlogKey";


@interface BlogDetailsViewController ()

@end

@implementation BlogDetailsViewController
@synthesize blog = _blog;

+ (UIViewController *)viewControllerWithRestorationIdentifierPath:(NSArray *)identifierComponents coder:(NSCoder *)coder {
    NSString *blogID = [coder decodeObjectForKey:WPBlogDetailsBlogKey];
    if (!blogID)
        return nil;
    
    NSManagedObjectContext *context = [[ContextManager sharedInstance] mainContext];
    NSManagedObjectID *objectID = [context.persistentStoreCoordinator managedObjectIDForURIRepresentation:[NSURL URLWithString:blogID]];
    if (!objectID)
        return nil;
    
    NSError *error = nil;
    Blog *restoredBlog = (Blog *)[context existingObjectWithID:objectID error:&error];
    if (error || !restoredBlog) {
        return nil;
    }
    
    BlogDetailsViewController *viewController = [[self alloc] initWithStyle:UITableViewStyleGrouped];
    viewController.blog = restoredBlog;

    return viewController;
}

- (id)initWithStyle:(UITableViewStyle)style {
    self = [super initWithStyle:UITableViewStyleGrouped];
    if (self) {
        self.restorationIdentifier = WPBlogDetailsRestorationID;
        self.restorationClass = [self class];
    }
    return self;
}

- (void)encodeRestorableStateWithCoder:(NSCoder *)coder {
    [coder encodeObject:[[self.blog.objectID URIRepresentation] absoluteString] forKey:WPBlogDetailsBlogKey];
    [super encodeRestorableStateWithCoder:coder];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [WPStyleGuide configureColorsForView:self.view andTableView:self.tableView];
    
    if (IS_IPHONE) {
        // Account for 1 pixel header height
        UIEdgeInsets tableInset = [self.tableView contentInset];
        tableInset.top = -1;
        self.tableView.contentInset = tableInset;
    }
    
    [self.tableView registerClass:[WPTableViewCell class] forCellReuseIdentifier:BlogDetailsCellIdentifier];
    
    if (!_blog.options) {
        NSManagedObjectContext *context = [[ContextManager sharedInstance] mainContext];
        BlogService *blogService = [[BlogService alloc] initWithManagedObjectContext:context];

        [blogService syncOptionsForBlog:_blog success:nil failure:nil];
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [self.tableView reloadData];
}

- (void)setBlog:(Blog *)blog {
    _blog = blog;
    self.title = blog.blogName;
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return BlogDetailsRowCount;
}

- (void)configureCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.row == BlogDetailsRowPosts) {
        cell.textLabel.text = NSLocalizedString(@"Posts", nil);
        cell.imageView.image = [UIImage imageNamed:@"icon-menu-posts"];
    } else if (indexPath.row == BlogDetailsRowPages) {
        cell.textLabel.text = NSLocalizedString(@"Pages", nil);
        cell.imageView.image = [UIImage imageNamed:@"icon-menu-pages"];
    } else if (indexPath.row == BlogDetailsRowComments) {
        cell.textLabel.text = NSLocalizedString(@"Comments", nil);
        cell.imageView.image = [UIImage imageNamed:@"icon-menu-comments"];
        NSUInteger numberOfPendingComments = [self.blog numberOfPendingComments];
        if (numberOfPendingComments > 0) {
            cell.detailTextLabel.text = [NSString stringWithFormat:@"%d", numberOfPendingComments];
        }
    } else if (indexPath.row == BlogDetailsRowStats) {
        cell.textLabel.text = NSLocalizedString(@"Stats", nil);
        cell.imageView.image = [UIImage imageNamed:@"icon-menu-stats"];
    } else if ([self isRowForMedia:indexPath.row]) {
        cell.textLabel.text = NSLocalizedString(@"Media", nil);
        cell.imageView.image = [UIImage imageNamed:@"icon-menu-media"];
    } else if ([self isRowForViewSite:indexPath.row]) {
        cell.textLabel.text = NSLocalizedString(@"View Site", nil);
        cell.imageView.image = [UIImage imageNamed:@"icon-menu-viewsite"];
    } else if ([self isRowForViewAdmin:indexPath.row]) {
        cell.textLabel.text = NSLocalizedString(@"View Admin", nil);
        cell.imageView.image = [UIImage imageNamed:@"icon-menu-viewadmin"];
    } else if (indexPath.row == BlogDetailsRowEdit) {
        cell.textLabel.text = NSLocalizedString(@"Edit Site", nil);
        cell.imageView.image = [UIImage imageNamed:@"icon-menu-settings"];
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:BlogDetailsCellIdentifier];
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    [self configureCell:cell atIndexPath:indexPath];
    [WPStyleGuide configureTableViewCell:cell];

    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    if ([self isRowForEditBlog:indexPath.row]) {
        EditSiteViewController *editSiteViewController = [[EditSiteViewController alloc] initWithBlog:self.blog];
        [self.navigationController pushViewController:editSiteViewController animated:YES];
    }
    
    Class controllerClass;
    if (indexPath.row == BlogDetailsRowPosts) {
        [WPAnalytics track:WPAnalyticsStatOpenedPosts];
        controllerClass = [PostsViewController class];
    } else if (indexPath.row == BlogDetailsRowPages) {
        [WPAnalytics track:WPAnalyticsStatOpenedPages];
        controllerClass = [PagesViewController class];
    } else if (indexPath.row == BlogDetailsRowComments) {
        [WPAnalytics track:WPAnalyticsStatOpenedComments];
        controllerClass = [CommentsViewController class];
    } else if (indexPath.row == BlogDetailsRowStats) {
        [WPAnalytics track:WPAnalyticsStatStatsAccessed];
        controllerClass =  [StatsViewController class];
    } else if ([self isRowForMedia:indexPath.row]) {
        [WPAnalytics track:WPAnalyticsStatOpenedMediaLibrary];
        controllerClass = [MediaBrowserViewController class];
    } else if (indexPath.row == BlogDetailsRowViewSite) {
        [self showViewSiteForBlog:self.blog];
    } else if ([self isRowForViewAdmin:indexPath.row]) {
        [self showViewAdminForBlog:self.blog];
    }
  
    // Check if the controller is already on the screen
    if ([self.navigationController.visibleViewController isMemberOfClass:controllerClass]) {
        if ([self.navigationController.visibleViewController respondsToSelector:@selector(setBlog:)]) {
            [self.navigationController.visibleViewController performSelector:@selector(setBlog:) withObject:self.blog];
        }
        [self.navigationController popToRootViewControllerAnimated:NO];
    
        return;
    }

    UIViewController *viewController = (UIViewController *)[[controllerClass alloc] init];
    viewController.restorationIdentifier = NSStringFromClass(controllerClass);
    viewController.restorationClass = controllerClass;
    if ([viewController respondsToSelector:@selector(setBlog:)]) {
        [viewController performSelector:@selector(setBlog:) withObject:self.blog];
        [self.navigationController pushViewController:viewController animated:YES];
    }
    
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 54;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    // No top margin on iPhone
    if (IS_IPHONE)
        return 1;
    
    return 40;
}


#pragma mark - Private methods
- (void)showViewSiteForBlog:(Blog *)blog {
    [WPAnalytics track:WPAnalyticsStatOpenedViewSite];
    
    NSString *blogURL = blog.homeURL;
    if (![blogURL hasPrefix:@"http"]) {
        blogURL = [NSString stringWithFormat:@"http://%@", blogURL];
    } else if ([blog isWPcom] && [blog.url rangeOfString:@"wordpress.com"].location == NSNotFound) {
        blogURL = [blog.xmlrpc stringByReplacingOccurrencesOfString:@"xmlrpc.php" withString:@""];
    }
    
    // Check if the same site already loaded
    if ([self.navigationController.visibleViewController isMemberOfClass:[WPWebViewController class]] &&
        [((WPWebViewController*)self.navigationController.visibleViewController).url.absoluteString isEqual:blogURL]) {
        // Do nothing
    } else {
        WPWebViewController *webViewController = [[WPWebViewController alloc] init];
        [webViewController setUrl:[NSURL URLWithString:blogURL]];
        if ([blog isPrivate]) {
            [webViewController setUsername:blog.username];
            [webViewController setPassword:blog.password];
            [webViewController setWpLoginURL:[NSURL URLWithString:blog.loginUrl]];
        }
        [self.navigationController pushViewController:webViewController animated:YES];
    }
    return;
}

- (void)showViewAdminForBlog:(Blog *)blog
{
    [WPAnalytics track:WPAnalyticsStatOpenedViewAdmin];
    
    NSString *dashboardUrl = [blog.xmlrpc stringByReplacingOccurrencesOfString:@"xmlrpc.php" withString:@"wp-admin/"];
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:dashboardUrl]];
}

- (BOOL)isRowForMedia:(NSUInteger)index {
    return index == BlogDetailsRowMedia;
}

- (BOOL)isRowForViewSite:(NSUInteger)index {
    return index == BlogDetailsRowViewSite;
}

- (BOOL)isRowForViewAdmin:(NSUInteger)index {
    return index == BlogDetailsRowViewAdmin;
}

- (BOOL)isRowForEditBlog:(NSUInteger)index {
    return index == BlogDetailsRowEdit;
}

/*
// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the specified item to be editable.
    return YES;
}
*/

/*
// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        // Delete the row from the data source
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
    }   
    else if (editingStyle == UITableViewCellEditingStyleInsert) {
        // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
    }   
}
*/

/*
// Override to support rearranging the table view.
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath
{
}
*/

/*
// Override to support conditional rearranging of the table view.
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the item to be re-orderable.
    return YES;
}
*/


@end
