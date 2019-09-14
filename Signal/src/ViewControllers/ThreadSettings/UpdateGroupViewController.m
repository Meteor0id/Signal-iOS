//
//  Copyright (c) 2019 Open Whisper Systems. All rights reserved.
//

#import "UpdateGroupViewController.h"
#import "AddToGroupViewController.h"
#import "AvatarViewHelper.h"
#import "OWSNavigationController.h"
#import "Signal-Swift.h"
#import "ViewControllerUtils.h"
#import <SignalCoreKit/NSDate+OWS.h>
#import <SignalCoreKit/NSString+OWS.h>
#import <SignalMessaging/BlockListUIUtils.h>
#import <SignalMessaging/ContactTableViewCell.h>
#import <SignalMessaging/ContactsViewHelper.h>
#import <SignalMessaging/Environment.h>
#import <SignalMessaging/OWSContactsManager.h>
#import <SignalMessaging/OWSTableViewController.h>
#import <SignalMessaging/UIUtil.h>
#import <SignalMessaging/UIView+OWS.h>
#import <SignalMessaging/UIViewController+OWS.h>
#import <SignalServiceKit/OWSMessageSender.h>
#import <SignalServiceKit/SignalAccount.h>
#import <SignalServiceKit/TSGroupModel.h>
#import <SignalServiceKit/TSGroupThread.h>
#import <SignalServiceKit/TSOutgoingMessage.h>

NS_ASSUME_NONNULL_BEGIN

@interface UpdateGroupViewController () <UIImagePickerControllerDelegate,
    UITextFieldDelegate,
    ContactsViewHelperDelegate,
    AvatarViewHelperDelegate,
    AddToGroupViewControllerDelegate,
    OWSTableViewControllerDelegate,
    UINavigationControllerDelegate,
    OWSNavigationView>

@property (nonatomic, readonly) OWSMessageSender *messageSender;
@property (nonatomic, readonly) ContactsViewHelper *contactsViewHelper;
@property (nonatomic, readonly) AvatarViewHelper *avatarViewHelper;

@property (nonatomic, readonly) OWSTableViewController *tableViewController;
@property (nonatomic, readonly) AvatarImageView *avatarView;
@property (nonatomic, readonly) UIImageView *cameraImageView;
@property (nonatomic, readonly) UITextField *groupNameTextField;

@property (nonatomic, nullable) UIImage *groupAvatar;
@property (nonatomic, nullable) NSSet<SignalServiceAddress *> *previousMemberAddresses;
@property (nonatomic) NSMutableSet<SignalServiceAddress *> *memberAddresses;

@property (nonatomic) BOOL hasUnsavedChanges;

@end

#pragma mark -

@implementation UpdateGroupViewController

- (instancetype)init
{
    self = [super init];
    if (!self) {
        return self;
    }

    [self commonInit];

    return self;
}

- (nullable instancetype)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (!self) {
        return self;
    }

    [self commonInit];

    return self;
}

- (void)commonInit
{
    _messageSender = SSKEnvironment.shared.messageSender;
    _contactsViewHelper = [[ContactsViewHelper alloc] initWithDelegate:self];
    _avatarViewHelper = [AvatarViewHelper new];
    _avatarViewHelper.delegate = self;

    self.memberAddresses = [NSMutableSet new];
}

#pragma mark - View Lifecycle

