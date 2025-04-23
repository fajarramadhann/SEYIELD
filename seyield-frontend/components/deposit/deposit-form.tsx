"use client"

import { useState, useEffect } from "react"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardDescription, CardFooter, CardHeader, CardTitle } from "@/components/ui/card"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select"
import { motion } from "framer-motion"
// We don't need useToast here as it's handled in the useDeposit hook
import { useAccount } from "wagmi"
import { useTokenBalance } from "@/hooks/useTokenBalance"
import { useDeposit } from "@/hooks/useDeposit"
import { Alert, AlertDescription, AlertTitle } from "@/components/ui/alert"
import { CheckCircle2, Loader2 } from "lucide-react"
import { formatUnits } from "viem"

export function DepositForm() {
  const [amount, setAmount] = useState("")
  const [asset, setAsset] = useState("usdc")
  // We don't need toast here as it's handled in the useDeposit hook
  const { isConnected } = useAccount()
  const { symbol, isLoading: isBalanceLoading } = useTokenBalance(asset as 'sei' | 'usdc')

  // Use our custom deposit hook
  const {
    isApproved,
    isApproveLoading,
    isDepositLoading,
    isApproveComplete,
    isDepositComplete,
    usdcBalance,
    pSyldBalance,
    handleApprove,
    handleDeposit,
    handleOneClickDeposit,
  } = useDeposit()

  // Format balances for display
  const formattedUsdcBalance = usdcBalance ? formatUnits(usdcBalance, 6) : "0"
  const formattedPSyldBalance = pSyldBalance ? formatUnits(pSyldBalance, 6) : "0"

  // Reset amount when deposit is complete
  useEffect(() => {
    if (isDepositComplete) {
      setAmount("")
    }
  }, [isDepositComplete])

  // Only allow USDC deposits for now
  useEffect(() => {
    if (asset !== "usdc") {
      setAsset("usdc")
    }
  }, [asset])

  // Common condition for disabling buttons
  const isInputInvalid =
    !isConnected ||
    !amount ||
    Number(amount) <= 0 ||
    isApproveLoading ||
    isDepositLoading

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
            <Select value={asset} onValueChange={setAsset} disabled={true}>
              <SelectTrigger id="asset">
                <SelectValue placeholder="Select Asset" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="usdc">USDC</SelectItem>
                <SelectItem value="sei" disabled>SEI (Coming Soon)</SelectItem>
              </SelectContent>
            </Select>
            <p className="text-xs text-muted-foreground">Currently only USDC deposits are supported</p>
          </div>

          <div className="space-y-2">
            <div className="flex justify-between">
              <Label htmlFor="amount">Amount</Label>
              {isConnected && (
                <div className="text-sm text-muted-foreground">
                  Balance: {isBalanceLoading ? "Loading..." : `${formattedUsdcBalance || "0"} ${symbol}`}
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
            {isConnected && formattedUsdcBalance && (
              <div className="flex justify-end">
                <Button
                  variant="link"
                  className="h-auto p-0 text-xs text-primary"
                  onClick={() => setAmount(formattedUsdcBalance)}
                  disabled={isApproveLoading || isDepositLoading}
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
            <div className="flex justify-between text-sm pt-2 border-t border-border">
              <span className="text-muted-foreground">You Receive</span>
              <span className="font-medium">
                {amount || "0.00"} pSYLD
              </span>
            </div>
          </div>

          {/* Status alerts */}
          {isApproveLoading && (
            <Alert variant="default" className="bg-blue-500/10 border-blue-500/20">
              <Loader2 className="h-4 w-4 text-blue-500 animate-spin" />
              <AlertTitle className="text-blue-500">Approving USDC</AlertTitle>
              <AlertDescription>
                Please confirm the transaction in your wallet...
              </AlertDescription>
            </Alert>
          )}

          {isDepositLoading && (
            <Alert variant="default" className="bg-blue-500/10 border-blue-500/20">
              <Loader2 className="h-4 w-4 text-blue-500 animate-spin" />
              <AlertTitle className="text-blue-500">Processing deposit</AlertTitle>
              <AlertDescription>
                Your deposit is being processed. Please wait...
              </AlertDescription>
            </Alert>
          )}

          {isDepositComplete && (
            <Alert variant="default" className="bg-green-500/10 border-green-500/20">
              <CheckCircle2 className="h-4 w-4 text-green-500" />
              <AlertTitle className="text-green-500">Deposit successful!</AlertTitle>
              <AlertDescription>
                <p>You have successfully deposited USDC and received pSYLD tokens.</p>
                <p className="text-sm text-green-500 mt-1">Your pSYLD balance: {formattedPSyldBalance} pSYLD</p>
              </AlertDescription>
            </Alert>
          )}
        </CardContent>
        <CardFooter className="flex flex-col space-y-4">
          {/* One-click deposit button */}
          <Button
            onClick={() => handleOneClickDeposit(amount)}
            disabled={isInputInvalid}
            className="w-full bg-gradient-to-r from-pink-500 to-violet-600 hover:from-pink-600 hover:to-violet-700"
          >
            {!isConnected
              ? "Connect Wallet"
              : isApproveLoading
                ? "Approving..."
                : isDepositLoading
                  ? "Processing..."
                  : !isApproved
                    ? "Approve & Deposit"
                    : "Deposit USDC"}
          </Button>

          {/* Show separate approve and deposit buttons for more control */}
          {isConnected && !isApproveLoading && !isDepositLoading && (
            <div className="flex gap-2 w-full">
              <Button
                onClick={() => handleApprove(amount)}
                disabled={isInputInvalid || isApproved || isApproveComplete}
                variant="outline"
                className="flex-1"
                size="sm"
              >
                Approve Only
              </Button>

              <Button
                onClick={() => handleDeposit(amount)}
                disabled={!isApproved && !isApproveComplete}
                variant="outline"
                className="flex-1"
                size="sm"
              >
                Deposit Only
              </Button>
            </div>
          )}

          {isConnected && (
            <div className="text-xs text-center text-muted-foreground">
              <p>Depositing will mint pSYLD tokens at a 1:1 ratio with your USDC</p>
              <p className="mt-1">You can withdraw your deposit at any time</p>
              {!isApproved && !isApproveComplete && (
                <p className="mt-1 text-amber-500">Note: This requires two transactions - first approve, then deposit</p>
              )}
            </div>
          )}
        </CardFooter>
      </Card>
    </motion.div>
  )
}
