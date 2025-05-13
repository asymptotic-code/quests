#[test_only]
module ghost_votes::governance_tests;

use sui::test_scenario;
use sui::coin;
use ghost_votes::governance::{Self, Governance};

public struct COIN has drop {}

const USER: address = @0xA;
const USER2: address = @0xB;
const PROPOSAL_INDEX: u64 = 0;

fun stake(governance: &mut Governance<COIN>, amount: u64, ctx: &mut TxContext) {
    stake_for(governance, ctx.sender(), amount, ctx);
}

fun stake_for(governance: &mut Governance<COIN>, user: address, amount: u64, ctx: &mut TxContext) {
    let balance_before = governance.get_balance();
    let stake_before = governance.get_stake(user);

    let coins = coin::mint_for_testing<COIN>(amount, ctx);
    governance.stake_for(user, coins);

    let stake_amount = governance.get_stake(user);
    assert!(stake_amount == stake_before + amount);

    let balance_after = governance.get_balance();
    assert!(balance_before + amount == balance_after);
}

fun unstake(governance: &mut Governance<COIN>, expected_amount: u64, ctx: &mut TxContext) {
    let user = ctx.sender();
    let balance_before = governance.get_balance();
    let stake_before = governance.get_stake(user);
    assert!(expected_amount == stake_before);

    let coins = governance.unstake( ctx);
    assert!(coins.value() == expected_amount);
    coin::burn_for_testing(coins);

    let stake_amount = governance.get_stake(user);
    assert!(stake_amount == 0);

    let balance_after = governance.get_balance();
    assert!(balance_before - expected_amount == balance_after);
}

fun vote(governance: &mut Governance<COIN>, yes: bool, is_open_expected: bool, ctx: &mut TxContext) {
    let user = ctx.sender();
    let balance_before = governance.get_balance();
    let stake_before = governance.get_stake(user);

    let proposal_before = governance.get_proposal(PROPOSAL_INDEX);
    assert!(proposal_before.is_open());
    let yes_before = proposal_before.yes_votes();
    let no_before = proposal_before.no_votes();

    governance.vote( PROPOSAL_INDEX, yes, ctx);

    let proposal_after = governance.get_proposal(PROPOSAL_INDEX);
    assert!(proposal_after.is_open() == is_open_expected);
    if (yes) {
        assert!(proposal_after.yes_votes() == yes_before + stake_before);
        assert!(proposal_after.no_votes() == no_before);
    } else {
        assert!(proposal_after.yes_votes() == yes_before);
        assert!(proposal_after.no_votes() == no_before + stake_before);
    };

    assert!(stake_before == governance.get_stake(user));
    assert!(balance_before == governance.get_balance());
}

#[test]
public fun test_stake_for() {
    let mut scenario = test_scenario::begin(USER);

    let (mut governance, admin_cap) = governance::create<COIN>(scenario.ctx());

    stake(&mut governance, 200, scenario.ctx());

    transfer::public_transfer(admin_cap, USER);
    transfer::public_transfer(governance, USER);
    scenario.end();
}

#[test]
public fun test_stake_for_twice() {
    let mut scenario = test_scenario::begin(USER);

    let (mut governance, admin_cap) = governance::create<COIN>(scenario.ctx());

    stake(&mut governance, 200, scenario.ctx());
    stake(&mut governance, 100, scenario.ctx());
    assert!(governance.get_stake(USER) == 300);
    assert!(governance.get_balance() == 300);

    transfer::public_transfer(admin_cap, USER);
    transfer::public_transfer(governance, USER);
    scenario.end();
}

#[test]
public fun test_stake_two_users() {
    let mut scenario = test_scenario::begin(USER);

    let (mut governance, admin_cap) = governance::create<COIN>(scenario.ctx());

    stake(&mut governance, 10, scenario.ctx());
    stake_for(&mut governance, USER2, 20, scenario.ctx());
    assert!(governance.get_balance() == 30);

    transfer::public_transfer(admin_cap, USER);
    transfer::public_transfer(governance, USER);
    scenario.end();
}

#[test]
#[expected_failure]
public fun test_unstake_fail() {
    let mut scenario = test_scenario::begin(USER);

    let (mut governance, admin_cap) = governance::create<COIN>(scenario.ctx());

    let coins = governance.unstake( scenario.ctx());    // abort here
    coin::burn_for_testing(coins);

    transfer::public_transfer(admin_cap, USER);
    transfer::public_transfer(governance, USER);
    scenario.end();
}

