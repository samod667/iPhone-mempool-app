//
//  NotificationsManager.swift
//  BitcoinMempool
//
//  Created by Dor Sam on 09/03/2025.
//
import Foundation
import UserNotifications
import SwiftUI

/// Manages local notifications for Bitcoin blockchain events
class NotificationsManager {
    static let shared = NotificationsManager()
    private init() {}
    
    /// Check if notifications are enabled in app settings
    var areNotificationsEnabled: Bool {
        return UserDefaults.standard.bool(forKey: "enablePushNotifications")
    }
    
    /// Request system notification permissions
    func requestPermissions() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if let error = error {
                print("Error requesting notification permissions: \(error)")
            }
        }
    }
    
    /// Check current notification authorization status
    /// - Parameter completion: Callback with boolean indicating if notifications are authorized
    func checkNotificationStatus(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            let isAuthorized = settings.authorizationStatus == .authorized
            DispatchQueue.main.async {
                completion(isAuthorized)
            }
        }
    }
    
    /// Send a local notification
    /// - Parameters:
    ///   - title: Notification title
    ///   - body: Notification body text
    ///   - timeInterval: Delay before showing notification (default: 1 second)
    func sendNotification(title: String, body: String, timeInterval: TimeInterval = 1) {
        guard areNotificationsEnabled else { return }
        
        checkNotificationStatus { isAuthorized in
            guard isAuthorized else { return }
            
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = UNNotificationSound.default
            
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: timeInterval, repeats: false)
            let request = UNNotificationRequest(
                identifier: UUID().uuidString,
                content: content,
                trigger: trigger
            )
            
            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("Error scheduling notification: \(error)")
                }
            }
        }
    }
    
    /// Notify user about a new block being mined
    /// - Parameter height: Block height
    func notifyNewBlock(height: Int) {
        sendNotification(
            title: "New Bitcoin Block",
            body: "Block #\(height) has been mined and added to the blockchain."
        )
    }
    
    /// Notify user about mempool congestion
    /// - Parameters:
    ///   - txCount: Number of transactions in mempool
    ///   - avgFeeRate: Average fee rate in sat/vB
    func notifyMempoolCongestion(txCount: Int, avgFeeRate: Double) {
        sendNotification(
            title: "Mempool Congestion Alert",
            body: "The mempool has \(txCount) transactions with average fee of \(String(format: "%.1f", avgFeeRate)) sat/vB."
        )
    }
    
    /// Notify user about fee rate changes
    /// - Parameters:
    ///   - newRate: Current fee rate in sat/vB
    ///   - changePercentage: Percentage change from previous rate
    func notifyFeeRateChange(newRate: Double, changePercentage: Double) {
        let direction = changePercentage >= 0 ? "increased" : "decreased"
        let absPercentage = abs(changePercentage)
        
        sendNotification(
            title: "Bitcoin Fee Rate Update",
            body: "Transaction fees have \(direction) by \(String(format: "%.1f", absPercentage))%. Current fastest rate: \(String(format: "%.1f", newRate)) sat/vB."
        )
    }
}
