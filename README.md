# Subway - V2

# THIS IS FOR EDUCATIONAL & LEARNING PURPOSES ONLY

A practical example on how to perform sandwich attacks on UniswapV2 pairs.

Having highly optimized contracts is just one part of the equation, a tech stack is just as important as the contracts to execute on the opportunities.

<details>
  <summary>Click to view the video</summary>
  
  https://user-images.githubusercontent.com/95674753/145967796-6c2c8925-fb5c-41d4-a64f-a22ce8701ce6.mp4
</details>

## Overview

The contracts are written in Yul+ and Solidity, and contain the **bare minimum** needed to perform a sandwich attack (i.e. `swap` and `transfer`). **They do NOT protect against [uncle bandit attacks](https://twitter.com/bertcmiller/status/1385294417091760134) so use at your own risk.**

The goal of this bot is to act as a low barrier of entry, reference source code for aspiring new searchers (hence, JavaScript). This bot contains:

- [x] read from the mempool
- [x] decode transaction data
- [x] simple logging system
- [x] profit calculation algos
- [x] gas bribe calculation
- [x] bundle firing
- [x] misc
  - [x] doing math in JS
  - [x] calculating next base fee


While the bot is functional, below are the upgrades in progress:

- [ ] circuit breakers
- [ ] poison token checker
- [ ] caching system
- [ ] robust logging system (e.g. Grafana)
- [ ] various gas saving ALPHAs

As such, this bot is intended as a piece of educational content, and not for production use.