- (void)loadView
{
    [super loadView];

    OWSAssertDebug(self.thread);
    OWSAssertDebug(self.thread.groupModel);
    OWSAssertDebug(self.thread.groupModel.groupMembers);

    self.view.backgroundColor = Theme.backgroundColor;

    [self.memberAddresses addObjectsFromArray:self.thread.groupModel.groupMembers];
    self.previousMemberAddresses = [NSSet setWithArray:self.thread.groupModel.groupMembers];

    self.title = NSLocalizedString(@"EDIT_GROUP_DEFAULT_TITLE", @"The navbar title for the 'update group' view.");

    // First section.

    UIView *firstSection = [self firstSectionHeader];
    [self.view addSubview:firstSection];
    [firstSection autoSetDimension:ALDimensionHeight toSize:100.f];
    [firstSection autoPinWidthToSuperview];
    [firstSection autoPinToTopLayoutGuideOfViewController:self withInset:0];

    _tableViewController = [OWSTableViewController new];
    _tableViewController.delegate = self;
    [self.view addSubview:self.tableViewController.view];
    [self.tableViewController.view autoPinEdgeToSuperviewSafeArea:ALEdgeLeading];
    [self.tableViewController.view autoPinEdgeToSuperviewSafeArea:ALEdgeTrailing];
    [_tableViewController.view autoPinEdge:ALEdgeTop toEdge:ALEdgeBottom ofView:firstSection];
    [self autoPinViewToBottomOfViewControllerOrKeyboard:self.tableViewController.view avoidNotch:NO];
    self.tableViewController.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableViewController.tableView.estimatedRowHeight = 60;

    [self updateTableContents];
}

- (void)setHasUnsavedChanges:(BOOL)hasUnsavedChanges
{
    _hasUnsavedChanges = hasUnsavedChanges;

    [self updateNavigationBar];
}

- (void)updateNavigationBar
{
    self.navigationItem.rightBarButtonItem = (self.hasUnsavedChanges
            ? [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"EDIT_GROUP_UPDATE_BUTTON",
                                                         @"The title for the 'update group' button.")
                                               style:UIBarButtonItemStylePlain
                                              target:self
                                              action:@selector(updateGroupPressed)
                             accessibilityIdentifier:ACCESSIBILITY_IDENTIFIER_WITH_NAME(self, @"update")]
            : nil);
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];

    switch (self.mode) {
        case UpdateGroupMode_EditGroupName:
            [self.groupNameTextField becomeFirstResponder];
            break;
        case UpdateGroupMode_EditGroupAvatar:
            [self showChangeAvatarUI];
            break;
        default:
            break;
    }
    // Only perform these actions the first time the view appears.
    self.mode = UpdateGroupMode_Default;
}

- (UIView *)firstSectionHeader
{
    OWSAssertDebug(self.thread);
    OWSAssertDebug(self.thread.groupModel);

    UIView *firstSectionHeader = [UIView new];
    firstSectionHeader.userInteractionEnabled = YES;
    [firstSectionHeader
        addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(headerWasTapped:)]];
    firstSectionHeader.backgroundColor = [Theme backgroundColor];
    UIView *threadInfoView = [UIView new];
    [firstSectionHeader addSubview:threadInfoView];
    [threadInfoView autoPinWidthToSuperviewWithMargin:16.f];
    [threadInfoView autoPinHeightToSuperviewWithMargin:16.f];

    AvatarImageView *avatarView = [AvatarImageView new];
    _avatarView = avatarView;

    [threadInfoView addSubview:avatarView];
    [avatarView autoVCenterInSuperview];
    [avatarView autoPinLeadingToSuperviewMargin];
    [avatarView autoSetDimension:ALDimensionWidth toSize:kLargeAvatarSize];
    [avatarView autoSetDimension:ALDimensionHeight toSize:kLargeAvatarSize];
    _groupAvatar = self.thread.groupModel.groupImage;

    UIImage *cameraImage = [UIImage imageNamed:@"settings-avatar-camera"];
    UIImageView *cameraImageView = [[UIImageView alloc] initWithImage:cameraImage];
    [threadInfoView addSubview:cameraImageView];
    [cameraImageView autoPinTrailingToEdgeOfView:avatarView];
    [cameraImageView autoPinEdge:ALEdgeBottom toEdge:ALEdgeBottom ofView:avatarView];
    _cameraImageView = cameraImageView;

    [self updateAvatarView];

    UITextField *groupNameTextField = [OWSTextField new];
    _groupNameTextField = groupNameTextField;
    self.groupNameTextField.text = [self.thread.groupModel.groupName ows_stripped];
    groupNameTextField.textColor = [Theme primaryColor];
    groupNameTextField.font = [UIFont ows_dynamicTypeTitle2Font];
    groupNameTextField.placeholder
        = NSLocalizedString(@"NEW_GROUP_NAMEGROUP_REQUEST_DEFAULT", @"Placeholder text for group name field");
    groupNameTextField.delegate = self;
    [groupNameTextField addTarget:self
                           action:@selector(groupNameDidChange:)
                 forControlEvents:UIControlEventEditingChanged];
    [threadInfoView addSubview:groupNameTextField];
    [groupNameTextField autoVCenterInSuperview];
    [groupNameTextField autoPinTrailingToSuperviewMargin];
    [groupNameTextField autoPinLeadingToTrailingEdgeOfView:avatarView offset:16.f];
    SET_SUBVIEW_ACCESSIBILITY_IDENTIFIER(self, groupNameTextField);

    [avatarView
        addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(avatarTouched:)]];
    avatarView.userInteractionEnabled = YES;
    SET_SUBVIEW_ACCESSIBILITY_IDENTIFIER(self, avatarView);

    return firstSectionHeader;
}

