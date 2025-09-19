#!/bin/bash

#===============================================================================
# Personal Finance App Deployment Script
# Version: 1.0
# Description: Deploy Next.js Personal Finance App to Ubuntu Server
# Compatible: Ubuntu 20.04 LTS, 22.04 LTS
# Author: System Administrator
# License: MIT
#===============================================================================

set -euo pipefail  # Exit on error, undefined vars, pipe failures

#===============================================================================
# CONFIGURATION SECTION - Customize these variables as needed
#===============================================================================

# Repository Configuration
REPO_URL="${REPO_URL:-https://github.com/wjlander/finance3.git}"
REPO_BRANCH="${REPO_BRANCH:-main}"

# Basic Configuration
readonly SCRIPT_NAME="Personal Finance App Deployment"
readonly SCRIPT_VERSION="1.0"
readonly LOG_FILE="/var/log/finance-app-deploy.log"
readonly REPO_URL="${REPO_URL:-https://github.com/wjlander/finance3.git}"
readonly APP_DIR="/var/www/finance"
readonly BACKUP_DIR="/root/finance-app-backup-$(date +%Y%m%d-%H%M%S)"

# Application Configuration
APP_NAME="${APP_NAME:-personal-finance-app}"
APP_USER="${APP_USER:-financeapp}"
APP_PORT="${APP_PORT:-8080}"
APP_DOMAIN="${APP_DOMAIN:-}"
NODE_VERSION="${NODE_VERSION:-18}"

# SSL Configuration
ENABLE_SSL="${ENABLE_SSL:-false}"
SSL_EMAIL="${SSL_EMAIL:-}"

# Database Configuration
DB_PATH="${DB_PATH:-${APP_DIR}/prisma/dev.db}"

# Service Configuration
ENABLE_SYSTEMD="${ENABLE_SYSTEMD:-true}"
ENABLE_NGINX="${ENABLE_NGINX:-true}"
ENABLE_FIREWALL="${ENABLE_FIREWALL:-true}"

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m' # No Color

#===============================================================================
# UTILITY FUNCTIONS
#===============================================================================

# Logging function
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${timestamp} [${level}] ${message}" | tee -a "${LOG_FILE}"
}

# Print colored output
print_status() {
    local color="$1"
    local message="$2"
    echo -e "${color}${message}${NC}"
    log "INFO" "${message}"
}

# Print section header
print_header() {
    local title="$1"
    echo
    print_status "${PURPLE}" "==============================================================================="
    print_status "${PURPLE}" " ${title}"
    print_status "${PURPLE}" "==============================================================================="
}

# Print progress
print_progress() {
    local message="$1"
    print_status "${BLUE}" "➤ ${message}"
}

# Print success
print_success() {
    local message="$1"
    print_status "${GREEN}" "✓ ${message}"
}

# Print warning
print_warning() {
    local message="$1"
    print_status "${YELLOW}" "⚠ ${message}"
}

