module challenge::reward_coin;

use sui::coin;

public struct REWARD_COIN has drop {}

fun init(witness: REWARD_COIN, ctx: &mut TxContext) {
    let (treasury, metadata) = coin::create_currency(
        witness,
        6,
        b"REW",
        b"CTF Reward Coin",
        b"CTF Reward Coin",
        option::none(),
        ctx,
    );
    transfer::public_freeze_object(metadata);
    transfer::public_transfer(treasury, ctx.sender());
}
