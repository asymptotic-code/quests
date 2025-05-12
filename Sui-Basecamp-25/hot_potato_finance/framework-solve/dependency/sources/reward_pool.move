module challenge::reward_pool;

use challenge::oracle::PriceOracle;
use sui::bag::{Self, Bag};
use sui::balance::Balance;
use sui::coin::{Self, Coin};
use sui::event;
use sui::vec_set::{Self, VecSet};

const REWARD_AMOUNT_TO_SOLVE: u64 = 2_000;

public enum Stage has copy, drop, store {
    Depositing,
    Claiming,
}

public struct RewardPool<phantom R> has key, store {
    id: UID,
    stage: Stage,
    rewards: Balance<R>,
    users: VecSet<address>,
    deposits: Bag, // user's address -> Balance<D>
    has_active_claiming: bool,
    is_solved: bool,
}

public fun is_claiming_allowed<R>(self: &RewardPool<R>): bool {
    self.stage == Stage::Claiming
}

public fun get_rewards_amount<R>(self: &RewardPool<R>): u64 {
    self.rewards.value()
}

public fun get_users_count<R>(self: &RewardPool<R>): u64 {
    self.users.size()
}
public fun get_user<R>(self: &RewardPool<R>, index: u64): address {
    self.users.keys()[index]
}

public fun get_deposits_count<R>(self: &RewardPool<R>): u64 {
    self.deposits.length()
}

public fun get_deposit_amount<R, D>(self: &RewardPool<R>, user: address): u64 {
    self.deposits.borrow<address, Balance<D>>(user).value()
}

public fun has_active_claiming<R>(self: &RewardPool<R>): bool {
    self.has_active_claiming
}

public fun is_solved<R>(self: &RewardPool<R>): bool {
    self.is_solved
}

public struct PoolAdminCap has key, store {
    id: UID,
    pool_id: ID,
}

public(package) fun create<R>(
    rewards: Coin<R>,
    ctx: &mut TxContext,
): (RewardPool<R>, PoolAdminCap) {
    assert!(rewards.value() > 0);
    let pool = RewardPool<R> {
        id: sui::object::new(ctx),
        stage: Stage::Depositing,
        rewards: rewards.into_balance(),
        users: vec_set::empty(),
        deposits: bag::new(ctx),
        has_active_claiming: false,
        is_solved: false,
    };

    let admin_cap = PoolAdminCap {
        id: sui::object::new(ctx),
        pool_id: object::id(&pool),
    };

    (pool, admin_cap)
}

public struct Emulated<phantom D> has copy, drop {
    user: address,
    amount: u64,
}

public(package) fun emulate_deposit<R, D>(
    pool: &mut RewardPool<R>,
    user: address,
    deposit: Balance<D>,
) {
    assert!(!pool.is_solved);

    let amount = deposit.value();
    pool.deposits.add(user, deposit);
    pool.users.insert(user);

    event::emit(Emulated<D> {
        user,
        amount,
    });
}

public fun increase_rewards<R>(pool: &mut RewardPool<R>, cap: &PoolAdminCap, rewards: Coin<R>) {
    assert!(cap.pool_id == object::id(pool));
    assert!(rewards.value() > 0);
    pool.rewards.join(rewards.into_balance());
}

public fun allow_claiming<R>(pool: &mut RewardPool<R>, cap: &PoolAdminCap) {
    assert!(cap.pool_id == object::id(pool));
    assert!(pool.stage == Stage::Depositing);
    pool.stage = Stage::Claiming;
}

public struct Deposited<phantom D> has copy, drop {
    user: address,
    amount: u64,
    evaluation: u64,
}

public struct ClaimStarted<phantom D> has copy, drop {
    user: address,
    amount: u64,
    evaluation: u64,
}

public struct ClaimCompleted<phantom D> has copy, drop {
    user: address,
    amount: u64,
    evaluation: u64,
    total_evaluation: u64,
    rewards_amount: u64,
}

public struct ClaimCanceled<phantom D> has copy, drop {
    user: address,
}

public fun deposit<R, D>(
    pool: &mut RewardPool<R>,
    funds: Coin<D>,
    oracle: &PriceOracle,
    ctx: &TxContext,
) {
    deposit_for(pool, ctx.sender(), funds, oracle)
}

public fun deposit_for<R, D>(
    pool: &mut RewardPool<R>,
    user: address,
    funds: Coin<D>,
    oracle: &PriceOracle,
) {
    assert!(!pool.is_solved);
    assert!(funds.value() > 0);
    assert!(!pool.users.contains(&user));
    assert!(!pool.deposits.contains(user));

    let deposited = funds.into_balance();
    let evaluation = evaluate(&deposited, oracle);
    if (evaluation > 0) {
        // this deposit has real value
        assert!(pool.stage == Stage::Depositing);
    };

    let amount = deposited.value();
    pool.deposits.add(user, deposited);
    pool.users.insert(user);

    event::emit(Deposited<D> {
        user,
        amount,
        evaluation,
    });
}

