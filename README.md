# Personal Finance App

A comprehensive personal finance management application with bi-weekly budget tracking, debt management, and open banking integration.

## Features

### Core Features
- **Bi-Weekly Budget Tracker**: Track income and expenses based on bi-weekly pay periods
- **Debt Tracker**: Calculate payoff dates and track debt reduction progress
- **Transaction Management**: Categorize and track all financial transactions
- **Account Management**: Connect and manage multiple bank accounts

### Advanced Features
- **Open Banking Integration**: Secure bank account connections via Plaid
- **Savings Goals**: Track progress toward financial goals
- **Bill Reminders**: Never miss a payment with automated reminders
- **Financial Insights**: AI-powered recommendations and analytics
- **Mobile Responsive**: Works on all device sizes

## Quick Start

### Using Docker (Recommended)
```bash
# Clone and setup
git clone <repository-url> finance-app
cd finance-app

# Copy environment variables
cp .env.example .env
# Edit .env with your configuration

# Start services
docker-compose up -d

# Access app
# Frontend: http://localhost
# API: http://localhost:8000/docs
```

### Manual Installation
See [DEPLOYMENT_GUIDE.md](docs/DEPLOYMENT_GUIDE.md) for detailed instructions.

## API Documentation

Once running, visit `http://localhost:8000/docs` for interactive API documentation.

## Development

### Backend
```bash
cd backend
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
pip install -r requirements.txt
uvicorn app.main:app --reload
```

### Frontend
```bash
cd frontend
npm install
npm start
```

## Testing

### Backend Tests
```bash
cd backend
pytest
```

### Frontend Tests
```bash
cd frontend
npm test
```

## Deployment

For production deployment, see the [Deployment Guide](docs/DEPLOYMENT_GUIDE.md).

## Security

- JWT authentication
- HTTPS enforcement
- Input validation
- Rate limiting
- SQL injection protection
- XSS protection

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests
5. Submit a pull request

## License

MIT License - see LICENSE file for details