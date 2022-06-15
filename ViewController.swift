//
//  ViewController.swift
//  PlaneTracker
//
//  Created by NewTest on 2022-05-21.
//

import Foundation
import UIKit
import MapKit

class ViewController: UIViewController, MKMapViewDelegate {
    
    //MARK: OPENSKY AUTHENTICATION
    let USER_NAME = ""
    let PASS_WORD = ""
    
    let LONG_MIN = -74.1318463
    let LONG_MAX = -73.2047503
    let LAT_MIN  =  45.2123555
    let LAT_MAX  =  45.8443642
    let mapHeightOffset = 90.0
    
    var PLANE_API: String!
    var mapView: MKMapView!
    
    var __countryOfOrigin: UILabel!
    var __latitude: UILabel!
    var __longitude: UILabel!
    var __icao: UILabel!
    var __date: UILabel!
    
    var routes: Dictionary<String, [CLLocationCoordinate2D]>!
    var planes: Dictionary<String, MKPointAnnotation>!
    var stats:  Dictionary<String, MKPointAnnotation>!
    var dataDate: String!

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        routes = Dictionary<String, [CLLocationCoordinate2D]>()
        planes = Dictionary<String, MKPointAnnotation>()
        stats  = Dictionary<String, MKPointAnnotation>()
        
        PLANE_API = "https://\(USER_NAME):\(PASS_WORD)@opensky-network.org/api/states/all?lamin=\(LAT_MIN)&lomin=\(LONG_MIN)&lamax=\(LAT_MAX)&lomax=\(LONG_MAX)"
        view.backgroundColor = UIColor(red: 30/255, green: 36/255, blue: 44/255, alpha: 1)
        
