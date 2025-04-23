"use client"

import { useState } from "react"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardDescription, CardFooter, CardHeader, CardTitle } from "@/components/ui/card"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select"
import { motion } from "framer-motion"
import { useToast } from "@/components/ui/use-toast"
import { useAccount } from "wagmi"
import { useTokenBalance } from "@/hooks/useTokenBalance"

export function DepositForm() {
  const [amount, setAmount] = useState("")
  const [asset, setAsset] = useState("usdc")
  const [isLoading, setIsLoading] = useState(false)
  const { toast } = useToast()
  const { isConnected } = useAccount()
  const { balance, symbol, isLoading: isBalanceLoading } = useTokenBalance(asset as 'sei' | 'usdc')

  const handleDeposit = () => {
    setIsLoading(true)
    // Simulate API call
    setTimeout(() => {
      setIsLoading(false)
      toast({
        title: "Deposit successful!",
        description: `You've deposited ${amount} ${asset.toUpperCase()}. Your rewards will start accumulating immediately.`,
      })
      setAmount("")
    }, 2000)
  }

  return (
    <motion.div
      initial={{ opacity: 0, y: 20 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.5, delay: 0.2 }}
      id="deposit-form"
    >
      <Card className="border border-pink-100 dark:border-pink-900/20">
        <CardHeader>
          <CardTitle>Deposit Assets</CardTitle>
          <CardDescription>Deposit your assets to start generating rewards for shopping</CardDescription>
        </CardHeader>
        <CardContent className="space-y-6">
          <div className="space-y-2">
            <Label htmlFor="asset">Select Asset</Label>
            <Select value={asset} onValueChange={setAsset}>
              <SelectTrigger id="asset">
                <SelectValue placeholder="Select Asset" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="usdc">USDC</SelectItem>
                <SelectItem value="sei">SEI</SelectItem>
              </SelectContent>
            </Select>
          </div>

          <div className="space-y-2">
            <div className="flex justify-between">
              <Label htmlFor="amount">Amount</Label>
              {isConnected && (
                <div className="text-sm text-muted-foreground">
                  Balance: {isBalanceLoading ? "Loading..." : `${balance || "0"} ${symbol}`}
                </div>
              )}
            </div>
            <div className="relative">
              <Input
                id="amount"
                type="number"
                placeholder="0.00"
                value={amount}
                onChange={(e) => setAmount(e.target.value)}
                className="pr-16"
              />
              <div className="absolute inset-y-0 right-0 flex items-center pr-3 pointer-events-none text-muted-foreground">
                {asset.toUpperCase()}
              </div>
            </div>
            {isConnected && balance && (
              <div className="flex justify-end">
                <Button
                  variant="link"
                  className="h-auto p-0 text-xs text-primary"
                  onClick={() => setAmount(balance)}
                >
                  Max
                </Button>
              </div>
            )}
          </div>

          <div className="space-y-2 rounded-lg bg-muted p-4">
            <div className="flex justify-between text-sm">
              <span className="text-muted-foreground">Annual Rewards (7%)</span>
              <span className="font-medium">
                {amount ? (Number.parseFloat(amount) * 0.07).toFixed(2) : "0.00"} {asset.toUpperCase()}
              </span>
            </div>
            <div className="flex justify-between text-sm">
              <span className="text-muted-foreground">Monthly Rewards</span>
              <span className="font-medium">
                {amount ? ((Number.parseFloat(amount) * 0.07) / 12).toFixed(2) : "0.00"} {asset.toUpperCase()}
              </span>
            </div>
            <div className="flex justify-between text-sm">
              <span className="text-muted-foreground">Deposit Amount</span>
              <span className="font-medium">
                {amount || "0.00"} {asset.toUpperCase()}
              </span>
            </div>
          </div>
        </CardContent>
        <CardFooter>
          <Button
            onClick={handleDeposit}
            disabled={!amount || Number.parseFloat(amount) <= 0 || isLoading || !isConnected}
            className="w-full bg-gradient-to-r from-pink-500 to-violet-600 hover:from-pink-600 hover:to-violet-700"
          >
            {!isConnected ? "Connect Wallet to Deposit" : isLoading ? "Processing..." : "Deposit"}
          </Button>
        </CardFooter>
      </Card>
    </motion.div>
  )
}
