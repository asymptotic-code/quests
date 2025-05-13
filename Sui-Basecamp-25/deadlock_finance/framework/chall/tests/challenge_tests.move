#[test_only]
module ghost_votes::challenge_tests;

use sui::test_scenario;
use ghost_votes::challenge::{Self, Challenge};
use ghost_votes::coin::COIN;
use sui::coin;

const USER: address = @0xA;
const USER2: address = @0xB;

#[test]
public fun test_create_and_claim() {
    let mut scenario = test_scenario::begin(USER);

    let treasury_cap = coin::create_treasury_cap_for_testing<COIN>(scenario.ctx());
    challenge::create(treasury_cap, scenario.ctx());
    scenario.next_tx(USER);

    let mut challenge = scenario.take_shared<Challenge<COIN>>();
    assert!(challenge.get_governance().get_balance() == 10_000);

    let coin = challenge.claim_coin(scenario.ctx());
    assert!(coin.value() == 1_000);
    coin::burn_for_testing(coin);

    scenario.next_tx(USER2);
    let coin = challenge.claim_coin(scenario.ctx());
    assert!(coin.value() == 1_000);
    coin::burn_for_testing(coin);

    scenario.next_tx(USER);

    test_scenario::return_shared(challenge);
    scenario.end();
}

#[test]
#[expected_failure]
public fun test_create_and_claim_twice() {
    let mut scenario = test_scenario::begin(USER);

    let treasury_cap = coin::create_treasury_cap_for_testing<COIN>(scenario.ctx());
    challenge::create(treasury_cap, scenario.ctx());
    scenario.next_tx(USER);

    let mut challenge = scenario.take_shared<Challenge<COIN>>();
    assert!(challenge.get_governance().get_balance() == 10_000);

    let coin = challenge.claim_coin(scenario.ctx());
    assert!(coin.value() == 1_000);
    coin::burn_for_testing(coin);
    let coin = challenge.claim_coin(scenario.ctx());    // aborts here
    assert!(coin.value() == 1_000);
    coin::burn_for_testing(coin);

    test_scenario::return_shared(challenge);
    scenario.end();
}