# Print error and exit
print_error() {
    local message="$1"
    print_status "${RED}" "✗ ERROR: ${message}"
    log "ERROR" "${message}"
    exit 1
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check if package is installed
package_installed() {
    dpkg -l "$1" >/dev/null 2>&1
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root (use sudo)"
    fi
}

# Backup file if it exists
backup_file() {
    local file="$1"
    if [[ -f "$file" ]]; then
        mkdir -p "${BACKUP_DIR}"
        cp "$file" "${BACKUP_DIR}/$(basename "$file").backup"
        print_progress "Backed up $file"
    fi
}

#===============================================================================
# VALIDATION FUNCTIONS
#===============================================================================

validate_configuration() {
    print_header "Validating Configuration"
    
    # Validate port
    if [[ ! "$APP_PORT" =~ ^[0-9]+$ ]] || [[ "$APP_PORT" -lt 1 ]] || [[ "$APP_PORT" -gt 65535 ]]; then
        print_error "Invalid port: $APP_PORT"
    fi
    
    # Validate app user
    if [[ ! "$APP_USER" =~ ^[a-z_][a-z0-9_-]*$ ]]; then
        print_error "Invalid app user: $APP_USER"
    fi
    
    # Check SSL configuration
    if [[ "$ENABLE_SSL" == "true" ]]; then
        if [[ -z "$APP_DOMAIN" ]]; then
            print_error "SSL enabled but no domain specified. Set APP_DOMAIN."
        fi
        if [[ -z "$SSL_EMAIL" ]]; then
            print_error "SSL enabled but no email specified. Set SSL_EMAIL."
        fi
    fi
    
    print_success "Configuration validation completed"
}

#===============================================================================
# SYSTEM PREPARATION FUNCTIONS
#===============================================================================

install_dependencies() {
    print_header "Installing System Dependencies"
    
    print_progress "Updating package lists..."
    apt-get update -qq
    
    # Install essential packages
    local packages=(
        curl wget git unzip
        nginx
        certbot python3-certbot-nginx
        sqlite3
        ufw
    )
    
    for package in "${packages[@]}"; do
        if ! package_installed "$package"; then
            print_progress "Installing $package..."
            DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "$package"
        fi
    done
    
    print_success "System dependencies installed"
}

install_nodejs() {
    print_header "Installing Node.js and PM2"
    
    if ! command_exists node || [[ "$(node -v | cut -d'v' -f2 | cut -d'.' -f1)" -lt "$NODE_VERSION" ]]; then
        print_progress "Installing Node.js ${NODE_VERSION}..."
        
        # Install NodeSource repository
        curl -fsSL https://deb.nodesource.com/setup_${NODE_VERSION}.x | bash -
        apt-get install -y nodejs
        
        print_success "Node.js $(node -v) installed"
    else
        print_success "Node.js $(node -v) already installed"
    fi
    
    # Install PM2 globally
    if ! command_exists pm2; then
        print_progress "Installing PM2 process manager..."
        npm install -g pm2
        print_success "PM2 installed"
    else
        print_success "PM2 already installed"
    fi
}

create_app_user() {
    print_header "Creating Application User"
    
    if ! id "$APP_USER" &>/dev/null; then
        print_progress "Creating user: $APP_USER"
        useradd -r -s /bin/bash -d "$APP_DIR" "$APP_USER"
        print_success "User $APP_USER created"
    else
        print_success "User $APP_USER already exists"
    fi
    
    # Create application directory
    mkdir -p "$APP_DIR"
    chown "$APP_USER:$APP_USER" "$APP_DIR"
    
    print_success "Application directory created: $APP_DIR"
}

# Clone or update repository
setup_repository() {
    print_header "Repository Setup"
    
    # Create parent directory
    mkdir -p "$(dirname "$APP_DIR")"
    
    if [[ -d "$APP_DIR" ]]; then
        print_progress "Application directory exists, backing up..."
        mkdir -p "$BACKUP_DIR"
        cp -r "$APP_DIR" "$BACKUP_DIR/finance-app-backup"
        print_success "Backup created at $BACKUP_DIR"
        
        print_progress "Updating existing repository..."
        cd "$APP_DIR"
        
        # Stash any local changes
        if git status --porcelain | grep -q .; then
            print_warning "Local changes detected, stashing..."
            git stash push -m "Auto-stash before deployment $(date)"
        fi
        
        # Pull latest changes
        git fetch origin
        git reset --hard origin/main || git reset --hard origin/master
        print_success "Repository updated"
    else
        print_progress "Cloning repository from $REPO_URL..."
        git clone "$REPO_URL" "$APP_DIR"
        print_success "Repository cloned to $APP_DIR"
    fi
    
    # Set proper ownership
    chown -R "$APP_USER:$APP_USER" "$APP_DIR"
    
    print_success "Repository setup completed"
}

#===============================================================================
# APPLICATION DEPLOYMENT FUNCTIONS
#===============================================================================

deploy_application() {
    print_header "Deploying Personal Finance Application"
    
    # Create application structure
    print_progress "Creating application structure..."
    
    # Create package.json
    cat > "$APP_DIR/package.json" << 'EOF'
{
  "name": "personal-finance-app",
  "version": "1.0.0",
  "description": "A comprehensive personal finance management application",
  "private": true,
  "scripts": {
    "dev": "next dev",
    "build": "next build",
    "start": "next start",
    "lint": "next lint",
    "db:generate": "prisma generate",
    "db:push": "prisma db push",
    "db:studio": "prisma studio"
  },
  "dependencies": {
    "@prisma/client": "^5.7.1",
    "lucide-react": "^0.294.0",
    "next": "14.0.4",
    "react": "^18.2.0",
    "react-dom": "^18.2.0"
  },
  "devDependencies": {
    "@types/node": "^20.10.5",
    "@types/react": "^18.2.45",
    "@types/react-dom": "^18.2.18",
    "autoprefixer": "^10.4.16",
    "eslint": "^8.56.0",
    "eslint-config-next": "14.0.4",
    "postcss": "^8.4.32",
    "prisma": "^5.7.1",
    "tailwindcss": "^3.3.6",
    "typescript": "^5.3.3"
  }
}
EOF

    # Create Next.js configuration
    cat > "$APP_DIR/next.config.js" << 'EOF'
/** @type {import('next').NextConfig} */
const nextConfig = {
  output: 'standalone',
  experimental: {
    serverComponentsExternalPackages: ['@prisma/client', 'prisma']
  }
}

module.exports = nextConfig
EOF

    # Create TypeScript configuration
    cat > "$APP_DIR/tsconfig.json" << 'EOF'
{
  "compilerOptions": {
    "lib": ["dom", "dom.iterable", "es6"],
    "allowJs": true,
    "skipLibCheck": true,
    "strict": true,
    "noEmit": true,
    "esModuleInterop": true,
    "module": "esnext",
    "moduleResolution": "bundler",
    "resolveJsonModule": true,
    "isolatedModules": true,
    "jsx": "preserve",
    "incremental": true,
    "plugins": [
      {
        "name": "next"
      }
    ],
    "baseUrl": ".",
    "paths": {
      "@/*": ["./src/*"]
    }
  },
  "include": ["next-env.d.ts", "**/*.ts", "**/*.tsx", ".next/types/**/*.ts"],
  "exclude": ["node_modules"]
}
EOF

    # Create Tailwind configuration
    cat > "$APP_DIR/tailwind.config.js" << 'EOF'
/** @type {import('tailwindcss').Config} */
module.exports = {
  content: [
    './src/pages/**/*.{js,ts,jsx,tsx,mdx}',
    './src/components/**/*.{js,ts,jsx,tsx,mdx}',
    './src/app/**/*.{js,ts,jsx,tsx,mdx}',
  ],
  theme: {
    extend: {},
  },
  plugins: [],
}
EOF

    # Create PostCSS configuration
    cat > "$APP_DIR/postcss.config.js" << 'EOF'
module.exports = {
  plugins: {
    tailwindcss: {},
    autoprefixer: {},
  },
}
EOF

    # Create directory structure
    mkdir -p "$APP_DIR/src/app"
    mkdir -p "$APP_DIR/src/components/ui"
    mkdir -p "$APP_DIR/prisma"
    mkdir -p "$APP_DIR/lib"
    mkdir -p "$APP_DIR/src/app/budget"
    mkdir -p "$APP_DIR/src/app/debts"
    mkdir -p "$APP_DIR/src/app/api/dashboard"

    print_success "Application structure created"
}

create_database_schema() {
    print_header "Setting Up Database Schema"
    
    # Create Prisma schema
    cat > "$APP_DIR/prisma/schema.prisma" << 'EOF'
generator client {
  provider = "prisma-client-js"
}

datasource db {
  provider = "sqlite"
  url      = "file:./dev.db"
}

model User {
  id        String   @id @default(cuid())
  email     String   @unique
  name      String
  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt

  budgets      Budget[]
  debts        Debt[]
  transactions Transaction[]
  accounts     Account[]
  savingsGoals SavingsGoal[]

  @@map("users")
}

model Budget {
  id              String   @id @default(cuid())
  name            String
  monthlyIncome   Float
  payFrequency    String   @default("bi-weekly")
  firstPayDate    DateTime
  createdAt       DateTime @default(now())
  updatedAt       DateTime @updatedAt

  userId String
  user   User   @relation(fields: [userId], references: [id], onDelete: Cascade)

  categories BudgetCategory[]

  @@map("budgets")
}

model BudgetCategory {
  id              String @id @default(cuid())
  category        String
  allocatedAmount Float
  spentAmount     Float  @default(0)

  budgetId String
  budget   Budget @relation(fields: [budgetId], references: [id], onDelete: Cascade)

  @@map("budget_categories")
}

model Debt {
  id                   String    @id @default(cuid())
  name                 String
  principal            Float
  interestRate         Float
  minimumPayment       Float
  currentBalance       Float
  paymentFrequency     String    @default("monthly")
  nextPaymentDate      DateTime?
  estimatedPayoffDate  DateTime?
  createdAt            DateTime  @default(now())
  updatedAt            DateTime  @updatedAt

  userId String
  user   User   @relation(fields: [userId], references: [id], onDelete: Cascade)

  payments DebtPayment[]

  @@map("debts")
}

model DebtPayment {
  id              String   @id @default(cuid())
  amount          Float
  paymentDate     DateTime
  principalAmount Float
  interestAmount  Float
  createdAt       DateTime @default(now())

  debtId String
  debt   Debt   @relation(fields: [debtId], references: [id], onDelete: Cascade)

  @@map("debt_payments")
}

model Account {
  id            String    @id @default(cuid())
  name          String
  type          String
  balance       Float
  bankName      String?
  accountNumber String?
  isActive      Boolean   @default(true)
  lastSync      DateTime?
  createdAt     DateTime  @default(now())
  updatedAt     DateTime  @updatedAt

  userId String
  user   User   @relation(fields: [userId], references: [id], onDelete: Cascade)

  transactions Transaction[]

  @@map("accounts")
}

model Transaction {
  id              String   @id @default(cuid())
  amount          Float
  description     String
  category        String
  type            String
  date            DateTime
  isRecurring     Boolean  @default(false)
  createdAt       DateTime @default(now())

  userId String
  user   User   @relation(fields: [userId], references: [id], onDelete: Cascade)

  accountId String?
  account   Account? @relation(fields: [accountId], references: [id], onDelete: SetNull)

  @@map("transactions")
}

model SavingsGoal {
  id            String   @id @default(cuid())
  name          String
  targetAmount  Float
  currentAmount Float    @default(0)
  targetDate    DateTime
  category      String
  isActive      Boolean  @default(true)
  createdAt     DateTime @default(now())
  updatedAt     DateTime @updatedAt

  userId String
  user   User   @relation(fields: [userId], references: [id], onDelete: Cascade)

  @@map("savings_goals")
}
EOF

    # Create database client
    cat > "$APP_DIR/lib/db.ts" << 'EOF'
import { PrismaClient } from '@prisma/client'

const globalForPrisma = globalThis as unknown as {
  prisma: PrismaClient | undefined
}

export const prisma = globalForPrisma.prisma ?? new PrismaClient()

if (process.env.NODE_ENV !== 'production') globalForPrisma.prisma = prisma
EOF

    print_success "Database schema created"
}

create_application_files() {
    print_header "Creating Application Files"
    
    # Create global styles
    cat > "$APP_DIR/src/app/globals.css" << 'EOF'
@tailwind base;
@tailwind components;
@tailwind utilities;

@layer base {
  html {
    font-family: system-ui, sans-serif;
  }
}
EOF

    # Create layout
    cat > "$APP_DIR/src/app/layout.tsx" << 'EOF'
import type { Metadata } from 'next'
import { Inter } from 'next/font/google'
import './globals.css'
import { Navigation } from '@/components/Navigation'

const inter = Inter({ subsets: ['latin'] })

export const metadata: Metadata = {
  title: 'Personal Finance App',
  description: 'Manage your finances with bi-weekly budgeting and debt tracking',
}

export default function RootLayout({
  children,
}: {
  children: React.ReactNode
}) {
  return (
    <html lang="en">
      <body className={inter.className}>
        <div className="min-h-screen bg-gray-50">
          <Navigation />
          <main className="container mx-auto px-4 py-8">
            {children}
          </main>
        </div>
      </body>
    </html>
  )
}
EOF

    # Create main page
    cat > "$APP_DIR/src/app/page.tsx" << 'EOF'
import { Dashboard } from '@/components/Dashboard'

export default function Home() {
  return <Dashboard />
}
EOF

    # Create Card component
    cat > "$APP_DIR/src/components/ui/Card.tsx" << 'EOF'
import { ReactNode } from 'react'

interface CardProps {
  children: ReactNode
  className?: string
}

interface CardHeaderProps {
  children: ReactNode
  className?: string
}

interface CardTitleProps {
  children: ReactNode
  className?: string
}

interface CardContentProps {
  children: ReactNode
  className?: string
}

export function Card({ children, className = '' }: CardProps) {
  return (
    <div className={`bg-white rounded-lg border shadow-sm ${className}`}>
      {children}
    </div>
  )
}

export function CardHeader({ children, className = '' }: CardHeaderProps) {
  return (
    <div className={`p-6 pb-4 ${className}`}>
      {children}
    </div>
  )
}

export function CardTitle({ children, className = '' }: CardTitleProps) {
  return (
    <h3 className={`text-lg font-semibold leading-none tracking-tight ${className}`}>
      {children}
    </h3>
  )
}

export function CardContent({ children, className = '' }: CardContentProps) {
  return (
    <div className={`p-6 pt-0 ${className}`}>
      {children}
    </div>
  )
}
EOF

    # Create Navigation component
    cat > "$APP_DIR/src/components/Navigation.tsx" << 'EOF'
'use client'

import Link from 'next/link'
import { usePathname } from 'next/navigation'
import { 
  Home, 
  CreditCard, 
  Receipt, 
  PiggyBank, 
  Target,
  Calendar,
  Wallet
} from 'lucide-react'

const navigation = [
  { name: 'Dashboard', href: '/', icon: Home },
  { name: 'Budget', href: '/budget', icon: Wallet },
  { name: 'Debts', href: '/debts', icon: CreditCard },
  { name: 'Transactions', href: '/transactions', icon: Receipt },
  { name: 'Accounts', href: '/accounts', icon: PiggyBank },
  { name: 'Savings Goals', href: '/savings', icon: Target },
  { name: 'Bills', href: '/bills', icon: Calendar },
]

export function Navigation() {
  const pathname = usePathname()

  return (
    <nav className="bg-white shadow-sm border-b">
      <div className="container mx-auto px-4">
        <div className="flex justify-between items-center h-16">
          <div className="flex items-center space-x-8">
            <Link href="/" className="text-xl font-bold text-blue-600">
              Personal Finance
            </Link>
            <div className="hidden md:flex space-x-6">
              {navigation.map((item) => {
                const Icon = item.icon
                const isActive = pathname === item.href
                return (
                  <Link
                    key={item.name}
                    href={item.href}
                    className={`flex items-center space-x-2 px-3 py-2 rounded-md text-sm font-medium transition-colors ${
                      isActive
                        ? 'bg-blue-100 text-blue-700'
                        : 'text-gray-600 hover:text-gray-900 hover:bg-gray-100'
                    }`}
                  >
                    <Icon className="w-4 h-4" />
                    <span>{item.name}</span>
                  </Link>
                )
              })}
            </div>
          </div>
        </div>
      </div>
    </nav>
  )
}
EOF

    # Create Dashboard component
    cat > "$APP_DIR/src/components/Dashboard.tsx" << 'EOF'
'use client'

import { useEffect, useState } from 'react'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/Card'
import { DollarSign, TrendingUp, TrendingDown, CreditCard } from 'lucide-react'

interface DashboardData {
  totalBalance: number
  totalDebt: number
  monthlyIncome: number
  monthlyExpenses: number
  recentTransactions: Array<{
    id: string
    description: string
    amount: number
    type: string
    date: string
  }>
}

export function Dashboard() {
  const [data, setData] = useState<DashboardData | null>(null)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    // Simulate API call - replace with actual API call later
    setTimeout(() => {
      setData({
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
      })
      setLoading(false)
    }, 1000)
  }, [])

  if (loading) {
    return (
      <div className="space-y-6">
        <h1 className="text-3xl font-bold text-gray-900">Dashboard</h1>
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
          {[...Array(4)].map((_, i) => (
            <Card key={i} className="animate-pulse">
              <CardContent className="p-6">
                <div className="h-4 bg-gray-200 rounded w-3/4 mb-2"></div>
                <div className="h-8 bg-gray-200 rounded w-1/2"></div>
              </CardContent>
            </Card>
          ))}
        </div>
      </div>
    )
  }

  if (!data) return null

  const netWorth = data.totalBalance - data.totalDebt
  const savingsRate = ((data.monthlyIncome - data.monthlyExpenses) / data.monthlyIncome) * 100

  return (
    <div className="space-y-6">
      <h1 className="text-3xl font-bold text-gray-900">Financial Dashboard</h1>
      
      {/* Summary Cards */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium text-gray-600">
              Total Balance
            </CardTitle>
            <DollarSign className="h-4 w-4 text-green-600" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold text-green-600">
              ${data.totalBalance.toLocaleString()}
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium text-gray-600">
              Total Debt
            </CardTitle>
            <CreditCard className="h-4 w-4 text-red-600" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold text-red-600">
              ${data.totalDebt.toLocaleString()}
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium text-gray-600">
              Net Worth
            </CardTitle>
            {netWorth >= 0 ? (
              <TrendingUp className="h-4 w-4 text-green-600" />
            ) : (
              <TrendingDown className="h-4 w-4 text-red-600" />
            )}
          </CardHeader>
          <CardContent>
            <div className={`text-2xl font-bold ${netWorth >= 0 ? 'text-green-600' : 'text-red-600'}`}>
              ${netWorth.toLocaleString()}
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium text-gray-600">
              Savings Rate
            </CardTitle>
            <TrendingUp className="h-4 w-4 text-blue-600" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold text-blue-600">
              {savingsRate.toFixed(1)}%
            </div>
          </CardContent>
        </Card>
      </div>

      {/* Recent Transactions */}
      <Card>
        <CardHeader>
          <CardTitle>Recent Transactions</CardTitle>
        </CardHeader>
        <CardContent>
          <div className="space-y-4">
            {data.recentTransactions.map((transaction) => (
              <div key={transaction.id} className="flex items-center justify-between p-4 border rounded-lg">
                <div>
                  <p className="font-medium">{transaction.description}</p>
                  <p className="text-sm text-gray-500">
                    {new Date(transaction.date).toLocaleDateString()}
                  </p>
                </div>
                <div className={`font-bold ${
                  transaction.amount >= 0 ? 'text-green-600' : 'text-red-600'
                }`}>
                  {transaction.amount >= 0 ? '+' : ''}${Math.abs(transaction.amount).toFixed(2)}
                </div>
              </div>
            ))}
          </div>
        </CardContent>
      </Card>
    </div>
  )
}
EOF

    # Create budget page
    cat > "$APP_DIR/src/app/budget/page.tsx" << 'EOF'
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
    </div>
  )
}
EOF

    # Create debts page
    cat > "$APP_DIR/src/app/debts/page.tsx" << 'EOF'
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
    </div>
  )
}
EOF

    # Create transactions page
    cat > "$APP_DIR/src/app/transactions/page.tsx" << 'EOF'
