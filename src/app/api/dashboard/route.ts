import { NextResponse } from 'next/server'
import { prisma } from '@/lib/db'

export async function GET() {
  try {
    // For now, return mock data since we don't have user authentication yet
    // In a real app, you'd get the user ID from the session/token
    
    const mockData = {
      totalBalance: 5420.50,
      totalDebt: 12500.00,
      monthlyIncome: 4500.00,
      monthlyExpenses: 3200.00,
      recentTransactions: [
        {
          id: '1',
          description: 'Grocery Store',
          amount: -125.50,
          type: 'expense',
          date: '2024-01-15'
        },
        {
          id: '2',
          description: 'Salary Deposit',
          amount: 2250.00,
          type: 'income',
          date: '2024-01-15'
        },
        {
          id: '3',
          description: 'Gas Station',
          amount: -45.00,
          type: 'expense',
          date: '2024-01-14'
        }
      ]
    }

    return NextResponse.json(mockData)
  } catch (error) {
    console.error('Dashboard API error:', error)
    return NextResponse.json(
      { error: 'Failed to fetch dashboard data' },
      { status: 500 }
    )
  }
}