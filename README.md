# Trailblaze Mobile 📱

**Trailblaze Mobile** is a Flutter-based Android application that serves as a **companion app** to the [Trailblaze Platform](https://github.com/tiagoroque3/Trailblaze-Platform).  
It enables field technicians and users to access parcel data, view details, and interact with map layers from their mobile devices.

---

## ✨ Features

- **Parcel Management**
  - Browse and search land parcels from the backend API
  - View parcel details (attributes, status, owner, etc.)

- **Map Visualization**
  - Display parcel boundaries and locations on an interactive map (Google Maps)
  - Layer toggle and zoom controls

- **User Authentication**
  - Login with platform credentials
  - Role-aware navigation (Admin, Technician, Viewer)

- **Responsive UI**
  - Clean, mobile-friendly design built with Flutter widgets
  - Tested for performance and accessibility

---

## 🚀 Getting Started

### Prerequisites
- [Flutter SDK](https://flutter.dev/docs/get-started/install) (3.x+)
- Android Studio or VS Code with Flutter extensions
- Android device or emulator
- API endpoint from the [Trailblaze backend](https://github.com/tiagoroque3/Trailblaze-Platform)

### Installation

1. Clone the repository:
```bash
git clone https://github.com/tiagoroque3/Trailblaze-Mobile.git
cd Trailblaze-Mobile
```

2. Install dependencies:
```bash
flutter pub get
```

3. Configure your API endpoint in the app (see `lib/services/api.dart` or config file).

4. Run the app:
```bash
flutter run
```

---

## 📊 My Contributions (Tiago Roque)

- Built Flutter UI components and navigation structure  
- Integrated REST API client with the backend (authentication, parcel data, role-based flows)  
- Implemented user login and role-aware screens  
- Optimized performance (achieved ~95% score with Flutter DevTools/Lighthouse tests)  
- Collaborated on linking map functionality with parcel data endpoints  

👉 [See my commits](https://github.com/tiagoroque3/Trailblaze-Mobile/commits?author=tiagoroque3)

---

## 💻 Tech Stack

- **Language/Framework:** Dart & Flutter  
- **API Integration:** REST/JSON with backend services  
- **Maps:** Google Maps (via `google_maps_flutter`)  
- **State Management:** (replace with what you used, e.g. Provider / Bloc)  
- **UI:** Material Design components

---

## 🤝 The Team

5Leaf Team:
- Francisco Sousa  
- Lourenço Cunha e Sá  
- Maria Penalva  
- Tiago Roque  
- Tomás Gouveia  

---

## 📝 License / Notice

This repository reflects a **university coursework project**.  
Code is published for **portfolio purposes**; reuse may be restricted if no explicit license is defined.

---
