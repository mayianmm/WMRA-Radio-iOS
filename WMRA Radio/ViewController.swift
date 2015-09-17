//
//  ViewController.swift
//  WMRA Radio
//
//  Created by Linzy Cumbia on 12/3/14.
//  Copyright (c) 2014 James Madison University. All rights reserved.
//

import UIKit
import Foundation
import AVFoundation
import MediaPlayer
import QuartzCore

extension CMTime {
    var isValid:Bool { return (flags & .Valid) != nil }
}

enum Stations: String {
    case WMRA = "http://media.wmra.org/hls/wmra.m3u8"
    case WEMC = "http://media.wmra.org/hls/wemc.m3u8"
}

enum StationMetadata: String {
    case WMRA = "https://api.composer.nprstations.org/v1/widget/53a98b40e1c834ef434eed74/now?format=json"
    case WEMC = "https://api.composer.nprstations.org/v1/widget/53a98b80e1c824cb90c40be6/now?format=json"
}

class ViewController: UIViewController, AVAudioSessionDelegate, UITableViewDelegate, UITableViewDataSource, NSXMLParserDelegate {
    
    var player = AVPlayer()
    var stories: [Story] = []
    var parseStory: Story = Story()
    var currentStream: Stations!
    var shouldResumePlayingStream:Bool = false
    @IBOutlet var playPause: UIButton!
    @IBOutlet var volumeView: MPVolumeView!
    @IBOutlet var storiesTableView: UITableView!
    @IBOutlet var playerBackground: JCRBlurView!
    @IBOutlet var nowPlayingText: UILabel!
    @IBOutlet var showStreamSwitcherButton: UIButton!
    @IBOutlet var streamSwitcherView: UIView!

    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        volumeView.setVolumeThumbImage(UIImage(named: "volumeThumb"), forState: UIControlState.Normal)
        volumeView.setMaximumVolumeSliderImage(UIImage(named: "volumeSliderMax")?.resizableImageWithCapInsets(UIEdgeInsetsMake(0, 2, 0, 2)), forState: UIControlState.Normal)
        volumeView.setMinimumVolumeSliderImage(UIImage(named: "volumeSliderMin")?.resizableImageWithCapInsets(UIEdgeInsetsMake(0, 2, 0, 2)), forState: UIControlState.Normal)
        volumeView.setRouteButtonImage(UIImage(named: "airPlay"), forState: UIControlState.Normal)
        volumeView.setRouteButtonImage(UIImage(named: "airPlayOn"), forState: UIControlState.Selected)
        
        let context = UIGraphicsGetCurrentContext()
        var color = UIColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1.0)
        CGContextSetFillColorWithColor(context, color.CGColor)
        CGContextFillEllipseInRect(context, CGRect(x: 10, y: 11, width: 21, height: 21))
        playerBackground.blurTintColor = UIColor(red: 0.130, green: 0.130, blue: 0.130, alpha: 1)
        
        
        // Do any additional setup after loading the view, typically from a nib.
    }
    
    override func viewDidAppear(animated: Bool) {
        storiesTableView.reloadData()
        
        if shouldResumePlayingStream {
            if let resume:Stations = currentStream {
                player = AVPlayer(URL: NSURL(string: resume.rawValue))
                play()
                player.volume = 0.0
                fadeInVolume()
            } else {
                player = AVPlayer(URL: NSURL(string: Stations.WMRA.rawValue))
            }

        }
        
    }
    