'use client'

import { useState } from 'react'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/Card'
import { Receipt, TrendingUp, TrendingDown, Filter } from 'lucide-react'

interface Transaction {
  id: string
  description: string
  amount: number
  category: string
  type: 'income' | 'expense'
  date: string
  account: string
}

export default function TransactionsPage() {
  const [transactions] = useState<Transaction[]>([
    {
      id: '1',
      description: 'Salary Deposit',
      amount: 2250.00,
      category: 'Salary',
      type: 'income',
      date: '2024-01-15',
      account: 'Checking'
    },
    {
      id: '2',
      description: 'Grocery Store',
      amount: -125.50,
      category: 'Food & Dining',
      type: 'expense',
      date: '2024-01-15',
      account: 'Credit Card'
    },
    {
      id: '3',
      description: 'Gas Station',
      amount: -45.00,
      category: 'Transportation',
      type: 'expense',
      date: '2024-01-14',
      account: 'Debit Card'
    },
    {
      id: '4',
      description: 'Electric Bill',
      amount: -89.50,
      category: 'Utilities',
      type: 'expense',
      date: '2024-01-13',
      account: 'Checking'
    },
    {
      id: '5',
      description: 'Freelance Payment',
      amount: 350.00,
      category: 'Freelance',
      type: 'income',
      date: '2024-01-12',
      account: 'Checking'
    }
  ])

  const totalIncome = transactions.filter(t => t.type === 'income').reduce((sum, t) => sum + t.amount, 0)
  const totalExpenses = transactions.filter(t => t.type === 'expense').reduce((sum, t) => sum + Math.abs(t.amount), 0)
  const netFlow = totalIncome - totalExpenses

  return (
    <div className="space-y-6">
      <h1 className="text-3xl font-bold text-gray-900">Transactions</h1>
      
      {/* Summary Cards */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium text-gray-600">Total Income</CardTitle>
            <TrendingUp className="h-4 w-4 text-green-600" />
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
            <TrendingDown className="h-4 w-4 text-red-600" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold text-red-600">
              ${totalExpenses.toLocaleString()}
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium text-gray-600">Net Flow</CardTitle>
            {netFlow >= 0 ? (
              <TrendingUp className="h-4 w-4 text-green-600" />
            ) : (
              <TrendingDown className="h-4 w-4 text-red-600" />
            )}
          </CardHeader>
          <CardContent>
            <div className={`text-2xl font-bold ${netFlow >= 0 ? 'text-green-600' : 'text-red-600'}`}>
              ${netFlow.toLocaleString()}
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium text-gray-600">Transactions</CardTitle>
            <Receipt className="h-4 w-4 text-blue-600" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold text-blue-600">
              {transactions.length}
            </div>
          </CardContent>
        </Card>
      </div>

      {/* Transactions List */}
      <Card>
        <CardHeader>
          <CardTitle className="flex items-center justify-between">
            <span>Recent Transactions</span>
            <button className="flex items-center space-x-2 px-3 py-2 text-sm bg-gray-100 rounded-md hover:bg-gray-200 transition-colors">
              <Filter className="w-4 h-4" />
              <span>Filter</span>
            </button>
          </CardTitle>
        </CardHeader>
        <CardContent>
          <div className="space-y-4">
            {transactions.map((transaction) => (
              <div key={transaction.id} className="flex items-center justify-between p-4 border rounded-lg hover:bg-gray-50 transition-colors">
                <div className="flex-1">
                  <div className="flex items-center justify-between">
                    <p className="font-medium">{transaction.description}</p>
                    <div className={`font-bold text-lg ${
                      transaction.type === 'income' ? 'text-green-600' : 'text-red-600'
                    }`}>
                      {transaction.type === 'income' ? '+' : ''}${Math.abs(transaction.amount).toFixed(2)}
                    </div>
                  </div>
                  <div className="flex items-center justify-between mt-1">
                    <div className="flex items-center space-x-4 text-sm text-gray-500">
                      <span>{transaction.category}</span>
                      <span>•</span>
                      <span>{transaction.account}</span>
                    </div>
                    <span className="text-sm text-gray-500">
                      {new Date(transaction.date).toLocaleDateString()}
                    </span>
                  </div>
                </div>
              </div>
            ))}
          </div>
        </CardContent>
      </Card>
    </div>
  )
}
EOF

    # Create accounts page
    cat > "$APP_DIR/src/app/accounts/page.tsx" << 'EOF'
'use client'

import { useState } from 'react'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/Card'
import { PiggyBank, CreditCard, Wallet, TrendingUp } from 'lucide-react'

interface Account {
  id: string
  name: string
  type: string
  balance: number
  bankName: string
  lastSync: string
  isActive: boolean
}

export default function AccountsPage() {
  const [accounts] = useState<Account[]>([
    {
      id: '1',
      name: 'Primary Checking',
      type: 'checking',
      balance: 3420.50,
      bankName: 'Chase Bank',
      lastSync: '2024-01-15T10:30:00Z',
      isActive: true
    },
    {
      id: '2',
      name: 'High Yield Savings',
      type: 'savings',
      balance: 15750.00,
      bankName: 'Ally Bank',
      lastSync: '2024-01-15T10:30:00Z',
      isActive: true
    },
    {
      id: '3',
      name: 'Rewards Credit Card',
      type: 'credit',
      balance: -1250.75,
      bankName: 'Capital One',
      lastSync: '2024-01-15T10:30:00Z',
      isActive: true
    },
    {
      id: '4',
      name: 'Emergency Fund',
      type: 'savings',
      balance: 8500.00,
      bankName: 'Marcus by Goldman Sachs',
      lastSync: '2024-01-15T10:30:00Z',
      isActive: true
    }
  ])

  const totalAssets = accounts.filter(a => a.balance > 0).reduce((sum, a) => sum + a.balance, 0)
  const totalLiabilities = accounts.filter(a => a.balance < 0).reduce((sum, a) => sum + Math.abs(a.balance), 0)
  const netWorth = totalAssets - totalLiabilities

  const getAccountIcon = (type: string) => {
    switch (type) {
      case 'checking':
        return <Wallet className="w-6 h-6" />
      case 'savings':
        return <PiggyBank className="w-6 h-6" />
      case 'credit':
        return <CreditCard className="w-6 h-6" />
      default:
        return <Wallet className="w-6 h-6" />
    }
  }

  const getAccountColor = (type: string) => {
    switch (type) {
      case 'checking':
        return 'text-blue-600 bg-blue-100'
      case 'savings':
        return 'text-green-600 bg-green-100'
      case 'credit':
        return 'text-red-600 bg-red-100'
      default:
        return 'text-gray-600 bg-gray-100'
    }
  }

  return (
    <div className="space-y-6">
      <h1 className="text-3xl font-bold text-gray-900">Accounts</h1>
      
      {/* Summary Cards */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium text-gray-600">Total Assets</CardTitle>
            <TrendingUp className="h-4 w-4 text-green-600" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold text-green-600">
              ${totalAssets.toLocaleString()}
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
              ${totalLiabilities.toLocaleString()}
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium text-gray-600">Net Worth</CardTitle>
            {netWorth >= 0 ? (
              <TrendingUp className="h-4 w-4 text-green-600" />
            ) : (
              <TrendingUp className="h-4 w-4 text-red-600" />
            )}
          </CardHeader>
          <CardContent>
            <div className={`text-2xl font-bold ${netWorth >= 0 ? 'text-green-600' : 'text-red-600'}`}>
              ${netWorth.toLocaleString()}
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium text-gray-600">Active Accounts</CardTitle>
            <PiggyBank className="h-4 w-4 text-blue-600" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold text-blue-600">
              {accounts.filter(a => a.isActive).length}
            </div>
          </CardContent>
        </Card>
      </div>

      {/* Accounts List */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {accounts.map((account) => (
          <Card key={account.id}>
            <CardHeader>
              <CardTitle className="flex items-center justify-between">
                <div className="flex items-center space-x-3">
                  <div className={`p-2 rounded-full ${getAccountColor(account.type)}`}>
                    {getAccountIcon(account.type)}
                  </div>
                  <div>
                    <div className="font-semibold">{account.name}</div>
                    <div className="text-sm text-gray-500">{account.bankName}</div>
                  </div>
                </div>
                <div className={`text-xl font-bold ${
                  account.balance >= 0 ? 'text-green-600' : 'text-red-600'
                }`}>
                  ${Math.abs(account.balance).toLocaleString()}
                </div>
              </CardTitle>
            </CardHeader>
            <CardContent className="space-y-4">
              <div className="flex justify-between items-center">
                <span className="text-sm text-gray-600">Account Type:</span>
                <span className="font-medium capitalize">{account.type}</span>
              </div>
              <div className="flex justify-between items-center">
                <span className="text-sm text-gray-600">Status:</span>
                <span className={`px-2 py-1 rounded-full text-xs font-medium ${
                  account.isActive 
                    ? 'bg-green-100 text-green-800' 
                    : 'bg-gray-100 text-gray-800'
                }`}>
                  {account.isActive ? 'Active' : 'Inactive'}
                </span>
              </div>
              <div className="flex justify-between items-center">
                <span className="text-sm text-gray-600">Last Sync:</span>
                <span className="text-sm font-medium">
                  {new Date(account.lastSync).toLocaleDateString()}
                </span>
              </div>
              <div className="flex space-x-2 pt-2">
                <button className="flex-1 bg-blue-600 text-white px-4 py-2 rounded-md text-sm font-medium hover:bg-blue-700 transition-colors">
                  View Details
                </button>
                <button className="flex-1 bg-gray-100 text-gray-700 px-4 py-2 rounded-md text-sm font-medium hover:bg-gray-200 transition-colors">
                  Sync Now
                </button>
              </div>
            </CardContent>
          </Card>
        ))}
      </div>
    </div>
  )
}
EOF

    # Create savings goals page
    cat > "$APP_DIR/src/app/savings/page.tsx" << 'EOF'
'use client'

import { useState } from 'react'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/Card'
import { Target, TrendingUp, Calendar, DollarSign } from 'lucide-react'

interface SavingsGoal {
  id: string
  name: string
  targetAmount: number
  currentAmount: number
  targetDate: string
  category: string
  isActive: boolean
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
      progress: 40
    },
    {
      id: '4',
      name: 'Home Renovation',
      targetAmount: 15000,
      currentAmount: 4500,
      targetDate: '2025-03-01',
      category: 'Home',
      isActive: true,
      progress: 30
    }
  ])

  const totalTargetAmount = goals.reduce((sum, goal) => sum + goal.targetAmount, 0)
  const totalCurrentAmount = goals.reduce((sum, goal) => sum + goal.currentAmount, 0)
  const overallProgress = (totalCurrentAmount / totalTargetAmount) * 100
  const activeGoals = goals.filter(goal => goal.isActive).length

  const getCategoryColor = (category: string) => {
    switch (category.toLowerCase()) {
      case 'emergency':
        return 'bg-red-100 text-red-800'
      case 'travel':
        return 'bg-blue-100 text-blue-800'
      case 'transportation':
        return 'bg-green-100 text-green-800'
      case 'home':
        return 'bg-purple-100 text-purple-800'
      default:
        return 'bg-gray-100 text-gray-800'
    }
  }

  const getDaysRemaining = (targetDate: string) => {
    const today = new Date()
    const target = new Date(targetDate)
    const diffTime = target.getTime() - today.getTime()
    const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24))
    return diffDays
  }

  return (
    <div className="space-y-6">
      <h1 className="text-3xl font-bold text-gray-900">Savings Goals</h1>
      
      {/* Summary Cards */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium text-gray-600">Total Target</CardTitle>
            <Target className="h-4 w-4 text-blue-600" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold text-blue-600">
              ${totalTargetAmount.toLocaleString()}
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
            <CardTitle className="text-sm font-medium text-gray-600">Overall Progress</CardTitle>
            <TrendingUp className="h-4 w-4 text-purple-600" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold text-purple-600">
              {overallProgress.toFixed(1)}%
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium text-gray-600">Active Goals</CardTitle>
            <Calendar className="h-4 w-4 text-orange-600" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold text-orange-600">
              {activeGoals}
            </div>
          </CardContent>
        </Card>
      </div>

      {/* Goals List */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {goals.map((goal) => {
          const daysRemaining = getDaysRemaining(goal.targetDate)
          const monthlyNeeded = (goal.targetAmount - goal.currentAmount) / Math.max(daysRemaining / 30, 1)
          
          return (
            <Card key={goal.id}>
              <CardHeader>
                <CardTitle className="flex items-center justify-between">
                  <span>{goal.name}</span>
                  <span className={`px-2 py-1 rounded-full text-xs font-medium ${getCategoryColor(goal.category)}`}>
                    {goal.category}
                  </span>
                </CardTitle>
              </CardHeader>
              <CardContent className="space-y-4">
                {/* Progress Bar */}
                <div>
                  <div className="flex justify-between text-sm text-gray-600 mb-1">
                    <span>Progress</span>
                    <span>{goal.progress}% complete</span>
                  </div>
                  <div className="w-full bg-gray-200 rounded-full h-3">
                    <div 
                      className="bg-blue-600 h-3 rounded-full transition-all duration-300"
                      style={{ width: `${goal.progress}%` }}
                    ></div>
                  </div>
                </div>

                {/* Goal Details */}
                <div className="space-y-2">
                  <div className="flex justify-between">
                    <span className="text-sm text-gray-600">Current Amount:</span>
                    <span className="font-medium text-green-600">${goal.currentAmount.toLocaleString()}</span>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-sm text-gray-600">Target Amount:</span>
                    <span className="font-medium">${goal.targetAmount.toLocaleString()}</span>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-sm text-gray-600">Remaining:</span>
                    <span className="font-medium text-orange-600">
                      ${(goal.targetAmount - goal.currentAmount).toLocaleString()}
                    </span>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-sm text-gray-600">Target Date:</span>
                    <span className="font-medium">{new Date(goal.targetDate).toLocaleDateString()}</span>
                  </div>
                  <div className="flex justify-between border-t pt-2">
                    <span className="text-sm text-gray-600">Days Remaining:</span>
                    <span className={`font-medium ${daysRemaining < 30 ? 'text-red-600' : 'text-blue-600'}`}>
                      {daysRemaining > 0 ? `${daysRemaining} days` : 'Overdue'}
                    </span>
                  </div>
                  {daysRemaining > 0 && (
                    <div className="flex justify-between">
                      <span className="text-sm text-gray-600">Monthly Needed:</span>
                      <span className="font-medium text-purple-600">
                        ${monthlyNeeded.toFixed(0)}/month
                      </span>
                    </div>
                  )}
                </div>

                {/* Action Buttons */}
                <div className="flex space-x-2 pt-2">
                  <button className="flex-1 bg-blue-600 text-white px-4 py-2 rounded-md text-sm font-medium hover:bg-blue-700 transition-colors">
                    Add Money
                  </button>
                  <button className="flex-1 bg-gray-100 text-gray-700 px-4 py-2 rounded-md text-sm font-medium hover:bg-gray-200 transition-colors">
                    Edit Goal
                  </button>
                </div>
              </CardContent>
            </Card>
          )
        })}
      </div>
    </div>
  )
}
EOF

    # Create bills page
    cat > "$APP_DIR/src/app/bills/page.tsx" << 'EOF'
'use client'

import { useState } from 'react'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/Card'
import { Calendar, AlertCircle, CheckCircle, Clock } from 'lucide-react'

interface Bill {
  id: string
  name: string
  amount: number
  dueDate: string
  category: string
  status: 'paid' | 'pending' | 'overdue'
  isRecurring: boolean
  frequency: string
  account: string
}

export default function BillsPage() {
  const [bills] = useState<Bill[]>([
    {
      id: '1',
      name: 'Rent',
      amount: 1200.00,
      dueDate: '2024-02-01',
      category: 'Housing',
      status: 'pending',
      isRecurring: true,
      frequency: 'Monthly',
      account: 'Checking'
    },
    {
      id: '2',
      name: 'Electric Bill',
      amount: 89.50,
      dueDate: '2024-01-25',
      category: 'Utilities',
      status: 'paid',
      isRecurring: true,
      frequency: 'Monthly',
      account: 'Checking'
    },
    {
      id: '3',
      name: 'Internet',
      amount: 65.00,
      dueDate: '2024-01-28',
      category: 'Utilities',
      status: 'pending',
      isRecurring: true,
      frequency: 'Monthly',
      account: 'Checking'
    },
    {
      id: '4',
      name: 'Car Insurance',
      amount: 125.00,
      dueDate: '2024-01-20',
      category: 'Insurance',
      status: 'overdue',
      isRecurring: true,
      frequency: 'Monthly',
      account: 'Checking'
    },
    {
      id: '5',
      name: 'Phone Bill',
      amount: 45.00,
      dueDate: '2024-02-05',
      category: 'Utilities',
      status: 'pending',
      isRecurring: true,
      frequency: 'Monthly',
      account: 'Checking'
    },
    {
      id: '6',
      name: 'Gym Membership',
      amount: 29.99,
      dueDate: '2024-01-30',
      category: 'Health & Fitness',
      status: 'pending',
      isRecurring: true,
      frequency: 'Monthly',
      account: 'Credit Card'
    }
  ])

  const totalPending = bills.filter(b => b.status === 'pending').reduce((sum, b) => sum + b.amount, 0)
  const totalPaid = bills.filter(b => b.status === 'paid').reduce((sum, b) => sum + b.amount, 0)
  const overdueCount = bills.filter(b => b.status === 'overdue').length
  const upcomingCount = bills.filter(b => {
    const dueDate = new Date(b.dueDate)
    const today = new Date()
    const diffDays = Math.ceil((dueDate.getTime() - today.getTime()) / (1000 * 60 * 60 * 24))
    return diffDays <= 7 && b.status === 'pending'
  }).length

  const getStatusIcon = (status: string) => {
    switch (status) {
      case 'paid':
        return <CheckCircle className="w-5 h-5 text-green-600" />
      case 'overdue':
        return <AlertCircle className="w-5 h-5 text-red-600" />
      case 'pending':
        return <Clock className="w-5 h-5 text-yellow-600" />
      default:
        return <Clock className="w-5 h-5 text-gray-600" />
    }
  }

  const getStatusColor = (status: string) => {
    switch (status) {
      case 'paid':
        return 'bg-green-100 text-green-800'
      case 'overdue':
        return 'bg-red-100 text-red-800'
      case 'pending':
        return 'bg-yellow-100 text-yellow-800'
      default:
        return 'bg-gray-100 text-gray-800'
    }
  }

  const getDaysUntilDue = (dueDate: string) => {
    const today = new Date()
    const due = new Date(dueDate)
    const diffTime = due.getTime() - today.getTime()
    const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24))
    return diffDays
  }

  return (
    <div className="space-y-6">
      <h1 className="text-3xl font-bold text-gray-900">Bills & Payments</h1>
      
      {/* Summary Cards */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium text-gray-600">Pending Bills</CardTitle>
            <Clock className="h-4 w-4 text-yellow-600" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold text-yellow-600">
              ${totalPending.toLocaleString()}
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
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium text-gray-600">Overdue Bills</CardTitle>
            <AlertCircle className="h-4 w-4 text-red-600" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold text-red-600">
              {overdueCount}
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium text-gray-600">Due This Week</CardTitle>
            <Calendar className="h-4 w-4 text-blue-600" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold text-blue-600">
              {upcomingCount}
            </div>
          </CardContent>
        </Card>
      </div>

      {/* Bills List */}
      <Card>
        <CardHeader>
          <CardTitle>Upcoming Bills</CardTitle>
        </CardHeader>
        <CardContent>
          <div className="space-y-4">
            {bills
              .sort((a, b) => new Date(a.dueDate).getTime() - new Date(b.dueDate).getTime())
              .map((bill) => {
                const daysUntilDue = getDaysUntilDue(bill.dueDate)
                
                return (
                  <div key={bill.id} className="flex items-center justify-between p-4 border rounded-lg hover:bg-gray-50 transition-colors">
                    <div className="flex items-center space-x-4">
                      {getStatusIcon(bill.status)}
                      <div>
                        <div className="flex items-center space-x-2">
                          <p className="font-medium">{bill.name}</p>
                          <span className={`px-2 py-1 rounded-full text-xs font-medium ${getStatusColor(bill.status)}`}>
                            {bill.status}
                          </span>
                        </div>
                        <div className="flex items-center space-x-4 text-sm text-gray-500 mt-1">
                          <span>{bill.category}</span>
                          <span>•</span>
                          <span>{bill.account}</span>
                          <span>•</span>
                          <span>{bill.frequency}</span>
                        </div>
                      </div>
                    </div>
                    
                    <div className="text-right">
                      <div className="font-bold text-lg">${bill.amount.toFixed(2)}</div>
                      <div className="text-sm text-gray-500">
                        {bill.status === 'overdue' ? (
                          <span className="text-red-600 font-medium">
                            {Math.abs(daysUntilDue)} days overdue
                          </span>
                        ) : bill.status === 'paid' ? (
                          <span className="text-green-600">Paid</span>
                        ) : (
                          <span>
                            Due {new Date(bill.dueDate).toLocaleDateString()}
                            {daysUntilDue <= 7 && daysUntilDue > 0 && (
                              <span className="text-yellow-600 font-medium ml-1">
                                ({daysUntilDue} days)
                              </span>
                            )}
                          </span>
                        )}
                      </div>
                    </div>
                  </div>
                )
              })}
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
            <button className="p-4 border rounded-lg hover:bg-gray-50 transition-colors text-left">
              <div className="font-medium">Add New Bill</div>
              <div className="text-sm text-gray-500">Set up a new recurring bill</div>
            </button>
            <button className="p-4 border rounded-lg hover:bg-gray-50 transition-colors text-left">
              <div className="font-medium">Pay All Pending</div>
              <div className="text-sm text-gray-500">Pay all pending bills at once</div>
            </button>
            <button className="p-4 border rounded-lg hover:bg-gray-50 transition-colors text-left">
              <div className="font-medium">Set Reminders</div>
              <div className="text-sm text-gray-500">Configure bill payment reminders</div>
            </button>
          </div>
        </CardContent>
      </Card>
    </div>
  )
}
EOF
    # Set ownership
    chown -R "$APP_USER:$APP_USER" "$APP_DIR"
    
    print_success "Application files created"
}

