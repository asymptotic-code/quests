module challenge::coin;

use sui::coin;

public struct COIN has drop {}

fun init(witness: COIN, ctx: &mut TxContext) {
    let (treasury, metadata) = coin::create_currency(
        witness,
        6,
        b"STK",
        b"CTF Staking Coin",
        b"CTF Staking Coin",
        option::none(),
        ctx,
    );
    transfer::public_freeze_object(metadata);
    transfer::public_transfer(treasury, ctx.sender());
}