//    override func prefersStatusBarHidden() -> Bool {
//        if (self.traitCollection.horizontalSizeClass == UIUserInterfaceSizeClass.Compact) {
//            return true
//        } else {
//            return false
//        }
//    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if ((sender?.isKindOfClass(storyTableViewCell)) != nil) {
            let row = storiesTableView.indexPathForSelectedRow()?.row
            let destinationVC = segue.destinationViewController as! storyDetailViewController
            destinationVC.story = stories[row!-1]
            storiesTableView.deselectRowAtIndexPath(storiesTableView.indexPathForSelectedRow()!, animated: true)
            if (destinationVC.story.audio != nil) {
                fadeOutVolume()
            }
        }
    }
    
    func fadeInVolume() {
        player.volume = player.volume + 0.01;
        if (player.volume > 0.99) {
            
        } else {
            var dispatchTime: dispatch_time_t = dispatch_time(DISPATCH_TIME_NOW, Int64(0.007 * Double(NSEC_PER_SEC)))
            dispatch_after(dispatchTime, dispatch_get_main_queue(), {
                self.fadeInVolume()
            })
        }
    }
    
    func fadeOutVolume() {
        player.volume = player.volume - 0.01;
        if (player.volume < 0.01) {
            pauseToPlayStory()
        } else {
            var dispatchTime: dispatch_time_t = dispatch_time(DISPATCH_TIME_NOW, Int64(0.007 * Double(NSEC_PER_SEC)))
            dispatch_after(dispatchTime, dispatch_get_main_queue(), {
                self.fadeOutVolume()
            })
        }
    }
    
    @IBAction func shareButtonPressed(sender: AnyObject) {
        var point = sender.superview!!.convertPoint(sender.center, toView: storiesTableView)
        var indexPath = storiesTableView.indexPathForRowAtPoint(point)!
        
        var sharingItems = [AnyObject]()
        sharingItems.append(stories[indexPath.row].title)
        sharingItems.append((storiesTableView.cellForRowAtIndexPath(indexPath) as! storyTableViewCell).storyImageView!.image!)
        sharingItems.append(stories[indexPath.row].url!)
        sharingItems.append("\n From the WMRA News app.")
        
        let activityViewController = UIActivityViewController(activityItems: sharingItems, applicationActivities: nil)
        activityViewController.popoverPresentationController?.sourceView = sender as! UIButton
        activityViewController.popoverPresentationController?.sourceRect = (sender as! UIButton).bounds
        self.presentViewController(activityViewController, animated: true, completion: nil)
    }
    
    func shareTextImageAndURL(sharingText: String?, sharingImage: UIImage?, sharingURL: NSURL?) {
        
    }
    
    func setAudioSession() {
        let session:AVAudioSession = AVAudioSession.sharedInstance()
        var error: NSError?
        if !session.setCategory(AVAudioSessionCategoryPlayback, error:&error) {
            println("could not set session category")
            if let e = error {
                println(e.localizedDescription)
            }
        }
        if !session.setActive(true, error: &error) {
            println("could not make session active")
            if let e = error {
                println(e.localizedDescription)
            }
        }
    }
    
    func play() {
        setAudioSession()
        shouldResumePlayingStream = true
        identifyCurrentStream()
        player.play()
        playPause.setImage(UIImage(named: "play"), forState: UIControlState.Normal)
    }
    
    func pause() {
        shouldResumePlayingStream = false
        player.pause()
        playPause.setImage(UIImage(named: "pause"), forState: UIControlState.Normal)
    }
    
    func pauseToPlayStory() {
        player.pause()
        playPause.setImage(UIImage(named: "pause"), forState: UIControlState.Normal)
    }
    
    func togglePlayPause() {
        if (player.rate == 0) {
            play()
        } else {
            pause()
        }
    }
    
    func identifyCurrentStream() {
        let current = player.currentItem.asset as! AVURLAsset
        if (current.URL.absoluteString == Stations.WMRA.rawValue) {
            currentStream = Stations.WMRA
        } else if (current.URL.absoluteString == Stations.WEMC.rawValue) {
            currentStream = Stations.WEMC
        }
    }
    
    @IBAction func playPauseTapped(sender: UIButton) {
        if (player.status == AVPlayerStatus.ReadyToPlay) {
            togglePlayPause()
        } else {
            player = AVPlayer(URL: NSURL(string: Stations.WMRA.rawValue))
            play()
        }
    }
    
    @IBAction func playWMRA(sender: UIButton) {
        player = AVPlayer(URL: NSURL(string: Stations.WMRA.rawValue))
        play()
        fetchMetadataForStation(StationMetadata.WMRA)
        hideStreamSwitcher()
    }
    
    @IBAction func playWEMC(sender: UIButton) {
        player = AVPlayer(URL: NSURL(string: Stations.WEMC.rawValue))
        play()
        fetchMetadataForStation(StationMetadata.WEMC)
        hideStreamSwitcher()
    }

    @IBAction func showStreamSwitcher(sender: UIButton) {
        streamSwitcherView.hidden = false
        streamSwitcherView.layer.opacity = 0.0
        showStreamSwitcherButton.userInteractionEnabled = false
        UIView.animateWithDuration(0.5, delay: 0, options: .CurveEaseOut, animations: {
            var frame = self.streamSwitcherView.frame
            frame.origin.x += frame.size.width
            self.streamSwitcherView.layer.opacity = 1.0
            self.streamSwitcherView.frame = frame
            }, completion: nil)
    }

    func hideStreamSwitcher() {
        UIView.animateWithDuration(0.5, delay: 0, options: .CurveEaseIn, animations: {
            var frame = self.streamSwitcherView.frame
            frame.origin.x -= frame.size.width
            self.streamSwitcherView.layer.opacity = 0.0
            self.streamSwitcherView.frame = frame
            }, completion: { finished in
                self.showStreamSwitcherButton.userInteractionEnabled = true
                self.streamSwitcherView.hidden = true
        })
    }
    
