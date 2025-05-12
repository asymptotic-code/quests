# Ghost Votes

### Description

In the decentralized protocol Governet, governance decisions are made by users staking tokens and casting votes. The more tokens you stake, the more your voice counts - at least, that's the idea. But something’s off.

During a recent vote, a few wallets punched far above their weight, swaying the results with seemingly phantom voting power. The system insists everything checks out. But insiders suspect a flaw...

Now, you're being asked to prove it. Can you uncover the bug and cast votes with more power than your stake should allow?

### Objective

There is one proposal titled "Proposal to decline". Your goal is to reject it by ensuring the `is_open` flag is set to `false`, and the number of `no` votes exceeds the number of `yes` votes.

### Solution + Specs

We included the solution in `solve.move`.

`governance.move` contains a spec that reveals the vulnerability. 
Comment out the specs to run the solution without sui-prover.

### Author

https://t.me/mykhailo_1
