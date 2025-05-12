module challenge::deposit_coin;

use sui::coin;

public struct DEPOSIT_COIN has drop {}

fun init(witness: DEPOSIT_COIN, ctx: &mut TxContext) {
    let (treasury, metadata) = coin::create_currency(
        witness,
        6,
        b"DEP",
        b"CTF Deposit Coin",
        b"CTF Deposit Coin",
        option::none(),
        ctx,
    );
    transfer::public_freeze_object(metadata);
    transfer::public_transfer(treasury, ctx.sender());
}
