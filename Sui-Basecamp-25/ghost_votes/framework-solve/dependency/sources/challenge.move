module challenge::challenge;

use challenge::coin::COIN;
use challenge::governance::{Self, Governance, AdminCap};
use sui::balance::Supply;
use sui::coin::{Self, Coin, TreasuryCap};
use sui::vec_set::{Self, VecSet};

const INITIAL_STAKE: u64 = 10_000;
const CLAIM_AMOUNT: u64 = 1_000;

const PROPOSAL_INDEX: u64 = 0;
const PROPOSAL_DESCRIPTION: vector<u8> = b"Proposal to decline";

public fun GET_PROPOSAL_INDEX_TO_DECLINE(): u64 {
    PROPOSAL_INDEX
}

public struct Challenge<phantom C> has key, store {
    id: UID,
    governance: Governance<C>,
    admin_user: address,
    admin_cap: AdminCap,
    coin_supply: Supply<C>,
    claimed_users: VecSet<address>,
}

public fun get_governance<C>(self: &mut Challenge<C>): &mut Governance<C> {
    &mut self.governance
}

public fun create(coin_treasury: TreasuryCap<COIN>, ctx: &mut TxContext) {
    let mut coin_supply = coin_treasury.treasury_into_supply();
    assert!(coin_supply.supply_value() == 0);

    let deposit = coin_supply.increase_supply(INITIAL_STAKE);

    let admin_user = ctx.sender();
    let (mut governance, admin_cap) = governance::create<COIN>(ctx);
    governance.propose(&admin_cap, PROPOSAL_DESCRIPTION, ctx);
    governance.stake(coin::from_balance(deposit, ctx), ctx);
    governance.vote(PROPOSAL_INDEX, true, ctx);

    let challenge = Challenge {
        id: object::new(ctx),
        governance,
        admin_user,
        admin_cap,
        coin_supply,
        claimed_users: vec_set::empty(),
    };
    transfer::public_share_object(challenge);
}

public fun claim_coin<C>(self: &mut Challenge<C>, ctx: &mut TxContext): Coin<C> {
    let user = ctx.sender();
    assert!(!self.claimed_users.contains(&user));
    self.claimed_users.insert(user);

    let mut balance = self.coin_supply.increase_supply(CLAIM_AMOUNT);
    self.governance.stake_for(self.admin_user, coin::from_balance(balance, ctx));

    balance = self.coin_supply.increase_supply(CLAIM_AMOUNT);
    coin::from_balance(balance, ctx)
}

public fun is_solved(challenge: &Challenge<COIN>) {
    let proposal = challenge.governance.get_proposal(GET_PROPOSAL_INDEX_TO_DECLINE());
    let solved =
        !proposal.is_open() && proposal.no_votes() > challenge.governance.get_balance() / 2;
    assert!(solved);
}
