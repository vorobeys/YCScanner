//
//  ViewController.swift
//  MyApp
//
//  Created by Ilya Vorobyev on 19.07.2018.
//  Copyright © 2018 Ilya Vorobyev. All rights reserved.
//

import UIKit
import AVFoundation
import Alamofire
import SwiftyJSON
import AudioToolbox


class ViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    @IBOutlet weak var popupView: UIView!
    @IBOutlet weak var infoLabel: UILabel!
    @IBOutlet weak var popupButton: UIButton!
    @IBOutlet weak var popupLabel: UILabel!
    @IBOutlet weak var countLabel: UILabel!
    @IBOutlet weak var countImage: UIImageView!

    var captureSession : AVCaptureSession?
    var videoPreviewLayer: AVCaptureVideoPreviewLayer?
    var qrCodeFrameView: UIView?
    var qrReadyScan: Bool = true
    var player: AVAudioPlayer?
    @IBOutlet weak var imageSmile: UIImageView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        popupButton.layer.cornerRadius = 10
        popupButton.clipsToBounds = true
        
        popupView.layer.cornerRadius = 10
        popupView.clipsToBounds = true
        
        let captureDevice = AVCaptureDevice.default(for: AVMediaType.video)
        
        do {
            let input = try AVCaptureDeviceInput(device: captureDevice!)
            
            captureSession = AVCaptureSession()
            captureSession?.addInput(input)
            
            let captureMetadataOutput = AVCaptureMetadataOutput()
            captureSession?.addOutput(captureMetadataOutput)
            
            captureMetadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            captureMetadataOutput.metadataObjectTypes = [AVMetadataObject.ObjectType.qr]
            
            videoPreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession!)
            videoPreviewLayer?.videoGravity = AVLayerVideoGravity.resizeAspectFill
            videoPreviewLayer?.frame = view.layer.bounds
            view.layer.addSublayer(videoPreviewLayer!)
            
            captureSession?.startRunning()
            
            view.bringSubview(toFront: infoLabel)
            view.bringSubview(toFront: countLabel)
            view.bringSubview(toFront: countImage)
            
            qrCodeFrameView = UIView()
            if let qrCodeFrameView = qrCodeFrameView {
                qrCodeFrameView.layer.borderColor = UIColor.red.cgColor
                qrCodeFrameView.layer.borderWidth = 3
                
                view.addSubview(qrCodeFrameView)
                view.bringSubview(toFront: qrCodeFrameView)
            }
            
        } catch {
            print(error)
            return
        }
        
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func playFileNamed(fileName: String, withExtenstion fileExtension: String) {
            var sound: SystemSoundID = 0
        if let soundURL = Bundle.main.url(forResource: fileName, withExtension: fileExtension) {
            AudioServicesCreateSystemSoundID(soundURL as CFURL, &sound)
                AudioServicesPlaySystemSound(sound)
            }
        }
    
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        if self.qrReadyScan == true {
            self.qrReadyScan = false
            if metadataObjects.count == 0 {
                qrCodeFrameView?.frame = CGRect.zero
                infoLabel.text = "QR код не обнаружен"
                self.qrReadyScan = true
                
                return
            }
            
            let metadataObj = metadataObjects[0] as! AVMetadataMachineReadableCodeObject
            
            let barCodeObject = videoPreviewLayer?.transformedMetadataObject(for: metadataObj)
            
            qrCodeFrameView?.frame = barCodeObject!.bounds
            
            if metadataObj.stringValue != nil {
                playFileNamed(fileName: "sound", withExtenstion: "mp3")
                let typeTicket: String
                var getQrMessage : String = metadataObj.stringValue!
                let numberIndex = getQrMessage.index(of: ";")?.encodedOffset
                if numberIndex != nil {
                    let MessageArray = getQrMessage.components(separatedBy: ";")
                    typeTicket = "Offline"
                    getQrMessage = MessageArray[4]
                }else{
                    typeTicket = "Rambler"
                }
                let parameters : Parameters = ["NumberOrder" : getQrMessage, "Type" : typeTicket]
                Alamofire.request("URL", parameters: parameters).responseJSON { response in
                    switch response.result {
                    case .success(let value):
                        var getMessage : String
                        var price: String
                        let json = JSON(value)
                        if !json.isEmpty {
                            let nameEvent = "Мероприятие: " + json["NameEvent"].stringValue
                            let typeTicketJSON = "Тип билета: " + json["TypeTicket"].stringValue
                            price = "Цена: " + json["Price"].stringValue
                            let numberMarks = "Количество отметок: " + json["NumberMarks"].stringValue
                            self.countLabel.text = "\(json["CountIncomer"])/\(json["CountAll"])"
                            getMessage = nameEvent + "\n" + typeTicketJSON + "\n" + price + "\n" + numberMarks
                            self.imageSmile.image = UIImage(named: "good")
                            self.popupView.backgroundColor = UIColor(red:0.20, green:0.80, blue:0.20, alpha:1.0)
                            self.popupLabel.backgroundColor = self.popupView.backgroundColor
                        } else {
                            self.imageSmile.image = UIImage(named: "bad")
                            getMessage = "Билет не найден"
                            self.popupView.backgroundColor = UIColor(red:1.00, green:0.00, blue:0.30, alpha:1.0)
                            self.popupLabel.backgroundColor = self.popupView.backgroundColor
                        }
                        self.popupLabel.text = getMessage
                        self.popupView.isHidden = false
                        self.view.addSubview(self.popupView)
                        self.view.bringSubview(toFront: self.popupView)
                    case .failure(let error):
                        self.imageSmile.image = UIImage(named: "bad")
                        self.popupLabel.text = "Ошибка ответа от сервера"
                        self.popupView.backgroundColor = UIColor(red:1.00, green:0.00, blue:0.30, alpha:1.0)
                        self.popupLabel.backgroundColor = self.popupView.backgroundColor
                        self.popupView.isHidden = false
                        self.view.addSubview(self.popupView)
                        self.view.bringSubview(toFront: self.popupView)
                        print(error)
                    }
                }
            }
        } else {
            qrCodeFrameView?.frame = CGRect.zero
            return
        }
    }
    
    @IBAction func closePopup(_ sender: Any) {
        self.qrReadyScan = true
        self.popupView.isHidden = true
        self.captureSession?.startRunning()
        
    }
    
}

