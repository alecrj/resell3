//
//  EbaySignInView.swift
//  ResellAI
//
//  Fixed eBay Sign In View without redeclaration
//

import SwiftUI
import AuthenticationServices

struct EbaySignInView: View {
    @EnvironmentObject var ebayAuth: EbayAuthManager
    @State private var isSigningIn = false
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 32) {
                headerSection
                
                if ebayAuth.isAuthenticated {
                    authenticatedSection
                } else {
                    signInSection
                }
                
                Spacer()
            }
            .padding(.horizontal, 24)
            .navigationTitle("eBay Account")
            .alert("Sign In Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "storefront.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.blue)
            
            Text("Connect to eBay")
                .font(.title)
                .fontWeight(.bold)
            
            Text("Connect your eBay account to automatically list items")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    private var signInSection: some View {
        VStack(spacing: 20) {
            Button(action: signInWithEbay) {
                HStack {
                    if isSigningIn {
                        ProgressView()
                            .scaleEffect(0.8)
                            .tint(.white)
                    } else {
                        Image(systemName: "person.crop.circle.badge.plus")
                            .font(.system(size: 20))
                    }
                    
                    Text(isSigningIn ? "Connecting..." : "Sign In with eBay")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.blue)
                )
            }
            .disabled(isSigningIn)
            .buttonStyle(ScaleButtonStyle())
            
            VStack(spacing: 12) {
                Text("What you can do:")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                VStack(alignment: .leading, spacing: 8) {
                    FeatureRow(icon: "camera.fill", text: "Automatically list items")
                    FeatureRow(icon: "chart.line.uptrend.xyaxis", text: "Track sales and profits")
                    FeatureRow(icon: "dollarsign.circle.fill", text: "Get real-time pricing")
                    FeatureRow(icon: "clock.fill", text: "Save hours of manual work")
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemGray6))
            )
        }
    }
    
    private var authenticatedSection: some View {
        VStack(spacing: 20) {
            VStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.green)
                
                Text("Connected Successfully!")
                    .font(.title2)
                    .fontWeight(.bold)
                
                if let username = ebayAuth.userProfile?.username {
                    Text("Signed in as: \(username)")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
            }
            
            VStack(spacing: 12) {
                StatusRow(label: "Account Status", value: "Connected", color: .green)
                StatusRow(label: "Listing Permissions", value: "Enabled", color: .green)
                
                if let tokenExpiry = ebayAuth.tokenExpiry {
                    let formatter = DateFormatter()
                    formatter.dateStyle = .medium
                    StatusRow(label: "Token Expires", value: formatter.string(from: tokenExpiry), color: .orange)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemGray6))
            )
            
            Button(action: signOut) {
                Text("Sign Out")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.red, lineWidth: 2)
                    )
            }
            .buttonStyle(ScaleButtonStyle())
        }
    }
    
    private func signInWithEbay() {
        isSigningIn = true
        
        ebayAuth.signInWithEbay { success in
            DispatchQueue.main.async {
                self.isSigningIn = false
                
                if !success {
                    self.errorMessage = self.ebayAuth.authError ?? "Failed to sign in with eBay"
                    self.showingError = true
                }
            }
        }
    }
    
    private func signOut() {
        ebayAuth.signOut()
    }
}

// MARK: - Supporting Views
struct FeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.blue)
                .frame(width: 20)
            
            Text(text)
                .font(.body)
                .foregroundColor(.primary)
            
            Spacer()
        }
    }
}

struct StatusRow: View {
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack {
            Text(label)
                .font(.body)
                .fontWeight(.medium)
            
            Spacer()
            
            Text(value)
                .font(.body)
                .fontWeight(.semibold)
                .foregroundColor(color)
        }
    }
}

// MARK: - String Extension for URL Encoding
extension String {
    func urlEncoded() -> String {
        return self.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? self
    }
}

#Preview {
    EbaySignInView()
        .environmentObject(EbayAuthManager.shared)
}
