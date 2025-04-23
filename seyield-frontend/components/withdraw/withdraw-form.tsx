"use client"

import { useState } from "react"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardDescription, CardFooter, CardHeader, CardTitle } from "@/components/ui/card"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select"
import { motion } from "framer-motion"
import { useToast } from "@/components/ui/use-toast"
import { RadioGroup, RadioGroupItem } from "@/components/ui/radio-group"

export function WithdrawForm() {
  const [amount, setAmount] = useState("")
  const [asset, setAsset] = useState("usdc")
  const [withdrawType, setWithdrawType] = useState("deposit")
  const [isLoading, setIsLoading] = useState(false)
  const { toast } = useToast()

  const handleWithdraw = () => {
    setIsLoading(true)
    // Simulate API call
    setTimeout(() => {
      setIsLoading(false)
      toast({
        title: "Withdrawal initiated!",
        description: `You've withdrawn ${amount} ${asset.toUpperCase()} from your ${withdrawType === "deposit" ? "deposit" : "rewards"}.`,
      })
      setAmount("")
    }, 2000)
  }

  return (
    <motion.div
      initial={{ opacity: 0, y: 20 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.5, delay: 0.2 }}
      id="withdraw-form"
    >
      <Card className="border border-pink-100 dark:border-pink-900/20">
        <CardHeader>
          <CardTitle>Withdraw Assets</CardTitle>
          <CardDescription>Access your deposited funds or rewards</CardDescription>
        </CardHeader>
        <CardContent className="space-y-6">
          <div className="space-y-2">
            <Label>Withdraw From</Label>
            <RadioGroup value={withdrawType} onValueChange={setWithdrawType} className="flex flex-col space-y-1">
              <div className="flex items-center space-x-2">
                <RadioGroupItem value="deposit" id="deposit" />
                <Label htmlFor="deposit" className="cursor-pointer">
                  Deposit (2,400 USDC available)
                </Label>
              </div>
              <div className="flex items-center space-x-2">
                <RadioGroupItem value="rewards" id="rewards" />
                <Label htmlFor="rewards" className="cursor-pointer">
                  Rewards (100 USDC available)
                </Label>
              </div>
            </RadioGroup>
          </div>

          <div className="space-y-2">
            <Label htmlFor="asset">Select Asset</Label>
            <Select value={asset} onValueChange={setAsset}>
              <SelectTrigger id="asset">
                <SelectValue placeholder="Select Asset" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="usdc">USDC</SelectItem>
                <SelectItem value="usdt">USDT</SelectItem>
                <SelectItem value="dai">DAI</SelectItem>
                <SelectItem value="sei">SEI</SelectItem>
              </SelectContent>
            </Select>
          </div>

          <div className="space-y-2">
            <Label htmlFor="amount">Amount</Label>
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
          </div>

          {withdrawType === "deposit" && (
            <div className="rounded-lg bg-amber-50 dark:bg-amber-950/20 p-4 text-amber-800 dark:text-amber-300 text-sm">
              <p className="font-medium">Early Withdrawal Notice</p>
              <p className="mt-1">
                Your deposit is locked for 30 days. Withdrawing before this period will incur a 5% fee.
              </p>
            </div>
          )}
        </CardContent>
        <CardFooter>
          <Button
            onClick={handleWithdraw}
            disabled={!amount || Number.parseFloat(amount) <= 0 || isLoading}
            className="w-full bg-gradient-to-r from-pink-500 to-violet-600 hover:from-pink-600 hover:to-violet-700"
          >
            {isLoading ? "Processing..." : "Withdraw"}
          </Button>
        </CardFooter>
      </Card>
    </motion.div>
  )
}
