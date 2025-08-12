module scard::scard;

use std::string::String;
use sui::url::Url;

// ===== Structs =====

public struct User has key {
    id: UID,
    info: PersonalInformation,
    completed_tasks: vector<Task>,
    badges: vector<Badge>,
    points: u64,
}

public struct PersonalInformation has store {
    name: String,
    address: address,
    email: String,
    image: Option<Url>,
    bio: Option<String>,
}

public struct Task has key, store {
    id: UID,
    info: TaskInformation,
    points: u64,
    total_points: u64,
    required_badges: vector<Badge>,
    eligible_users: vector<address>,
}

public struct TaskInformation has store {
    title: String,
    description: String,
    url: Option<Url>,
}

public struct Badge has key, store {
    id: UID,
    info: BadgeInformation,
    eligible_users: vector<address>,
}

public struct BadgeInformation has store {
    title: String,
    description: String,
    image: Url,
}

public struct AdminCap has key {
    id: UID,
}

public struct RoleManager has key {
    id: UID,
    task_manager: vector<address>,
    badge_manager: vector<address>,
}

// ===== Errors =====

const EWrongTaskManager: u64 = 0;
const EWrongBadgeManager: u64 = 1;
const ETaskAlreadyCompleted: u64 = 2;
const EBadgeAlreadyCollected: u64 = 3;
const EUserNotEligible: u64 = 4;
const EWrongUser: u64 = 5;
const EUserAlreadyExists: u64 = 6;
const EBadgeAlreadyExists: u64 = 7;

// ===== Functions =====

fun init(ctx: &mut TxContext) {
    let role_manager = RoleManager {
        id: object::new(ctx),
        task_manager: vector::empty(),
        badge_manager: vector::empty(),
    };
    let admin_cap = AdminCap {
        id: object::new(ctx),
    };
    transfer::transfer(admin_cap, ctx.sender());
    transfer::share_object(role_manager);
}

// TODO: Burda kullanıcının birden fazla kez hesap oluşturmasını bir şekilde engellememiz lazım. DF belki kullanılabilir ama emin değilim.
public fun create_user(
    name: String,
    email: String,
    image: Option<Url>,
    bio: Option<String>,
    ctx: &mut TxContext,
) {
    let user = create_user_inner(name, email, image, bio, ctx);
    transfer::transfer(user, ctx.sender());
}

#[allow(lint(share_owned))]
public fun create_task(
    title: String,
    description: String,
    url: Option<Url>,
    points: u64,
    total_points: u64,
    required_badges: vector<Badge>,
    role_manager: &RoleManager,
    ctx: &mut TxContext,
) {
    assert!(
        vector::contains(&role_manager.task_manager, &ctx.sender()),
        EWrongTaskManager
    );
    let task = create_task_inner(title, description, url, points, total_points, required_badges, ctx);
    transfer::share_object(task);
}

public fun create_badge(
    title: String,
    description: String,
    image: Url,
    role_manager: &RoleManager,
    ctx: &mut TxContext,
) {
    assert!(
        vector::contains(&role_manager.badge_manager, &ctx.sender()),
        EWrongBadgeManager
    );
    let badge = create_badge_inner(title, description, image, ctx);
    transfer::share_object(badge);
}

public fun claim_badge(
    badge: Badge,
    user: &mut User,
    ctx: &mut TxContext,
) {
    assert!(
        vector::contains(&badge.eligible_users, &ctx.sender()),
        EUserNotEligible
    );
    assert!(user.info.address == ctx.sender(), EWrongUser);
    assert!(!vector::contains(&user.badges, &badge), EBadgeAlreadyCollected);
    vector::push_back(&mut user.badges, badge);
}

public fun complete_task(
    task: Task,
    user: &mut User,
    ctx: &mut TxContext,
) {
    assert!(user.info.address == ctx.sender(), EWrongUser);
    assert!(!vector::contains(&user.completed_tasks, &task), ETaskAlreadyCompleted);
    assert!(vector::contains(&task.eligible_users, &ctx.sender()), EUserNotEligible);
    user.points = user.points + task.points;

    vector::push_back(&mut user.completed_tasks, task);
}

