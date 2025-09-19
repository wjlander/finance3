'use client'

import { useState } from 'react'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/Card'
import { Search, Filter, Plus, ArrowUpDown, Calendar, DollarSign } from 'lucide-react'

interface Transaction {
  id: string
  date: string
  description: string
  category: string
  amount: number
  type: 'income' | 'expense' | 'transfer'
  account: string
  isRecurring: boolean
}

export default function TransactionsPage() {
  const [transactions] = useState<Transaction[]>([
    {
      id: '1',
      date: '2024-01-15',
      description: 'Salary Deposit',
      category: 'Income',
      amount: 2250.00,
      type: 'income',
      account: 'Checking Account',
      isRecurring: true
    },
    {
      id: '2',
      date: '2024-01-15',
      description: 'Grocery Store',
      category: 'Food & Dining',
      amount: -125.50,
      type: 'expense',
      account: 'Credit Card',
      isRecurring: false
    },
    {
      id: '3',
      date: '2024-01-14',
      description: 'Gas Station',
      category: 'Transportation',
      amount: -45.00,
      type: 'expense',
      account: 'Debit Card',
      isRecurring: false
    },
    {
      id: '4',
      date: '2024-01-14',
      description: 'Electric Bill',
      category: 'Utilities',
      amount: -89.50,
      type: 'expense',
      account: 'Checking Account',
      isRecurring: true
    },
    {
      id: '5',
      date: '2024-01-13',
      description: 'Coffee Shop',
      category: 'Food & Dining',
      amount: -4.75,
      type: 'expense',
      account: 'Credit Card',
      isRecurring: false
    },
    {
      id: '6',
      date: '2024-01-12',
      description: 'Online Transfer',
      category: 'Transfer',
      amount: -500.00,
      type: 'transfer',
      account: 'Savings Account',
      isRecurring: false
    }
  ])

  const [searchTerm, setSearchTerm] = useState('')
  const [selectedCategory, setSelectedCategory] = useState('all')
  const [selectedType, setSelectedType] = useState('all')

  // Calculate summary statistics
  const totalIncome = transactions
    .filter(t => t.type === 'income')
    .reduce((sum, t) => sum + t.amount, 0)
  
  const totalExpenses = transactions
    .filter(t => t.type === 'expense')
    .reduce((sum, t) => sum + Math.abs(t.amount), 0)
  
  const netAmount = totalIncome - totalExpenses

  // Get unique categories for filter
  const categories = Array.from(new Set(transactions.map(t => t.category)))

  // Filter transactions
  const filteredTransactions = transactions.filter(transaction => {
    const matchesSearch = transaction.description.toLowerCase().includes(searchTerm.toLowerCase()) ||
                         transaction.category.toLowerCase().includes(searchTerm.toLowerCase())
    const matchesCategory = selectedCategory === 'all' || transaction.category === selectedCategory
    const matchesType = selectedType === 'all' || transaction.type === selectedType
    
    return matchesSearch && matchesCategory && matchesType
  })

  const formatAmount = (amount: number, type: string) => {
    const absAmount = Math.abs(amount)
    const sign = type === 'income' ? '+' : type === 'expense' ? '-' : ''
    return `${sign}$${absAmount.toFixed(2)}`
  }

  const getAmountColor = (type: string) => {
    switch (type) {
      case 'income': return 'text-green-600'
      case 'expense': return 'text-red-600'
      case 'transfer': return 'text-blue-600'
      default: return 'text-gray-600'
    }
  }

  return (
    <div className="space-y-6">
      <div className="flex justify-between items-center">
        <h1 className="text-3xl font-bold text-gray-900">Transactions</h1>
        <button className="bg-blue-600 text-white px-4 py-2 rounded-md font-medium hover:bg-blue-700 transition-colors flex items-center space-x-2">
          <Plus className="w-4 h-4" />
          <span>Add Transaction</span>
        </button>
      </div>

      {/* Summary Cards */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium text-gray-600">Total Income</CardTitle>
            <ArrowUpDown className="h-4 w-4 text-green-600" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold text-green-600">
              ${totalIncome.toLocaleString()}
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium text-gray-600">Total Expenses</CardTitle>
            <DollarSign className="h-4 w-4 text-red-600" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold text-red-600">
              ${totalExpenses.toLocaleString()}
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium text-gray-600">Net Amount</CardTitle>
            <Calendar className="h-4 w-4 text-blue-600" />
          </CardHeader>
          <CardContent>
            <div className={`text-2xl font-bold ${netAmount >= 0 ? 'text-green-600' : 'text-red-600'}`}>
              ${netAmount.toLocaleString()}
            </div>
          </CardContent>
        </Card>
      </div>

      {/* Filters */}
      <Card>
        <CardContent className="p-6">
          <div className="flex flex-col md:flex-row gap-4">
            {/* Search */}
            <div className="flex-1 relative">
              <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 text-gray-400 w-4 h-4" />
              <input
                type="text"
                placeholder="Search transactions..."
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
                className="w-full pl-10 pr-4 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500 focus:border-transparent"
              />
            </div>

            {/* Category Filter */}
            <div className="relative">
              <Filter className="absolute left-3 top-1/2 transform -translate-y-1/2 text-gray-400 w-4 h-4" />
              <select
                value={selectedCategory}
                onChange={(e) => setSelectedCategory(e.target.value)}
                className="pl-10 pr-8 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500 focus:border-transparent appearance-none bg-white"
              >
                <option value="all">All Categories</option>
                {categories.map(category => (
                  <option key={category} value={category}>{category}</option>
                ))}
              </select>
            </div>

            {/* Type Filter */}
            <select
              value={selectedType}
              onChange={(e) => setSelectedType(e.target.value)}
              className="px-4 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500 focus:border-transparent"
            >
              <option value="all">All Types</option>
              <option value="income">Income</option>
              <option value="expense">Expense</option>
              <option value="transfer">Transfer</option>
            </select>
          </div>
        </CardContent>
      </Card>

      {/* Transactions List */}
      <Card>
        <CardHeader>
          <CardTitle>Recent Transactions ({filteredTransactions.length})</CardTitle>
        </CardHeader>
        <CardContent>
          <div className="space-y-3">
            {filteredTransactions.length === 0 ? (
              <div className="text-center py-8 text-gray-500">
                No transactions found matching your criteria.
              </div>
            ) : (
              filteredTransactions.map((transaction) => (
                <div
                  key={transaction.id}
                  className="flex items-center justify-between p-4 border rounded-lg hover:bg-gray-50 transition-colors"
                >
                  <div className="flex-1">
                    <div className="flex items-center space-x-3">
                      <div>
                        <p className="font-medium text-gray-900">{transaction.description}</p>
                        <div className="flex items-center space-x-2 text-sm text-gray-500">
                          <span>{transaction.category}</span>
                          <span>•</span>
                          <span>{transaction.account}</span>
                          {transaction.isRecurring && (
                            <>
                              <span>•</span>
                              <span className="text-blue-600 font-medium">Recurring</span>
                            </>
                          )}
                        </div>
                      </div>
                    </div>
                  </div>
                  
                  <div className="text-right">
                    <div className={`text-lg font-bold ${getAmountColor(transaction.type)}`}>
                      {formatAmount(transaction.amount, transaction.type)}
                    </div>
                    <div className="text-sm text-gray-500">
                      {new Date(transaction.date).toLocaleDateString()}
                    </div>
                  </div>
                </div>
              ))
            )}
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
              <span className="text-sm font-medium text-gray-600">Add Income</span>
            </button>
            
            <button className="p-4 border border-dashed border-gray-300 rounded-lg hover:border-red-500 hover:bg-red-50 transition-colors text-center">
              <Plus className="w-6 h-6 mx-auto mb-2 text-gray-400" />
              <span className="text-sm font-medium text-gray-600">Add Expense</span>
            </button>
            
            <button className="p-4 border border-dashed border-gray-300 rounded-lg hover:border-green-500 hover:bg-green-50 transition-colors text-center">
              <ArrowUpDown className="w-6 h-6 mx-auto mb-2 text-gray-400" />
              <span className="text-sm font-medium text-gray-600">Transfer Funds</span>
            </button>
          </div>
        </CardContent>
      </Card>
    </div>
  )
}
