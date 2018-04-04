//
//  MapViewController.swift
//  TurnByTurnMap
//
//  Created by WanliMa on 2018/4/4.
//  Copyright © 2018年 WanliMa. All rights reserved.
//

import UIKit
import MapKit
import CoreLocation
import AVFoundation

class MapViewController: UIViewController, CLLocationManagerDelegate, MKMapViewDelegate, UISearchBarDelegate {

    // MARK: - outlets
    @IBOutlet weak var searchBar: UISearchBar!
    @IBOutlet weak var directionLInfo: UILabel!
    @IBOutlet weak var mapView: MKMapView!
    
    // Instance
    let locationManager = CLLocationManager()
    var currentCoordinate: CLLocationCoordinate2D!
    var steps = [MKRouteStep]()
    var currentPolyline: MKPolyline!
    let speak = AVSpeechSynthesizer()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // setup locationManager
        locationManager.delegate = self
        locationManager.requestAlwaysAuthorization()
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        locationManager.startUpdatingLocation()
        
        // setup mapView
        mapView.delegate = self
        mapView.userTrackingMode = .followWithHeading   //The map follows the user location and rotates when the heading changes.
        
        // setup Seach Bar
        searchBar.delegate = self
        
    }

    // MARK: protocol funtions
    /**********************Core Location**************************/
    // Core Location, 地点更新后触发
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let currentLocation = locations.last else {
            print("Location Not Found")
            return
        }
        currentCoordinate = currentLocation.coordinate
    }
    
    // Core Location, 进入geofence后触发
    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        print("Entered in region list: \(region.identifier)")
        updateDerectionInstruction(stepCount: Int(region.identifier)!)
    }
    /**********************Core Location**************************/

    
    /**********************路线**************************/
    // MapView, 显示路线
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        if overlay is MKPolyline {
            let render = MKPolylineRenderer(overlay: overlay)
            render.strokeColor = UIColor.blue
            render.lineWidth = 5
            return render
        }
        else if overlay is MKCircle {
            let render = MKCircleRenderer(circle: overlay as! MKCircle)
            render.strokeColor = UIColor.brown
            render.alpha = 0.3
            return render
        }
        return MKOverlayRenderer()
    }
    
    // 计算路线
    func getDirection(to destinationMapItem: MKMapItem) {  // ** external argument + internal argument
//        print(destinationMapItem)
//        print(destinationMapItem.placemark)
        let sourcePlacemark = MKPlacemark(coordinate: currentCoordinate)
        let sourceMapItem = MKMapItem(placemark: sourcePlacemark)
        
        // setup direction request
        let directionRequest = MKDirectionsRequest()
        directionRequest.source = sourceMapItem
        directionRequest.destination = destinationMapItem
        directionRequest.transportType = .automobile
        
        // make direction calculation
        let direction = MKDirections(request: directionRequest)
        direction.calculate(completionHandler: { (res, err) in
            if err != nil {
                print("Direction error: \(err!)")
            }
            else {
                if let response = res {
                    let routes = response.routes    // A list of routes
                    let optimalRoute = routes.first!
                    
                    if self.currentPolyline != nil {
                        self.mapView.removeOverlays([self.currentPolyline])
                    }
                    
                    self.currentPolyline = optimalRoute.polyline
                    self.mapView.addOverlays([optimalRoute.polyline], level: .aboveRoads)
                    
                    self.steps = optimalRoute.steps

                    self.generateTurnByTurnInstruction(self.steps)

                    self.updateDerectionInstruction(stepCount: 0)
                }
            }
        })
    }
    
    // turn by turn 处理
    func generateTurnByTurnInstruction(_ steps: [MKRouteStep]) {
        
        // clear all other monitored regions
        self.locationManager.monitoredRegions.forEach {
            self.locationManager.stopMonitoring(for: $0)
        }
        
        for (i, step) in steps.enumerated() {
            print("\(step.instructions, step.distance), \(step.polyline.coordinate)")
            let region = CLCircularRegion(center: step.polyline.coordinate, radius: 20, identifier: "\(i)") // A circular geofence! [Core Location]
            
            self.locationManager.startMonitoring(for: region)   // monitor 这个范围
            let circle = MKCircle(center: region.center, radius: region.radius) //A circular overlay with a configurable radius and centered on a specific geographic coordinate.   [MKMap]
            mapView.add(circle)
        }
    }
    
    // udpate 声音，语音
    func updateDerectionInstruction(stepCount: Int) {
        var info = "Calculating"
        if(stepCount == steps.count - 1) {
            info = "\(steps[stepCount].instructions)"
        }
        else {
            info = "\(steps[stepCount].instructions) and move \(steps[stepCount + 1].distance) meters"
        }
        directionLInfo.text = info
        speak.speak(AVSpeechUtterance(string: info))
    }
    /**********************路线**************************/
    
    
    /**********************搜索**************************/
    // Search Bar, 点搜索后触发
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        // Disable search after searchPressed
        searchBar.endEditing(true)
        directionLInfo.text = ""
        
        // setup search request
        let localSearcRequest = MKLocalSearchRequest()
        localSearcRequest.naturalLanguageQuery = searchBar.text
        let region = MKCoordinateRegion(center: currentCoordinate, span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)) //中心 + “半径”
        localSearcRequest.region = region
        
        // make search request
        let localSearch = MKLocalSearch(request: localSearcRequest)
        localSearch.start(completionHandler: { (res, err) in
            if err != nil {
                print("Search response error: \(err!)")
            }
            else {
                let searchResults = res?.mapItems   //A list of search results
//                print(searchResults)
                self.displayAnnotation(mapItems: searchResults!)
            }
        })
    }
    /**********************搜索**************************/
    
    
    /**********************大头针**************************/
    // 显示 大头针
    func displayAnnotation(mapItems: [MKMapItem]) {
        for mapItem in mapItems {
            // setup destination 大头针
            let annotation = MKPointAnnotation()
            
            annotation.title = mapItem.name
            annotation.subtitle = mapItem.placemark.title
            annotation.coordinate = mapItem.placemark.coordinate
            
            // Add 大头针 to mapview
            mapView.addAnnotation(annotation)
        }
    }
    
    // 大头针气泡
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        if annotation is MKUserLocation {   //User location 大头针
            return nil
        }
        
        let identifier = "SearchResult"
        //如果有，取出可以循环利用的大头针view.
        var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
        
        if annotationView == nil {
            let annotationPinView =  MKPinAnnotationView(annotation: annotation, reuseIdentifier: identifier)
            annotationPinView.animatesDrop = true
            //显示子标题和标题bubble
            annotationPinView.canShowCallout = true
            //bubble右边的控件
            annotationPinView.rightCalloutAccessoryView = UIButton(type: .detailDisclosure)
            annotationView = annotationPinView
        }
        
        annotationView!.annotation = annotation
        
        return annotationView
    }
    
    // 点击大头针气泡后触发
    func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView, calloutAccessoryControlTapped control: UIControl) {
        let annotation = view.annotation as! MKPointAnnotation
        getDirection(to: MKMapItem(placemark: MKPlacemark(coordinate: annotation.coordinate)))
    }
    /**********************大头针**************************/


}
