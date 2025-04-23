## Foundry

## Contract Address
```text
    fundsVault: '0x94E3Ae807dD4c1030AA3bF94B348e29CFf1CF0aE'
    treasury: '0xC6660C0952C98a9Ac14c26b35b1dB598f2139Efa'
    yieldToken: '0x8A90B3FDa4fEb2Cafc875b5241227ee285be18D4'
    principalToken: '0xe89Ad517A30292Ab63A922B147B7E83727C2B3BB'
    mockUsdc: '0x5e47b3Ba6f9E80f1504b8cCbC83e2d7Ca69Ab22d'
    mockAavePool: '0xab01753b6D75d550d87807a8E4a9Ddd07D15797e'
```


**Foundry is a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.**

Foundry consists of:

-   **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools).
-   **Cast**: Swiss army knife for interacting with EVM smart contracts, sending transactions and getting chain data.
-   **Anvil**: Local Ethereum node, akin to Ganache, Hardhat Network.
-   **Chisel**: Fast, utilitarian, and verbose solidity REPL.

## Documentation

https://book.getfoundry.sh/

## Usage

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```

### Anvil

```shell
$ anvil
```

### Deploy

```shell
$ forge script script/Counter.s.sol:CounterScript --rpc-url <your_rpc_url> --private-key <your_private_key>
```

### Cast

```shell
$ cast <subcommand>
```

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```
