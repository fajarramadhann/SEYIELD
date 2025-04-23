'use client'

import { useState, useEffect } from 'react'
import { useAccount, useReadContract, useWriteContract, useWaitForTransactionReceipt, useSimulateContract } from 'wagmi'
import { parseUnits } from 'viem'
import { contractAddresses } from '@/app/config/contract-addresses'
import { fundsVaultAbi } from '@/app/config/abis/funds-vault-abi'
import { erc20Abi } from '@/app/config/abis/erc20-abi'
import { useToast } from '@/components/ui/use-toast'
// We'll use a simpler approach without JSX in toasts

export interface DepositHookReturn {
  isApproved: boolean;
  isCheckingApproval: boolean;
  isApproveLoading: boolean;
  isDepositLoading: boolean;
  isApproveComplete: boolean;
  isDepositComplete: boolean;
  userInfo: { deposit: bigint; depositTime: bigint; hasWithdrawn: boolean } | undefined;
  usdcBalance: bigint | undefined;
  pSyldBalance: bigint | undefined;
  handleApprove: (amount: string) => Promise<void>;
  handleDeposit: (amount: string) => Promise<void>;
  handleOneClickDeposit: (amount: string) => Promise<void>;
  isConnected: boolean;
}

export function useDeposit(): DepositHookReturn {
  const { address, isConnected } = useAccount()
  const { toast } = useToast()
  const [isApproved, setIsApproved] = useState(false)
  const [isCheckingApproval, setIsCheckingApproval] = useState(false)
  const [depositAmount, setDepositAmount] = useState<string>('')

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

  // Get user's USDC allowance for the vault
  const { data: allowance, refetch: refetchAllowance } = useReadContract({
    address: contractAddresses.usdc as `0x${string}`,
    abi: erc20Abi,
    functionName: 'allowance',
    args: [address, contractAddresses.fundsVault],
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

  // Approve USDC spending
  const {
    data: approveData,
    isPending: isApproveLoading,
    isSuccess: isApproveStarted,
    writeContract: approveUsdc,
    error: approveError
  } = useWriteContract()

  // Wait for approval transaction to complete
  const {
    isLoading: isApproveConfirming,
    isSuccess: isApproveComplete
  } = useWaitForTransactionReceipt({
    hash: approveData?.hash,
  })

  // Deposit USDC
  const {
    data: depositData,
    isPending: isDepositLoading,
    isSuccess: isDepositStarted,
    writeContract: depositUsdc,
    error: depositError
  } = useWriteContract()

  // Wait for deposit transaction to complete
  const {
    isLoading: isDepositConfirming,
    isSuccess: isDepositComplete
  } = useWaitForTransactionReceipt({
    hash: depositData?.hash,
  })

  // Check if the current amount is approved
  useEffect(() => {
    if (!depositAmount || !allowance || !isConnected) return

    try {
      const parsedAmount = parseUnits(depositAmount, 6) // USDC has 6 decimals
      setIsApproved(allowance >= parsedAmount)
    } catch (error) {
      console.error('Error parsing amount:', error)
      setIsApproved(false)
    }
  }, [depositAmount, allowance, isConnected])

  // Handle approval completion
  useEffect(() => {
    if (isApproveComplete) {
      toast({
        title: "Approval successful!",
        description: "You can now deposit your USDC into the vault.",
        duration: 5000,
      })

      // Immediately set isApproved to true when approval is complete
      setIsApproved(true)

      // Also refetch allowance after successful approval
      setTimeout(() => {
        refetchAllowance()
      }, 2000)
    }
  }, [isApproveComplete, toast, refetchAllowance])

  // Handle deposit completion
  useEffect(() => {
    if (isDepositComplete) {
      // Show success toast
      toast({
        title: "Deposit successful! 🎉",
        description: `You've deposited ${depositAmount} USDC and received pSYLD tokens.`,
        duration: 8000,
      })

      // Open transaction in explorer if available
      if (depositData?.hash) {
        // Create a clickable link in the description instead of using JSX
        toast({
          title: "Transaction confirmed",
          description: "View your transaction on the explorer",
          duration: 5000,
          // Use a simple function for the action instead of JSX
          action: {
            label: "View",
            onClick: () => window.open(`https://sei.explorers.guru/tx/${depositData.hash}`, '_blank')
          }
        })
      }

      // Refetch balances and user info after successful deposit
      setTimeout(() => {
        refetchUserInfo()
        refetchUsdcBalance()
        refetchPSyldBalance()
      }, 2000)
    }
  }, [isDepositComplete, depositAmount, depositData, toast, refetchUserInfo, refetchUsdcBalance, refetchPSyldBalance])

  // Handle errors
  useEffect(() => {
    if (approveError) {
      console.error('Approval error:', approveError)
      toast({
        title: "Approval failed",
        description: approveError.message || "Failed to approve USDC. Please try again.",
        variant: "destructive",
        duration: 5000,
      })
    }
  }, [approveError, toast])

  // Handle deposit errors separately
  useEffect(() => {
    if (depositError) {
      console.error('Deposit error:', depositError)

      // Extract revert reason if available
      let errorMessage = depositError.message || "Failed to deposit USDC. Please try again."
      if (typeof errorMessage === 'string' && errorMessage.includes('execution reverted:')) {
        errorMessage = errorMessage.split('execution reverted:')[1].trim()
      }

      toast({
        title: "Deposit failed",
        description: errorMessage,
        variant: "destructive",
        duration: 5000,
      })
    }
  }, [depositError, toast])

  // Function to approve USDC
  const handleApprove = async (amount: string) => {
    if (!amount || !isConnected) return

    try {
      setIsCheckingApproval(true)
      const parsedAmount = parseUnits(amount, 6) // USDC has 6 decimals

      approveUsdc({
        address: contractAddresses.usdc as `0x${string}`,
        abi: erc20Abi,
        functionName: 'approve',
        args: [contractAddresses.fundsVault, parsedAmount],
      })

      setDepositAmount(amount)
    } catch (error) {
      console.error('Error approving USDC:', error)
      toast({
        title: "Approval error",
        description: "Failed to approve USDC. Please try again.",
        variant: "destructive",
      })
    } finally {
      setIsCheckingApproval(false)
    }
  }

  // Function to deposit USDC
  const handleDeposit = async (amount: string) => {
    if (!amount || !isConnected) return

    try {
      const parsedAmount = parseUnits(amount, 6) // USDC has 6 decimals

      depositUsdc({
        address: contractAddresses.fundsVault as `0x${string}`,
        abi: fundsVaultAbi,
        functionName: 'deposit',
        args: [parsedAmount],
      })
    } catch (error) {
      console.error('Error depositing USDC:', error)
      toast({
        title: "Deposit error",
        description: "Failed to deposit USDC. Please try again.",
        variant: "destructive",
      })
    }
  }

  // Function to handle one-click deposit (approve if needed, then deposit)
  const handleOneClickDeposit = async (amount: string) => {
    if (!amount || !isConnected) return

    try {
      const parsedAmount = parseUnits(amount, 6) // USDC has 6 decimals

      // Check if approval is needed
      if (!isApproved) {
        // Need to approve first
        await handleApprove(amount)
        // Note: We can't automatically proceed to deposit here because
        // the approval transaction needs to be confirmed by the user and mined first
        toast({
          title: "Approval required",
          description: "Please approve USDC spending first, then you can deposit.",
          duration: 5000,
        })
        return
      }

      // Already approved, proceed with deposit
      await handleDeposit(amount)
    } catch (error) {
      console.error('Error in one-click deposit:', error)
      toast({
        title: "Transaction error",
        description: "Failed to process your deposit. Please try again.",
        variant: "destructive",
      })
    }
  }

  return {
    // State
    isApproved,
    isCheckingApproval,
    depositAmount,

    // Loading states
    isApproveLoading: isApproveLoading || isApproveConfirming,
    isDepositLoading: isDepositLoading || isDepositConfirming,

    // Completion states
    isApproveComplete,
    isDepositComplete,

    // Data
    userInfo,
    usdcBalance,
    pSyldBalance,

    // Functions
    handleApprove,
    handleDeposit,
    handleOneClickDeposit,

    // Connection state
    isConnected,
  }
}