//    @IBAction func newsTapped(sender: UIButton) {
//        let cell = sender.superview?.superview as! headerTableViewCell
//        cell.menuContainer.hidden = !cell.menuContainer.hidden
//    }
    
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        if (indexPath.row == 0) {
            tableView.deselectRowAtIndexPath(indexPath, animated: true)
            UIApplication.sharedApplication().openURL(NSURL(string: "https://support.wmra.org/Load/wmra.html")!)
        }
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return stories.count + 1
    }
    
    func tableView(tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        return UIView()
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        if (indexPath.row == 0)
        {
            let cell = tableView.dequeueReusableCellWithIdentifier("headerCell") as! headerTableViewCell
            return cell
        } else {
            let cell = tableView.dequeueReusableCellWithIdentifier("storyCell") as! storyTableViewCell
            var story = stories[indexPath.row-1]
            if (story.title.rangeOfString("School Closings") != nil || story.title.rangeOfString("School Delays") != nil)
            {
                cell.storyImageView.image = UIImage(named: "schoolClosings")
            } else {
                cell.storyImageView.sd_setImageWithURL(NSURL(string: story.image!), placeholderImage: UIImage(named: "newsPlaceholder"))
            }
            cell.storyTitle.text = story.title
            cell.storyAuthor.text = story.author
            
            var dateFormatter = NSDateFormatter()
            dateFormatter.dateFormat = "d MMMM yy"
            cell.storyDate.text = dateFormatter.stringFromDate(story.date)
            cell.storyText.text = ""
            for paragraph in story.text {
                cell.storyText.text = cell.storyText.text?.stringByAppendingString("\(paragraph) \n\n")
            }
            return cell
        }
    }
    
    func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        if (indexPath.row == 0) {
            return 136
        } else {
            return UITableViewAutomaticDimension
        }
    }
    
    func tableView(tableView: UITableView, estimatedHeightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        if (indexPath.row == 0) {
            return 136
        } else {
            return 420
        }
    }
    
    func fetchStories() {
        var url = NSURL(string: "http://api.npr.org/query?orgId=518&numResults=50&fields=title,storyDate,byline,text,audio,image&output=JSON&apiKey=MDE0MDk5MjM4MDE0MDA2MzM5NDJiOWU0Nw001")

        if var data = NSData(contentsOfURL: url!) {
            let json = JSON(data: data)
            var storyNumber = 0
            while let story = json["list"]["story"][storyNumber]["id"].stringValue {
                parseStory = Story()
                
                if let storyTitle = json["list"]["story"][storyNumber]["title"]["$text"].stringValue {
                    parseStory.title = storyTitle
                }
                if let storyDate = json["list"]["story"][storyNumber]["storyDate"]["$text"].stringValue {
                    var dateFormatter = NSDateFormatter()
                    dateFormatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss ZZ"
                    var date = dateFormatter.dateFromString(storyDate)
                    parseStory.date = date!
                }
                if let storyAuthor = json["list"]["story"][storyNumber]["byline"][0]["name"]["$text"].stringValue {
                    parseStory.author = storyAuthor
                }
                if var storyAudio = json["list"]["story"][storyNumber]["audio"][0]["format"]["mediastream"]["$text"].stringValue {
                    storyAudio = storyAudio.substringFromIndex(advance(storyAudio.startIndex, 46))
                    storyAudio = storyAudio.substringToIndex(advance(storyAudio.endIndex, -16))
                    parseStory.audio = NSURL(string: storyAudio)
                }
                if var storyURL = json["list"]["story"][storyNumber]["link"][0]["$text"].stringValue {
                    parseStory.url = NSURL(string: storyURL)
                }
                if let storyImage = json["list"]["story"][storyNumber]["image"][0]["src"].stringValue {
                    self.parseStory.image = storyImage
                }
                // Sometimes the first paragraph is blank so we need to test it separately
                if let storyTextFix = json["list"]["story"][storyNumber]["text"]["paragraph"][0]["$text"].stringValue {
                    var removedHTML = storyTextFix.stringByConvertingHTMLToPlainText()
                    parseStory.text.append(removedHTML)
                }
                
                var paragraphNumber = 1
                while let storyText = json["list"]["story"][storyNumber]["text"]["paragraph"][paragraphNumber]["$text"].stringValue {
                    var removedHTML = storyText.stringByConvertingHTMLToPlainText()
                    parseStory.text.append(removedHTML)
                    paragraphNumber++
                }
                if parseStory.text[parseStory.text.count-1].rangeOfString("[Copyright") != nil {
                    let copyright = Range<String.Index>(start: advance(parseStory.text[parseStory.text.count-1].endIndex, -24), end: advance(parseStory.text[parseStory.text.count-1].endIndex, 0))
                    parseStory.text[parseStory.text.count-1].removeRange(copyright)
                }
                stories.append(self.parseStory)
                storyNumber++
            }
        }
    }
    
    func fetchMetadataForStation(station: StationMetadata) {
        var url = NSURL(string: station.rawValue)
        
        if var data = NSData(contentsOfURL: url!) {
            let json = JSON(data: data)
            var startTime:String!
            var endTime:String!
            var nowPlayingMetadata = String()
            
            if let programName = json["onNow"]["program"]["name"].stringValue {
                nowPlayingMetadata = programName
            }
            
            if let programHosts = json["onNow"]["program"]["hosts"][0]["name"].stringValue {
                if (programHosts != "") {
                    nowPlayingMetadata += "\n" + "Hosted by " + programHosts
                }
            }
            
            if let programStartTime = json["onNow"]["start_time"].stringValue {
                var dateFormatter = NSDateFormatter()
                dateFormatter.dateFormat = "HH:mm"
                var date = dateFormatter.dateFromString(programStartTime)
                
                var dateReformatter = NSDateFormatter()
                dateReformatter.dateFormat = "h:mma"
                startTime = dateReformatter.stringFromDate(date!)
            }
            
            if let programEndTime = json["onNow"]["end_time"].stringValue {
                var dateFormatter = NSDateFormatter()
                dateFormatter.dateFormat = "HH:mm"
                var date = dateFormatter.dateFromString(programEndTime)
                
                var dateReformatter = NSDateFormatter()
                dateReformatter.dateFormat = "h:mma"
                endTime = dateReformatter.stringFromDate(date!)
            }
            var programTime = startTime + " - " + endTime;
            nowPlayingMetadata += "\n" + programTime
            nowPlayingText.text = nowPlayingMetadata            
        }
    }
}