- (void)headerWasTapped:(UIGestureRecognizer *)sender
{
    if (sender.state == UIGestureRecognizerStateRecognized) {
        [self.groupNameTextField becomeFirstResponder];
    }
}

- (void)avatarTouched:(UIGestureRecognizer *)sender
{
    if (sender.state == UIGestureRecognizerStateRecognized) {
        [self showChangeAvatarUI];
    }
}

#pragma mark - Table Contents

- (void)updateTableContents
{
    OWSAssertDebug(self.thread);

    OWSTableContents *contents = [OWSTableContents new];

    __weak UpdateGroupViewController *weakSelf = self;
    ContactsViewHelper *contactsViewHelper = self.contactsViewHelper;

    // Group Members

    OWSTableSection *section = [OWSTableSection new];
    section.headerTitle = NSLocalizedString(
        @"EDIT_GROUP_MEMBERS_SECTION_TITLE", @"a title for the members section of the 'new/update group' view.");

    [section
        addItem:[OWSTableItem
                     disclosureItemWithText:NSLocalizedString(@"EDIT_GROUP_MEMBERS_ADD_MEMBER",
                                                @"Label for the cell that lets you add a new member to a group.")
                    accessibilityIdentifier:ACCESSIBILITY_IDENTIFIER_WITH_NAME(UpdateGroupViewController, @"add_member")
                            customRowHeight:UITableViewAutomaticDimension
                                actionBlock:^{
                                    AddToGroupViewController *viewController = [AddToGroupViewController new];
                                    viewController.addToGroupDelegate = weakSelf;
                                    [weakSelf.navigationController pushViewController:viewController animated:YES];
                                }]];

    NSMutableSet *memberAddresses = [self.memberAddresses mutableCopy];
    [memberAddresses removeObject:[contactsViewHelper localAddress]];

    for (SignalServiceAddress *address in [memberAddresses.allObjects sortedArrayUsingSelector:@selector(compare:)]) {
        [section
            addItem:[OWSTableItem
                        itemWithCustomCellBlock:^{
                            UpdateGroupViewController *strongSelf = weakSelf;
                            OWSCAssertDebug(strongSelf);

                            ContactTableViewCell *cell = [ContactTableViewCell new];
                            BOOL isPreviousMember = [strongSelf.previousMemberAddresses containsObject:address];
                            BOOL isBlocked = [contactsViewHelper isSignalServiceAddressBlocked:address];
                            if (isPreviousMember) {
                                if (isBlocked) {
                                    cell.accessoryMessage = MessageStrings.conversationIsBlocked;
                                } else {
                                    cell.selectionStyle = UITableViewCellSelectionStyleNone;
                                }
                            } else {
                                // In the "members" section, we label "new" members as such when editing an existing
                                // group.
                                //
                                // The only way a "new" member could be blocked is if we blocked them on a linked device
                                // while in this dialog.  We don't need to worry about that edge case.
                                cell.accessoryMessage = NSLocalizedString(@"EDIT_GROUP_NEW_MEMBER_LABEL",
                                    @"An indicator that a user is a new member of the group.");
                            }

                            [cell configureWithRecipientAddress:address];

                            // TODO: Confirm with nancy if this will work.
                            NSString *cellName = [NSString stringWithFormat:@"member.%@", address.stringForDisplay];
                            cell.accessibilityIdentifier
                                = ACCESSIBILITY_IDENTIFIER_WITH_NAME(UpdateGroupViewController, cellName);

                            return cell;
                        }
                        customRowHeight:UITableViewAutomaticDimension
                        actionBlock:^{
                            SignalAccount *_Nullable signalAccount =
                                [contactsViewHelper fetchSignalAccountForAddress:address];
                            BOOL isPreviousMember = [weakSelf.previousMemberAddresses containsObject:address];
                            BOOL isBlocked = [contactsViewHelper isSignalServiceAddressBlocked:address];
                            if (isPreviousMember) {
                                if (isBlocked) {
                                    if (signalAccount) {
                                        [weakSelf showUnblockAlertForSignalAccount:signalAccount];
                                    } else {
                                        [weakSelf showUnblockAlertForRecipientAddress:address];
                                    }
                                } else {
                                    [OWSAlerts
                                        showAlertWithTitle:
                                            NSLocalizedString(@"UPDATE_GROUP_CANT_REMOVE_MEMBERS_ALERT_TITLE",
                                                @"Title for alert indicating that group members can't be removed.")
                                                   message:NSLocalizedString(
                                                               @"UPDATE_GROUP_CANT_REMOVE_MEMBERS_ALERT_MESSAGE",
                                                               @"Title for alert indicating that group members can't "
                                                               @"be removed.")];
                                }
                            } else {
                                [weakSelf removeRecipientAddress:address];
                            }
                        }]];
    }
    [contents addSection:section];

    self.tableViewController.contents = contents;
}

