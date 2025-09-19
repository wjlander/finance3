'use client'

import { useState } from 'react'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/Card'
import { Plus, Eye, EyeOff, Trash2, Edit, Banknote, CreditCard, PiggyBank, Wallet } from 'lucide-react'

interface Account {
  id: string
  name: string
  type: 'checking' | 'savings' | 'credit' | 'investment'
  balance: number
  bankName: string
  accountNumber: string
  isActive: boolean
  lastSync: string
}

export default function AccountsPage() {
  const [accounts] = useState<Account[]>([
    {
      id: '1',
      name: 'Primary Checking',
      type: 'checking',
      balance: 2450.75,
      bankName: 'Chase Bank',
      accountNumber: '****1234',
      isActive: true,
      lastSync: '2024-01-15T10:30:00Z'
    },
    {
      id: '2',
      name: 'Emergency Savings',
      type: 'savings',
      balance: 8500.00,
      bankName: 'Chase Bank',
      accountNumber: '****5678',
      isActive: true,
      lastSync: '2024-01-15T10:30:00Z'
    },
    {
      id: '3',
      name: 'Travel Rewards Card',
      type: 'credit',
      balance: -1250.30,
      bankName: 'Capital One',
      accountNumber: '****9012',
      isActive: true,
      lastSync: '2024-01-15T09:45:00Z'
    },
    {
      id: '4',
      name: 'Investment Account',
      type: 'investment',
      balance: 15750.25,
      bankName: 'Fidelity',
      accountNumber: '****3456',
      isActive: true,
      lastSync: '2024-01-15T08:15:00Z'
    }
  ])

  const [showBalances, setShowBalances] = useState(true)

  const getAccountIcon = (type: string) => {
    switch (type) {
      case 'checking': return Wallet
      case 'savings': return PiggyBank
      case 'credit': return CreditCard
      case 'investment': return Banknote
      default: return Wallet
    }
  }

  const getAccountTypeColor = (type: string) => {
    switch (type) {
      case 'checking': return 'text-blue-600 bg-blue-100'
      case 'savings': return 'text-green-600 bg-green-100'
      case 'credit': return 'text-red-600 bg-red-100'
      case 'investment': return 'text-purple-600 bg-purple-100'
      default: return 'text-gray-600 bg-gray-100'
    }
  }

  const formatBalance = (balance: number, type: string) => {
    const absBalance = Math.abs(balance)
    if (type === 'credit') {
      return balance < 0 ? `-$${absBalance.toLocaleString()}` : `$${balance.toLocaleString()}`
    }
    return `$${balance.toLocaleString()}`
  }

  const getBalanceColor = (balance: number, type: string) => {
    if (type === 'credit') {
      return balance < 0 ? 'text-red-600' : 'text-green-600'
    }
    return balance >= 0 ? 'text-green-600' : 'text-red-600'
  }

  const totalAssets = accounts
    .filter(account => account.type !== 'credit' && account.balance > 0)
    .reduce((sum, account) => sum + account.balance, 0)

  const totalLiabilities = accounts
    .filter(account => account.type === 'credit' && account.balance < 0)
    .reduce((sum, account) => sum + Math.abs(account.balance), 0)

  const netWorth = totalAssets - totalLiabilities

  return (
    <div className="space-y-6">
      <div className="flex justify-between items-center">
        <h1 className="text-3xl font-bold text-gray-900">Accounts</h1>
        <div className="flex space-x-3">
          <button
            onClick={() => setShowBalances(!showBalances)}
            className="flex items-center space-x-2 px-4 py-2 text-gray-600 border border-gray-300 rounded-md hover:bg-gray-50 transition-colors"
          >
            {showBalances ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}
            <span>{showBalances ? 'Hide' : 'Show'} Balances</span>
          </button>
          <button className="bg-blue-600 text-white px-4 py-2 rounded-md font-medium hover:bg-blue-700 transition-colors flex items-center space-x-2">
            <Plus className="w-4 h-4" />
            <span>Add Account</span>
          </button>
        </div>
      </div>

      {/* Summary Cards */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium text-gray-600">Total Assets</CardTitle>
            <PiggyBank className="h-4 w-4 text-green-600" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold text-green-600">
              {showBalances ? `$${totalAssets.toLocaleString()}` : '••••••'}
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium text-gray-600">Total Liabilities</CardTitle>
            <CreditCard className="h-4 w-4 text-red-600" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold text-red-600">
              {showBalances ? `$${totalLiabilities.toLocaleString()}` : '••••••'}
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium text-gray-600">Net Worth</CardTitle>
            <Banknote className="h-4 w-4 text-blue-600" />
          </CardHeader>
          <CardContent>
            <div className={`text-2xl font-bold ${netWorth >= 0 ? 'text-green-600' : 'text-red-600'}`}>
              {showBalances ? `$${netWorth.toLocaleString()}` : '••••••'}
            </div>
          </CardContent>
        </Card>
      </div>

      {/* Accounts Grid */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {accounts.map((account) => {
          const Icon = getAccountIcon(account.type)
          return (
            <Card key={account.id} className="hover:shadow-md transition-shadow">
              <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-4">
                <div className="flex items-center space-x-3">
                  <div className={`p-2 rounded-full ${getAccountTypeColor(account.type)}`}>
                    <Icon className="w-4 h-4" />
                  </div>
                  <div>
                    <CardTitle className="text-lg">{account.name}</CardTitle>
                    <p className="text-sm text-gray-500">{account.bankName}</p>
                  </div>
                </div>
                <div className="flex items-center space-x-2">
                  <button className="p-2 text-gray-400 hover:text-gray-600 transition-colors">
                    <Edit className="w-4 h-4" />
                  </button>
                  <button className="p-2 text-gray-400 hover:text-red-600 transition-colors">
                    <Trash2 className="w-4 h-4" />
                  </button>
                </div>
              </CardHeader>
              <CardContent className="space-y-4">
                {/* Balance */}
                <div className="flex justify-between items-center">
                  <span className="text-sm text-gray-600">Balance:</span>
                  <span className={`text-xl font-bold ${getBalanceColor(account.balance, account.type)}`}>
                    {showBalances ? formatBalance(account.balance, account.type) : '••••••'}
                  </span>
                </div>

                {/* Account Details */}
                <div className="space-y-2 text-sm">
                  <div className="flex justify-between">
                    <span className="text-gray-600">Account Number:</span>
                    <span className="font-mono">{account.accountNumber}</span>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-gray-600">Type:</span>
                    <span className="capitalize font-medium">{account.type}</span>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-gray-600">Last Sync:</span>
                    <span>{new Date(account.lastSync).toLocaleDateString()}</span>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-gray-600">Status:</span>
                    <span className={`font-medium ${account.isActive ? 'text-green-600' : 'text-red-600'}`}>
                      {account.isActive ? 'Active' : 'Inactive'}
                    </span>
                  </div>
                </div>

                {/* Action Buttons */}
                <div className="flex space-x-2 pt-2">
                  <button className="flex-1 bg-blue-600 text-white px-3 py-2 rounded-md text-sm font-medium hover:bg-blue-700 transition-colors">
                    View Transactions
                  </button>
                  <button className="flex-1 bg-gray-100 text-gray-700 px-3 py-2 rounded-md text-sm font-medium hover:bg-gray-200 transition-colors">
                    Sync Now
                  </button>
                </div>
              </CardContent>
            </Card>
          )
        })}
      </div>

      {/* Account Types Info */}
      <Card>
        <CardHeader>
          <CardTitle>Account Management</CardTitle>
        </CardHeader>
        <CardContent>
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
            <div className="p-4 border rounded-lg text-center">
              <Wallet className="w-8 h-8 mx-auto mb-2 text-blue-600" />
              <h4 className="font-medium text-blue-900">Checking</h4>
              <p className="text-sm text-gray-600 mt-1">Daily spending accounts</p>
            </div>
            
            <div className="p-4 border rounded-lg text-center">
              <PiggyBank className="w-8 h-8 mx-auto mb-2 text-green-600" />
              <h4 className="font-medium text-green-900">Savings</h4>
              <p className="text-sm text-gray-600 mt-1">Emergency & goal funds</p>
            </div>
            
            <div className="p-4 border rounded-lg text-center">
              <CreditCard className="w-8 h-8 mx-auto mb-2 text-red-600" />
              <h4 className="font-medium text-red-900">Credit</h4>
              <p className="text-sm text-gray-600 mt-1">Credit cards & loans</p>
            </div>
            
            <div className="p-4 border rounded-lg text-center">
              <Banknote className="w-8 h-8 mx-auto mb-2 text-purple-600" />
              <h4 className="font-medium text-purple-900">Investment</h4>
              <p className="text-sm text-gray-600 mt-1">Stocks, bonds & funds</p>
            </div>
          </div>
        </CardContent>
      </Card>

      {/* Quick Actions */}
      <Card>
        <CardHeader>
          <CardTitle>Quick Actions</CardTitle>
        </CardHeader>
        <CardContent>
          <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
            <button className="p-4 border border-dashed border-gray-300 rounded-lg hover:border-blue-500 hover:bg-blue-50 transition-colors text-center">
              <Plus className="w-6 h-6 mx-auto mb-2 text-gray-400" />
              <span className="text-sm font-medium text-gray-600">Connect Bank Account</span>
            </button>
            
            <button className="p-4 border border-dashed border-gray-300 rounded-lg hover:border-green-500 hover:bg-green-50 transition-colors text-center">
              <PiggyBank className="w-6 h-6 mx-auto mb-2 text-gray-400" />
              <span className="text-sm font-medium text-gray-600">Add Savings Goal</span>
            </button>
            
            <button className="p-4 border border-dashed border-gray-300 rounded-lg hover:border-purple-500 hover:bg-purple-50 transition-colors text-center">
              <Banknote className="w-6 h-6 mx-auto mb-2 text-gray-400" />
              <span className="text-sm font-medium text-gray-600">Link Investment</span>
            </button>
          </div>
        </CardContent>
      </Card>
    </div>
  )
}