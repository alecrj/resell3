//
//  EbaySignInView.swift
//  ResellAI
//
//  Created by Alec on 8/2/25.
//


//
//  EbaySignInView.swift
//  ResellAI
//
//  eBay User Authentication and Account Management
//

import SwiftUI

// MARK: - eBay Sign-In View
struct EbaySignInView: View {
    @StateObject private var ebayAuthManager = EbayAuthManager()
    @Environment(\.presentationMode) var presentationMode
    @State private var showingSignOutAlert = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 32) {
                // Header
                VStack(spacing: 16) {
                    Image(systemName: "storefront")
                        .font(.system(size: 64, weight: .ultraLight))
                        .foregroundColor(.blue)
                    
                    VStack(spacing: 8) {
                        Text("eBay Integration")
                            .font(.system(size: 28, weight: .bold))
                        
                        Text("Connect your eBay account to create listings")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                
                // Authentication Status
                VStack(spacing: 20) {
                    // Status Card
                    HStack(spacing: 16) {
                        Circle()
                            .fill(ebayAuthManager.isAuthenticated ? .green : .orange)
                            .frame(width: 12, height: 12)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Status")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                            
                            Text(ebayAuthManager.authenticationStatus)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.primary)
                        }
                        
                        Spacer()
                        
                        if ebayAuthManager.isAuthenticating {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.systemBackground))
                            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
                    )
                    
                    // User Profile (if signed in)
                    if ebayAuthManager.isAuthenticated, let profile = ebayAuthManager.userProfile {
                        EbayUserProfileCard(profile: profile)
                    }
                    
                    // Authentication Actions
                    if ebayAuthManager.isAuthenticated {
                        VStack(spacing: 12) {
                            // Listing Capabilities
                            EbayCapabilitiesCard(capabilities: ebayAuthManager.getListingCapabilities())
                            
                            // Sign Out Button
                            Button("Sign Out of eBay") {
                                showingSignOutAlert = true
                            }
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.red.opacity(0.1))
                            )
                            .buttonStyle(ScaleButtonStyle())
                        }
                    } else {
                        // Sign In Button
                        Button(action: signInToEbay) {
                            HStack(spacing: 8) {
                                if ebayAuthManager.isAuthenticating {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                    Text("Signing In...")
                                } else {
                                    Image(systemName: "person.badge.plus")
                                    Text("Sign In with eBay")
                                }
                            }
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.blue)
                            )
                        }
                        .disabled(ebayAuthManager.isAuthenticating)
                        .buttonStyle(ScaleButtonStyle())
                        
                        // Privacy Notice
                        VStack(spacing: 8) {
                            Text("Why connect eBay?")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.primary)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                PrivacyBulletPoint(text: "Create listings directly from the app")
                                PrivacyBulletPoint(text: "Upload photos and descriptions automatically")
                                PrivacyBulletPoint(text: "Track your listings and sales")
                                PrivacyBulletPoint(text: "Secure OAuth 2.0 authentication")
                            }
                        }
                        .padding(20)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.blue.opacity(0.05))
                        )
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .navigationTitle("eBay Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .font(.system(size: 17, weight: .medium))
                }
            }
            .background(Color(.systemGroupedBackground))
        }
        .alert("Sign Out of eBay", isPresented: $showingSignOutAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Sign Out", role: .destructive) {
                ebayAuthManager.signOut()
            }
        } message: {
            Text("You'll need to sign in again to create eBay listings.")
        }
    }
    
    private func signInToEbay() {
        ebayAuthManager.signInWithEbay { success in
            if success {
                print("✅ eBay sign-in successful")
            } else {
                print("❌ eBay sign-in failed")
            }
        }
    }
}

// MARK: - eBay User Profile Card
struct EbayUserProfileCard: View {
    let profile: EbayUserProfile
    
    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                // Profile Avatar
                ZStack {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 56, height: 56)
                    
                    Text(profile.username?.prefix(1).uppercased() ?? "?")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(profile.username ?? "eBay User")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.primary)
                    
                    if let email = profile.email {
                        Text(email)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    
                    Text("Connected Account")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.green)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.green.opacity(0.1))
                        )
                }
                
                Spacer()
            }
            
            // Account Type
            HStack {
                Text("Account Type:")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                let accountType = profile.businessAccount == true ? "Business" : "Individual"
                Text(accountType)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.blue)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
    }
}

// MARK: - eBay Capabilities Card
struct EbayCapabilitiesCard: View {
    let capabilities: EbayListingCapabilities
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Listing Capabilities")
                .font(.system(size: 18, weight: .bold))
            
            VStack(spacing: 12) {
                CapabilityRow(
                    icon: "checkmark.circle.fill",
                    title: "Create Listings",
                    value: capabilities.canList ? "Enabled" : "Not Available",
                    color: capabilities.canList ? .green : .red
                )
                
                CapabilityRow(
                    icon: "photo.stack",
                    title: "Max Photos",
                    value: "\(capabilities.maxPhotos)",
                    color: .blue
                )
                
                CapabilityRow(
                    icon: "tag",
                    title: "Listing Types",
                    value: capabilities.supportedFormats.joined(separator: ", "),
                    color: .purple
                )
                
                CapabilityRow(
                    icon: "star.fill",
                    title: "Seller Level",
                    value: capabilities.sellerLevel,
                    color: .orange
                )
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
    }
}

// MARK: - Capability Row
struct CapabilityRow: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(color)
                .frame(width: 20)
            
            Text(title)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.primary)
            
            Spacer()
            
            Text(value)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(color)
        }
    }
}

// MARK: - Privacy Bullet Point
struct PrivacyBulletPoint: View {
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(Color.blue)
                .frame(width: 6, height: 6)
                .padding(.top, 6)
            
            Text(text)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.primary)
        }
    }
}

// MARK: - Preview
struct EbaySignInView_Previews: PreviewProvider {
    static var previews: some View {
        EbaySignInView()
    }
}