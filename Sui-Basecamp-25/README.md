# Sui Basecamp 2025 CTF Challenges

This directory contains security challenges for the Sui Basecamp 2025 Capture The Flag (CTF) competition. Each challenge focuses on exploiting vulnerabilities in Sui Move smart contracts.

## Challenges

### Ghost Votes
A governance protocol challenge where you must exploit a voting system to cast votes with more power than your stake should allow.

### Hot Potato Finance
A DeFi challenge related to the "hot potato" concept in finance.

### Deadlock Finance
A DeFi challenge focused on finding and exploiting deadlock vulnerabilities.

## Running the Challenges

Each challenge directory contains:
- `framework/` - The challenge framework and Move code
- `framework-solve/` - Where you can implement your solution
- `run_server.sh` - Script to start the challenge server
- `run_client.sh` - Script to run a client to interact with the challenge

## Prerequisites

- Sui Move development environment
- Docker (for containerized challenges)