        setProperties()
    }
    
    func RefreshPlanes() throws {
        
        //mapView.removeAnnotations(mapView.annotations)
        let url = URL(string: PLANE_API)!
        
        // Sending HTTP requests to OpenSky for plane information
        let task = URLSession.shared.dataTask(with: url) {(data, response, error) in
            guard let data = data else { return }
            let dat = String(data: data, encoding: .utf8)!
            
            let json = (try? JSONSerialization.jsonObject(with: dat.data(using: .utf8)!, options: []) as? [String:Any])
            
            let nested = json?["states"] as? [Any]
            let len = nested?.count
            let timeStamp = (nested?[0] as? [Any])?[3] as! NSNumber
            let date = Date(timeIntervalSince1970: TimeInterval(truncating: timeStamp))
            let formatter = DateFormatter()
            formatter.timeZone = TimeZone(abbreviation: "EST")
            formatter.locale = NSLocale.current
            formatter.dateFormat = "yyyy/MM/dd - HH:mm:ss"
            self.dataDate = formatter.string(from: date)
                        
            var listedKeys: [String] = []
                        
            for i in 0...(len!) - 1 {
                
                // Getting necessary information
                let icao        = (nested?[i] as? [Any])?[0]  as! String
                let spi         = (nested?[i] as? [Any])?[15] as! Bool
                let country     = (nested?[i] as? [Any])?[2]  as! String
                let callSign    = (nested?[i] as? [Any])?[1]  as! String
                let lat         = (nested?[i] as? [Any])?[6]  as! NSNumber
                let long        = (nested?[i] as? [Any])?[5]  as! NSNumber
                let isGrounded  = (nested?[i] as? [Any])?[8]  as! NSNumber
                
                // Creating key for accessing plane (static, unchanging plane information)
                let key = icao+":"+callSign+":"+country+":\(spi)"
                
                listedKeys.append(key)
                
                var altitudeStr = ""
                var altitude = 0
                if isGrounded == 0 {
                    
                    let pre_alt = (nested?[i] as? [Any])?[13]
                    
                    if pre_alt as? NSNull == nil {
                        altitude = Int(truncating: pre_alt as! NSNumber)
                    }
                    //if (Float(truncating: altitude) < 0) { altitude = 0.0 }
                    altitudeStr  = String(format: "%0.02f", Float(truncating: NSNumber(value: altitude)))
                }
                else {
                    altitudeStr = "0"
                }
                
                // Creating annotation (pin)
                let annotation = MKPointAnnotation()
                annotation.coordinate = CLLocationCoordinate2D(latitude: CLLocationDegrees(Float(truncating: lat)), longitude: CLLocationDegrees(Float(truncating: long)))
                annotation.title = altitudeStr + "ft"
                
                let la = String(format: "%.04f", Float(truncating: lat))
                let lo = String(format: "%.04f", Float(truncating: long))
                self.stats[country+":"+icao+":\(la):\(lo)"] = annotation
                
                // Setting current planes' annotation
                DispatchQueue.main.async {
                    if self.planes[key] == nil {
                        self.planes[key] = annotation
                        self.mapView.view(for: annotation)
                        self.mapView.addAnnotation(annotation)
                    }
                    else {
                        self.planes[key]?.coordinate = annotation.coordinate
                        self.planes[key]?.title = altitudeStr + "ft"
                        
                        self.mapView.view(for: self.planes[key]!)
                    }
                }
                
                // Saving coordinates to build trails (plane route)
                if self.routes[key] == nil {
                    self.routes[key] = []
                    self.routes[key]?.append(annotation.coordinate)
                }
                
                self.routes[key]?.append(annotation.coordinate)
                // Sets max amount of segments the planes trail has
                if (self.routes[key]!.count > 20) {
                    self.routes[key]!.removeFirst()
                }
            }
            
            // Drawing plane routes
            self.mapView.removeOverlays(self.mapView.overlays)
            for (_, value) in self.routes {
                            
                let polyline = MKPolyline(coordinates: value, count: value.count)
                self.mapView.addOverlay(polyline)
            }
            
            self.planes = self.removeUnwantedKeys(dict: self.planes, keys: listedKeys) as? Dictionary<String, MKPointAnnotation>
        }
        task.resume()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        mapView = MKMapView()
        mapView.delegate = self
        
        
        let mapWidth:   CGFloat = view.frame.size.width
        let mapHeight:  CGFloat = view.frame.size.height / 2
        
        mapView.frame = CGRect(x: 0, y: 0, width: mapWidth, height: mapHeight + CGFloat(mapHeightOffset))
        
        __date = UILabel()
        __date = UILabel(frame: CGRect(x: 0, y: 30, width: view.frame.size.width, height: 70))
        __date.textColor = .white
        __date.textAlignment = .center
        __date.text = "0000/00/00 - 00:00:00"
        __date.font = UIFont.boldSystemFont(ofSize: 20)
        
        mapView.mapType = MKMapType.mutedStandard
        mapView.isZoomEnabled = true
        mapView.isScrollEnabled = true
        
        let focus = CLLocationCoordinate2D(latitude: 45.5068351, longitude: -73.6152835)
        let region = MKCoordinateRegion(center: focus, span: MKCoordinateSpan(latitudeDelta: 0.2, longitudeDelta: 0.2))
        mapView.setRegion(region, animated: true)
        view.addSubview(mapView)
        
        mapView.addSubview(__date)
        mapView.bringSubviewToFront(__date)
        
        let thread = Thread(target: self, selector: #selector(Update), object: nil)
        thread.start()
    }
    
    @objc func Update() {
        
        while true {
            do {
                try RefreshPlanes()
            }
            catch { }
            sleep(10)
        }
    }
}


extension ViewController {
    
    func removeUnwantedKeys(dict: Dictionary<String, Any>, keys: [String]) -> Dictionary<String, Any> {
        
        var res: Dictionary<String, Any>
        res = dict
            
        for (key, _) in dict {
            
            var found = false
            for __key in keys {
                if __key == key { found = true }
            }
            
            if !found {
                if res is Dictionary<String, MKPointAnnotation> {
                    let p = res[key] as! MKPointAnnotation
                    mapView.removeAnnotation(p)
                }
                res.removeValue(forKey: key)
            }
        }
        
        return res
    }
    