- (void)showUnblockAlertForSignalAccount:(SignalAccount *)signalAccount
{
    OWSAssertDebug(signalAccount);

    __weak UpdateGroupViewController *weakSelf = self;
    [BlockListUIUtils showUnblockSignalAccountActionSheet:signalAccount
                                       fromViewController:self
                                          blockingManager:self.contactsViewHelper.blockingManager
                                          contactsManager:self.contactsViewHelper.contactsManager
                                          completionBlock:^(BOOL isBlocked) {
                                              if (!isBlocked) {
                                                  [weakSelf updateTableContents];
                                              }
                                          }];
}

- (void)showUnblockAlertForRecipientAddress:(SignalServiceAddress *)address
{
    OWSAssertDebug(address.isValid);

    __weak UpdateGroupViewController *weakSelf = self;
    [BlockListUIUtils showUnblockAddressActionSheet:address
                                 fromViewController:self
                                    blockingManager:self.contactsViewHelper.blockingManager
                                    contactsManager:self.contactsViewHelper.contactsManager
                                    completionBlock:^(BOOL isBlocked) {
                                        if (!isBlocked) {
                                            [weakSelf updateTableContents];
                                        }
                                    }];
}

- (void)removeRecipientAddress:(SignalServiceAddress *)address
{
    OWSAssertDebug(address.isValid);

    [self.memberAddresses removeObject:address];
    [self updateTableContents];
}

#pragma mark - Methods

- (void)updateGroup
{
    OWSAssertDebug(self.conversationSettingsViewDelegate);

    [self.groupNameTextField acceptAutocorrectSuggestion];

    NSString *groupName = [self.groupNameTextField.text ows_stripped];
    TSGroupModel *groupModel = [[TSGroupModel alloc] initWithTitle:groupName
                                                           members:self.memberAddresses.allObjects
                                                             image:self.groupAvatar
                                                           groupId:self.thread.groupModel.groupId];
    [self.conversationSettingsViewDelegate groupWasUpdated:groupModel];
}

#pragma mark - Group Avatar

- (void)showChangeAvatarUI
{
    [self.groupNameTextField resignFirstResponder];

    [self.avatarViewHelper showChangeAvatarUI];
}

- (void)setGroupAvatar:(nullable UIImage *)groupAvatar
{
    OWSAssertIsOnMainThread();

    _groupAvatar = groupAvatar;

    self.hasUnsavedChanges = YES;

    [self updateAvatarView];
}