build_application() {
    print_header "Building Application"
    
    cd "$APP_DIR"
    
    # Install dependencies
    print_progress "Installing dependencies..."
    sudo -u "$APP_USER" npm ci --production
    
    # Build the application
    print_progress "Building application..."
    sudo -u "$APP_USER" npm run build
    
    # Generate Prisma client
    print_progress "Generating Prisma client..."
    sudo -u "$APP_USER" npx prisma generate
    
    # Initialize database
    print_progress "Initializing database..."
    sudo -u "$APP_USER" npx prisma db push
    
    print_success "Application built successfully"
}

#===============================================================================
# SERVICE CONFIGURATION FUNCTIONS
#===============================================================================

configure_systemd_service() {
    if [[ "$ENABLE_SYSTEMD" != "true" ]]; then
        return 0
    fi
    
    print_header "Configuring Systemd Service"
    
    # Create systemd service file
    cat > "/etc/systemd/system/${APP_NAME}.service" << EOF
[Unit]
Description=Personal Finance App
After=network.target

[Service]
Type=simple
User=$APP_USER
WorkingDirectory=$APP_DIR
ExecStart=/usr/bin/npm start
Restart=always
RestartSec=10
Environment=NODE_ENV=production
Environment=PORT=$APP_PORT

[Install]
WantedBy=multi-user.target
EOF

    # Enable and start service
    systemctl daemon-reload
    systemctl enable "$APP_NAME"
    systemctl start "$APP_NAME"
    
    print_success "Systemd service configured and started"
}

