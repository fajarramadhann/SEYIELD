/**
 * Token addresses for the SEI Testnet
 */
export const tokenAddresses = {
  // Native SEI token doesn't need an address as it's the native currency
  sei: null,
  // Mock USDC token address from the contract deployment
  usdc: '0x855036d27d0B0691ac6FC8A958fF90d394Db9b62',
  // Principal token address
  principalToken: '0xb954f29215Cf0239017f54515F83aBFC5d70dCb4',
  // Yield token address
  yieldToken: '0xD461574893Ad06d0100A69833aB17fa0481c80A1',
}

/**
 * Token metadata
 */
export const tokenMetadata = {
  sei: {
    name: 'SEI',
    symbol: 'SEI',
    decimals: 18,
  },
  usdc: {
    name: 'USDC',
    symbol: 'USDC',
    decimals: 6,
  },
}
