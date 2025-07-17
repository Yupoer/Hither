//
//  RouteMapView.swift
//  Hither
//
//  Created by Dillion on 2025/7/17.
//

import SwiftUI
import MapKit
import CoreLocation

struct RouteMapView: UIViewRepresentable {
    @Binding var region: MKCoordinateRegion
    let mapType: MKMapType
    let annotations: [MapViewAnnotationItem]
    let currentRoute: MKRoute?
    let userLocation: CLLocation?
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        mapView.userTrackingMode = .none
        mapView.mapType = mapType
        
        return mapView
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {
        // Update map type
        mapView.mapType = mapType
        
        // Update region
        if !mapView.region.center.isEqual(to: region.center, tolerance: 0.0001) {
            mapView.setRegion(region, animated: true)
        }
        
        // Update annotations
        let existingAnnotations = mapView.annotations.compactMap { $0 as? RouteMapAnnotation }
        let newAnnotationIds = Set(annotations.map { $0.id })
        let existingAnnotationIds = Set(existingAnnotations.map { $0.id })
        
        // Remove annotations that are no longer needed
        let annotationsToRemove = existingAnnotations.filter { !newAnnotationIds.contains($0.id) }
        mapView.removeAnnotations(annotationsToRemove)
        
        // Add new annotations
        let annotationsToAdd = annotations.filter { !existingAnnotationIds.contains($0.id) }
        let mapAnnotations = annotationsToAdd.map { RouteMapAnnotation(from: $0) }
        mapView.addAnnotations(mapAnnotations)
        
        // Update route overlay
        context.coordinator.updateRoute(mapView: mapView, route: currentRoute)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: RouteMapView
        private var currentRouteOverlay: MKPolyline?
        
        init(_ parent: RouteMapView) {
            self.parent = parent
        }
        
        func updateRoute(mapView: MKMapView, route: MKRoute?) {
            // Remove existing route overlay
            if let existingOverlay = currentRouteOverlay {
                mapView.removeOverlay(existingOverlay)
                currentRouteOverlay = nil
            }
            
            // Add new route overlay
            if let route = route {
                let polyline = route.polyline
                mapView.addOverlay(polyline)
                currentRouteOverlay = polyline
            }
        }
        
        // MARK: - MKMapViewDelegate
        
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard let mapAnnotation = annotation as? RouteMapAnnotation else {
                return nil
            }
            
            let identifier = mapAnnotation.isMember ? "MemberAnnotation" : "WaypointAnnotation"
            
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
            if annotationView == nil {
                annotationView = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                annotationView?.canShowCallout = true
            } else {
                annotationView?.annotation = annotation
            }
            
            // Create custom view based on annotation type
            if mapAnnotation.isMember {
                if let member = mapAnnotation.member {
                    let memberView = MemberAnnotationView(member: member)
                    let hostingController = UIHostingController(rootView: memberView)
                    hostingController.view.backgroundColor = UIColor.clear
                    annotationView?.addSubview(hostingController.view)
                    
                    // Set frame
                    hostingController.view.frame = CGRect(x: -20, y: -30, width: 40, height: 60)
                }
            } else {
                if let waypoint = mapAnnotation.waypoint {
                    let waypointView = WaypointAnnotationView(waypoint: waypoint)
                    let hostingController = UIHostingController(rootView: waypointView)
                    hostingController.view.backgroundColor = UIColor.clear
                    annotationView?.addSubview(hostingController.view)
                    
                    // Set frame
                    hostingController.view.frame = CGRect(x: -25, y: -35, width: 50, height: 70)
                }
            }
            
            return annotationView
        }
        
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = UIColor.systemBlue
                renderer.lineWidth = 4.0
                renderer.lineCap = .round
                renderer.lineJoin = .round
                return renderer
            }
            return MKOverlayRenderer()
        }
    }
}

class RouteMapAnnotation: NSObject, MKAnnotation {
    let id: UUID
    let coordinate: CLLocationCoordinate2D
    let member: GroupMember?
    let waypoint: Waypoint?
    let isMember: Bool
    
    var title: String? {
        if isMember {
            return member?.displayName
        } else {
            return waypoint?.name
        }
    }
    
    init(from item: MapViewAnnotationItem) {
        self.id = item.id
        self.coordinate = item.coordinate
        self.member = item.member
        self.waypoint = item.waypoint
        self.isMember = item.isMember
        super.init()
    }
}

extension CLLocationCoordinate2D {
    func isEqual(to other: CLLocationCoordinate2D, tolerance: Double) -> Bool {
        return abs(self.latitude - other.latitude) < tolerance &&
               abs(self.longitude - other.longitude) < tolerance
    }
}