public fun add_eligible_user_to_task(
    task: &mut Task,
    eligible_user: address,
    task_manager: &RoleManager,
    ctx: &mut TxContext,
) {
    assert!(
        vector::contains(&task_manager.task_manager, &ctx.sender()),
        EWrongTaskManager
    );
    assert!(!vector::contains(&task.eligible_users, &eligible_user), EUserAlreadyExists);
    vector::push_back(&mut task.eligible_users, eligible_user);
}

public fun add_eligible_user_to_badge(
    badge: &mut Badge,
    eligible_user: address,
    task_manager: &RoleManager,
    ctx: &mut TxContext,
) {
    assert!(
        vector::contains(&task_manager.task_manager, &ctx.sender()),
        EWrongTaskManager
    );
    assert!(!vector::contains(&badge.eligible_users, &eligible_user), EUserAlreadyExists);
    vector::push_back(&mut badge.eligible_users, eligible_user);
}

public fun remove_eligible_user_from_task(
    task: Task,
    eligible_user: address,
    task_manager: &RoleManager,
    ctx: &mut TxContext,
) {
    assert!(
        vector::contains(&task_manager.task_manager, &ctx.sender()),
        EWrongTaskManager
    );
    // TODO: Implement this
}

public fun remove_eligible_user_from_badge(
    badge: Badge,
    eligible_user: address,
    task_manager: &RoleManager,
    ctx: &mut TxContext,
) {
    assert!(
        vector::contains(&task_manager.task_manager, &ctx.sender()),
        EWrongBadgeManager
    );
    // TODO: Implement this
}

public fun add_badge_to_task(
    task: &mut Task,
    badge: Badge,
    task_manager: &RoleManager,
    ctx: &mut TxContext,
) {
    assert!(
        vector::contains(&task_manager.task_manager, &ctx.sender()),
        EWrongTaskManager
    );
    assert!(!vector::contains(&task.required_badges, &badge), EBadgeAlreadyExists);
    vector::push_back(&mut task.required_badges, badge);
}

public fun remove_badge_from_task(
    task: &mut Task,
    badge: Badge,
    task_manager: &RoleManager,
    ctx: &mut TxContext,
) {
    // TODO: Implement this
}

public fun update_role_manager(
    _: &AdminCap,
    role_manager: &mut RoleManager,
    task_manager: vector<address>,
    badge_manager: vector<address>,
    ctx: &mut TxContext,
) {
    role_manager.task_manager = task_manager;
    role_manager.badge_manager = badge_manager;
}

// ===== Internal Functions =====

fun create_user_inner(
    name: String,
    email: String,
    image: Option<Url>,
    bio: Option<String>,
    ctx: &mut TxContext,
): User {
    User {
        id: object::new(ctx),
        info: PersonalInformation {
            name: name,
            address: ctx.sender(),
            email: email,
            image: image,
            bio: bio,
        },
        completed_tasks: vector::empty(),
        badges: vector::empty(),
        points: 0,
    }
}

fun create_task_inner(
    title: String,
    description: String,
    url: Option<Url>,
    points: u64,
    total_points: u64,
    required_badges: vector<Badge>,
    ctx: &mut TxContext,
): Task {
    Task {
        id: object::new(ctx),
        info: TaskInformation {
            title,
            description,
            url,
        },
        points,
        total_points: points,
        required_badges,
        eligible_users: vector::empty(),
    }
}

fun create_badge_inner(
    title: String,
    description: String,
    image: Url,
    ctx: &mut TxContext,
): Badge {
    Badge {
        id: object::new(ctx),
        info: BadgeInformation {
            title,
            description,
            image,
        },
        eligible_users: vector::empty(),
    }
}

