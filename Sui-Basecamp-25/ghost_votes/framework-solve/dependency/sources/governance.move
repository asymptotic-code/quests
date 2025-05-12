module challenge::governance;

use sui::balance::{Self, Balance};
use sui::coin::{Self, Coin};
use sui::table::{Self, Table};

public struct Proposal has key, store {
    id: UID,
    description: vector<u8>,
    yes_votes: u64,
    no_votes: u64,
    voted: vector<address>,
    is_open: bool,
}

public fun description(self: &Proposal): vector<u8> {
    self.description
}

public fun yes_votes(self: &Proposal): u64 {
    self.yes_votes
}

public fun no_votes(self: &Proposal): u64 {
    self.no_votes
}

public fun is_open(self: &Proposal): bool {
    self.is_open
}

public struct Governance<phantom C> has key, store {
    id: UID,
    stakes: Table<address, u64>,
    proposals: vector<Proposal>,
    balance: Balance<C>,
}

public fun get_proposal<C>(self: &Governance<C>, proposal_index: u64): &Proposal {
    &self.proposals[proposal_index]
}

public fun get_balance<C>(self: &Governance<C>): u64 {
    self.balance.value()
}

public struct AdminCap has key, store {
    id: UID,
    governance_id: ID,
}

public(package) fun create<C>(ctx: &mut TxContext): (Governance<C>, AdminCap) {
    let governance = Governance<C> {
        id: object::new(ctx),
        stakes: table::new(ctx),
        proposals: vector::empty(),
        balance: balance::zero(),
    };

    let admin_cap = AdminCap {
        id: object::new(ctx),
        governance_id: object::id(&governance),
    };

    (governance, admin_cap)
}

public fun propose<C>(
    self: &mut Governance<C>,
    _: &AdminCap,
    description: vector<u8>,
    ctx: &mut TxContext,
) {
    let proposal = Proposal {
        id: object::new(ctx),
        description,
        yes_votes: 0,
        no_votes: 0,
        voted: vector::empty(),
        is_open: true,
    };
    self.proposals.push_back(proposal);
}

public fun close_proposal<C>(self: &mut Governance<C>, _: &AdminCap, proposal_index: u64) {
    let proposal = &mut self.proposals[proposal_index];
    proposal.is_open = false;
}

public fun stake<C>(self: &mut Governance<C>, deposit: Coin<C>, ctx: &TxContext) {
    self.stake_for(ctx.sender(), deposit);
}

public fun stake_for<C>(self: &mut Governance<C>, user: address, deposit: Coin<C>) {
    let amount = deposit.value();
    assert!(amount > 0);

    if (self.stakes.contains(user)) {
        let stake_amount = self.stakes.borrow_mut(user);
        *stake_amount = *stake_amount + amount;
    } else {
        self.stakes.add(user, amount);
    };

    self.balance.join(deposit.into_balance());
}

public fun unstake<C>(self: &mut Governance<C>, ctx: &mut TxContext): Coin<C> {
    let user = ctx.sender();
    assert!(self.stakes.contains(user));

    let amount = self.stakes.remove(user);
    coin::from_balance(self.balance.split(amount), ctx)
}

public fun vote<C>(self: &mut Governance<C>, proposal_index: u64, yes: bool, ctx: &mut TxContext) {
    let proposal = &mut self.proposals[proposal_index];
    assert!(proposal.is_open);

    let user = ctx.sender();
    assert!(self.stakes.contains(user));
    let vote_power = *self.stakes.borrow(user);

    proposal.voted.push_back(user);
    if (yes) {
        proposal.yes_votes = proposal.yes_votes + vote_power;
    } else {
        proposal.no_votes = proposal.no_votes + vote_power;
        if (proposal.no_votes > self.balance.value() / 2) {
            proposal.is_open = false;
        };
    };
}
