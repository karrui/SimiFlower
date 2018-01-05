//
//  ViewController.swift
//  SimiFlower
//
//  Created by Karrui Lau on 5/1/18.
//  Copyright © 2018 Karrui Lau. All rights reserved.
//

import UIKit
import CoreML
import Vision
import Alamofire
import SwiftyJSON
import SDWebImage

class ViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {

    
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var cameraButton: UIBarButtonItem!
    @IBOutlet weak var extractLabel: UILabel!
    @IBOutlet weak var userPickedImageView: UIImageView!
    @IBOutlet weak var confidenceLabel: UILabel!
    
    var pickedImage: UIImage?
    
    let imagePicker = UIImagePickerController()
    
    @IBAction func cameraButtonPressed(_ sender: Any) {
        present(imagePicker, animated: true, completion: nil)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        imagePicker.delegate = self
        imagePicker.allowsEditing = true
        imagePicker.sourceType = .camera
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        if let userPickedImage = info[UIImagePickerControllerEditedImage] as? UIImage {
            userPickedImageView.image = userPickedImage
            guard let ciImage = CIImage(image: userPickedImage) else {
                fatalError("Could not convert UIImage to CIImage")
            }
            pickedImage = userPickedImage
            
            detect(flowerImage: ciImage)
        }
        
        imagePicker.dismiss(animated: true, completion: nil)
    }
    
    func detect(flowerImage: CIImage) {
        guard let model = try? VNCoreMLModel(for: FlowerClassifier().model) else {
            fatalError("Failed to initialize model")
        }
        
        let request = VNCoreMLRequest(model: model) { (request, error) in
            guard let results = request.results as? [VNClassificationObservation] else {
                fatalError("Failed to obtain results")
            }
            
            if let firstResult = results.first {
                let identifier = firstResult.identifier
                self.navigationItem.title = identifier.capitalized
                self.confidenceLabel.text = "\(Int(firstResult.confidence * 100))% confident"
                self.getWikiData(flowerName: identifier)
            }
            
        }
        
        let handler = VNImageRequestHandler(ciImage: flowerImage)
        
        do {
            try handler.perform([request])
        } catch {
            print(error)
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    
    //MARK: - Alamofire networking methods
    func getWikiData(flowerName: String) {
        let wikiURL = "https://en.wikipedia.org/w/api.php"
        let params : [String: String] = [
            "format": "json",
            "action": "query",
            "prop": "extracts|pageimages",
            "exintro": "",
            "explaintext": "",
            "titles": flowerName,
            "indexpageids": "",
            "redirects": "1",
            "pithumbsize": "500"
            ]
        
        Alamofire.request(wikiURL, method: .get, parameters: params).responseJSON { response in
            if response.result.isSuccess {
                self.updateFlowerData(flowerJSON: JSON(response.result.value!))
            } else {
                self.extractLabel.text = "Unable to get data!"
            }
        }
    }
    
    //MARK: - SwiftyJSON JSON parsing methods
    func updateFlowerData(flowerJSON: JSON) {
        if let wikiPageID = flowerJSON["query"]["pageids"][0].string {
            if let flowerExtract = flowerJSON["query"]["pages"][wikiPageID]["extract"].string {
                extractLabel.text = flowerExtract
            }
            if let flowerImageURL = flowerJSON["query"]["pages"][wikiPageID]["thumbnail"]["source"].string {
                self.imageView.sd_setImage(with: URL(string: flowerImageURL))
                self.view.bringSubview(toFront: userPickedImageView)
                self.view.bringSubview(toFront: confidenceLabel)
            } else {
                self.imageView.image = #imageLiteral(resourceName: "not-found")
            }
        }
    }

}

