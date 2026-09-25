# Capstone Budget Tracker 📊

An offline-first, single-ledger mobile budgeting and audit trail application built with **Flutter** and **Material 3**. Designed specifically to manage pooled project funds, track hardware/operational purchases, and eliminate confusion around member reimbursements and personal cash advances.

---

## ✨ Key Features

- **Project Budget Pool**: Real-time tracking of total allocated funds, current burn rate, and remaining balance.
- **Dual Reimbursement Ledger**:
  - **To Collect for Yourself**: Automatically aggregates out-of-pocket personal advances (`Me (Advance)`) waiting to be reimbursed from the project pool.
  - **Debts to Repay Teammates**: Tracks itemized advances made by individual teammates with quick settlement checkmarks.
- **Direct Fund Safeguards**: Supports direct envelope/account disbursements (`Direct Fund`) that bypass reimbursement tracking with dedicated visual badges.
- **Referential Integrity Guards**: Prevents accidental deletion of categories or team members tied to existing expense records.
- **Granular Auditing & Sorters**:
  - Filter by month/year or view all-time records.
  - Quick-filter chips for specific categories and payers.
  - Instant toggle between newest and oldest entries.
- **Persistent State**: Zero-backend offline storage powered by `shared_preferences` for custom categories, team rosters, expenses, and theme settings.
- **Theme Support**: Adaptive Material 3 Light and Dark modes with custom OLED palette styling.

---

## 🛠️ Tech Stack

- **Framework**: Flutter (Dart SDK `^3.13.1`+)
- **UI & Design**: Material 3
- **Local Persistence**: `shared_preferences`
- **Icon Tooling**: `flutter_launcher_icons`

---

## 🚀 Getting Started

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) installed and added to PATH
- Android Studio / VS Code with Flutter extension
- Android device or emulator running Android 5.0 (API 21) or higher

### Installation

1. Clone the repository:
   ```bash
   git clone [https://github.com/](https://github.com/)<your-username>/capstone_budget.git
   cd capstone_budget