- (void)updateAvatarView
{
    UIImage *_Nullable groupAvatar = self.groupAvatar;
    self.cameraImageView.hidden = groupAvatar != nil;

    if (!groupAvatar) {
        groupAvatar = [[[OWSGroupAvatarBuilder alloc] initWithThread:self.thread diameter:kLargeAvatarSize] build];
    }

    self.avatarView.image = groupAvatar;
}

#pragma mark - Event Handling

- (void)backButtonPressed
{
    [self.groupNameTextField resignFirstResponder];

    if (!self.hasUnsavedChanges) {
        // If user made no changes, return to conversation settings view.
        [self.navigationController popViewControllerAnimated:YES];
        return;
    }

    UIAlertController *alert = [UIAlertController
        alertControllerWithTitle:NSLocalizedString(@"EDIT_GROUP_VIEW_UNSAVED_CHANGES_TITLE",
                                     @"The alert title if user tries to exit update group view without saving changes.")
                         message:
                             NSLocalizedString(@"EDIT_GROUP_VIEW_UNSAVED_CHANGES_MESSAGE",
                                 @"The alert message if user tries to exit update group view without saving changes.")
                  preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"ALERT_SAVE",
                                                        @"The label for the 'save' button in action sheets.")
                            accessibilityIdentifier:ACCESSIBILITY_IDENTIFIER_WITH_NAME(self, @"save")
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction *action) {
                                                OWSAssertDebug(self.conversationSettingsViewDelegate);

                                                [self updateGroup];

                                                [self.conversationSettingsViewDelegate
                                                    popAllConversationSettingsViewsWithCompletion:nil];
                                            }]];
    [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"ALERT_DONT_SAVE",
                                                        @"The label for the 'don't save' button in action sheets.")
                            accessibilityIdentifier:ACCESSIBILITY_IDENTIFIER_WITH_NAME(self, @"dont_save")
                                              style:UIAlertActionStyleDestructive
                                            handler:^(UIAlertAction *action) {
                                                [self.navigationController popViewControllerAnimated:YES];
                                            }]];
    [self presentAlert:alert];
}

- (void)updateGroupPressed
{
    OWSAssertDebug(self.conversationSettingsViewDelegate);

    [self updateGroup];

    [self.conversationSettingsViewDelegate popAllConversationSettingsViewsWithCompletion:nil];
}

- (void)groupNameDidChange:(id)sender
{
    self.hasUnsavedChanges = YES;
}

#pragma mark - Text Field Delegate

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    [self.groupNameTextField resignFirstResponder];
    return NO;
}

#pragma mark - OWSTableViewControllerDelegate

- (void)tableViewWillBeginDragging
{
    [self.groupNameTextField resignFirstResponder];
}

#pragma mark - ContactsViewHelperDelegate

- (void)contactsViewHelperDidUpdateContacts
{
    [self updateTableContents];
}

- (BOOL)shouldHideLocalNumber
{
    return YES;
}

#pragma mark - AvatarViewHelperDelegate

- (nullable NSString *)avatarActionSheetTitle
{
    return NSLocalizedString(
        @"NEW_GROUP_ADD_PHOTO_ACTION", @"Action Sheet title prompting the user for a group avatar");
}

- (void)avatarDidChange:(UIImage *)image
{
    OWSAssertIsOnMainThread();
    OWSAssertDebug(image);

    self.groupAvatar = image;
}

- (UIViewController *)fromViewController
{
    return self;
}

- (BOOL)hasClearAvatarAction
{
    return NO;
}

#pragma mark - AddToGroupViewControllerDelegate

- (void)recipientAddressWasAdded:(SignalServiceAddress *)address
{
    OWSAssertDebug(address.isValid);
    [self.memberAddresses addObject:address];
    self.hasUnsavedChanges = YES;
    [self updateTableContents];
}

- (BOOL)isRecipientGroupMember:(SignalServiceAddress *)address
{
    OWSAssertDebug(address.isValid);

    return [self.memberAddresses containsObject:address];
}

#pragma mark - OWSNavigationView

- (BOOL)shouldCancelNavigationBack
{
    BOOL result = self.hasUnsavedChanges;
    if (result) {
        [self backButtonPressed];
    }
    return result;
}

@end

NS_ASSUME_NONNULL_END