configure_nginx() {
    if [[ "$ENABLE_NGINX" != "true" ]]; then
        return 0
    fi
    
    print_header "Configuring Nginx Reverse Proxy"
    
    # Backup existing nginx config
    backup_file "/etc/nginx/sites-available/default"
    
    # Create nginx configuration
    local server_name="${APP_DOMAIN:-_}"
    
    cat > "/etc/nginx/sites-available/${APP_NAME}" << EOF
server {
    listen 80;
    server_name $server_name;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline'; script-src 'self' 'unsafe-inline' 'unsafe-eval';" always;

    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_proxied expired no-cache no-store private auth;
    gzip_types text/plain text/css text/xml text/javascript application/x-javascript application/xml+rss application/javascript;

    location / {
        proxy_pass http://127.0.0.1:$APP_PORT;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
    }

    # Static files caching
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg)$ {
        proxy_pass http://127.0.0.1:$APP_PORT;
        proxy_set_header Host \$host;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
}
EOF

    # Enable site
    ln -sf "/etc/nginx/sites-available/${APP_NAME}" "/etc/nginx/sites-enabled/"
    
    # Remove default site if it exists
    rm -f /etc/nginx/sites-enabled/default
    
    # Test nginx configuration
    if nginx -t; then
        systemctl restart nginx
        print_success "Nginx configured and restarted"
    else
        print_error "Nginx configuration test failed"
    fi
}

