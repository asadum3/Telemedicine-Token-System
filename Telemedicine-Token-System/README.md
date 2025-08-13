# Telemedicine Token System

A decentralized healthcare consultation platform built on the Stacks blockchain using Clarity smart contracts. This system enables secure, transparent, and incentivized telemedicine consultations with automated specialist rewards.

##  Overview

The Telemedicine Token System revolutionizes healthcare delivery by creating a decentralized platform where:
- Patients can book consultations with verified healthcare providers
- Doctors receive transparent, automated payments with specialist bonuses
- All medical interactions are securely recorded on-chain
- Quality is maintained through a rating system

##  Key Features

### For Patients
- **Secure Registration**: Register with encrypted medical record hashes
- **Easy Booking**: Book consultations with available doctors
- **Transparent Pricing**: Clear fee structure with no hidden costs
- **Quality Assurance**: Rate doctors and view their ratings
- **Token Purchase**: Buy consultation tokens directly

### for Healthcare Providers
- **Doctor Registration**: Register with specializations and hourly rates
- **Specialist Rewards**: 20% bonus for certified specialists
- **Automated Payments**: Instant payment processing after consultations
- **Reputation System**: Build reputation through patient ratings
- **Earnings Management**: Easy withdrawal of accumulated earnings

### System Features
- **Escrow Protection**: Funds held securely until consultation completion
- **Platform Sustainability**: 5% platform fee for system maintenance
- **Medical Records**: Secure, hash-based medical note storage
- **Consultation Tracking**: Complete audit trail of all interactions

##  Quick Start

### Prerequisites
- Stacks wallet (Hiro Wallet recommended)
- STX tokens for transaction fees
- Node.js and npm (for frontend integration)

### Deployment

1. **Deploy the Contract**
   ```bash
   clarinet deploy --network testnet
   ```

2. **Initialize the System**
   ```clarity
   (contract-call? .telemedicine-token initialize-contract)
   ```

##  Contract Functions

### Registration Functions

#### Register as Doctor
```clarity
(register-doctor 
    "Dr. Jane Smith"           ;; name
    "Cardiology"              ;; specialty
    u75000000                 ;; hourly rate (75 tokens)
    true                      ;; is specialist
)
```

#### Register as Patient
```clarity
(register-patient 
    "John Doe"                               ;; name
    "hash_of_encrypted_medical_records"      ;; medical record hash
)
```

### Consultation Workflow

#### 1. Book Consultation
```clarity
(book-consultation 
    'SP1234...DOCTOR-ADDRESS    ;; doctor principal
    u2                          ;; estimated duration (hours)
)
```

#### 2. Start Consultation (Doctor)
```clarity
(start-consultation u1)  ;; consultation ID
```

#### 3. End Consultation (Doctor)
```clarity
(end-consultation 
    u1                                    ;; consultation ID
    "hash_of_medical_notes"              ;; medical notes hash
)
```

#### 4. Rate Consultation (Patient)
```clarity
(rate-consultation 
    u1      ;; consultation ID
    u4500   ;; rating (4.5/5.0 scaled by 1000)
)
```

### Financial Functions

#### Purchase Tokens
```clarity
(purchase-tokens u100000000)  ;; 100 tokens
```

#### Withdraw Earnings (Doctor)
```clarity
(withdraw-earnings)
```

##  Architecture

### Token Economics
- **Total Supply**: 1,000,000 TMED tokens
- **Decimals**: 6
- **Base Consultation Fee**: 50 TMED tokens
- **Platform Fee**: 5% of consultation fees
- **Specialist Bonus**: 20% additional reward

### Data Structure

#### Doctor Profile
```clarity
{
    name: (string-utf8 100),
    specialty: (string-utf8 50),
    rating: uint,                    ;; scaled by 1000
    total-consultations: uint,
    is-specialist: bool,
    hourly-rate: uint,
    is-active: bool
}
```

#### Consultation Record
```clarity
{
    patient: principal,
    doctor: principal,
    consultation-fee: uint,
    status: (string-ascii 20),       ;; "booked", "active", "completed"
    start-time: uint,
    end-time: (optional uint),
    rating: (optional uint),
    medical-notes-hash: (optional (string-utf8 64))
}
```

##  Security Features

### Access Control
- Function-specific authorization checks
- Role-based permissions (patients, doctors, contract owner)
- State validation for all operations

### Data Protection
- Medical records stored as cryptographic hashes
- Private medical notes secured off-chain with hash verification
- Patient data privacy maintained throughout the system

### Financial Security
- Escrow-based payment system
- Automated fee calculation and distribution
- Protection against double-spending and unauthorized withdrawals

##  Fee Structure

| Component | Rate | Description |
|-----------|------|-------------|
| Base Consultation | Doctor's hourly rate × duration | Core consultation fee |
| Specialist Bonus | +20% of base fee | Additional reward for specialists |
| Platform Fee | 5% of total fee | System maintenance and development |
| Patient Payment | Base + Specialist Bonus | Total amount paid by patient |
| Doctor Earnings | Patient Payment - Platform Fee | Amount credited to doctor |

##  Testing

### Unit Tests
Run the complete test suite:
```bash
clarinet test
```

### Integration Testing
Test full consultation workflow:
```bash
clarinet run scripts/test-consultation-flow.ts
```

##  Frontend Integration

### Web3 Connection Example
```javascript
import { openContractCall } from '@stacks/connect';

const bookConsultation = async (doctorAddress, duration) => {
  const functionArgs = [
    principalCV(doctorAddress),
    uintCV(duration)
  ];
  
  await openContractCall({
    network: new StacksTestnet(),
    contractAddress: 'ST1234...CONTRACT-ADDRESS',
    contractName: 'telemedicine-token',
    functionName: 'book-consultation',
    functionArgs,
  });
};
```

##  Development Roadmap

### Phase 1: Core Platform 
- Basic consultation booking and management
- Payment processing with specialist rewards
- Doctor and patient registration

### Phase 2: Enhanced Features 
- Multi-signature medical record access
- Prescription management system
- Insurance integration framework

### Phase 3: Advanced Capabilities 
- AI-assisted diagnosis support
- Telemedicine video integration
- Cross-chain interoperability

##  Contributing

We welcome contributions! Please see our [Contributing Guide](CONTRIBUTING.md) for details.

### Development Setup
```bash
git clone https://github.com/your-org/telemedicine-token-system
cd telemedicine-token-system
npm install
clarinet requirements
```

##  License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

##  Support

- **Documentation**: [Full API Documentation](docs/API.md)
- **Community**: Join our [Discord](https://discord.gg/telemedicine-token)
- **Issues**: [GitHub Issues](https://github.com/your-org/telemedicine-token-system/issues)
- **Email**: support@telemedicine-token.org

##  Legal Compliance

This system is designed to be HIPAA-compliant when properly implemented with appropriate off-chain infrastructure. Ensure compliance with local healthcare regulations before deployment.

---

** Disclaimer**: This is a demonstration smart contract. Ensure thorough testing and security audits before any production deployment in healthcare environments.