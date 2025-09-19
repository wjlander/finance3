'use client'

import { useState } from 'react'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/Card'
import { Calendar, Clock, DollarSign, AlertTriangle, CheckCircle, Plus, Bell, CreditCard } from 'lucide-react'

interface Bill {
  id: string
  name: string
  amount: number
  dueDate: string
  frequency: 'monthly' | 'quarterly' | 'yearly' | 'weekly'
  category: string
  isPaid: boolean
  isOverdue: boolean
  paymentMethod: string
  isRecurring: boolean
  nextDueDate: string
  lastPaidDate?: string
}

export default function BillsPage() {
  const [bills] = useState<Bill[]>([
    {
      id: '1',
      name: 'Rent',
      amount: 1200,
      dueDate: '2024-01-01',
      frequency: 'monthly',
      category: 'Housing',
      isPaid: true,
      isOverdue: false,
      paymentMethod: 'Bank Transfer',
      isRecurring: true,
      nextDueDate: '2024-02-01',
      lastPaidDate: '2024-01-01'
    },
    {
      id: '2',
      name: 'Electric Bill',
      amount: 89.50,
      dueDate: '2024-01-15',
      frequency: 'monthly',
      category: 'Utilities',
      isPaid: false,
      isOverdue: false,
      paymentMethod: 'Credit Card',
      isRecurring: true,
      nextDueDate: '2024-01-15'
    },
    {
      id: '3',
      name: 'Internet',
      amount: 65.00,
      dueDate: '2024-01-20',
      frequency: 'monthly',
      category: 'Utilities',
      isPaid: false,
      isOverdue: false,
      paymentMethod: 'Auto Pay',
      isRecurring: true,
      nextDueDate: '2024-01-20'
    },
    {
      id: '4',
      name: 'Car Insurance',
      amount: 125.00,
      dueDate: '2024-01-10',
      frequency: 'monthly',
      category: 'Insurance',
      isPaid: false,
      isOverdue: true,
      paymentMethod: 'Credit Card',
      isRecurring: true,
      nextDueDate: '2024-01-10'
    },
    {
      id: '5',
      name: 'Phone Bill',
      amount: 45.00,
      dueDate: '2024-01-25',
      frequency: 'monthly',
      category: 'Utilities',
      isPaid: false,
      isOverdue: false,
      paymentMethod: 'Auto Pay',
      isRecurring: true,
      nextDueDate: '2024-01-25'
    },
    {
      id: '6',
      name: 'Gym Membership',
      amount: 29.99,
      dueDate: '2024-01-12',
      frequency: 'monthly',
      category: 'Health & Fitness',
      isPaid: true,
      isOverdue: false,
      paymentMethod: 'Credit Card',
      isRecurring: true,
      nextDueDate: '2024-02-12',
      lastPaidDate: '2024-01-12'
    }
  ])

  const [selectedFilter, setSelectedFilter] = useState('all')

  // Calculate summary statistics
  const totalMonthlyBills = bills.reduce((sum, bill) => sum + bill.amount, 0)
  const paidBills = bills.filter(bill => bill.isPaid)
  const unpaidBills = bills.filter(bill => !bill.isPaid)
  const overdueBills = bills.filter(bill => bill.isOverdue)
  const upcomingBills = bills.filter(bill => !bill.isPaid && !bill.isOverdue)

  const totalPaid = paidBills.reduce((sum, bill) => sum + bill.amount, 0)
  const totalUnpaid = unpaidBills.reduce((sum, bill) => sum + bill.amount, 0)
  const totalOverdue = overdueBills.reduce((sum, bill) => sum + bill.amount, 0)

  // Get unique categories for filter
  const categories = Array.from(new Set(bills.map(bill => bill.category)))

  // Filter bills
  const filteredBills = bills.filter(bill => {
    switch (selectedFilter) {
      case 'paid': return bill.isPaid
      case 'unpaid': return !bill.isPaid
      case 'overdue': return bill.isOverdue
      case 'upcoming': return !bill.isPaid && !bill.isOverdue
      default: return true
    }
  })

  const getBillStatusColor = (bill: Bill) => {
    if (bill.isPaid) return 'text-green-600 bg-green-100'
    if (bill.isOverdue) return 'text-red-600 bg-red-100'
    return 'text-yellow-600 bg-yellow-100'
  }

  const getBillStatusText = (bill: Bill) => {
    if (bill.isPaid) return 'Paid'
    if (bill.isOverdue) return 'Overdue'
    return 'Pending'
  }

  const getBillStatusIcon = (bill: Bill) => {
    if (bill.isPaid) return CheckCircle
    if (bill.isOverdue) return AlertTriangle
    return Clock
  }

  const getCategoryColor = (category: string) => {
    switch (category.toLowerCase()) {
      case 'housing': return 'text-blue-600 bg-blue-100'
      case 'utilities': return 'text-green-600 bg-green-100'
      case 'insurance': return 'text-purple-600 bg-purple-100'
      case 'health & fitness': return 'text-pink-600 bg-pink-100'
      case 'transportation': return 'text-orange-600 bg-orange-100'
      default: return 'text-gray-600 bg-gray-100'
    }
  }

  const getDaysUntilDue = (dueDate: string) => {
    const due = new Date(dueDate)
    const today = new Date()
    const diffTime = due.getTime() - today.getTime()
    const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24))
    return diffDays
  }

  return (
    <div className="space-y-6">
      <div className="flex justify-between items-center">
        <h1 className="text-3xl font-bold text-gray-900">Bills & Reminders</h1>
        <button className="bg-blue-600 text-white px-4 py-2 rounded-md font-medium hover:bg-blue-700 transition-colors flex items-center space-x-2">
          <Plus className="w-4 h-4" />
          <span>Add Bill</span>
        </button>
      </div>

      {/* Summary Cards */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium text-gray-600">Total Monthly Bills</CardTitle>
            <DollarSign className="h-4 w-4 text-blue-600" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold text-blue-600">
              ${totalMonthlyBills.toLocaleString()}
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium text-gray-600">Paid This Month</CardTitle>
            <CheckCircle className="h-4 w-4 text-green-600" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold text-green-600">
              ${totalPaid.toLocaleString()}
            </div>
            <p className="text-xs text-gray-500 mt-1">
              {paidBills.length} bill{paidBills.length !== 1 ? 's' : ''} paid
            </p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium text-gray-600">Pending Bills</CardTitle>
            <Clock className="h-4 w-4 text-yellow-600" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold text-yellow-600">
              ${totalUnpaid.toLocaleString()}
            </div>
            <p className="text-xs text-gray-500 mt-1">
              {unpaidBills.length} bill{unpaidBills.length !== 1 ? 's' : ''} pending
            </p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium text-gray-600">Overdue Bills</CardTitle>
            <AlertTriangle className="h-4 w-4 text-red-600" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold text-red-600">
              ${totalOverdue.toLocaleString()}
            </div>
            <p className="text-xs text-gray-500 mt-1">
              {overdueBills.length} bill{overdueBills.length !== 1 ? 's' : ''} overdue
            </p>
          </CardContent>
        </Card>
      </div>

      {/* Alerts */}
      {overdueBills.length > 0 && (
        <Card className="border-red-200 bg-red-50">
          <CardContent className="p-4">
            <div className="flex items-center space-x-2">
              <AlertTriangle className="w-5 h-5 text-red-600" />
              <div>
                <h4 className="font-medium text-red-800">Overdue Bills Alert</h4>
                <p className="text-red-600 text-sm">
                  You have {overdueBills.length} overdue bill{overdueBills.length !== 1 ? 's' : ''} totaling ${totalOverdue.toLocaleString()}. 
                  Please pay them as soon as possible to avoid late fees.
                </p>
              </div>
            </div>
          </CardContent>
        </Card>
      )}

      {/* Filter Tabs */}
      <Card>
        <CardContent className="p-4">
          <div className="flex flex-wrap gap-2">
            {[
              { key: 'all', label: 'All Bills', count: bills.length },
              { key: 'unpaid', label: 'Unpaid', count: unpaidBills.length },
              { key: 'paid', label: 'Paid', count: paidBills.length },
              { key: 'overdue', label: 'Overdue', count: overdueBills.length },
              { key: 'upcoming', label: 'Upcoming', count: upcomingBills.length }
            ].map(filter => (
              <button
                key={filter.key}
                onClick={() => setSelectedFilter(filter.key)}
                className={`px-4 py-2 rounded-md text-sm font-medium transition-colors ${
                  selectedFilter === filter.key
                    ? 'bg-blue-600 text-white'
                    : 'bg-gray-100 text-gray-700 hover:bg-gray-200'
                }`}
              >
                {filter.label} ({filter.count})
              </button>
            ))}
          </div>
        </CardContent>
      </Card>

      {/* Bills List */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {filteredBills.map((bill) => {
          const StatusIcon = getBillStatusIcon(bill)
          const daysUntilDue = getDaysUntilDue(bill.nextDueDate)
          
          return (
            <Card key={bill.id} className="hover:shadow-md transition-shadow">
              <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-4">
                <div className="flex items-center space-x-3">
                  <div className={`p-2 rounded-full ${getCategoryColor(bill.category)}`}>
                    <CreditCard className="w-4 h-4" />
                  </div>
                  <div>
                    <CardTitle className="text-lg">{bill.name}</CardTitle>
                    <p className="text-sm text-gray-500">{bill.category}</p>
                  </div>
                </div>
                <div className={`flex items-center space-x-1 px-2 py-1 rounded-full text-xs font-medium ${getBillStatusColor(bill)}`}>
                  <StatusIcon className="w-3 h-3" />
                  <span>{getBillStatusText(bill)}</span>
                </div>
              </CardHeader>
              <CardContent className="space-y-4">
                {/* Amount and Due Date */}
                <div className="flex justify-between items-center">
                  <div>
                    <div className="text-2xl font-bold text-gray-900">${bill.amount}</div>
                    <div className="text-sm text-gray-500">
                      {bill.frequency} • {bill.paymentMethod}
                    </div>
                  </div>
                  <div className="text-right">
                    <div className="font-medium">
                      {bill.isPaid ? 'Paid' : 'Due'}: {new Date(bill.isPaid ? bill.lastPaidDate! : bill.nextDueDate).toLocaleDateString()}
                    </div>
                    {!bill.isPaid && (
                      <div className={`text-sm ${
                        daysUntilDue < 0 ? 'text-red-600' : 
                        daysUntilDue <= 3 ? 'text-yellow-600' : 'text-gray-500'
                      }`}>
                        {daysUntilDue < 0 ? `${Math.abs(daysUntilDue)} days overdue` :
                         daysUntilDue === 0 ? 'Due today' :
                         `${daysUntilDue} days remaining`}
                      </div>
                    )}
                  </div>
                </div>

                {/* Recurring Info */}
                {bill.isRecurring && (
                  <div className="flex items-center space-x-2 text-sm text-gray-600">
                    <Bell className="w-4 h-4" />
                    <span>Recurring {bill.frequency}</span>
                  </div>
                )}

                {/* Action Buttons */}
                <div className="flex space-x-2 pt-2">
                  {!bill.isPaid ? (
                    <>
                      <button className="flex-1 bg-green-600 text-white px-3 py-2 rounded-md text-sm font-medium hover:bg-green-700 transition-colors">
                        Mark as Paid
                      </button>
                      <button className="flex-1 bg-blue-600 text-white px-3 py-2 rounded-md text-sm font-medium hover:bg-blue-700 transition-colors">
                        Pay Now
                      </button>
                    </>
                  ) : (
                    <button className="flex-1 bg-gray-100 text-gray-700 px-3 py-2 rounded-md text-sm font-medium hover:bg-gray-200 transition-colors">
                      View Receipt
                    </button>
                  )}
                  <button className="px-3 py-2 bg-gray-100 text-gray-700 rounded-md text-sm font-medium hover:bg-gray-200 transition-colors">
                    Edit
                  </button>
                </div>
              </CardContent>
            </Card>
          )
        })}
      </div>

      {filteredBills.length === 0 && (
        <Card>
          <CardContent className="p-8 text-center">
            <Calendar className="w-12 h-12 mx-auto mb-4 text-gray-400" />
            <h3 className="text-lg font-medium text-gray-900 mb-2">No bills found</h3>
            <p className="text-gray-500 mb-4">
              {selectedFilter === 'all' 
                ? "You haven't added any bills yet."
                : `No bills match the "${selectedFilter}" filter.`}
            </p>
            <button className="bg-blue-600 text-white px-4 py-2 rounded-md font-medium hover:bg-blue-700 transition-colors">
              Add Your First Bill
            </button>
          </CardContent>
        </Card>
      )}

      {/* Bill Management Tips */}
      <Card>
        <CardHeader>
          <CardTitle>Bill Management Tips</CardTitle>
        </CardHeader>
        <CardContent>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            <div className="space-y-3">
              <h4 className="font-medium text-gray-900">💡 Stay on Top of Bills</h4>
              <ul className="text-sm text-gray-600 space-y-2">
                <li>• Set up automatic payments for recurring bills</li>
                <li>• Use calendar reminders 3-5 days before due dates</li>
                <li>• Review bills monthly for accuracy and changes</li>
                <li>• Keep digital copies of receipts and statements</li>
              </ul>
            </div>
            
            <div className="space-y-3">
              <h4 className="font-medium text-gray-900">📊 Your Bill Summary</h4>
              <div className="text-sm text-gray-600 space-y-2">
                <div>• You have {bills.length} total bills to manage</div>
                <div>• {paidBills.length} bills paid this month (${totalPaid.toLocaleString()})</div>
                <div>• {unpaidBills.length} bills still pending (${totalUnpaid.toLocaleString()})</div>
                {overdueBills.length > 0 && (
                  <div className="text-red-600">• {overdueBills.length} overdue bills need immediate attention</div>
                )}
              </div>
            </div>
          </div>
        </CardContent>
      </Card>
    </div>
  )
}