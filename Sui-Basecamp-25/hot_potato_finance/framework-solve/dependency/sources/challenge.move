module challenge::challenge;

use challenge::deposit_coin::DEPOSIT_COIN;
use challenge::oracle::{Self, PriceOracle};
use challenge::reward_coin::REWARD_COIN;
use challenge::reward_pool::{Self, RewardPool, PoolAdminCap};
use sui::balance::Supply;
use sui::coin::{Self, TreasuryCap};
use sui::vec_set::{Self, VecSet};

const INITIAL_REWARD: u64 = 10_000;
const DEPOSIT: u64 = 1_000;

const DEPOSIT_COIN_PRICE_VALUE: u64 = 1;
const DEPOSIT_COIN_PRICE_DECIMALS: u8 = 0;

public struct Challenge<phantom R, phantom D> has key, store {
    id: UID,
    oracle: PriceOracle,
    pool: RewardPool<R>,
    pool_admin: PoolAdminCap,
    reward_supply: Supply<R>,
    deposit_supply: Supply<D>,
    users_emulated_deposit: VecSet<address>,
}

public fun get_pool(self: &Challenge<REWARD_COIN, DEPOSIT_COIN>): &RewardPool<REWARD_COIN> {
    &self.pool
}

public fun get_pool_and_oracle(
    self: &mut Challenge<REWARD_COIN, DEPOSIT_COIN>,
): (&mut RewardPool<REWARD_COIN>, &PriceOracle) {
    (&mut self.pool, &self.oracle)
}

public fun create(
    reward_treasury: TreasuryCap<REWARD_COIN>,
    deposit_treasury: TreasuryCap<DEPOSIT_COIN>,
    ctx: &mut TxContext,
) {
    let mut reward_supply = reward_treasury.treasury_into_supply();
    assert!(reward_supply.supply_value() == 0);
    let mut deposit_supply = deposit_treasury.treasury_into_supply();
    assert!(deposit_supply.supply_value() == 0);

    let mut oracle = oracle::create(ctx);
    oracle.set_price<DEPOSIT_COIN>(DEPOSIT_COIN_PRICE_VALUE, DEPOSIT_COIN_PRICE_DECIMALS);

    let rewards = reward_supply.increase_supply(INITIAL_REWARD);
    let (mut pool, pool_admin) = reward_pool::create<REWARD_COIN>(
        coin::from_balance(rewards, ctx),
        ctx,
    );

    let deposit = deposit_supply.increase_supply(INITIAL_REWARD);
    pool.deposit<REWARD_COIN, DEPOSIT_COIN>(coin::from_balance(deposit, ctx), &oracle, ctx);

    pool.allow_claiming(&pool_admin);

    let challenge = Challenge {
        id: object::new(ctx),
        oracle,
        pool,
        pool_admin,
        reward_supply,
        deposit_supply,
        users_emulated_deposit: vec_set::empty(),
    };
    transfer::public_share_object(challenge);
}

public fun emulate_deposit(self: &mut Challenge<REWARD_COIN, DEPOSIT_COIN>, ctx: &mut TxContext) {
    let user = ctx.sender();
    assert!(!self.users_emulated_deposit.contains(&user));
    self.users_emulated_deposit.insert(user);

    let reward = self.reward_supply.increase_supply(DEPOSIT);
    let deposit = self.deposit_supply.increase_supply(DEPOSIT);

    self.pool.emulate_deposit(user, deposit);
    self.pool.increase_rewards<REWARD_COIN>(&self.pool_admin, coin::from_balance(reward, ctx));
}

public fun is_solved(challenge: &Challenge<REWARD_COIN, DEPOSIT_COIN>) {
    let solved = challenge.get_pool().is_solved();
    assert!(solved);
}
