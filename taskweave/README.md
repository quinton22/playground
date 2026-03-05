# 🧵 TaskWeave

> **Weave your tasks together** — A collaborative todo app with smart SMS-based suggestions

TaskWeave is a Flutter mobile application that goes beyond the ordinary todo app. It lets you share task lists with friends and family in real-time, and intelligently analyzes your text messages to suggest relevant todos.

---

## ✨ Features

### Core Todo Functionality
- ✅ Create todos with or without deadlines (open-ended or time-bound)
- ✏️ Edit and update existing tasks
- 🗑️ Delete tasks with swipe gesture
- ☑️ Check off completed tasks
- 🏷️ Organize with tags and priority levels (Low / Medium / High)
- 📁 Multiple named lists with custom emoji and color

### ⏰ Reminders & Notifications
- Set custom reminder times for any task
- Deadline-approaching notifications
- Scheduled local notifications that persist through device restarts
- Notifications survive app being closed (via exact alarm scheduling)

### 👥 Shared Todo Lists
- Invite collaborators to any list by email
- Real-time sync across all members via Firebase Firestore
- Role-based access: owner vs. member
- Manage pending invites and remove members
- All changes reflected instantly for everyone in the list

### 💬 Smart SMS Suggestions *(Android only)*
TaskWeave's standout feature reads your recent text messages and uses pattern matching to detect actionable items:

- Detects **action words** like "don't forget", "pick up", "make sure to", "please", etc.
- Recognizes **deadlines** from natural language: "tomorrow", "tonight", "by Friday", "on 3/15"
- Assigns a **confidence score** to each suggestion
- Displays suggested title, snippet from original message, and inferred deadline
- One tap to accept a suggestion and create a task pre-filled with the extracted info
- **Privacy-first**: all analysis happens on-device, messages never leave your phone

---

## 🏗️ Architecture

```
taskweave/
├── lib/
│   ├── main.dart                  # App entry point, Firebase init, providers setup
│   ├── models/
│   │   ├── todo_item.dart         # TodoItem model with Firestore serialization
│   │   ├── todo_list.dart         # TodoList model
│   │   ├── app_user.dart          # User profile model
│   │   └── sms_message.dart       # SMS message & suggestion models
│   ├── services/
│   │   ├── auth_service.dart      # Firebase Auth wrapper
│   │   ├── firestore_service.dart # Firestore CRUD + real-time streams
│   │   ├── notification_service.dart # Local notification scheduling
│   │   └── sms_service.dart       # SMS reading + NLP-style pattern analysis
│   ├── providers/
│   │   ├── auth_provider.dart     # Auth state management
│   │   ├── todo_provider.dart     # Todo CRUD + list management
│   │   └── sms_provider.dart      # SMS permission + suggestion state
│   ├── screens/
│   │   ├── splash_screen.dart     # Animated launch screen
│   │   ├── login_screen.dart      # Sign in
│   │   ├── signup_screen.dart     # Account creation
│   │   ├── home_screen.dart       # Main app shell (sidebar + todo list)
│   │   ├── create_todo_screen.dart # New task form
│   │   ├── edit_todo_screen.dart  # Edit existing task
│   │   └── list_settings_screen.dart # List management + member invite
│   ├── widgets/
│   │   ├── todo_list_sidebar.dart # Navigation sidebar with list counts
│   │   ├── todo_list_view.dart    # Task list with swipe gestures
│   │   └── sms_suggestions_sheet.dart # Bottom sheet with SMS suggestions
│   └── utils/
│       └── app_theme.dart         # Material 3 light/dark themes
├── test/
│   ├── models_test.dart           # Unit tests for data models
│   ├── sms_service_test.dart      # Tests for SMS parsing logic
│   └── app_user_test.dart         # Tests for user model
└── android/
    └── app/src/main/
        └── AndroidManifest.xml   # SMS, notification & internet permissions
```

### Tech Stack
| Layer | Technology |
|-------|-----------|
| UI Framework | Flutter 3 (Material 3) |
| State Management | Provider |
| Backend / Auth | Firebase Auth + Cloud Firestore |
| Notifications | flutter_local_notifications + timezone |
| SMS Reading | telephony (Android) |
| Permissions | permission_handler |

---

## 🚀 Getting Started

### Prerequisites
- Flutter SDK ≥ 3.0.0
- Firebase project with Authentication and Firestore enabled
- Android SDK (for SMS features)

### Setup

1. **Clone the project and install dependencies:**
   ```bash
   cd taskweave
   flutter pub get
   ```

2. **Configure Firebase:**
   - Create a Firebase project at [console.firebase.google.com](https://console.firebase.google.com)
   - Enable **Email/Password** authentication
   - Enable **Cloud Firestore**
   - Download `google-services.json` and place it in `android/app/`
   - Download `GoogleService-Info.plist` and place it in `ios/Runner/`

3. **Set up Firestore security rules:**
   ```
   rules_version = '2';
   service cloud.firestore {
     match /databases/{database}/documents {
       match /users/{userId} {
         allow read, write: if request.auth.uid == userId;
       }
       match /lists/{listId} {
         allow read, write: if request.auth.uid == resource.data.ownerId
           || request.auth.uid in resource.data.memberIds;
         allow create: if request.auth != null;
       }
       match /todos/{todoId} {
         allow read, write: if request.auth != null;
       }
     }
   }
   ```

4. **Run the app:**
   ```bash
   flutter run
   ```

### Running Tests
```bash
flutter test
```

---

## 📱 Screenshots

The app features:
- A clean Material 3 design with Indigo as the primary color
- Adaptive layout: sidebar for tablets/desktops, drawer for phones
- Swipe left to delete, swipe right to complete tasks
- Bottom sheet for SMS suggestions with confidence scores
- Dark mode support

---

## 📋 Firestore Data Model

### Collection: `lists`
```json
{
  "id": "uuid",
  "name": "Shopping List",
  "description": "Weekly groceries",
  "ownerId": "firebase-uid",
  "memberIds": ["uid-2", "uid-3"],
  "pendingInvites": ["friend@email.com"],
  "createdAt": "Timestamp",
  "emoji": "🛒",
  "color": "green"
}
```

### Collection: `todos`
```json
{
  "id": "uuid",
  "title": "Buy milk",
  "description": "2% reduced fat",
  "createdAt": "Timestamp",
  "deadline": "Timestamp | null",
  "reminderAt": "Timestamp | null",
  "priority": "low | medium | high",
  "status": "open | inProgress | completed",
  "createdBy": "firebase-uid",
  "listId": "list-uuid",
  "tags": ["shopping", "weekly"],
  "hasReminder": true,
  "suggestedFromMessageId": "sms-id | null"
}
```

---

## 🔒 Privacy & Security

- **SMS messages are never uploaded**: Analysis happens entirely on-device using regex pattern matching
- **Firebase Auth** handles user authentication with email/password
- **Firestore rules** ensure users can only access lists they own or are members of
- Notification content is stored locally only
