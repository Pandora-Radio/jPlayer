/*
 * jPlayer Plugin for jQuery JavaScript Library
 * http://www.jplayer.org
 *
 * Copyright (c) 2009 - 2014 Happyworm Ltd
 * Licensed under the MIT license.
 * http://opensource.org/licenses/MIT
 *
 * Author: Mark J Panaghiston
 * Date: 29th January 2013
 */

package happyworm.jPlayer {
	import flash.display.Sprite;

	import flash.media.Video;
	import flash.media.SoundTransform;

	import flash.net.NetConnection;
	import flash.net.NetStream;

	import flash.utils.Timer;
	import flash.utils.setTimeout;

	import flash.events.NetStatusEvent;
	import flash.events.SecurityErrorEvent;
	import flash.events.TimerEvent;

	public class JplayerMp4 extends Sprite {
		
		public var myVideo:Video = new Video();
		private var myConnection:NetConnection;
		private var myStream:NetStream;
		
		private var myTransform:SoundTransform = new SoundTransform();

		public var myStatus:JplayerStatus = new JplayerStatus();
		
		private var timeUpdateTimer:Timer = new Timer(250, 0); // Matched to HTML event freq
		private var progressTimer:Timer = new Timer(250, 0); // Matched to HTML event freq
		private var seekingTimer:Timer = new Timer(100, 0); // Internal: How often seeking is checked to see if it is over.

		public function JplayerMp4(volume:Number) {
			myConnection = new NetConnection();
			myConnection.addEventListener(NetStatusEvent.NET_STATUS, netStatusHandler);
			myConnection.addEventListener(SecurityErrorEvent.SECURITY_ERROR, securityErrorHandler);
			myVideo.smoothing = true;
			this.addChild(myVideo);
			
			timeUpdateTimer.addEventListener(TimerEvent.TIMER, timeUpdateHandler);
			progressTimer.addEventListener(TimerEvent.TIMER, progressHandler);
			seekingTimer.addEventListener(TimerEvent.TIMER, seekingHandler);
			
			myStatus.volume = volume;

			this.dispatchEvent(new JplayerEvent(JplayerEvent.DEBUG_MSG, myStatus, "JplayerMp4 initialized: volume = " + volume));
		}
		private function progressUpdates(active:Boolean):void {
			this.dispatchEvent(new JplayerEvent(JplayerEvent.DEBUG_MSG, myStatus, "progressUpdates: Start - active = " + active));
			if(active) {
				progressTimer.start();
			} else {
				progressTimer.stop();
			}
			this.dispatchEvent(new JplayerEvent(JplayerEvent.DEBUG_MSG, myStatus, "progressUpdates: End"));
		}
		private function progressHandler(e:TimerEvent):void {
			this.dispatchEvent(new JplayerEvent(JplayerEvent.DEBUG_MSG, myStatus, "progressHandler: Start - type = " + e.type));
			if(myStatus.isLoading) {
				if(getLoadRatio() == 1) { // Close as can get to a loadComplete event since client.onPlayStatus only works with FMS
					myStatus.loaded();
					progressUpdates(false);
				}
			}
			progressEvent();
			this.dispatchEvent(new JplayerEvent(JplayerEvent.DEBUG_MSG, myStatus, "progressHandler: End"));
		}
		private function progressEvent():void {
			this.dispatchEvent(new JplayerEvent(JplayerEvent.DEBUG_MSG, myStatus, "progressEvent: Start"));
			updateStatusValues();
			this.dispatchEvent(new JplayerEvent(JplayerEvent.JPLAYER_PROGRESS, myStatus));
			this.dispatchEvent(new JplayerEvent(JplayerEvent.DEBUG_MSG, myStatus, "progressEvent: End"));
		}
		private function timeUpdates(active:Boolean):void {
			this.dispatchEvent(new JplayerEvent(JplayerEvent.DEBUG_MSG, myStatus, "timeUpdates: Start - active = " + active));
			if(active) {
				timeUpdateTimer.start();
			} else {
				timeUpdateTimer.stop();
			}
			this.dispatchEvent(new JplayerEvent(JplayerEvent.DEBUG_MSG, myStatus, "timeUpdates: End"));
		}
		private function timeUpdateHandler(e:TimerEvent):void {
			//this.dispatchEvent(new JplayerEvent(JplayerEvent.DEBUG_MSG, myStatus, "timeUpdateHandler: Start - type = " + e.type));
			if(!myStatus.flashIsSeeking){
				setTimeout(timeUpdateEvent, 100);
			}
			//this.dispatchEvent(new JplayerEvent(JplayerEvent.DEBUG_MSG, myStatus, "timeUpdateHandler: End"));
		}
		private function timeUpdateEvent():void {
			//this.dispatchEvent(new JplayerEvent(JplayerEvent.DEBUG_MSG, myStatus, "timeUpdateEvent: Start"));
			updateStatusValues();
			this.dispatchEvent(new JplayerEvent(JplayerEvent.JPLAYER_TIMEUPDATE, myStatus));
			//this.dispatchEvent(new JplayerEvent(JplayerEvent.DEBUG_MSG, myStatus, "timeUpdateEvent: End"));
		}
		private function seeking(active:Boolean):void {
			this.dispatchEvent(new JplayerEvent(JplayerEvent.DEBUG_MSG, myStatus, "seeking: Start - active = " + active));
			if(active) {
				if(!myStatus.isSeeking) {
					seekingEvent();
				}
				seekingTimer.start();
			} else {
				if(myStatus.isSeeking) {
					seekedEvent();
				}
				seekingTimer.stop();
			}
			this.dispatchEvent(new JplayerEvent(JplayerEvent.DEBUG_MSG, myStatus, "seeking: End"));
		}
		private function seekingHandler(e:TimerEvent):void {
			this.dispatchEvent(new JplayerEvent(JplayerEvent.DEBUG_MSG, myStatus, "seekingHandler: Start - type = " + e.type));
			if(getSeekTimeRatio() <= getLoadRatio()) {
				seeking(false);
				if(myStatus.playOnSeek) {
					myStatus.playOnSeek = false; // Capture the flag.
					play(myStatus.pausePosition); // Must pass time or the seek time is never set.
				} else {
					pause(myStatus.pausePosition); // Must pass time or the stream.time is read.
				}
			} else if(myStatus.metaDataReady && myStatus.pausePosition > myStatus.duration) {
				// Illegal seek time
				seeking(false);
				pause(0);
			}
			this.dispatchEvent(new JplayerEvent(JplayerEvent.DEBUG_MSG, myStatus, "seekingHandler: End"));
		}
		private function seekingEvent():void {
			this.dispatchEvent(new JplayerEvent(JplayerEvent.DEBUG_MSG, myStatus, "seekingEvent: Start"));
			myStatus.isSeeking = true;
			updateStatusValues();
			this.dispatchEvent(new JplayerEvent(JplayerEvent.JPLAYER_SEEKING, myStatus));
			this.dispatchEvent(new JplayerEvent(JplayerEvent.DEBUG_MSG, myStatus, "seekingEvent: End"));
		}
		private function seekedEvent():void {
			this.dispatchEvent(new JplayerEvent(JplayerEvent.DEBUG_MSG, myStatus, "seekedEvent: Start"));
			myStatus.isSeeking = false;
			updateStatusValues();
			this.dispatchEvent(new JplayerEvent(JplayerEvent.JPLAYER_SEEKED, myStatus));
			this.dispatchEvent(new JplayerEvent(JplayerEvent.DEBUG_MSG, myStatus, "seekedEvent: End"));
		}
		private function netStatusHandler(e:NetStatusEvent):void {
			var code:String = e.info.code;
			this.dispatchEvent(new JplayerEvent(JplayerEvent.DEBUG_MSG, myStatus, "netStatusHandler: Start - code = " + code + " - level = " + e.info.level));
			switch(code) {
				case "NetConnection.Connect.Success":
					this.dispatchEvent(new JplayerEvent(JplayerEvent.DEBUG_MSG, myStatus, "netStatusHandler: " + code + " begin"));
					connectStream();
					this.dispatchEvent(new JplayerEvent(JplayerEvent.DEBUG_MSG, myStatus, "netStatusHandler: " + code + " end"));
					break;
				case "NetStream.Play.Start":
					// This event code occurs once, when the media is opened. Equiv to loadOpen() in mp3 player.
					this.dispatchEvent(new JplayerEvent(JplayerEvent.DEBUG_MSG, myStatus, "netStatusHandler: " + code + " begin"));

					//If we're not playing from the start, temporarily mute the stream; otherwise, while we seek to the starting position, the audio will come through.
					if(myStatus.pausePosition > 0){
						setTemporaryVolume(0);
					}

					myStatus.loading();
					this.dispatchEvent(new JplayerEvent(JplayerEvent.JPLAYER_LOADSTART, myStatus));
					progressUpdates(true);
					// See onMetaDataHandler() for other condition, since duration is vital.

					this.dispatchEvent(new JplayerEvent(JplayerEvent.DEBUG_MSG, myStatus, "netStatusHandler: " + code + " end"));
					break;
				case "NetStream.Play.Stop":
					this.dispatchEvent(new JplayerEvent(JplayerEvent.DEBUG_MSG, myStatus, "netStatusHandler: " + code + " begin: getDuration() - getCurrentTime() = " + (getDuration() - getCurrentTime())));

					// Check if media is at the end (or close) otherwise this was due to download bandwidth stopping playback. ie., Download is not fast enough.
					if(Math.abs(getDuration() - getCurrentTime()) < 1000) { // Using 1000ms to be extra safe, testing found that for M4A files, playHead(99.9) caused a stuck state due to firing with up to 186ms left to play.
						endedEvent();
					}
					this.dispatchEvent(new JplayerEvent(JplayerEvent.DEBUG_MSG, myStatus, "netStatusHandler: " + code + " end"));
					break;
				case "NetStream.Seek.InvalidTime":
					this.dispatchEvent(new JplayerEvent(JplayerEvent.DEBUG_MSG, myStatus, "netStatusHandler: " + code + " begin"));
					// Used for capturing invalid set times and clicks on the end of the progress bar.
					endedEvent();
					this.dispatchEvent(new JplayerEvent(JplayerEvent.DEBUG_MSG, myStatus, "netStatusHandler: " + code + " end"));
					break;
				case "NetStream.Play.StreamNotFound":
					this.dispatchEvent(new JplayerEvent(JplayerEvent.DEBUG_MSG, myStatus, "netStatusHandler: " + code + " begin"));
					myStatus.error(); // Resets status except the src, and it sets srcError property.
					this.dispatchEvent(new JplayerEvent(JplayerEvent.JPLAYER_ERROR, myStatus));
					this.dispatchEvent(new JplayerEvent(JplayerEvent.DEBUG_MSG, myStatus, "netStatusHandler: " + code + " end"));
					break;
				case "NetStream.SeekStart.Notify":
					this.dispatchEvent(new JplayerEvent(JplayerEvent.DEBUG_MSG, myStatus, "netStatusHandler: " + code + " begin"));
					myStatus.flashIsSeeking = true;
					this.dispatchEvent(new JplayerEvent(JplayerEvent.DEBUG_MSG, myStatus, "netStatusHandler: " + code + " end"));
					break;
				case "NetStream.Seek.Notify":
					// A typical seek call involves 1) pausing the stream, 2) seeking, then 3) waiting for Flash to finish seeking. We're at step 3 now.
					// However, step 3 can be triggered when someone hits pause then seeks around. So, we need to keep track of that case.
					// myStatus.playAfterFlashIsSeeking is the flag that distinguishes this use case.
					this.dispatchEvent(new JplayerEvent(JplayerEvent.DEBUG_MSG, myStatus, "netStatusHandler: " + code + " begin"));
					if(myStatus.playAfterFlashIsSeeking){
						myStatus.playAfterFlashIsSeeking = false; // Unset the flag.
						myStatus.isPlaying = true; // Set immediately before playing. Could affects events.
						timeUpdates(true); // Resume time updates.
						myStream.resume(); // Resume the stream.
						restoreVolume();
						this.dispatchEvent(new JplayerEvent(JplayerEvent.JPLAYER_PLAY, myStatus)); // Note that we're playing the stream again.
					}
					myStatus.flashIsSeeking = false; // Note that Flash is no longer seeking.
					this.dispatchEvent(new JplayerEvent(JplayerEvent.DEBUG_MSG, myStatus, "netStatusHandler: " + code + " end"));
					break;
			}
			// "NetStream.Seek.Notify" event code is not very useful. It occurs after every seek(t) command issued and does not appear to wait for the media to be ready.
			this.dispatchEvent(new JplayerEvent(JplayerEvent.DEBUG_MSG, myStatus, "netStatusHandler: End"));
		}
		private function endedEvent():void {
			this.dispatchEvent(new JplayerEvent(JplayerEvent.DEBUG_MSG, myStatus, "endedEvent: Start"));
			var wasPlaying:Boolean = myStatus.isPlaying;
			myStatus.flashIsSeeking = false;
			// This is (theoretically) causing the double-play and LifeHacker bug.
			// By going back to the beginning when the track has ended, it opens up the possibility for the song to loop.
			// There doesn't seem to be a use case within Pandora for a loop, so this commented out.
			//pause(0);
			timeUpdates(false);
			timeUpdateEvent();
			if(wasPlaying) {
				this.dispatchEvent(new JplayerEvent(JplayerEvent.JPLAYER_ENDED, myStatus));
			}
			this.dispatchEvent(new JplayerEvent(JplayerEvent.DEBUG_MSG, myStatus, "endedEvent: End"));
		}
		private function securityErrorHandler(event:SecurityErrorEvent):void {
			this.dispatchEvent(new JplayerEvent(JplayerEvent.DEBUG_MSG, myStatus, "securityErrorHandler."));
		}
		private function connectStream():void {
			this.dispatchEvent(new JplayerEvent(JplayerEvent.DEBUG_MSG, myStatus, "connectStream: Start"));
			var customClient:Object = new Object();
			customClient.onMetaData = onMetaDataHandler;
			// customClient.onPlayStatus = onPlayStatusHandler; // According to the forums and my tests, onPlayStatus only works with FMS (Flash Media Server).
			myStream = null;
			myStream = new NetStream(myConnection);
			myStream.bufferTime = 5;
			myStream.addEventListener(NetStatusEvent.NET_STATUS, netStatusHandler);
			myStream.client = customClient;
			myVideo.attachNetStream(myStream);
			setVolume(myStatus.volume);
			setTemporaryVolume(0);
			myStream.play(myStatus.src);
			this.dispatchEvent(new JplayerEvent(JplayerEvent.DEBUG_MSG, myStatus, "connectStream: End"));
		}
		public function setFile(src:String):void {
			this.dispatchEvent(new JplayerEvent(JplayerEvent.DEBUG_MSG, myStatus, "setFile: Start - src = " + src));
			this.dispatchEvent(new JplayerEvent(JplayerEvent.DEBUG_MSG, myStatus, "setFile: myStream = " + myStream));
			if(myStream != null) {
				myStream.close();
			}
			myVideo.clear();
			progressUpdates(false);
			timeUpdates(false);

			myStatus.reset();
			myStatus.src = src;
			myStatus.srcSet = true;
			timeUpdateEvent();
			this.dispatchEvent(new JplayerEvent(JplayerEvent.DEBUG_MSG, myStatus, "setFile: End"));
		}
		public function clearFile():void {
			this.dispatchEvent(new JplayerEvent(JplayerEvent.DEBUG_MSG, myStatus, "clearFile: Start"));
			setFile("");
			myStatus.srcSet = false;
			this.dispatchEvent(new JplayerEvent(JplayerEvent.DEBUG_MSG, myStatus, "clearFile: End"));
		}
		public function load():Boolean {
			this.dispatchEvent(new JplayerEvent(JplayerEvent.DEBUG_MSG, myStatus, "load: Start"));
			if(myStatus.loadRequired()) {
				myStatus.startingDownload();
				myConnection.connect(null);
				this.dispatchEvent(new JplayerEvent(JplayerEvent.DEBUG_MSG, myStatus, "load: End"));
				return true;
			} else {
				this.dispatchEvent(new JplayerEvent(JplayerEvent.DEBUG_MSG, myStatus, "load: End"));
				return false;
			}
		}
		public function play(time:Number = NaN):Boolean {
			this.dispatchEvent(new JplayerEvent(JplayerEvent.DEBUG_MSG, myStatus, "play: Start - time = " + time));
			var wasPlaying:Boolean = myStatus.isPlaying;
			
			if(!isNaN(time) && myStatus.srcSet) {
				if(myStatus.isPlaying) {
					myStream.pause();
					myStatus.isPlaying = false;
				}
				myStatus.pausePosition = time;
			}

			if(myStatus.isStartingDownload) {
				myStatus.playOnLoad = true; // Raise flag, captured in onMetaDataHandler()
				this.dispatchEvent(new JplayerEvent(JplayerEvent.DEBUG_MSG, myStatus, "play: End"));
				return true;
			} else if(myStatus.loadRequired()) {
				myStatus.playOnLoad = true; // Raise flag, captured in onMetaDataHandler()
				this.dispatchEvent(new JplayerEvent(JplayerEvent.DEBUG_MSG, myStatus, "play: End"));
				return load();
			} else if((myStatus.isLoading || myStatus.isLoaded) && !myStatus.isPlaying) {
				if(myStatus.metaDataReady && myStatus.pausePosition > myStatus.duration) { // The time is invalid, ie., past the end.
					myStream.pause(); // Since it is playing by default at this point.
					myStatus.pausePosition = 0;
					myStream.seek(0);
					timeUpdates(false);
					timeUpdateEvent();
					if(wasPlaying) { // For when playing and then get a play(huge)
						this.dispatchEvent(new JplayerEvent(JplayerEvent.JPLAYER_PAUSE, myStatus));
					}
				} else if(getSeekTimeRatio() > getLoadRatio()) { // Use an estimate based on the downloaded amount
					// This case, we're trying to play past where we're loaded. We need to wait for loading to catch up.
					myStatus.playOnSeek = true;
					seeking(true);
					// Normally we would pause the stream at this point, since the player is playing at this point.
					// But that can do bizarre things with AAC files.
					// For now, turn off the volume.
					setTemporaryVolume(0);
				} else {
					// We're at place where we're ready to play the stream, or seek to the play point.
					if(!isNaN(time)) { // Avoid using seek() when it is already correct.
						// We're ready to seek to the pause point and play it.
						// Again, calling this prematurely can do bizarre things with AAC files. So it's wrapped in a timeout.
						setTemporaryVolume(0);
						setTimeout(seekToPausePositionAndPlay, 500); // Try seeking in 500ms. (Calling it immediately may cause failures.)
					}else{
						// We're ready to play from wherever we're at. Resume.
						myStatus.isPlaying = true; // Set immediately before playing. Could affects events.
						timeUpdates(true);
						myStream.resume();
						restoreVolume();
						if(!wasPlaying) {
							this.dispatchEvent(new JplayerEvent(JplayerEvent.JPLAYER_PLAY, myStatus));
						}
					}
				}
				this.dispatchEvent(new JplayerEvent(JplayerEvent.DEBUG_MSG, myStatus, "play: End"));
				return true;
			} else {
				this.dispatchEvent(new JplayerEvent(JplayerEvent.DEBUG_MSG, myStatus, "play: End"));
				return false;
			}
		}

		public function seekToPausePositionAndPlay():void {
			this.dispatchEvent(new JplayerEvent(JplayerEvent.DEBUG_MSG, myStatus, "seekToPausePositionAndPlay: Start"));
			setTemporaryVolume(0);
			myStatus.playAfterFlashIsSeeking = true; // Note that once flash is done seeking, we should resume/play the stream.
			myStream.seek(myStatus.pausePosition/1000); // Seek to the pause position.
			this.dispatchEvent(new JplayerEvent(JplayerEvent.DEBUG_MSG, myStatus, "seekToPausePositionAndPlay: End"));
		}

		public function pause(time:Number = NaN):Boolean {
			this.dispatchEvent(new JplayerEvent(JplayerEvent.DEBUG_MSG, myStatus, "pause: Start - time = " + time));
			myStatus.playOnLoad = false; // Reset flag in case load/play issued immediately before this command, ie., before onMetadata() event.
			myStatus.playOnSeek = false; // Reset flag in case play(time) issued before the command and is still seeking to time set.

			var wasPlaying:Boolean = myStatus.isPlaying;
			var flashWasSeeking:Boolean = myStatus.flashIsSeeking;

			// To avoid possible loops with timeupdate and pause(time). A pause() does not have the problem.
			var alreadyPausedAtTime:Boolean = false;
			if(!isNaN(time) && myStatus.pausePosition == time) {
				alreadyPausedAtTime = true;
			}

			// Need to wait for metadata to load before ever issuing a pause. The metadata handler will call this function if needed, when ready.
			if(myStream != null && myStatus.metaDataReady) { // myStream is a null until the 1st media is loaded. ie., The 1st ever setMedia being followed by a pause() or pause(t).

				myStream.pause();
			}
			if(myStatus.isPlaying) {
				myStatus.isPlaying = false;
				myStatus.pausePosition = myStream.time * 1000;
			}
			if(myStatus.flashIsSeeking){
				myStatus.isPlaying = false;
				myStatus.playAfterFlashIsSeeking = false;
			}
			if(!isNaN(time) && myStatus.srcSet) {
				myStatus.pausePosition = time;
			}

			if(wasPlaying || flashWasSeeking) {
				this.dispatchEvent(new JplayerEvent(JplayerEvent.JPLAYER_PAUSE, myStatus));
			}

			if(myStatus.isStartingDownload) {
				this.dispatchEvent(new JplayerEvent(JplayerEvent.DEBUG_MSG, myStatus, "pause: End"));
				return true;
			} else if(myStatus.loadRequired()) {
				if(time > 0) { // We do not want the stop() command, which does pause(0), causing a load operation.
					this.dispatchEvent(new JplayerEvent(JplayerEvent.DEBUG_MSG, myStatus, "pause: End"));
					return load();
				} else {
					this.dispatchEvent(new JplayerEvent(JplayerEvent.DEBUG_MSG, myStatus, "pause: End"));
					return true; // Technically the pause(0) succeeded. ie., It did nothing, since nothing was required.
				}
			} else if(myStatus.isLoading || myStatus.isLoaded) {
				if(myStatus.metaDataReady && myStatus.pausePosition > myStatus.duration) { // The time is invalid, ie., past the end.
					myStatus.pausePosition = 0;
					seekToPausePositionAndPlay();
					seekedEvent(); // Deals with seeking effect when using setMedia() then pause(huge). NB: There is no preceeding seeking event.
				} else if(!isNaN(time)) {
					if(getSeekTimeRatio() > getLoadRatio()) { // Use an estimate based on the downloaded amount
						seeking(true);
					} else {
						if(myStatus.metaDataReady) { // Otherwise seek(0) will stop the metadata loading.
							seekToPausePositionAndPlay();
						}
					}
				}
				timeUpdates(false);
				// Need to be careful with timeupdate event, otherwise a pause in a timeupdate event can cause a loop.
				// Neither pause() nor pause(time) will cause a timeupdate loop.
				if(wasPlaying || !isNaN(time) && !alreadyPausedAtTime) {
					timeUpdateEvent();
				}
				this.dispatchEvent(new JplayerEvent(JplayerEvent.DEBUG_MSG, myStatus, "pause: End"));
				return true;
			} else {
				this.dispatchEvent(new JplayerEvent(JplayerEvent.DEBUG_MSG, myStatus, "pause: End"));
				return false;
			}
		}
		public function playHead(percent:Number):Boolean {
			this.dispatchEvent(new JplayerEvent(JplayerEvent.DEBUG_MSG, myStatus, "playHead: Start - percent = " + percent));
			var time:Number = percent * getDuration() * getLoadRatio() / 100;
			if(myStatus.isPlaying || myStatus.playOnLoad || myStatus.playOnSeek) {
				this.dispatchEvent(new JplayerEvent(JplayerEvent.DEBUG_MSG, myStatus, "playHead: End"));
				return play(time);
			} else {
				this.dispatchEvent(new JplayerEvent(JplayerEvent.DEBUG_MSG, myStatus, "playHead: End"));
				return pause(time);
			}
		}
		public function setVolume(v:Number):void {
			myStatus.volume = v;
			myTransform.volume = v;
			if(myStream != null) {
				myStream.soundTransform = myTransform;
			}
		}
		private function setTemporaryVolume(v:Number):void {
			myTransform.volume = v;
			if(myStream != null) {
				myStream.soundTransform = myTransform;
			}
		}
		private function restoreVolume():void {
			setVolume(myStatus.volume);
		}
		
		private function updateStatusValues():void {
			myStatus.seekPercent = 100 * getLoadRatio();
			myStatus.currentTime = getCurrentTime();
			myStatus.currentPercentRelative = 100 * getCurrentRatioRel();
			myStatus.currentPercentAbsolute = 100 * getCurrentRatioAbs();
			myStatus.duration = getDuration();
		}
		public function getLoadRatio():Number {
			if((myStatus.isLoading || myStatus.isLoaded) && myStream.bytesTotal > 0) {
				return myStream.bytesLoaded / myStream.bytesTotal;
			} else if (myStatus.isLoaded && myStream.bytesLoaded > 0) {
				return 1;
			} else {
				return 0;
			}
		}
		public function getDuration():Number {
			return myStatus.duration; // Set from meta data.
		}
		public function getCurrentTime():Number {
			if(myStatus.isPlaying && !myStatus.flashIsSeeking) {
				return myStream.time * 1000;
			} else {
				return myStatus.pausePosition;
			}
		}
		public function getCurrentRatioRel():Number {
			if((getLoadRatio() > 0) && (getCurrentRatioAbs() <= getLoadRatio())) {
				return getCurrentRatioAbs() / getLoadRatio();
			} else {
				return 0;
			}
		}
		public function getCurrentRatioAbs():Number {
			if(getDuration() > 0) {
				return getCurrentTime() / getDuration();
			} else {
				return 0;
			}
		}
		public function getSeekTimeRatio():Number {
			if(getDuration() > 0) {
				return myStatus.pausePosition / getDuration();
			} else {
				return 1;
			}
		}
		public function onMetaDataHandler(info:Object):void { // Used in connectStream() in myStream.client object.
			this.dispatchEvent(new JplayerEvent(JplayerEvent.DEBUG_MSG, myStatus, "onMetaDataHandler: Start - " + info.duration + " | " + info.width + "x" + info.height));
			// This event occurs when jumping to the start of static files! ie., seek(0) will cause this event to occur.
			if(!myStatus.metaDataReady) {
				myStatus.metaDataReady = true; // Set flag so that this event only effects jPlayer the 1st time.
				myStatus.metaData = info;
				myStatus.duration = info.duration * 1000; // Only available via Meta Data.
				if(info.width != undefined) {
					myVideo.width = myStatus.videoWidth = info.width;
				}
				if(info.height != undefined) {
					myVideo.height = myStatus.videoHeight = info.height;
				}

				if(myStatus.playOnLoad) {
					myStatus.playOnLoad = false; // Capture the flag
					if(myStatus.pausePosition > 0 ) { // Important for setMedia followed by play(time).
						play(myStatus.pausePosition);
					} else {
						play(); // Not always sending pausePosition avoids the extra seek(0) for a normal play() command.
					}
				} else {
					// pause() is wrapped in a timeout due to a bug where triggering pause() or seek() on a NetStream
					// object too soon after instantiation causing a loss of audio.
					setTimeout(function():void {
						pause(myStatus.pausePosition);
					}, 10); // Always send the pausePosition. Important for setMedia() followed by pause(time). Deals with not reading stream.time with setMedia() and play() immediately followed by stop() or pause(0)
				}
				this.dispatchEvent(new JplayerEvent(JplayerEvent.JPLAYER_LOADEDMETADATA, myStatus));
			} else {
				this.dispatchEvent(new JplayerEvent(JplayerEvent.DEBUG_MSG, myStatus, "onMetaDataHandler: Already read (NO EFFECT)"));
			}
			this.dispatchEvent(new JplayerEvent(JplayerEvent.DEBUG_MSG, myStatus, "onMetaDataHandler: End"));
		}
	}
}
