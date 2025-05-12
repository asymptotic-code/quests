# Hot Potato Finance

### Description

In the wild west of DeFi on Sui, a new protocol is born: Hot Potato Finance. It offers staking across multiple tokens and distributes rewards based on the value of staked assets, fetched from an on-chain oracle. The protocol uses a bizarre technique called the Hot Potato Pattern to fairly calculate each user’s share during the claim process.
And like every good DeFi project rushed to mainnet... there's a fatal flaw.

### Objective

Use a single wallet to claim over 2000 rewards from the pool by calling `claim_complete()`. When successful, the `is_solved` flag in the `RewardPool` will be set to `true`.

Note: You’re not allowed to transfer reward tokens between accounts. All interactions with the challenge contracts must be done from a single wallet, and you must rely entirely on the claim functionality to earn rewards directly into that wallet.

### Author

https://t.me/mykhailo_17