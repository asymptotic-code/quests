module challenge::challenge;

use challenge::staking::{Self, Pool, AdminCap};
use challenge::coin::COIN;
use sui::balance::Supply;
use sui::clock::Clock;
use sui::coin::{Self, Coin, TreasuryCap};
use sui::vec_set::{Self, VecSet};

const INITIAL_STAKE: u64 = 1000;
const CLAIM_AMOUNT: u64 = 100;

const APR: u64 = 1000;
const APR_DECIMALS: u8 = 3;
const DURATION: u64 = 90 * 24 * 60 * 60; // 90 days
const COOLDOWN: u64 = 24 * 60 * 60; // 1 day
const MIN_STAKE: u64 = 200;
const MAX_STAKE: u64 = 1_000_000;

public struct Challenge<phantom T> has key, store {
    id: UID,
    pool: Pool<T>,
    admin_cap: AdminCap,
    coin_supply: Supply<T>,
    claimed_users: VecSet<address>,
}

public fun get_pool(self: &mut Challenge<COIN>): &mut Pool<COIN> {
    &mut self.pool
}

public fun create(coin_treasury: TreasuryCap<COIN>, clock: &Clock, ctx: &mut TxContext) {
    let mut coin_supply = coin_treasury.treasury_into_supply();
    assert!(coin_supply.supply_value() == 0);

    let rewards = coin_supply.increase_supply(INITIAL_STAKE);

    let (mut pool, admin_cap) = staking::create<COIN>(
        APR,
        APR_DECIMALS,
        DURATION,
        COOLDOWN,
        MIN_STAKE,
        MAX_STAKE,
        coin::from_balance(rewards, ctx),
        ctx,
    );

    let stake = coin_supply.increase_supply(INITIAL_STAKE);
    pool.stake(coin::from_balance(stake, ctx), clock, ctx);

    let challenge = Challenge {
        id: object::new(ctx),
        pool,
        admin_cap,
        coin_supply,
        claimed_users: vec_set::empty(),
    };
    transfer::public_share_object(challenge);
}

public fun claim_coin(self: &mut Challenge<COIN>, ctx: &mut TxContext): Coin<COIN> {
    let user = ctx.sender();
    assert!(!self.claimed_users.contains(&user));
    self.claimed_users.insert(user);

    let mut balance = self.coin_supply.increase_supply(CLAIM_AMOUNT);
    self.pool.add_rewards(coin::from_balance(balance, ctx));

    balance = self.coin_supply.increase_supply(CLAIM_AMOUNT);
    coin::from_balance(balance, ctx)
}

public fun is_solved(challenge: &mut Challenge<COIN>, clock: &Clock, ctx: &mut TxContext) {
    let (min_stake, _) = challenge.pool.get_stake_limits();
    let stake = challenge.coin_supply.increase_supply(min_stake);
    challenge.pool.stake(coin::from_balance(stake, ctx), clock, ctx);
}