class storyTableViewCell: UITableViewCell {
    @IBOutlet var storyImageView: UIImageView!
    @IBOutlet var storyTitle: UILabel!
    @IBOutlet var storyDate: UILabel!
    @IBOutlet var storyAuthor: UILabel!
    @IBOutlet var storyText: UILabel!
}

class headerTableViewCell: UITableViewCell {
    @IBOutlet var newsButton: UIButton!
}

class storyDetailViewController: UIViewController, AVAudioSessionDelegate {
    var story: Story!
    var player:AVPlayer!
    var timer:NSTimer!
    @IBOutlet var storyImageView: UIImageView!
    @IBOutlet var storyTitle: UILabel!
    @IBOutlet var storyDate: UILabel!
    @IBOutlet var storyAuthor: UILabel!
    @IBOutlet var audioScrubber: UISlider!
    @IBOutlet var storyText: UILabel!
    @IBOutlet var scrollView: UIScrollView!
    @IBOutlet var contentView: UIView!
    @IBOutlet var playPause: UIButton!
    @IBOutlet var timeLabel: UILabel!
    
    override func viewDidLoad() {
        storyImageView.sd_setImageWithURL(NSURL(string: story.image!), placeholderImage: UIImage(named: "newsPlaceholder"))
        storyTitle.text = story.title
        storyAuthor.text = story.author
        
        var dateFormatter = NSDateFormatter()
        dateFormatter.dateFormat = "d MMMM yy"
        storyDate.text = dateFormatter.stringFromDate(story.date)
        
        for paragraph in story.text {
            storyText.text = storyText.text?.stringByAppendingString("\(paragraph) \n\n")
        }
        audioScrubber.setMinimumTrackImage(UIImage(named: "minimum")?.stretchableImageWithLeftCapWidth(3, topCapHeight: 0), forState: UIControlState.Normal)
        audioScrubber.setMaximumTrackImage(UIImage(named: "maximum")?.stretchableImageWithLeftCapWidth(3, topCapHeight: 0), forState: UIControlState.Normal)
        audioScrubber.setThumbImage(UIImage(named: "thumb"), forState: UIControlState.Normal)
        player = AVPlayer(URL: story.audio)
        player.addObserver(self, forKeyPath: "status", options: NSKeyValueObservingOptions.New, context: nil)
    }
    
