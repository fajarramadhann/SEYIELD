/**
 * Token addresses for the SEI Testnet
 */
export const tokenAddresses = {
  // Native SEI token doesn't need an address as it's the native currency
  sei: null,
  // Mock USDC token address from the contract deployment
  usdc: '0x855036d27d0B0691ac6FC8A958fF90d394Db9b62',
  // Principal token address
  principalToken: '0x2C0ee6326E724d377066E89699977CB1bfAeD652',
  // Yield token address
  yieldToken: '0x89d8C67e1B5887fB11879Ff2CA178cC1d2ae8E4A',
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
