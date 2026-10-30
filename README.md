# PennyNote

A fast expense tracker for iPhone. Sign in with email and password and your expenses are kept in your account, synced across devices and available offline.

<p align="center">
  <img src="docs/screenshots/main.png" width="200" alt="Main screen with the month's total, the comparison with the previous month and a daily spending chart">
  <img src="docs/screenshots/add.png" width="200" alt="Add expense sheet with title, amount, category, payment method and date">
  <img src="docs/screenshots/statistics.png" width="200" alt="Statistics screen with the month's total, daily spending chart and spending per category">
  <img src="docs/screenshots/statistics-more.png" width="200" alt="Statistics screen with spending per payment method and the last six months">
</p>
<p align="center">
  <img src="docs/screenshots/filters.png" width="200" alt="Filter menu with categories and payment methods">
  <img src="docs/screenshots/search.png" width="200" alt="Search results for expenses matching a title">
  <img src="docs/screenshots/widget.jpg" width="200" alt="Medium Home Screen widget with the month's chart and top categories">
  <img src="docs/screenshots/signin.png" width="200" alt="Sign-in screen with email and password and a Demo button">
</p>

## Features

- Log an expense in seconds with title, amount, category and payment method.
- Search and filter expenses by category and payment method.
- Daily spending chart and a comparison with the previous month right on the main screen.
- Statistics: spending per day, per category and per payment method, and the last six months.
- Home Screen widgets (small and medium) with the month's chart and top categories, and Lock Screen widgets with the total.
- Control Center button and Siri/Shortcuts action to add an expense.
- Works offline: changes are saved on the device and synced to your account ([Supabase](https://supabase.com)) when there is a connection.
- Demo mode: tap **Demo** on the sign-in screen to browse the app with sample data, without an account. It is read-only and nothing is saved.

## Requirements

- iOS 18 or later.
- The app is in English, Spanish and Simplified Chinese, and follows the iPhone's language. To use another one, go to iOS **Settings → PennyNote → Language**.

## Installation

PennyNote is not on the App Store. It is installed with [AltStore Classic](https://altstore.io), which signs apps with your own Apple ID.

1. Set up AltServer on your computer and AltStore on your iPhone by following the [official AltStore guide](https://faq.altstore.io).
2. In AltStore on your iPhone, go to **Sources** → **+** and add:
   ```
   https://raw.githubusercontent.com/lsopenad/PennyNote/main/altstore-source.json
   ```
3. Open the PennyNote source and install the app. New versions show up in **My Apps**.
4. Optionally add the widgets from the Home Screen and Lock Screen editors.

Apps signed with a free Apple ID expire after 7 days. AltStore refreshes them automatically while AltServer is running on a computer on the same Wi-Fi network.

## Your data

Each account only sees its own expenses (enforced in the database with row-level security). Signing out removes the data from the iPhone; it stays in your account. **Settings → Delete my account and my data** removes the account and everything in it from the server.

## Development

See [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md) (in Spanish) for building, testing and publishing releases.

## License

[MIT](LICENSE)
