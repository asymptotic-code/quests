module challenge::staking;

use sui::balance::{Self, Balance};
use sui::clock::Clock;
use sui::coin::{Self, Coin};
use sui::event;
use sui::table::{Self, Table};

const MIN_APR_PERCENTAGE: u64 = 10;
const MAX_APR_PERCENTAGE: u64 = 1000;
const MIN_APR_DECIMALS: u8 = 2;
const MAX_APR_DECIMALS: u8 = 18;

const YEAR_IN_SECONDS: u64 = 365 * 24 * 60 * 60; // 1 year
const MAX_DURATION: u64 = YEAR_IN_SECONDS;
const MAX_COOLDOWN: u64 = 7 * 24 * 60 * 60; // 7 days

public struct Stake has copy, store {
    amount: u64,
    stake_timestamp: u64,
    unstake_timestamp: u64,
}

public struct Pool<phantom T> has key, store {
    id: UID,
    apr: u64,
    apr_base: u64,
    duration: u64,
    cooldown: u64,
    min_stake: u64,
    max_stake: u64,
    available_rewards: Balance<T>,
    locked_rewards: Balance<T>,
    stakes: Table<address, Stake>,
    total_staked: Balance<T>,
}

public fun get_apr<T>(self: &Pool<T>): (u64, u64) {
    (self.apr, self.apr_base)
}

public fun get_duration<T>(self: &Pool<T>): u64 {
    self.duration
}

public fun get_cooldown<T>(self: &Pool<T>): u64 {
    self.cooldown
}

public fun get_stake_limits<T>(self: &Pool<T>): (u64, u64) {
    (self.min_stake, self.max_stake)
}

public fun get_available_rewards<T>(self: &Pool<T>): u64 {
    self.available_rewards.value()
}

public fun get_locked_rewards<T>(self: &Pool<T>): u64 {
    self.locked_rewards.value()
}

public fun get_total_staked<T>(self: &Pool<T>): u64 {
    self.total_staked.value()
}

public fun get_stake_info<T>(self: &Pool<T>, user: address): Stake {
    *self.stakes.borrow(user)
}

public struct AdminCap has key, store {
    id: UID,
    pool_id: ID,
}

public fun create<T>(
    apr: u64,
    apr_decimals: u8,
    duration: u64,
    cooldown: u64,
    min_stake: u64,
    max_stake: u64,
    rewards: Coin<T>,
    ctx: &mut TxContext,
): (Pool<T>, AdminCap) {
    assert!(rewards.value() > 0);

    check_apr(apr, apr_decimals);
    check_duration(duration);
    check_cooldown(cooldown);
    check_stake_limits(min_stake, max_stake);

    let pool = Pool<T> {
        id: sui::object::new(ctx),
        apr,
        apr_base: 10u64.pow(apr_decimals),
        duration,
        cooldown,
        min_stake,
        max_stake,
        available_rewards: rewards.into_balance(),
        locked_rewards: balance::zero(),
        stakes: table::new(ctx),
        total_staked: balance::zero(),
    };

    let admin_cap = AdminCap {
        id: sui::object::new(ctx),
        pool_id: object::id(&pool),
    };

    (pool, admin_cap)
}

fun check_apr(apr: u64, decimals: u8) {
    assert!(decimals >= MIN_APR_DECIMALS && decimals <= MAX_APR_DECIMALS);
    let apr_percentage = ((apr as u128) * 100u128 / 10u128.pow(decimals)) as u64;
    assert!(apr_percentage >= MIN_APR_PERCENTAGE && apr_percentage <= MAX_APR_PERCENTAGE);
}

fun check_duration(duration: u64) {
    assert!(duration > 0 && duration <= MAX_DURATION);
}

fun check_cooldown(cooldown: u64) {
    assert!(cooldown > 0 && cooldown <= MAX_COOLDOWN);
}

fun check_stake_limits(min_stake: u64, max_stake: u64) {
    assert!(min_stake > 0 && max_stake >= min_stake);
}

public struct AprUpdated has copy, drop {
    pool_id: ID,
    new_apr: u64,
    new_precision: u8,
}

public struct DurationUpdated has copy, drop {
    pool_id: ID,
    new_duration: u64,
}

public struct CooldownUpdated has copy, drop {
    pool_id: ID,
    new_cooldown: u64,
}

public struct StakeLimitsUpdated has copy, drop {
    pool_id: ID,
    new_min: u64,
    new_max: u64,
}

public struct RewardsAdded has copy, drop {
    pool_id: ID,
    amount: u64,
}

fun update_rewards<T>(pool: &mut Pool<T>, apr: u64, apr_base: u64, duration: u64) {
    let old_locked_rewards = calculate_rewards(
        pool.total_staked.value(),
        pool.apr,
        pool.apr_base,
        pool.duration,
    );
    assert!(old_locked_rewards >= pool.locked_rewards.value());

    let new_locked_rewards = calculate_rewards(
        pool.total_staked.value(),
        apr,
        apr_base,
        duration,
    );
    pool.available_rewards.join(pool.locked_rewards.withdraw_all());
    assert!(new_locked_rewards <= pool.available_rewards.value());
    pool.locked_rewards.join(pool.available_rewards.split(new_locked_rewards));
}

