'use client'

import { useState } from 'react'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/Card'
import { Calendar, DollarSign, TrendingUp } from 'lucide-react'

export default function BudgetPage() {
  const [budget, setBudget] = useState({
    name: 'My Budget',
    monthlyIncome: 4500,
    payFrequency: 'bi-weekly',
    firstPayDate: '2024-01-01'
  })

  // Calculate bi-weekly income
  const biWeeklyIncome = budget.monthlyIncome * 12 / 26

  // Mock current period data
  const currentPeriod = {
    start: '2024-01-15',
    end: '2024-01-28',
    income: biWeeklyIncome,
    spent: 1250.75,
    remaining: biWeeklyIncome - 1250.75
  }

  const nextPeriod = {
    start: '2024-01-29',
    end: '2024-02-11',
    income: biWeeklyIncome,
    projectedBills: 850.00
  }

  return (
    <div className="space-y-6">
      <h1 className="text-3xl font-bold text-gray-900">Budget Tracker</h1>
      
      {/* Pay Period Cards */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-lg font-medium">Current Pay Period</CardTitle>
            <Calendar className="h-5 w-5 text-blue-600" />
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="text-sm text-gray-600">
              {new Date(currentPeriod.start).toLocaleDateString()} - {new Date(currentPeriod.end).toLocaleDateString()}
            </div>
            <div className="space-y-2">
              <div className="flex justify-between">
                <span className="text-sm text-gray-600">Income:</span>
                <span className="font-medium text-green-600">${currentPeriod.income.toFixed(2)}</span>
              </div>
              <div className="flex justify-between">
                <span className="text-sm text-gray-600">Spent:</span>
                <span className="font-medium text-red-600">${currentPeriod.spent.toFixed(2)}</span>
              </div>
              <div className="flex justify-between border-t pt-2">
                <span className="font-medium">Remaining:</span>
                <span className={`font-bold ${currentPeriod.remaining >= 0 ? 'text-green-600' : 'text-red-600'}`}>
                  ${currentPeriod.remaining.toFixed(2)}
                </span>
              </div>
            </div>
            
            {/* Progress Bar */}
            <div className="w-full bg-gray-200 rounded-full h-2">
              <div 
                className="bg-blue-600 h-2 rounded-full transition-all duration-300"
                style={{ width: `${Math.min((currentPeriod.spent / currentPeriod.income) * 100, 100)}%` }}
              ></div>
            </div>
            <div className="text-xs text-gray-500 text-center">
              {((currentPeriod.spent / currentPeriod.income) * 100).toFixed(1)}% of income used
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-lg font-medium">Next Pay Period</CardTitle>
            <TrendingUp className="h-5 w-5 text-green-600" />
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="text-sm text-gray-600">
              {new Date(nextPeriod.start).toLocaleDateString()} - {new Date(nextPeriod.end).toLocaleDateString()}
            </div>
            <div className="space-y-2">
              <div className="flex justify-between">
                <span className="text-sm text-gray-600">Expected Income:</span>
                <span className="font-medium text-green-600">${nextPeriod.income.toFixed(2)}</span>
              </div>
              <div className="flex justify-between">
                <span className="text-sm text-gray-600">Projected Bills:</span>
                <span className="font-medium text-orange-600">${nextPeriod.projectedBills.toFixed(2)}</span>
              </div>
              <div className="flex justify-between border-t pt-2">
                <span className="font-medium">Available:</span>
                <span className="font-bold text-green-600">
                  ${(nextPeriod.income - nextPeriod.projectedBills).toFixed(2)}
                </span>
              </div>
            </div>
          </CardContent>
        </Card>
      </div>

      {/* Budget Summary */}
      <Card>
        <CardHeader>
          <CardTitle>Budget Summary</CardTitle>
        </CardHeader>
        <CardContent>
          <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
            <div className="text-center">
              <div className="text-2xl font-bold text-blue-600">${budget.monthlyIncome.toLocaleString()}</div>
              <div className="text-sm text-gray-600">Monthly Income</div>
            </div>
            <div className="text-center">
              <div className="text-2xl font-bold text-green-600">${biWeeklyIncome.toFixed(2)}</div>
              <div className="text-sm text-gray-600">Bi-Weekly Income</div>
            </div>
            <div className="text-center">
              <div className="text-2xl font-bold text-purple-600">{budget.payFrequency}</div>
              <div className="text-sm text-gray-600">Pay Frequency</div>
            </div>
          </div>
        </CardContent>
      </Card>

      {/* Recommendations */}
      <Card>
        <CardHeader>
          <CardTitle>Budget Recommendations</CardTitle>
        </CardHeader>
        <CardContent>
          <div className="space-y-3">
            {currentPeriod.remaining < 0 && (
              <div className="p-3 bg-red-50 border border-red-200 rounded-lg">
                <div className="text-red-800 font-medium">⚠️ Over Budget Alert</div>
                <div className="text-red-600 text-sm">
                  You're ${Math.abs(currentPeriod.remaining).toFixed(2)} over budget this period. Consider reducing discretionary spending.
                </div>
              </div>
            )}
            
            {currentPeriod.remaining > 0 && currentPeriod.remaining < 200 && (
              <div className="p-3 bg-yellow-50 border border-yellow-200 rounded-lg">
                <div className="text-yellow-800 font-medium">💡 Budget Tip</div>
                <div className="text-yellow-600 text-sm">
                  You have ${currentPeriod.remaining.toFixed(2)} remaining. Consider setting aside some for savings or next period's bills.
                </div>
              </div>
            )}
            
            {currentPeriod.remaining >= 200 && (
              <div className="p-3 bg-green-50 border border-green-200 rounded-lg">
                <div className="text-green-800 font-medium">🎉 Great Job!</div>
                <div className="text-green-600 text-sm">
                  You have ${currentPeriod.remaining.toFixed(2)} remaining this period. Consider adding to your emergency fund or savings goals.
                </div>
              </div>
            )}
          </div>
        </CardContent>
      </Card>
    </div>
  )
}