    func setAudioSession() {
        let session:AVAudioSession = AVAudioSession.sharedInstance()
        var error: NSError?
        if !session.setCategory(AVAudioSessionCategoryPlayback, error:&error) {
            println("could not set session category")
            if let e = error {
                println(e.localizedDescription)
            }
        }
        if !session.setActive(true, error: &error) {
            println("could not make session active")
            if let e = error {
                println(e.localizedDescription)
            }
        }
    }
    
    @IBAction func playPauseTapped(sender: AnyObject) {
        if (player.rate == 0) {
            play()
        } else {
            pause()
        }
    }
    
    func play() {
        if (player != nil) {
            setAudioSession()
            player.play()
            playPause.setImage(UIImage(named: "play"), forState: UIControlState.Normal)
        }
    }
    
    func pause() {
        player.pause()
        playPause.setImage(UIImage(named: "pause"), forState: UIControlState.Normal)
    }
    
    func setupPlayerScrubber() {
        var interval = 0.1;
        var playerDuration = playerItemDuration()
        if !playerDuration.isValid {
            return;
        }
        var duration = Double(CMTimeGetSeconds(playerDuration));
        timeLabel.text = formatTime(duration) as String
        if (isfinite(duration)) {
            var width = CGRectGetWidth(audioScrubber.bounds);
            interval = 0.5 * duration / Double(width);
        }

        timer = NSTimer.scheduledTimerWithTimeInterval(1.0, target: self, selector: "syncScrubber", userInfo: nil, repeats: true)
    }
    
    func syncScrubber() {
        var playerDuration = playerItemDuration()
        if !playerDuration.isValid {
            audioScrubber.minimumValue = 0.0;
            return;
        }
    
        var duration = Float(CMTimeGetSeconds(playerDuration));
        if (isfinite(duration) && (duration > 0))
        {
            var minValue = audioScrubber.minimumValue
            var maxValue = audioScrubber.maximumValue
            var time = CMTimeGetSeconds(player.currentTime());
            var value = (maxValue - minValue) * Float(time) / Float(duration) + minValue
            audioScrubber.setValue(value, animated: true)
            var timeRemaining = Double(duration)-Double(time)
            timeLabel.text = formatTime(timeRemaining) as String
        }
    }
    
    func playerItemDuration() -> CMTime {
        if (player != nil) {
            var playerItem = player.currentItem
            if (player.status == AVPlayerStatus.ReadyToPlay) {
                return(playerItem.asset.duration);
            }
        }
        return(kCMTimeInvalid);
    }
    
    @IBAction func beginScrubbing(sender: AnyObject) {
        player.rate = 0.0
        self.removePlayerTimeObserver()
    }
    
