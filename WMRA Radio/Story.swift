//
//  Story.swift
//  WMRA Radio
//
//  Created by Linzy Cumbia on 12/21/14.
//  Copyright (c) 2014 James Madison University. All rights reserved.
//

import Foundation
import UIKit

class Story : NSObject {
    var title:String = ""
    var date:NSDate = NSDate(timeIntervalSinceNow: 0)
    var author:String = ""
    var audio:NSURL?
    var image:UIImage?
    var text:String = ""
    
    override init() {
        
    }
    init(title:String, date:NSDate, author:String, audio:NSURL?, image:UIImage?, text:String) {
        // perform some initialization here
        self.title = title
        self.date = date
        self.author = author
        self.audio = audio
        self.image = image
        self.text = text
    }
}