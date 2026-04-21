# Charagach

**Charagach** is an iOS plant marketplace and plant-care service application developed with **SwiftUI** and **Supabase**. The app combines plant buying and selling, plant sitting support, plant care guidance, and profile management in a single mobile platform. Based on the project audit you shared, the application currently includes authentication, marketplace CRUD operations, caregiver browsing and registration, profile editing, and static plant care tips, while some advanced features are still planned for future updates. fileciteturn0file0

## Team Members
- **Adnan Hossain Siraz**
- **Md. Rubayet Nabil**
- **Md. Shakibuzzaman**

## Project Overview
Charagach was designed to help plant lovers connect in a simple and user-friendly way. Users can create accounts, browse available plant listings, add their own listings, explore plant sitters, and read useful plant care tips. The app follows a tab-based structure and uses Supabase for backend services such as authentication, data storage, and profile-related operations. fileciteturn0file0

## Main Modules

### 1. Authentication Module
The authentication system manages:
- User sign up
- User sign in
- Sign out
- Password reset
- Email confirmation flow

This part is already connected end to end and is one of the working parts of the application. fileciteturn0file0

### 2. Marketplace Module
The marketplace allows users to:
- Browse plant listings
- Search listings
- Filter by category
- View plant details
- Add new listings
- Edit existing listings
- Change listing status
- Delete listings
- Open a dedicated **My Listings** section

According to the audit, marketplace CRUD is properly connected with Supabase. fileciteturn0file0

### 3. Plant Sitting Module
The plant sitting section supports:
- Browsing caregivers
- Viewing caregiver details
- Registering as a caregiver

At the moment, caregiver loading and registration are implemented, but the final booking operation is still a UI-based flow and does not yet create a booking row in Supabase. fileciteturn0file0

### 4. Plant Care Module
This module provides:
- Plant care tips
- Tip categories
- Tip detail pages

Currently, the tips work using local sample data. They are not yet loaded dynamically from the database. fileciteturn0file0

### 5. Profile Module
The profile section currently supports:
- Profile viewing
- Editing profile information
- Avatar upload
- Basic stats
- Sign out

However, some menu items such as **My Bookings**, **My Reviews**, **Notifications**, **Privacy & Security**, and **Help Center** are still placeholders. fileciteturn0file0

## Technologies Used
- **Language:** Swift
- **Framework:** SwiftUI
- **Backend:** Supabase
- **Database Features:** Authentication, profile storage, listing management, caregiver data, bookings table, care tips table, and storage bucket setup

The database schema already includes tables for profiles, caregivers, plant listings, plant sitting bookings, and plant care tips, along with row-level security policies. fileciteturn0file0

## Features That Are Working
- Authentication flow is implemented
- Marketplace CRUD is implemented
- Caregiver loading and caregiver registration work
- Profile load and save work
- Avatar upload works
- Plant care tips screen works with static data
- Fallback sample data prevents empty screens
- No compile errors were reported in the shared project audit

These are the confirmed working features from the code review summary you provided. fileciteturn0file0

## Features Still Incomplete
- Contact Seller is currently only an alert
- Plant-sitting booking is not fully connected to Supabase
- Several profile actions are placeholders
- Listing image upload is not fully integrated into the add-listing flow
- Plant care tips are not yet dynamic from database content
- Documentation was previously missing

These points can be improved in future versions of the project. fileciteturn0file0

## Future Improvements
Some important features that can be added next are:
- Real plant-sitting booking creation and history
- Seller contact or messaging system
- Listing photo upload support
- Favorites or saved items
- Reviews and ratings
- Notification system
- Database-driven plant care tips

## Suggested Screenshots to Add
Add your screenshot files in the same folder as this `README.md` file and keep the names as shown below. When GitHub or a Markdown viewer opens the README, the images will appear automatically.

### 1. Login Screen
![Login Screen](img1.png)

### 2. Sign Up Screen
![Sign Up Screen](img2.png)

### 3. Home Tab Layout
![Home Tab Layout](img3.png)

### 4. Marketplace Screen
![Marketplace Screen](img4.png)

### 5. Add Listing Screen
![Add Listing Screen](img5.png)

### 6. My Listings Screen
![My Listings Screen](img6.png)

### 7. Plant Sitting Screen
![Plant Sitting Screen](img7.png)

### 8. Caregiver Detail Screen
![Caregiver Detail Screen](img8.png)

### 9. Plant Care Screen
![Plant Care Screen](img9.png)

### 10. Profile Screen
![Profile Screen](img10.png)

### 11. Edit Profile Screen
![Edit Profile Screen](img11.png)

**Note:** If you want, you can replace `img1.png`, `img2.png`, etc. with any other file names later. Just update the image paths in this README.

## Conclusion
Charagach is a promising iOS project that already demonstrates a solid SwiftUI + Supabase architecture. The current version successfully covers user authentication, plant listing management, caregiver registration, profile editing, and informational content for plant care. With the addition of booking persistence, messaging, dynamic content, and image upload, the application can become a more complete and practical platform for plant lovers.
