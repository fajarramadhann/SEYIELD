'use client'

import { useState, useEffect } from 'react'
import { useAccount, useReadContract, useWriteContract, useWaitForTransactionReceipt } from 'wagmi'
import { parseUnits, formatUnits } from 'viem'
import { contractAddresses } from '@/app/config/contract-addresses'
import { merchantAbi } from '@/app/config/abis/merchant-abi'
import { erc20Abi } from '@/app/config/abis/erc20-abi'
import { useToast } from '@/components/ui/use-toast'

export interface MerchantItem {
  id: number
  merchant: string
  name: string
  description: string
  price: bigint
  requiredYSYLD: bigint
  isActive: boolean
}

export interface Purchase {
  id: number
  buyer: string
  merchant: string
  itemId: number
  price: bigint
  timestamp: number
  isPaid: boolean
}

export function useMerchantContract() {
  const { address, isConnected } = useAccount()
  const { toast } = useToast()
  const [isLoading, setIsLoading] = useState(false)
  const [items, setItems] = useState<MerchantItem[]>([])
  const [purchases, setPurchases] = useState<Purchase[]>([])

  // Get user's ySYLD balance
  const { data: ySYLDBalance, refetch: refetchYSYLDBalance } = useReadContract({
    address: contractAddresses.yieldToken as `0x${string}`,
    abi: erc20Abi,
    functionName: 'balanceOf',
    args: [address],
    query: {
      enabled: !!address && isConnected,
    }
  })

  // Get item count
  const { data: itemCount, refetch: refetchItemCount } = useReadContract({
    address: contractAddresses.merchant as `0x${string}`,
    abi: merchantAbi,
    functionName: 'itemCount',
    query: {
      enabled: isConnected,
    }
  })

  // Get purchase count
  const { data: purchaseCount, refetch: refetchPurchaseCount } = useReadContract({
    address: contractAddresses.merchant as `0x${string}`,
    abi: merchantAbi,
    functionName: 'purchaseCount',
    query: {
      enabled: isConnected,
    }
  })

  // Purchase item
  const {
    data: purchaseData,
    isPending: isPurchaseLoading,
    isSuccess: isPurchaseStarted,
    writeContract: purchaseItem,
    error: purchaseError
  } = useWriteContract()

  // Wait for purchase transaction to complete
  const {
    isLoading: isPurchaseConfirming,
    isSuccess: isPurchaseComplete
  } = useWaitForTransactionReceipt({
    hash: purchaseData,
  })

  // Load items
  useEffect(() => {
    if (!itemCount || !isConnected) return

    const loadItems = async () => {
      setIsLoading(true)
      try {
        const itemsArray: MerchantItem[] = []

        for (let i = 1; i <= Number(itemCount); i++) {
          try {
            const itemInfo = await readContract({
              address: contractAddresses.merchant as `0x${string}`,
              abi: merchantAbi,
              functionName: 'getItemInfo',
              args: [BigInt(i)],
            })

            if (itemInfo && itemInfo.isActive) {
              itemsArray.push({
                id: i,
                merchant: itemInfo.merchant,
                name: itemInfo.name,
                description: itemInfo.description,
                price: itemInfo.price,
                requiredYSYLD: itemInfo.requiredYSYLD,
                isActive: itemInfo.isActive
              })
            }
          } catch (error) {
            console.error(`Error loading item ${i}:`, error)
          }
        }

        setItems(itemsArray)
      } catch (error) {
        console.error('Error loading items:', error)
        toast({
          title: "Failed to load marketplace items",
          description: "There was an error loading the marketplace items. Please try again later.",
          variant: "destructive",
        })
      } finally {
        setIsLoading(false)
      }
    }

    loadItems()
  }, [itemCount, isConnected, toast])

  // Load user purchases
  useEffect(() => {
    if (!address || !isConnected || !purchaseCount) return

    const loadPurchases = async () => {
      try {
        const purchasesArray: Purchase[] = []

        for (let i = 1; i <= Number(purchaseCount); i++) {
          try {
            const purchaseInfo = await readContract({
              address: contractAddresses.merchant as `0x${string}`,
              abi: merchantAbi,
              functionName: 'getPurchaseInfo',
              args: [BigInt(i)],
            })

            if (purchaseInfo && purchaseInfo.buyer === address) {
              purchasesArray.push({
                id: i,
                buyer: purchaseInfo.buyer,
                merchant: purchaseInfo.merchant,
                itemId: Number(purchaseInfo.itemId),
                price: purchaseInfo.price,
                timestamp: Number(purchaseInfo.timestamp),
                isPaid: purchaseInfo.isPaid
              })
            }
          } catch (error) {
            console.error(`Error loading purchase ${i}:`, error)
          }
        }

        setPurchases(purchasesArray)
      } catch (error) {
        console.error('Error loading purchases:', error)
      }
    }

    loadPurchases()
  }, [address, isConnected, purchaseCount, isPurchaseComplete])

  // Handle purchase errors
  useEffect(() => {
    if (purchaseError) {
      console.error('Purchase error:', purchaseError)

      // Extract revert reason if available
      let errorMessage = purchaseError.message || "Failed to complete purchase. Please try again."
      if (typeof errorMessage === 'string' && errorMessage.includes('execution reverted:')) {
        errorMessage = errorMessage.split('execution reverted:')[1].trim()
      }

      toast({
        title: "Purchase failed",
        description: errorMessage,
        variant: "destructive",
        duration: 5000,
      })
    }
  }, [purchaseError, toast])

  // Function to handle item purchase
  const handlePurchaseItem = async (itemId: number) => {
    if (!isConnected) {
      toast({
        title: "Wallet not connected",
        description: "Please connect your wallet to make a purchase.",
        variant: "destructive",
      })
      return
    }

    try {
      // Find the item
      const item = items.find(i => i.id === itemId)
      if (!item) {
        toast({
          title: "Item not found",
          description: "The item you're trying to purchase could not be found.",
          variant: "destructive",
        })
        return
      }

      // Check if user has enough ySYLD
      if (ySYLDBalance && ySYLDBalance < item.price) {
        toast({
          title: "Insufficient ySYLD",
          description: `You need at least ${formatUnits(item.price, 6)} ySYLD tokens to purchase this item.`,
          variant: "destructive",
        })
        return
      }

      // Execute purchase - this will burn ySYLD tokens and automatically pay the merchant
      await purchaseItem({
        address: contractAddresses.merchant as `0x${string}`,
        abi: merchantAbi,
        functionName: 'purchaseItem',
        args: [BigInt(itemId)],
      })
    } catch (error) {
      console.error('Error purchasing item:', error)
      toast({
        title: "Purchase error",
        description: "Failed to purchase item. Please try again.",
        variant: "destructive",
      })
    }
  }

  // Function to refresh data
  const refreshData = async () => {
    await Promise.all([
      refetchYSYLDBalance(),
      refetchItemCount(),
      refetchPurchaseCount()
    ])
  }

  return {
    // State
    isLoading,
    isPurchaseLoading: isPurchaseLoading || isPurchaseConfirming,
    isPurchaseComplete,
    items,
    purchases,
    ySYLDBalance,

    // Functions
    handlePurchaseItem,
    refreshData,

    // Connection state
    isConnected,
  }
}

// Helper function to read contract data
async function readContract({ address, abi, functionName, args }) {
  // This is a placeholder - in a real implementation, you would use a library like viem or ethers.js
  // to read contract data. For now, we'll just return mock data.
  return null
}