public fun update_apr<T>(pool: &mut Pool<T>, _: &AdminCap, new_apr: u64, new_precision: u8) {
    check_apr(new_apr, new_precision);
    let new_apr_base = 10u64.pow(new_precision);
    assert!(pool.apr != new_apr || pool.apr_base != new_apr_base);

    let is_same =
        (pool.apr as u128) * (new_apr_base as u128) ==
        (new_apr as u128) * (pool.apr_base as u128);
    if (!is_same) {
        let duration = pool.duration;
        pool.update_rewards(new_apr, new_apr_base, duration);
    } else {
        assert!(pool.apr_base < new_apr_base);
    };

    pool.apr = new_apr;
    pool.apr_base = new_apr_base;

    event::emit(AprUpdated {
        pool_id: object::id(pool),
        new_apr,
        new_precision,
    });
}

public fun update_duration<T>(pool: &mut Pool<T>, _: &AdminCap, new_duration: u64) {
    assert!(pool.duration != new_duration);
    check_duration(new_duration);

    let (apr, apr_base) = pool.get_apr();
    pool.update_rewards(apr, apr_base, new_duration);

    pool.duration = new_duration;

    event::emit(DurationUpdated {
        pool_id: object::id(pool),
        new_duration,
    });
}

public fun update_cooldown<T>(pool: &mut Pool<T>, _: &AdminCap, new_cooldown: u64) {
    check_cooldown(new_cooldown);
    pool.cooldown = new_cooldown;
    event::emit(CooldownUpdated {
        pool_id: object::id(pool),
        new_cooldown,
    });
}

public fun update_stake_limits<T>(pool: &mut Pool<T>, _: &AdminCap, new_min: u64, new_max: u64) {
    check_stake_limits(new_max, new_min);
    assert!(new_min < new_max);
    pool.min_stake = new_min;
    pool.max_stake = new_max;
    event::emit(StakeLimitsUpdated {
        pool_id: object::id(pool),
        new_min,
        new_max,
    });
}

public fun add_rewards<T>(pool: &mut Pool<T>, additional_rewards: Coin<T>) {
    let amount = additional_rewards.value();
    assert!(amount > 0);
    pool.available_rewards.join(additional_rewards.into_balance());
    event::emit(RewardsAdded {
        pool_id: object::id(pool),
        amount,
    });
}

public struct Staked has copy, drop {
    user: address,
    amount: u64,
    timestamp: u64,
}

public struct UnstakeStarted has copy, drop {
    user: address,
    amount: u64,
    rewards: u64,
    timestamp: u64,
}

public struct UnstakeCompleted has copy, drop {
    user: address,
    amount: u64,
    rewards: u64,
    timestamp: u64,
}

public fun stake<T>(pool: &mut Pool<T>, funds: Coin<T>, clock: &Clock, ctx: &TxContext) {
    let mut amount = funds.value();
    assert!(amount >= pool.min_stake && amount <= pool.max_stake);
    assert!(pool.available_rewards.value() > 0);

    let user = ctx.sender();
    let timestamp = clock.timestamp_ms();
    if (pool.stakes.contains(ctx.sender())) {
        let Stake { amount: old_amount, stake_timestamp: _, unstake_timestamp: _ } = pool
            .stakes
            .remove(user);

        let locked_rewards = old_amount * pool.apr / pool.apr_base;
        let locked_rewards = locked_rewards * pool.duration / YEAR_IN_SECONDS;
        assert!(locked_rewards <= pool.locked_rewards.value());
        pool.available_rewards.join(pool.locked_rewards.split(locked_rewards));

        amount = amount + old_amount;
        assert!(amount <= pool.max_stake);
    };

    let rewards = calculate_rewards(amount, pool.apr, pool.apr_base, pool.duration);
    assert!(rewards <= pool.available_rewards.value());

    pool.locked_rewards.join(pool.available_rewards.split(rewards));
    pool.total_staked.join(funds.into_balance());

    pool
        .stakes
        .add(
            user,
            Stake {
                amount,
                stake_timestamp: timestamp,
                unstake_timestamp: 0,
            },
        );

    event::emit(Staked {
        user,
        amount,
        timestamp,
    });
}

public fun unstake_start<T>(pool: &mut Pool<T>, clock: &Clock, ctx: &TxContext) {
    let user = ctx.sender();
    let timestamp = clock.timestamp_ms();
    assert!(pool.stakes.contains(user));

    let stake = pool.stakes.borrow_mut(user);
    assert!(stake.unstake_timestamp == 0);
    stake.unstake_timestamp = timestamp;

    event::emit(UnstakeStarted {
        user,
        amount: stake.amount,
        rewards: calculate_rewards(stake.amount, pool.apr, pool.apr_base, pool.duration),
        timestamp,
    });
}

#[allow(lint(self_transfer))]
public fun unstake_complete<T>(pool: &mut Pool<T>, clock: &Clock, ctx: &mut TxContext) {
    let user = ctx.sender();
    let timestamp = clock.timestamp_ms();

    assert!(pool.stakes.contains(user));
    let Stake { amount, stake_timestamp: _, unstake_timestamp } = pool.stakes.remove(user);
    assert!(unstake_timestamp != 0);
    assert!(timestamp >= unstake_timestamp + pool.cooldown);

    let rewards = calculate_rewards(amount, pool.apr, pool.apr_base, pool.duration);

    let mut withdrawal = pool.total_staked.split(amount);
    withdrawal.join(pool.locked_rewards.split(rewards));
    transfer::public_transfer(coin::from_balance(withdrawal, ctx), user);

    event::emit(UnstakeCompleted {
        user,
        amount,
        rewards,
        timestamp,
    });
}

public fun calculate_rewards(amount: u64, apr: u64, apr_base: u64, duration: u64): u64 {
    if (amount == 0) {
        return 0
    };

    let rewards = (amount * apr) / apr_base;
    let rewards = rewards * duration / YEAR_IN_SECONDS;

    rewards
}
