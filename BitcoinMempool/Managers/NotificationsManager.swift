//
//  NotificationsManager.swift
//  BitcoinMempool
//
//  Created by Dor Sam on 09/03/2025.
//
import Foundation
import UserNotifications
import SwiftUI

class NotificationsManager {
    static let shared = NotificationsManager()
    
    // Check if notifications are enabled in settings
    var areNotificationsEnabled: Bool {
        return UserDefaults.standard.bool(forKey: "enablePushNotifications")
    }
    
    // Request notification permissions
    func requestPermissions() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if granted {
                print("Notification permissions granted")
            } else if let error = error {
                print("Error requesting notification permissions: \(error)")
            }
        }
    }
    
    // Check current notification settings
    func checkNotificationStatus(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            let isAuthorized = settings.authorizationStatus == .authorized
            DispatchQueue.main.async {
                completion(isAuthorized)
            }
        }
    }
    
    // Send a local notification
    func sendNotification(title: String, body: String, timeInterval: TimeInterval = 1) {
        // First check if notifications are enabled in app settings
        guard areNotificationsEnabled else {
            print("Notifications disabled in app settings")
            return
        }
        
        // Then check if we have system permission
        checkNotificationStatus { isAuthorized in
            guard isAuthorized else {
                print("Notifications not authorized by system")
                return
            }
            
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = UNNotificationSound.default
            
            // Create a time-based trigger
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: timeInterval, repeats: false)
            
            // Create a request
            let request = UNNotificationRequest(
                identifier: UUID().uuidString,
                content: content,
                trigger: trigger
            )
            
            // Add the request to the notification center
            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("Error scheduling notification: \(error)")
                } else {
                    print("Notification scheduled successfully")
                }
            }
        }
    }
    
    // Send a notification for new blocks
    func notifyNewBlock(height: Int) {
        sendNotification(
            title: "New Bitcoin Block",
            body: "Block #\(height) has been mined and added to the blockchain."
        )
    }
    
    // Send a notification for mempool congestion
    func notifyMempoolCongestion(txCount: Int, avgFeeRate: Double) {
        sendNotification(
            title: "Mempool Congestion Alert",
            body: "The mempool has \(txCount) transactions with average fee of \(String(format: "%.1f", avgFeeRate)) sat/vB."
        )
    }
    
    // Send a notification for fee rate changes
    func notifyFeeRateChange(newRate: Double, changePercentage: Double) {
        let direction = changePercentage >= 0 ? "increased" : "decreased"
        let absPercentage = abs(changePercentage)
        
        sendNotification(
            title: "Bitcoin Fee Rate Update",
            body: "Transaction fees have \(direction) by \(String(format: "%.1f", absPercentage))%. Current fastest rate: \(String(format: "%.1f", newRate)) sat/vB."
        )
    }
}
