'use client'

import { useState } from 'react'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/Card'
import { CreditCard, TrendingDown, Calendar, DollarSign } from 'lucide-react'

interface Debt {
  id: string
  name: string
  principal: number
  currentBalance: number
  interestRate: number
  minimumPayment: number
  estimatedPayoffDate: string
  totalInterest: number
  progress: number
}

export default function DebtsPage() {
  const [debts] = useState<Debt[]>([
    {
      id: '1',
      name: 'Credit Card',
      principal: 5000,
      currentBalance: 3200,
      interestRate: 18.5,
      minimumPayment: 150,
      estimatedPayoffDate: '2025-08-15',
      totalInterest: 850,
      progress: 36
    },
    {
      id: '2',
      name: 'Student Loan',
      principal: 15000,
      currentBalance: 9300,
      interestRate: 6.5,
      minimumPayment: 200,
      estimatedPayoffDate: '2027-12-01',
      totalInterest: 2100,
      progress: 38
    }
  ])

  const totalDebt = debts.reduce((sum, debt) => sum + debt.currentBalance, 0)
  const totalPaid = debts.reduce((sum, debt) => sum + (debt.principal - debt.currentBalance), 0)
  const avgInterestRate = debts.reduce((sum, debt) => sum + (debt.interestRate * debt.currentBalance), 0) / totalDebt

  const calculatePayoffDate = (balance: number, rate: number, payment: number) => {
    const monthlyRate = rate / 100 / 12
    const months = Math.log(payment / (payment - balance * monthlyRate)) / Math.log(1 + monthlyRate)
    return Math.ceil(months)
  }

  return (
    <div className="space-y-6">
      <h1 className="text-3xl font-bold text-gray-900">Debt Tracker</h1>
      
      {/* Summary Cards */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium text-gray-600">Total Debt</CardTitle>
            <CreditCard className="h-4 w-4 text-red-600" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold text-red-600">
              ${totalDebt.toLocaleString()}
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium text-gray-600">Total Paid</CardTitle>
            <TrendingDown className="h-4 w-4 text-green-600" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold text-green-600">
              ${totalPaid.toLocaleString()}
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium text-gray-600">Avg Interest Rate</CardTitle>
            <DollarSign className="h-4 w-4 text-orange-600" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold text-orange-600">
              {avgInterestRate.toFixed(1)}%
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium text-gray-600">Active Debts</CardTitle>
            <Calendar className="h-4 w-4 text-blue-600" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold text-blue-600">
              {debts.length}
            </div>
          </CardContent>
        </Card>
      </div>

      {/* Debt Cards */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {debts.map((debt) => (
          <Card key={debt.id}>
            <CardHeader>
              <CardTitle className="flex items-center justify-between">
                <span>{debt.name}</span>
                <span className="text-sm font-normal text-gray-500">
                  {debt.interestRate}% APR
                </span>
              </CardTitle>
            </CardHeader>
            <CardContent className="space-y-4">
              {/* Progress Bar */}
              <div>
                <div className="flex justify-between text-sm text-gray-600 mb-1">
                  <span>Progress</span>
                  <span>{debt.progress}% paid off</span>
                </div>
                <div className="w-full bg-gray-200 rounded-full h-2">
                  <div 
                    className="bg-green-600 h-2 rounded-full transition-all duration-300"
                    style={{ width: `${debt.progress}%` }}
                  ></div>
                </div>
              </div>

              {/* Debt Details */}
              <div className="space-y-2">
                <div className="flex justify-between">
                  <span className="text-sm text-gray-600">Current Balance:</span>
                  <span className="font-medium text-red-600">${debt.currentBalance.toLocaleString()}</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-sm text-gray-600">Original Amount:</span>
                  <span className="font-medium">${debt.principal.toLocaleString()}</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-sm text-gray-600">Minimum Payment:</span>
                  <span className="font-medium">${debt.minimumPayment}</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-sm text-gray-600">Payoff Date:</span>
                  <span className="font-medium">{new Date(debt.estimatedPayoffDate).toLocaleDateString()}</span>
                </div>
                <div className="flex justify-between border-t pt-2">
                  <span className="text-sm text-gray-600">Total Interest:</span>
                  <span className="font-medium text-orange-600">${debt.totalInterest.toLocaleString()}</span>
                </div>
              </div>

              {/* Action Buttons */}
              <div className="flex space-x-2 pt-2">
                <button className="flex-1 bg-blue-600 text-white px-4 py-2 rounded-md text-sm font-medium hover:bg-blue-700 transition-colors">
                  Make Payment
                </button>
                <button className="flex-1 bg-gray-100 text-gray-700 px-4 py-2 rounded-md text-sm font-medium hover:bg-gray-200 transition-colors">
                  View Details
                </button>
              </div>
            </CardContent>
          </Card>
        ))}
      </div>

      {/* Debt Strategy */}
      <Card>
        <CardHeader>
          <CardTitle>Debt Payoff Strategy</CardTitle>
        </CardHeader>
        <CardContent>
          <div className="space-y-4">
            <div className="p-4 bg-blue-50 border border-blue-200 rounded-lg">
              <h4 className="font-medium text-blue-900 mb-2">💡 Debt Avalanche Method</h4>
              <p className="text-blue-700 text-sm">
                Focus on paying off your Credit Card first (18.5% interest) while making minimum payments on other debts. 
                This will save you the most money in interest over time.
              </p>
            </div>
            
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div className="p-4 border rounded-lg">
                <h5 className="font-medium mb-2">If you pay an extra $50/month:</h5>
                <ul className="text-sm text-gray-600 space-y-1">
                  <li>• Credit Card: Paid off 8 months earlier</li>
                  <li>• Save approximately $340 in interest</li>
                  <li>• Total debt-free date: 6 months sooner</li>
                </ul>
              </div>
              
              <div className="p-4 border rounded-lg">
                <h5 className="font-medium mb-2">If you pay an extra $100/month:</h5>
                <ul className="text-sm text-gray-600 space-y-1">
                  <li>• Credit Card: Paid off 14 months earlier</li>
                  <li>• Save approximately $580 in interest</li>
                  <li>• Total debt-free date: 11 months sooner</li>
                </ul>
              </div>
            </div>
          </div>
        </CardContent>
      </Card>
    </div>
  )
}