configure_ssl() {
    if [[ "$ENABLE_SSL" != "true" ]] || [[ -z "$APP_DOMAIN" ]]; then
        return 0
    fi
    
    print_header "Configuring SSL Certificate"
    
    print_progress "Obtaining SSL certificate from Let's Encrypt..."
    
    # Get SSL certificate
    if certbot --nginx -d "$APP_DOMAIN" --non-interactive --agree-tos --email "$SSL_EMAIL"; then
        print_success "SSL certificate obtained and configured"
    else
        print_warning "Failed to obtain SSL certificate. Check domain configuration."
    fi
}

configure_firewall() {
    if [[ "$ENABLE_FIREWALL" != "true" ]]; then
        return 0
    fi
    
    print_header "Configuring Firewall"
    
    # Allow HTTP and HTTPS
    ufw allow 80/tcp comment "HTTP"
    ufw allow 443/tcp comment "HTTPS"
    
    # Reload UFW
    ufw reload
    
    print_success "Firewall configured for web traffic"
}

#===============================================================================
# FINALIZATION FUNCTIONS
#===============================================================================

generate_deployment_report() {
    print_header "Deployment Report Generation"
    
    local report_file="${BACKUP_DIR}/deployment-report.txt"
    
    cat > "$report_file" << EOF
===============================================================================
Personal Finance App Deployment Report
Generated: $(date)
===============================================================================

APPLICATION INFORMATION:
- App Name: $APP_NAME
- App User: $APP_USER
- App Directory: $APP_DIR
- App Port: $APP_PORT
- Domain: ${APP_DOMAIN:-"Not configured"}

SERVICES STATUS:
- Application Service: $(systemctl is-active "$APP_NAME" 2>/dev/null || echo "Not configured")
- Nginx: $(systemctl is-active nginx 2>/dev/null || echo "Not running")
- Database: SQLite (${DB_PATH})

CONFIGURATION:
- SSL Enabled: $ENABLE_SSL
- Systemd Service: $ENABLE_SYSTEMD
- Nginx Proxy: $ENABLE_NGINX
- Firewall: $ENABLE_FIREWALL

ACCESS INFORMATION:
- Local URL: http://localhost:$APP_PORT
- Public URL: http://$(hostname -I | awk '{print $1}')
$(if [[ -n "$APP_DOMAIN" ]]; then echo "- Domain URL: http://$APP_DOMAIN"; fi)
$(if [[ "$ENABLE_SSL" == "true" ]]; then echo "- HTTPS URL: https://$APP_DOMAIN"; fi)

IMPORTANT FILES:
- Application Directory: $APP_DIR
- Nginx Configuration: /etc/nginx/sites-available/$APP_NAME
- Systemd Service: /etc/systemd/system/$APP_NAME.service
- Database: $DB_PATH
- Deployment Log: $LOG_FILE

MANAGEMENT COMMANDS:
- View logs: sudo journalctl -u $APP_NAME -f
- Restart app: sudo systemctl restart $APP_NAME
- Check status: sudo systemctl status $APP_NAME
- Nginx reload: sudo systemctl reload nginx

NEXT STEPS:
1. Test the application at the provided URLs
2. Configure domain DNS if using custom domain
3. Set up regular database backups
4. Configure monitoring and alerting
5. Review and customize application settings

===============================================================================
EOF

    print_success "Deployment report generated: $report_file"
}