    @IBAction func scrub(sender: AnyObject) {
        var slider = sender as! UISlider;
        
        var playerDuration = playerItemDuration()
        if !playerDuration.isValid {
            return;
        }
        
        var duration = Double(CMTimeGetSeconds(playerDuration));
        if (isfinite(duration))
        {
            var minValue = audioScrubber.minimumValue;
            var maxValue = audioScrubber.maximumValue;
            var value = audioScrubber.value
            
            var time = Float(duration) * (value - minValue) / (maxValue - minValue);
            
            player.seekToTime(CMTimeMakeWithSeconds(Float64(time), Int32(NSEC_PER_SEC)))
        }
    }
    
    @IBAction func endScrubbing(sender: AnyObject) {
        if (timer == nil)
        {
            var playerDuration = playerItemDuration()
            if !playerDuration.isValid {
                return;
            }
            
            var duration = Double(CMTimeGetSeconds(playerDuration));
            if (isfinite(duration))
            {
                var width = CGRectGetWidth(self.audioScrubber.bounds);
                var tolerance = 0.5 * duration / Double(width);
                syncScrubber()
                timer = NSTimer.scheduledTimerWithTimeInterval(1.0, target: self, selector: "syncScrubber", userInfo: nil, repeats: true)
            }
        }
        play()
    }
    
    override func observeValueForKeyPath(keyPath: String, ofObject object: AnyObject, change: [NSObject : AnyObject], context: UnsafeMutablePointer<Void>) {
        if (object as! NSObject == player && keyPath == "status") {
            if (player.status == AVPlayerStatus.ReadyToPlay) {
                var dispatchTime: dispatch_time_t = dispatch_time(DISPATCH_TIME_NOW, Int64(1.0 * Double(NSEC_PER_SEC)))
                dispatch_after(dispatchTime, dispatch_get_main_queue(), {
                    self.play()
                    self.setupPlayerScrubber()
                })
            } else if (player.status == AVPlayerStatus.Failed) {
                // something went wrong. player.error should contain some information
            }
        }
    }
    
    func removePlayerTimeObserver()
    {
        if ((timer) != nil)
        {
            timer.invalidate()
            timer = nil
        }
    }
    
    func formatTime(time: Double) -> NSString
    {
        var minutes = floor(time/60)
        var seconds = floor(time - minutes * 60)
        
        return NSString(format: "%.0f:%02.f", minutes, seconds)
    }
    
    override func viewDidLayoutSubviews() {
        self.scrollView.contentSize = self.contentView.frame.size
    }
    
    override func didRotateFromInterfaceOrientation(fromInterfaceOrientation: UIInterfaceOrientation) {
        self.scrollView.contentSize = self.contentView.frame.size
    }
    
    override func prefersStatusBarHidden() -> Bool {
        return true
    }
    
    override func didReceiveMemoryWarning() {
        
    }
    
    @IBAction func closeButtonPressed(sender: AnyObject) {
        removePlayerTimeObserver()
        player.removeObserver(self, forKeyPath: "status")
        self.player = nil
        dismissViewControllerAnimated(true, completion: nil)
    }
    
    @IBAction func shareButtonPressed(sender: AnyObject) {
        var sharingItems = [AnyObject]()
        
        sharingItems.append(story.url!)
        
        let activityViewController = UIActivityViewController(activityItems: sharingItems, applicationActivities: nil)
        activityViewController.popoverPresentationController?.sourceView = sender as! UIButton
        activityViewController.popoverPresentationController?.sourceRect = (sender as! UIButton).bounds
        self.presentViewController(activityViewController, animated: true, completion: nil)
    }
}

class Story : NSObject {
    var title:String = ""
    var date:NSDate = NSDate(timeIntervalSinceNow: 0)
    var author:String = ""
    var audio:NSURL?
    var image:String? = ""
    var url:NSURL?
    var text:[String] = []
    
    override init() {
        
    }
    
    init(title:String, date:NSDate, author:String, audio:NSURL?, url:NSURL?, image:String?, text:[String]) {
        self.title = title
        self.date = date
        self.author = author
        self.audio = audio
        self.image = image
        self.url = url
        self.text = text
    }
}