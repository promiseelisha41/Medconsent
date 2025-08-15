# 🏥 Medconsent

> 📋 Blockchain-based Medical Consent Ledger for secure patient treatment authorization

## 🌟 Overview

Medconsent is a decentralized smart contract built on the Stacks blockchain that manages patient consent for medical treatments. It provides a transparent, immutable, and secure way to handle medical consent between patients and healthcare providers.

## ✨ Features

- 👤 **Patient Registration**: Secure patient profile creation with personal details
- 🏥 **Healthcare Provider Management**: Provider registration and verification system
- 📝 **Consent Management**: Give, update, and revoke medical treatment consent
- ⏰ **Expiry Tracking**: Time-bound consent with automatic expiration
- 🔍 **Consent Verification**: Real-time consent validity checking
- 🛡️ **Security**: Only patients can manage their own consent records

## 🚀 Getting Started

### Prerequisites

- Clarinet CLI installed
- Stacks wallet for testing

### Installation

```bash
git clone <your-repo>
cd medconsent
clarinet check
```

## 📖 Usage

### 1. Register as a Patient

```clarity
(contract-call? .medconsent register-patient "John Doe" "1990-01-01" "Jane Doe - 555-0123")
```

### 2. Register as Healthcare Provider

```clarity
(contract-call? .medconsent register-provider "Dr. Smith" "MD123456" "Cardiology")
```

### 3. Give Medical Consent

```clarity
(contract-call? .medconsent give-consent 'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7 "Heart Surgery" "Bypass surgery consent" u1000)
```

### 4. Check Consent Validity

```clarity
(contract-call? .medconsent check-consent-validity 'SP1HTBVD3JG9C05J7HBJTHGR0GGW7KXW28M5JS8QE 'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7 "Heart Surgery")
```

### 5. Revoke Consent

```clarity
(contract-call? .medconsent revoke-consent u1 "Changed my mind about the procedure")
```

## 🔧 Contract Functions

### Public Functions

| Function | Description |
|----------|-------------|
| `register-patient` | 👤 Register a new patient |
| `register-provider` | 🏥 Register a healthcare provider |
| `verify-provider` | ✅ Verify provider (owner only) |
| `give-consent` | 📝 Grant treatment consent |
| `revoke-consent` | ❌ Revoke existing consent |
| `update-consent` | 🔄 Update consent details |

### Read-Only Functions

| Function | Description |
|----------|-------------|
| `get-patient` | 👤 Get patient information |
| `get-provider` | 🏥 Get provider information |
| `get-consent` | 📋 Get consent record |
| `check-consent-validity` | ✅ Verify consent status |
| `get-consent-by-treatment` | 🔍 Find consent by treatment type |
| `is-provider-verified` | 🛡️ Check provider verification |

## 🏗️ Architecture

### Data Maps

- **patients**: Store patient registration data
- **healthcare-providers**: Manage provider information and verification
- **consent-records**: Track all consent transactions
- **patient-consents**: Quick lookup for patient-provider-treatment combinations

### Security Features

- 🔐 Patient-only consent management
- 👑 Owner-only provider verification
- ⏱️ Automatic consent expiration
- 🚫 Revocation tracking with reasons

## 🧪 Testing

```bash
clarinet test
```

## 📄 Error Codes

| Code | Description |
|------|-------------|
| u100 | Unauthorized access |
| u101 | Patient not found |
| u102 | Consent not found |
| u103 | Invalid expiry date |
| u104 | Consent expired |
| u105 | Consent revoked |
| u106 | Provider not authorized |
| u107 | Record already exists |

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## 📜 License

This project is licensed under the MIT License.

## 🆘 Support

For support and questions, please open an issue in the repository.


