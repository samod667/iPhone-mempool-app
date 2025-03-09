//
//  ColorExtension.swift
//  BitcoinMempool
//
//  Created by Dor Sam on 04/03/2025.
//

import Foundation
import SwiftUI

extension Color {
    // Main theme colors
    static let mempoolBackground = Color(red: 17/255, green: 30/255, blue: 37/255 ) // Dark blue background
    static let mempoolPrimary = Color(red: 60/255, green: 141/255, blue: 188/255) // Blue accent color
    static let mempoolSecondary = Color(red: 112/255, green: 204/255, blue: 189/255) // Teal accent color
    
    // Fee level colors
    static let lowFee = Color(red: 76/255, green: 175/255, blue: 80/255) // Green for low fees
    static let mediumFee = Color(red: 255/255, green: 152/255, blue: 0/255) // Orange for medium fees
    static let highFee = Color(red: 244/255, green: 67/255, blue: 54/255) // Red for high fees
    
    // Chart colors
    static let chartLine = Color(red: 112/255, green: 204/255, blue: 189/255) // Teal for chart lines
    static let chartAccent = Color(red: 255/255, green: 193/255, blue: 7/255) // Yellow accent for charts
}

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}