#[test]
public fun test_stake_and_unstake() {
    let mut scenario = test_scenario::begin(USER);

    let (mut governance, admin_cap) = governance::create<COIN>(scenario.ctx());

    stake(&mut governance, 1000, scenario.ctx());
    unstake(&mut governance, 1000, scenario.ctx());

    transfer::public_transfer(admin_cap, USER);
    transfer::public_transfer(governance, USER);
    scenario.end();
}

#[test]
public fun test_stake_and_unstake_two_users() {
    let mut scenario = test_scenario::begin(USER);

    let (mut governance, admin_cap) = governance::create<COIN>(scenario.ctx());

    stake(&mut governance, 700, scenario.ctx());
    stake_for(&mut governance, USER2, 500, scenario.ctx());
    assert!(governance.get_balance() == 1200);

    unstake(&mut governance, 700, scenario.ctx());
    scenario.next_tx(USER2);
    unstake(&mut governance, 500, scenario.ctx());

    assert!(governance.get_balance() == 0);

    transfer::public_transfer(admin_cap, USER);
    transfer::public_transfer(governance, USER);
    scenario.end();
}

#[test]
#[expected_failure]
public fun test_vote_no_stake() {
    let mut scenario = test_scenario::begin(USER);

    let (mut governance, admin_cap) = governance::create<COIN>(scenario.ctx());

    governance.vote( PROPOSAL_INDEX, true, scenario.ctx());    // abort here

    transfer::public_transfer(admin_cap, USER);
    transfer::public_transfer(governance, USER);
    scenario.end();
}

#[test]
#[expected_failure]
public fun test_vote_after_unstake() {
    let mut scenario = test_scenario::begin(USER);

    let (mut governance, admin_cap) = governance::create<COIN>(scenario.ctx());

    stake(&mut governance, 1, scenario.ctx());
    unstake(&mut governance, 1, scenario.ctx());
    governance.vote( PROPOSAL_INDEX, true, scenario.ctx());    // abort here

    transfer::public_transfer(admin_cap, USER);
    transfer::public_transfer(governance, USER);
    scenario.end();
}

#[test]
#[expected_failure]
public fun test_vote_no_proposal() {
    let mut scenario = test_scenario::begin(USER);

    let (mut governance, admin_cap) = governance::create<COIN>(scenario.ctx());

    governance.vote( 100, true, scenario.ctx());    // abort here

    transfer::public_transfer(admin_cap, USER);
    transfer::public_transfer(governance, USER);
    scenario.end();
}

#[test]
public fun test_vote_yes() {
    let mut scenario = test_scenario::begin(USER);

    let (mut governance, admin_cap) = governance::create<COIN>(scenario.ctx());
    governance.propose(&admin_cap, b"Proposal", scenario.ctx());

    stake(&mut governance, 100, scenario.ctx());
    vote(&mut governance, true, true, scenario.ctx());

    transfer::public_transfer(admin_cap, USER);
    transfer::public_transfer(governance, USER);
    scenario.end();
}

#[test]
public fun test_vote_no_close() {
    let mut scenario = test_scenario::begin(USER);

    let (mut governance, admin_cap) = governance::create<COIN>(scenario.ctx());
    governance.propose(&admin_cap, b"Proposal", scenario.ctx());

    stake(&mut governance, 1, scenario.ctx());
    vote(&mut governance, false, false, scenario.ctx());

    transfer::public_transfer(admin_cap, USER);
    transfer::public_transfer(governance, USER);
    scenario.end();
}

#[test]
public fun test_vote_no() {
    let mut scenario = test_scenario::begin(USER);

    let (mut governance, admin_cap) = governance::create<COIN>(scenario.ctx());
    governance.propose(&admin_cap, b"Proposal", scenario.ctx());

    stake(&mut governance, 99, scenario.ctx());
    stake_for(&mut governance, USER2, 100, scenario.ctx());

    vote(&mut governance, false, true, scenario.ctx());

    transfer::public_transfer(admin_cap, USER);
    transfer::public_transfer(governance, USER);
    scenario.end();
}