show_deployment_summary() {
    print_header "Deployment Summary"
    
    echo
    print_success "✓ Personal Finance App deployed successfully!"
    print_success "✓ Application running on port $APP_PORT"
    print_success "✓ Database initialized with SQLite"
    [[ "$ENABLE_NGINX" == "true" ]] && print_success "✓ Nginx reverse proxy configured"
    [[ "$ENABLE_SYSTEMD" == "true" ]] && print_success "✓ Systemd service enabled"
    [[ "$ENABLE_SSL" == "true" ]] && print_success "✓ SSL certificate configured"
    
    echo
    print_status "${CYAN}" "🌐 ACCESS YOUR APPLICATION:"
    echo "   Local: http://localhost:$APP_PORT"
    echo "   Server: http://$(hostname -I | awk '{print $1}')"
    [[ -n "$APP_DOMAIN" ]] && echo "   Domain: http://$APP_DOMAIN"
    [[ "$ENABLE_SSL" == "true" ]] && echo "   HTTPS: https://$APP_DOMAIN"
    
    echo
    print_status "${CYAN}" "📊 MANAGEMENT COMMANDS:"
    echo "   View logs: sudo journalctl -u $APP_NAME -f"
    echo "   Restart: sudo systemctl restart $APP_NAME"
    echo "   Status: sudo systemctl status $APP_NAME"
    
    echo
    print_warning "⚠ Remember to:"
    print_warning "  • Configure your domain's DNS if using a custom domain"
    print_warning "  • Set up regular database backups"
    print_warning "  • Review firewall settings for your environment"
    
    echo
}

