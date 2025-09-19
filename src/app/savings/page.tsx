'use client'

import { useState } from 'react'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/Card'
import { Target, Plus, Calendar, DollarSign, TrendingUp, CheckCircle } from 'lucide-react'

interface SavingsGoal {
  id: string
  name: string
  targetAmount: number
  currentAmount: number
  targetDate: string
  category: string
  isActive: boolean
  createdAt: string
  monthlyContribution: number
  progress: number
}

export default function SavingsPage() {
  const [goals] = useState<SavingsGoal[]>([
    {
      id: '1',
      name: 'Emergency Fund',
      targetAmount: 10000,
      currentAmount: 6500,
      targetDate: '2024-12-31',
      category: 'Emergency',
      isActive: true,
      createdAt: '2024-01-01',
      monthlyContribution: 500,
      progress: 65
    },
    {
      id: '2',
      name: 'Vacation to Europe',
      targetAmount: 5000,
      currentAmount: 2100,
      targetDate: '2024-08-15',
      category: 'Travel',
      isActive: true,
      createdAt: '2024-01-01',
      monthlyContribution: 400,
      progress: 42
    },
    {
      id: '3',
      name: 'New Car Down Payment',
      targetAmount: 8000,
      currentAmount: 3200,
      targetDate: '2025-06-01',
      category: 'Transportation',
      isActive: true,
      createdAt: '2024-01-01',
      monthlyContribution: 300,
      progress: 40
    },
    {
      id: '4',
      name: 'Home Renovation',
      targetAmount: 15000,
      currentAmount: 15000,
      targetDate: '2024-03-01',
      category: 'Home',
      isActive: false,
      createdAt: '2023-06-01',
      monthlyContribution: 0,
      progress: 100
    }
  ])

  const activeGoals = goals.filter(goal => goal.isActive)
  const completedGoals = goals.filter(goal => !goal.isActive && goal.progress === 100)
  
  const totalTargetAmount = activeGoals.reduce((sum, goal) => sum + goal.targetAmount, 0)
  const totalCurrentAmount = activeGoals.reduce((sum, goal) => sum + goal.currentAmount, 0)
  const totalMonthlyContribution = activeGoals.reduce((sum, goal) => sum + goal.monthlyContribution, 0)
  const overallProgress = totalTargetAmount > 0 ? (totalCurrentAmount / totalTargetAmount) * 100 : 0

  const getCategoryColor = (category: string) => {
    switch (category.toLowerCase()) {
      case 'emergency': return 'text-red-600 bg-red-100'
      case 'travel': return 'text-blue-600 bg-blue-100'
      case 'transportation': return 'text-green-600 bg-green-100'
      case 'home': return 'text-purple-600 bg-purple-100'
      case 'education': return 'text-yellow-600 bg-yellow-100'
      default: return 'text-gray-600 bg-gray-100'
    }
  }

  const calculateMonthsRemaining = (targetDate: string, currentAmount: number, targetAmount: number, monthlyContribution: number) => {
    const remaining = targetAmount - currentAmount
    if (remaining <= 0 || monthlyContribution <= 0) return 0
    return Math.ceil(remaining / monthlyContribution)
  }

  const isOnTrack = (goal: SavingsGoal) => {
    const targetDate = new Date(goal.targetDate)
    const now = new Date()
    const monthsUntilTarget = Math.ceil((targetDate.getTime() - now.getTime()) / (1000 * 60 * 60 * 24 * 30))
    const monthsNeeded = calculateMonthsRemaining(goal.targetDate, goal.currentAmount, goal.targetAmount, goal.monthlyContribution)
    return monthsNeeded <= monthsUntilTarget
  }

  return (
    <div className="space-y-6">
      <div className="flex justify-between items-center">
        <h1 className="text-3xl font-bold text-gray-900">Savings Goals</h1>
        <button className="bg-blue-600 text-white px-4 py-2 rounded-md font-medium hover:bg-blue-700 transition-colors flex items-center space-x-2">
          <Plus className="w-4 h-4" />
          <span>Add Goal</span>
        </button>
      </div>

      {/* Summary Cards */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium text-gray-600">Active Goals</CardTitle>
            <Target className="h-4 w-4 text-blue-600" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold text-blue-600">
              {activeGoals.length}
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium text-gray-600">Total Saved</CardTitle>
            <DollarSign className="h-4 w-4 text-green-600" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold text-green-600">
              ${totalCurrentAmount.toLocaleString()}
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium text-gray-600">Total Target</CardTitle>
            <TrendingUp className="h-4 w-4 text-purple-600" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold text-purple-600">
              ${totalTargetAmount.toLocaleString()}
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium text-gray-600">Monthly Savings</CardTitle>
            <Calendar className="h-4 w-4 text-orange-600" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold text-orange-600">
              ${totalMonthlyContribution.toLocaleString()}
            </div>
          </CardContent>
        </Card>
      </div>

      {/* Overall Progress */}
      <Card>
        <CardHeader>
          <CardTitle>Overall Savings Progress</CardTitle>
        </CardHeader>
        <CardContent>
          <div className="space-y-4">
            <div className="flex justify-between text-sm text-gray-600">
              <span>Total Progress</span>
              <span>{overallProgress.toFixed(1)}% complete</span>
            </div>
            <div className="w-full bg-gray-200 rounded-full h-3">
              <div 
                className="bg-gradient-to-r from-blue-500 to-green-500 h-3 rounded-full transition-all duration-300"
                style={{ width: `${Math.min(overallProgress, 100)}%` }}
              ></div>
            </div>
            <div className="grid grid-cols-1 md:grid-cols-3 gap-4 text-center">
              <div>
                <div className="text-lg font-semibold text-green-600">${totalCurrentAmount.toLocaleString()}</div>
                <div className="text-sm text-gray-600">Current Total</div>
              </div>
              <div>
                <div className="text-lg font-semibold text-purple-600">${totalTargetAmount.toLocaleString()}</div>
                <div className="text-sm text-gray-600">Target Total</div>
              </div>
              <div>
                <div className="text-lg font-semibold text-blue-600">${(totalTargetAmount - totalCurrentAmount).toLocaleString()}</div>
                <div className="text-sm text-gray-600">Remaining</div>
              </div>
            </div>
          </div>
        </CardContent>
      </Card>

      {/* Active Goals */}
      <div className="space-y-4">
        <h2 className="text-xl font-semibold text-gray-900">Active Goals</h2>
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
          {activeGoals.map((goal) => (
            <Card key={goal.id} className="hover:shadow-md transition-shadow">
              <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-4">
                <div className="flex items-center space-x-3">
                  <div className={`p-2 rounded-full ${getCategoryColor(goal.category)}`}>
                    <Target className="w-4 h-4" />
                  </div>
                  <div>
                    <CardTitle className="text-lg">{goal.name}</CardTitle>
                    <p className="text-sm text-gray-500">{goal.category}</p>
                  </div>
                </div>
                <div className={`px-2 py-1 rounded-full text-xs font-medium ${
                  isOnTrack(goal) ? 'bg-green-100 text-green-800' : 'bg-yellow-100 text-yellow-800'
                }`}>
                  {isOnTrack(goal) ? 'On Track' : 'Behind'}
                </div>
              </CardHeader>
              <CardContent className="space-y-4">
                {/* Progress Bar */}
                <div>
                  <div className="flex justify-between text-sm text-gray-600 mb-1">
                    <span>Progress</span>
                    <span>{goal.progress}%</span>
                  </div>
                  <div className="w-full bg-gray-200 rounded-full h-2">
                    <div 
                      className="bg-blue-600 h-2 rounded-full transition-all duration-300"
                      style={{ width: `${goal.progress}%` }}
                    ></div>
                  </div>
                </div>

                {/* Goal Details */}
                <div className="space-y-2 text-sm">
                  <div className="flex justify-between">
                    <span className="text-gray-600">Current Amount:</span>
                    <span className="font-medium text-green-600">${goal.currentAmount.toLocaleString()}</span>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-gray-600">Target Amount:</span>
                    <span className="font-medium">${goal.targetAmount.toLocaleString()}</span>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-gray-600">Remaining:</span>
                    <span className="font-medium text-blue-600">
                      ${(goal.targetAmount - goal.currentAmount).toLocaleString()}
                    </span>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-gray-600">Monthly Contribution:</span>
                    <span className="font-medium">${goal.monthlyContribution}</span>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-gray-600">Target Date:</span>
                    <span className="font-medium">{new Date(goal.targetDate).toLocaleDateString()}</span>
                  </div>
                  <div className="flex justify-between border-t pt-2">
                    <span className="text-gray-600">Months to Goal:</span>
                    <span className="font-medium">
                      {calculateMonthsRemaining(goal.targetDate, goal.currentAmount, goal.targetAmount, goal.monthlyContribution)} months
                    </span>
                  </div>
                </div>

                {/* Action Buttons */}
                <div className="flex space-x-2 pt-2">
                  <button className="flex-1 bg-blue-600 text-white px-3 py-2 rounded-md text-sm font-medium hover:bg-blue-700 transition-colors">
                    Add Money
                  </button>
                  <button className="flex-1 bg-gray-100 text-gray-700 px-3 py-2 rounded-md text-sm font-medium hover:bg-gray-200 transition-colors">
                    Edit Goal
                  </button>
                </div>
              </CardContent>
            </Card>
          ))}
        </div>
      </div>

      {/* Completed Goals */}
      {completedGoals.length > 0 && (
        <div className="space-y-4">
          <h2 className="text-xl font-semibold text-gray-900">Completed Goals</h2>
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
            {completedGoals.map((goal) => (
              <Card key={goal.id} className="border-green-200 bg-green-50">
                <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-4">
                  <div className="flex items-center space-x-3">
                    <div className="p-2 rounded-full bg-green-100 text-green-600">
                      <CheckCircle className="w-4 h-4" />
                    </div>
                    <div>
                      <CardTitle className="text-lg text-green-900">{goal.name}</CardTitle>
                      <p className="text-sm text-green-600">{goal.category}</p>
                    </div>
                  </div>
                  <div className="px-2 py-1 rounded-full text-xs font-medium bg-green-200 text-green-800">
                    Completed
                  </div>
                </CardHeader>
                <CardContent>
                  <div className="text-center">
                    <div className="text-2xl font-bold text-green-600 mb-1">
                      ${goal.targetAmount.toLocaleString()}
                    </div>
                    <div className="text-sm text-green-600">
                      Goal achieved on {new Date(goal.targetDate).toLocaleDateString()}
                    </div>
                  </div>
                </CardContent>
              </Card>
            ))}
          </div>
        </div>
      )}

      {/* Savings Tips */}
      <Card>
        <CardHeader>
          <CardTitle>Savings Tips & Insights</CardTitle>
        </CardHeader>
        <CardContent>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            <div className="space-y-3">
              <h4 className="font-medium text-gray-900">💡 Smart Saving Strategies</h4>
              <ul className="text-sm text-gray-600 space-y-2">
                <li>• Automate your savings to reach goals faster</li>
                <li>• Use the 50/30/20 rule: 50% needs, 30% wants, 20% savings</li>
                <li>• Start with small amounts and increase gradually</li>
                <li>• Consider high-yield savings accounts for better returns</li>
              </ul>
            </div>
            
            <div className="space-y-3">
              <h4 className="font-medium text-gray-900">📊 Your Progress</h4>
              <div className="text-sm text-gray-600 space-y-2">
                <div>• You're saving ${totalMonthlyContribution}/month across all goals</div>
                <div>• At this rate, you'll reach your goals in an average of {
                  Math.ceil(activeGoals.reduce((sum, goal) => 
                    sum + calculateMonthsRemaining(goal.targetDate, goal.currentAmount, goal.targetAmount, goal.monthlyContribution), 0
                  ) / activeGoals.length)
                } months</div>
                <div>• You've completed {completedGoals.length} goal{completedGoals.length !== 1 ? 's' : ''} so far</div>
                <div>• Keep up the great work! 🎉</div>
              </div>
            </div>
          </div>
        </CardContent>
      </Card>
    </div>
  )
}