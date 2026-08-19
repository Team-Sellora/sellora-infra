# WSO2 Identity Server - Sellora Configuration

## How to set up a fresh IS instance

### Prerequisites
- WSO2 IS is running and reachable
- Copy `deployment.toml` into `/repository/conf/` and restart IS

### Environment variables (do NOT commit these)
Create a `.env` file locally:

- IS_URL=https://your-oci-is-url:9443
- ADMIN_USER=admin
- ADMIN_PASS=your-password

### Run the setup script
```bash
source .env
chmod +x setup.sh
./setup.sh
```

## Test users (password: Test@1234)
| Email | Role |
|---|---|
| admin@testco.com | CompanyAdmin |
| areamanager@testco.com | AreaManager |
| agency@testco.com | AgencyOperator |
| rep@testco.com | SalesRep |
| shop@testco.com | ShopOwner |
