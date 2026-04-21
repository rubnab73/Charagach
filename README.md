# Charagach

Charagach is an iOS plant marketplace and plant-care service application built with SwiftUI and Supabase. It brings plant buying and selling, plant-sitting support, plant care guidance, and profile management into a single mobile experience.

## Team Members
- Adnan Hossain Siraz
- Md. Rubayet Nabil
- Md. Shakibuzzaman

## Project Overview
The app is organized around a tab-based interface and uses Supabase for authentication, database access, and storage. The current implementation includes user authentication, marketplace operations, caregiver browsing and registration, profile management, and plant care content.

## Main Modules

### 1. Authentication Module
The authentication flow supports:
- User registration
- User sign in
- User sign out
- Password reset

This flow is implemented and currently functional.

### 2. Marketplace Module
The marketplace supports:
- Browsing plant listings
- Searching listings
- Filtering by category
- Viewing listing details
- Creating new listings
- Editing existing listings
- Updating listing status
- Deleting listings
- Accessing the My Listings section

This module is connected to Supabase for listing data management.

### 3. Plant Sitting Module
The plant sitting section supports:
- Browsing caregivers
- Viewing caregiver details
- Registering as a caregiver

### 4. Plant Care Module
This module provides:
- Plant care tips
- Tip categories
- Tip detail pages

The current tips are backed by local sample data and are not yet loaded dynamically from the database.

### 5. Profile Module
The profile section supports:
- Viewing the user profile
- Editing profile information
- Avatar upload
- Basic statistics
- Sign out

Some menu items such as My Bookings, My Reviews, Notifications, Privacy and Security, and Help Center are still placeholders.

## Technologies Used
- Language: Swift
- Framework: SwiftUI
- Backend: Supabase
- Database and Storage: Authentication, profile storage, listing management, caregiver data, bookings table, care tips table, and storage bucket setup

The database schema includes tables for profiles, caregivers, plant listings, plant sitting bookings, and plant care tips, along with row-level security policies.

## Implemented Features
- Authentication flow
- Marketplace CRUD operations
- Caregiver loading and caregiver registration
- Profile loading and saving
- Avatar upload
- Plant care tips screen with static data
- Fallback sample data to avoid empty screens

## Future Improvements
Planned enhancements include:
- Real plant-sitting booking creation and history
- Seller contact or messaging system
- Listing photo upload support
- Favorites or saved items
- Reviews and ratings
- Notification system
- Database-driven plant care tips

## Screenshots of the App
The following screenshots are included for reference.

### 1. Marketplace Screen
![Marketplace Screen](marketplace.png)

### 2. Add Listing Screen
![Add Listing Screen](add_listing.png)

### 3. My Listings Screen
![My Listings Screen](my_listing.png)

### 4. Plant Sitting Screen
![Plant Sitting Screen](plant_sitting.png)

### 5. Become Sitter Screen
![Become Sitter Screen](become_sitter.png)

### 6. Care Reminder Screen
![Care Reminder Screen](care_reminder.png)

### 7. Plant Care Screen
![Plant Care Screen](plant_care_tips.png)

### 8. Profile Screen
![Profile Screen](profile.png)

### 9. Edit Profile Screen
![Edit Profile Screen](edit_profile.png)

## Conclusion
Charagach demonstrates a solid SwiftUI and Supabase architecture for a plant marketplace and care service app. The current version covers authentication, plant listing management, caregiver registration, profile editing, and plant care content. With booking persistence, messaging, dynamic content, and image upload improvements, it can become a more complete platform for plant lovers.