public struct ClaimingPotato {
    pool_id: ID,
    user: address,
    amount: u64,
    deposit_evaluation: u64,
    total_evaluation: u64,
    total_deposits: u64,
    processed_users: VecSet<address>,
}

public fun claim_start<R, D>(
    pool: &mut RewardPool<R>,
    amount: u64,
    oracle: &PriceOracle,
    ctx: &TxContext,
): ClaimingPotato {
    assert!(!pool.is_solved);
    assert!(!pool.has_active_claiming);
    let user = ctx.sender();
    assert!(pool.users.contains(&user));
    assert!(pool.deposits.contains(user));

    let deposited: &Balance<D> = pool.deposits.borrow(user);
    assert!(amount <= deposited.value());
    let evaluation = evaluate(deposited, oracle);

    let mut total_deposits = 1;
    if (evaluation > 0) {
        assert!(pool.stage == Stage::Claiming);
        total_deposits = pool.deposits.length();
    };

    pool.has_active_claiming = true;

    event::emit(ClaimStarted<D> {
        user,
        amount: deposited.value(),
        evaluation,
    });

    ClaimingPotato {
        pool_id: object::id(pool),
        user,
        amount,
        deposit_evaluation: evaluation,
        total_evaluation: evaluation,
        total_deposits,
        processed_users: vec_set::singleton(user),
    }
}

public fun claim_step<R, D>(
    pool: &RewardPool<R>,
    user: address,
    oracle: &PriceOracle,
    potato: &mut ClaimingPotato,
) {
    assert!(!pool.is_solved);
    assert!(object::id(pool) == potato.pool_id);
    assert!(pool.has_active_claiming);
    assert!(pool.users.contains(&user));
    assert!(pool.deposits.contains(user));
    assert!(user != potato.user);
    assert!(!potato.processed_users.contains(&user));
    assert!(potato.total_deposits > potato.processed_users.size());

    let deposited: &Balance<D> = pool.deposits.borrow(user);
    let evaluation = evaluate(deposited, oracle);

    potato.processed_users.insert(user);
    potato.total_evaluation = potato.total_evaluation + evaluation;
}

public fun claim_complete<R, D>(
    pool: &mut RewardPool<R>,
    potato: ClaimingPotato,
    ctx: &mut TxContext,
): (Coin<R>, Coin<D>) {
    assert!(!pool.is_solved);
    assert!(object::id(pool) == potato.pool_id);
    assert!(pool.has_active_claiming);
    assert!(potato.total_deposits == potato.processed_users.size());
    assert!(potato.deposit_evaluation <= potato.total_evaluation);

    let ClaimingPotato {
        pool_id: _,
        user,
        amount,
        deposit_evaluation,
        total_evaluation,
        total_deposits: _,
        processed_users: _,
    } = potato;

    let mut deposited: Balance<D> = pool.deposits.remove(user);
    let deposit_amount = deposited.value();
    let claimed = coin::take(&mut deposited, amount, ctx);
    if (deposited.value() == 0) {
        deposited.destroy_zero();
        pool.users.remove(&user);
    } else {
        pool.deposits.add(user, deposited);
    };

    let mut rewards: Coin<R> = coin::zero(ctx);
    let mut rewards_amount = 0;
    if (deposit_evaluation > 0) {
        assert!(pool.stage == Stage::Claiming);
        rewards_amount =
            (
                ((pool.rewards.value() as u128) * (deposit_evaluation as u128)) / (total_evaluation as u128),
            ) as u64;
        rewards_amount =
            (
                ((rewards_amount as u128) * (amount as u128)) / (deposit_amount as u128),
            ) as u64;
        if (rewards_amount > 0) {
            rewards.join(coin::take(&mut pool.rewards, rewards_amount, ctx));

            if (rewards_amount > REWARD_AMOUNT_TO_SOLVE) {
                pool.is_solved = true;
            }
        }
    };

    event::emit(ClaimCompleted<D> {
        user,
        amount,
        evaluation: deposit_evaluation,
        total_evaluation,
        rewards_amount,
    });

    pool.has_active_claiming = false;

    (rewards, claimed)
}

public fun claim_cancel<R, D>(pool: &mut RewardPool<R>, potato: ClaimingPotato, ctx: &TxContext) {
    assert!(object::id(pool) == potato.pool_id);
    assert!(pool.has_active_claiming);

    let user = ctx.sender();
    assert!(user == potato.user);

    let ClaimingPotato {
        pool_id: _,
        user: _,
        amount: _,
        deposit_evaluation: _,
        total_evaluation: _,
        total_deposits: _,
        processed_users: _,
    } = potato;

    event::emit(ClaimCanceled<D> {
        user,
    });

    pool.has_active_claiming = false;
}

fun evaluate<D>(funds: &Balance<D>, oracle: &PriceOracle): u64 {
    let price = oracle.get_price<D>();
    if (price.price() == 0) {
        return 0
    };

    funds.value() * price.price() / 10u64.pow(price.decimals())
}
