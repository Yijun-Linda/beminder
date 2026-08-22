//
//  LocationManager.swift
//  Beminder
//
//  负责获取启动位置 P0。v0.1 只记录 P0 不参与判断（rfc ADR-006）。
//

import Foundation
import CoreLocation

final class LocationManager: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var shouldAutoLocate = false

    override init() {
        super.init()
        manager.delegate = self
        // v0.1 不需要高精度，百米量级足够，省电
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    /// 请求一次当前位置，成功后广播 .locationDidUpdate。
    func requestCurrentLocation() {
        switch manager.authorizationStatus {
        case .notDetermined:
            shouldAutoLocate = true
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        default:
            // 权限被拒时静默返回，P0 为空不影响 v0.1 守护流程
            break
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            if shouldAutoLocate {
                shouldAutoLocate = false
                manager.requestLocation()
            }
        default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        NotificationCenter.default.post(name: .locationDidUpdate, object: loc)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // 拿不到定位不影响守护流程，P0 留空
    }
}