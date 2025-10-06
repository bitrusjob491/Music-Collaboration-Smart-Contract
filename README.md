# 🎵 Music Collaboration Smart Contract

A Clarity smart contract for tracking and splitting royalties among multiple artists in music collaborations. Built for the Stacks blockchain using Clarinet.

## 🚀 Features

- 🎼 **Create collaborative tracks** with multiple artists
- 💰 **Automatic royalty distribution** based on predefined percentages  
- 🔄 **Real-time earnings tracking** for each collaborator
- 💸 **Secure withdrawal system** for earned royalties
- 🎛️ **Track management** with activation/deactivation controls
- 📊 **Transparent earnings visibility** for all participants

## 🛠️ Usage

### Creating a New Track

```clarity
(contract-call? .music-collaboration create-track 
  "My Awesome Song"
  (list 
    { collaborator: 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM, percentage: u50 }
    { collaborator: 'ST2CY5V39NHDPWSXMW9QDT3HC3GD6Q6XX4CFRK9AG, percentage: u30 }
    { collaborator: 'ST2JHG361ZXG51QTKY2NQCVBPPRRE2KZB1HR05NNC, percentage: u20 }
  )
)
```

### Adding Royalties

```clarity
(contract-call? .music-collaboration add-royalty-amount u1 u1000000)
```

### Withdrawing Earnings

```clarity
(contract-call? .music-collaboration withdraw-earnings u1)
```

### Checking Available Earnings

```clarity
(contract-call? .music-collaboration get-available-earnings u1 tx-sender)
```

## 📋 Contract Functions

### Public Functions

- `create-track` - Create a new collaborative track with royalty splits
- `add-royalty` - Add royalties using sender's full STX balance
- `add-royalty-amount` - Add specific amount of royalties
- `withdraw-earnings` - Withdraw available earnings for a collaborator
- `update-collaborator-earnings` - Manually update collaborator earnings (creator only)
- `deactivate-track` - Deactivate a track (creator only)
- `calculate-and-distribute` - Calculate and distribute royalties (creator only)
- `manual-distribute` - Manually distribute earnings to specific collaborator

### Read-Only Functions

- `get-track` - Get track information
- `get-collaborator-info` - Get collaborator details for a track
- `get-available-earnings` - Check available earnings for withdrawal
- `get-contract-balance` - View total contract balance
- `get-next-track-id` - Get the next available track ID

## 🔧 Setup & Deployment

1. **Install Clarinet**
   ```bash
   npm install -g @hirosystems/clarinet-cli
   ```

2. **Initialize Project**
   ```bash
   clarinet new music-collaboration-project
   cd music-collaboration-project
   ```

3. **Add Contract**
   - Copy the contract code to `contracts/music-collaboration.clar`

4. **Test Contract**
   ```bash
   clarinet test
   ```

5. **Deploy Contract**
   ```bash
   clarinet deploy
   ```

## 💡 Example Workflow

1. **Artist creates track** with 3 collaborators (50%, 30%, 20% splits)
2. **Streaming revenue** gets added to the contract via `add-royalty-amount`
3. **Contract automatically calculates** each artist's share
4. **Artists withdraw** their earnings individually using `withdraw-earnings`
5. **Track creator** can manage the track and manually adjust distributions if needed

## 🔒 Security Features

- ✅ Percentage validation (must total 100%)
- ✅ Authorization checks for track creators
- ✅ Balance verification before transfers
- ✅ Withdrawal tracking to prevent double-spending
- ✅ Track activation status controls

## 📈 Contract State

The contract maintains:
- **Track metadata** (title, creator, earnings, status)
- **Collaborator information** (percentage, earnings, withdrawals)
- **Automatic ID generation** for new tracks
- **Balance tracking** for transparent accounting

## 🎯 Perfect For

- 🎤 **Music producers** collaborating on beats
- 🎸 **Band members** splitting song royalties  
- 🎹 **Songwriters** sharing composition credits
- 🎧 **DJs and remixers** working together
- 🎼 **Any creative collaboration** requiring fair revenue splits

Start building the future of music collaboration on the blockchain! 🚀🎵
```

**Git Commit Message:**
```
feat
