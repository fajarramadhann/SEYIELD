'use client'

import { useState, useEffect } from 'react'
import { useAccount, useReadContract, useWriteContract, useWaitForTransactionReceipt } from 'wagmi'
import { parseUnits, formatUnits } from 'viem'
import { contractAddresses } from '@/app/config/contract-addresses'
import { fundsVaultAbi } from '@/app/config/abis/funds-vault-abi'
import { erc20Abi } from '@/app/config/abis/erc20-abi'
import { useToast } from '@/components/ui/use-toast'

export function useWithdraw() {
  const { address, isConnected } = useAccount()
  const { toast } = useToast()
  const [isWithdrawLoading, setIsWithdrawLoading] = useState(false)

  // Get user's deposit info
  const { data: userInfo, refetch: refetchUserInfo } = useReadContract({
    address: contractAddresses.fundsVault as `0x${string}`,
    abi: fundsVaultAbi,
    functionName: 'userInfo',
    args: [address],
    query: {
      enabled: !!address && isConnected,
    }
  })

  // Get user's USDC balance
  const { data: usdcBalance, refetch: refetchUsdcBalance } = useReadContract({
    address: contractAddresses.usdc as `0x${string}`,
    abi: erc20Abi,
    functionName: 'balanceOf',
    args: [address],
    query: {
      enabled: !!address && isConnected,
    }
  })

  // Get user's pSYLD balance
  const { data: pSyldBalance, refetch: refetchPSyldBalance } = useReadContract({
    address: contractAddresses.principalToken as `0x${string}`,
    abi: erc20Abi,
    functionName: 'balanceOf',
    args: [address],
    query: {
      enabled: !!address && isConnected,
    }
  })

  // Get user's ySYLD balance
  const { data: ySyldBalance, refetch: refetchYSyldBalance } = useReadContract({
    address: contractAddresses.yieldToken as `0x${string}`,
    abi: erc20Abi,
    functionName: 'balanceOf',
    args: [address],
    query: {
      enabled: !!address && isConnected,
    }
  })

  // Withdraw USDC
  const {
    data: withdrawData,
    isPending: isWithdrawPending,
    isSuccess: isWithdrawStarted,
    writeContract: withdrawUsdc,
    error: withdrawError
  } = useWriteContract()

  // Wait for withdraw transaction to complete
  const {
    isLoading: isWithdrawConfirming,
    isSuccess: isWithdrawComplete
  } = useWaitForTransactionReceipt({
    hash: withdrawData,
  })

  // Handle withdraw completion
  useEffect(() => {
    if (isWithdrawComplete) {
      toast({
        title: "Withdrawal successful!",
        description: "Your USDC has been withdrawn successfully.",
        variant: "default",
        duration: 5000,
      })

      // Refresh balances
      Promise.all([
        refetchUserInfo(),
        refetchUsdcBalance(),
        refetchPSyldBalance(),
        refetchYSyldBalance()
      ]).then(() => {
        console.log("Balances refreshed after withdrawal");
      });
    }
  }, [isWithdrawComplete, toast, refetchUserInfo, refetchUsdcBalance, refetchPSyldBalance, refetchYSyldBalance])

  // Handle withdraw errors
  useEffect(() => {
    if (withdrawError) {
      console.error('Withdraw error:', withdrawError)

      // Extract revert reason if available
      let errorMessage = withdrawError.message || "Failed to withdraw USDC. Please try again."
      if (typeof errorMessage === 'string' && errorMessage.includes('execution reverted:')) {
        errorMessage = errorMessage.split('execution reverted:')[1].trim()
      }

      toast({
        title: "Withdrawal failed",
        description: errorMessage,
        variant: "destructive",
        duration: 5000,
      })
    }
  }, [withdrawError, toast])

  // Function to withdraw USDC
  const handleWithdraw = async (amount: string) => {
    if (!isConnected) {
      toast({
        title: "Wallet not connected",
        description: "Please connect your wallet to withdraw.",
        variant: "destructive",
      })
      return
    }

    setIsWithdrawLoading(true)
    try {
      // Validate amount
      if (Number(amount) <= 0) {
        toast({
          title: "Invalid amount",
          description: "Withdrawal amount must be greater than 0.",
          variant: "destructive",
        })
        setIsWithdrawLoading(false)
        return
      }

      const parsedAmount = parseUnits(amount, 6) // USDC has 6 decimals

      // Check if user has enough pSYLD
      if (pSyldBalance && pSyldBalance < parsedAmount) {
        toast({
          title: "Insufficient pSYLD balance",
          description: `You need ${formatUnits(parsedAmount, 6)} pSYLD but only have ${formatUnits(pSyldBalance, 6)} pSYLD.`,
          variant: "destructive",
        })
        setIsWithdrawLoading(false)
        return
      }

      // Execute withdraw transaction
      await withdrawUsdc({
        address: contractAddresses.fundsVault as `0x${string}`,
        abi: fundsVaultAbi,
        functionName: 'withdraw',
        args: [parsedAmount],
      })
    } catch (error) {
      console.error('Error withdrawing USDC:', error)
      toast({
        title: "Withdrawal error",
        description: "Failed to withdraw USDC. Please try again.",
        variant: "destructive",
      })
    } finally {
      setIsWithdrawLoading(false)
    }
  }

  // Function to force refresh all balances
  const forceRefreshBalances = async () => {
    console.log("Force refreshing all balances...");
    try {
      await refetchUsdcBalance();
      await refetchPSyldBalance();
      await refetchYSyldBalance();
      await refetchUserInfo();

      toast({
        title: "Balances refreshed",
        description: "Your token balances have been refreshed from the blockchain.",
        duration: 3000,
      });
    } catch (error) {
      console.error("Error refreshing balances:", error);
    }
  };

  return {
    // State
    isWithdrawLoading: isWithdrawLoading || isWithdrawPending || isWithdrawConfirming,
    isWithdrawComplete,
    userInfo,
    usdcBalance,
    pSyldBalance,
    ySyldBalance,

    // Functions
    handleWithdraw,
    forceRefreshBalances,

    // Connection state
    isConnected,
  }
}