    func setProperties() {
        
        let p_h = (view.frame.size.height / CGFloat(2.0)) - CGFloat(mapHeightOffset)
        let off = 20.0
        let h_off = off/2.0
        let height = p_h / 4.0 - CGFloat(off)
        let y = view.frame.size.height / 2
        let width = view.frame.size.width - 20
        let x = (view.frame.size.width - width) / 2
        
        __countryOfOrigin = UILabel(frame: CGRect(x: x, y: y + CGFloat(mapHeightOffset) + CGFloat(h_off), width: width, height: height))
        __countryOfOrigin.text = "\tCountry of Origin: N/A"
        __countryOfOrigin.textColor = .white
        __countryOfOrigin.backgroundColor = UIColor(red: 15/255, green: 18/255, blue: 22/255, alpha: 0.2)
        __countryOfOrigin.font = UIFont.boldSystemFont(ofSize: 20)
        __countryOfOrigin.numberOfLines = 2
        
        __icao = UILabel(frame: CGRect(x: x, y: y+height + CGFloat(mapHeightOffset) + CGFloat(h_off*2), width: width, height: height))
        __icao.text = "\tICAO: N/A"
        __icao.textColor = .white
        __icao.backgroundColor = UIColor(red: 15/255, green: 18/255, blue: 22/255, alpha: 0.2)
        __icao.font = UIFont.boldSystemFont(ofSize: 20)
        
        __latitude = UILabel(frame: CGRect(x: x, y: y+height*2 + CGFloat(mapHeightOffset) + CGFloat(h_off*3), width: width, height: height))
        __latitude.text = "\tLatitude: N/A"
        __latitude.textColor = .white
        __latitude.backgroundColor = UIColor(red: 15/255, green: 18/255, blue: 22/255, alpha: 0.2)
        __latitude.font = UIFont.boldSystemFont(ofSize: 20)
        
        __longitude = UILabel(frame: CGRect(x: x, y: y+height*3 + CGFloat(mapHeightOffset) + CGFloat(h_off*4), width: width, height: height))
        __longitude.text = "\tLongitude: N/A"
        __longitude.textColor = .white
        __longitude.backgroundColor = UIColor(red: 15/255, green: 18/255, blue: 22/255, alpha: 0.2)
        __longitude.font = UIFont.boldSystemFont(ofSize: 20)
        view.addSubview(__countryOfOrigin)
        view.addSubview(__icao)
        view.addSubview(__latitude)
        view.addSubview(__longitude)
    }
    
    
    // MARK: MAPVIEW DELEGATE FUNCTIONS
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
                
        var view = mapView.dequeueReusableAnnotationView(withIdentifier: "reuseIdentifier") as? MKMarkerAnnotationView
        
        if view == nil {
            view = MKMarkerAnnotationView(annotation: nil, reuseIdentifier: "reuseIdentifier")
        }
        
        view?.annotation = annotation
        view?.displayPriority = .required
        view?.animatesWhenAdded = true
        mapView.view(for: view?.annotation as! MKPointAnnotation)
        return view
    }
    
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        
        if (overlay is MKPolyline) {
            let pr = MKPolylineRenderer(overlay: overlay)
            pr.strokeColor = .red
            pr.lineWidth = 1
            
            return pr
        }
        
        return MKOverlayRenderer()
    }
    
    func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
        
        let region = MKCoordinateRegion(center: view.annotation!.coordinate, span: mapView.region.span)
        __date.text = dataDate! + " EDT"
        
        if (view.annotation is MKPointAnnotation) {
            
            mapView.deselectAnnotation(view.annotation, animated: false)
            
            let p: MKPointAnnotation = MKPointAnnotation()
            p.coordinate = view.annotation!.coordinate
            
            for (key, value) in stats {
                
                if value.coordinate.latitude == p.coordinate.latitude && value.coordinate.longitude == p.coordinate.longitude {
                    
                    __countryOfOrigin.text  = "\tCountry of Origin: " + key.split(separator: ":")[0]
                    __icao.text             = "\tICAO: " + key.split(separator: ":")[1]
                    __latitude.text         = "\tLatitude: " + key.split(separator: ":")[2]
                    __longitude.text        = "\tLongitude: " + key.split(separator: ":")[3]
                }
            }
        }
        
        mapView.setRegion(region, animated: true)
    }
    
}