show_help() {
    cat << EOF
$SCRIPT_NAME v$SCRIPT_VERSION

USAGE:
    sudo bash $0 [OPTIONS]

ENVIRONMENT VARIABLES:
    APP_NAME            Application name (default: personal-finance-app)
    APP_USER            Application user (default: financeapp)
    APP_PORT            Application port (default: 3000)
    APP_DIR             Application directory (default: /opt/personal-finance-app)
    APP_DOMAIN          Domain name for the application
    NODE_VERSION        Node.js version (default: 18)
    
    ENABLE_SSL          Enable SSL with Let's Encrypt (default: false)
    SSL_EMAIL           Email for SSL certificate
    
    ENABLE_SYSTEMD      Enable systemd service (default: true)
    ENABLE_NGINX        Enable Nginx reverse proxy (default: true)
    ENABLE_FIREWALL     Configure firewall rules (default: true)

EXAMPLES:
    # Basic deployment
    sudo bash $0

    # With custom domain and SSL
    sudo APP_DOMAIN=myfinance.com ENABLE_SSL=true SSL_EMAIL=admin@myfinance.com bash $0

    # Custom configuration
    sudo APP_PORT=8080 APP_USER=webapp bash $0

FEATURES:
    • Complete Next.js Personal Finance Application
    • SQLite database with Prisma ORM
    • Nginx reverse proxy with security headers
    • Systemd service for process management
    • Optional SSL with Let's Encrypt
    • Firewall configuration
    • Production-ready optimization

For more information, visit: https://github.com/your-repo/finance-app-deploy
EOF
}

#===============================================================================
# MAIN EXECUTION FUNCTION
#===============================================================================

main() {
    # Handle help option
    if [[ "${1:-}" == "--help" ]] || [[ "${1:-}" == "-h" ]]; then
        show_help
        exit 0
    fi
    
    # Initialize
    print_header "$SCRIPT_NAME v$SCRIPT_VERSION"
    print_progress "Starting Personal Finance App deployment..."
    
    # Create log file and backup directory
    mkdir -p "$(dirname "$LOG_FILE")"
    mkdir -p "$BACKUP_DIR"
    touch "$LOG_FILE"
    
    log "INFO" "Starting $SCRIPT_NAME v$SCRIPT_VERSION"
    log "INFO" "Backup directory: $BACKUP_DIR"
    
    # Pre-flight checks
    check_root
    validate_configuration
    
    # Main deployment phases
    install_dependencies
    setup_repository
    install_nodejs
    create_app_user
    deploy_application
    create_database_schema
    create_application_files
    build_application
    
    # Service configuration
    configure_systemd_service
    configure_nginx
    configure_ssl
    configure_firewall
    
    # Finalization
    generate_deployment_report
    show_deployment_summary
    
    print_header "Deployment Complete!"
    print_success "Personal Finance App deployed successfully!"
    print_success "Check the deployment report: ${BACKUP_DIR}/deployment-report.txt"
    print_success "Application directory: $APP_DIR"
    [[ -d "$BACKUP_DIR" ]] && print_success "Backup directory: $BACKUP_DIR"
    
    log "INFO" "Deployment completed successfully"
}

#===============================================================================
# SCRIPT EXECUTION
#===============================================================================

# Trap errors and cleanup
trap 'print_error "Deployment failed at line $LINENO"' ERR

# Execute main function
main "$@"

exit 0