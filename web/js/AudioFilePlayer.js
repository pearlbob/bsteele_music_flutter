/* 
 * Copyright 2018 Robert Steele at bsteele.com
 */

"use strict";

function AudioFilePlayer() {
    this.fileMap = new Map();

    //  setup audio output
    window.AudioContext = window.AudioContext || window.webkitAudioContext;
    this.audioContext = new window.AudioContext();
    this.mp3Sources = new Array(0);

    this.gain = this.audioContext.createGain();
    this.gain.gain.linearRampToValueAtTime(1, this.audioContext.currentTime + 0.1);
    this.gain.connect(this.audioContext.destination);

    // create Oscillator node to keep the timer running permanently
    this.oscillator = this.audioContext.createOscillator();
    this.oscillator.type = 'sine';
    this.oscillator.frequency.setValueAtTime(20, 0); // value in hertz
    this.oscillator.start();


    this.bufferFile = function (filePath) {
        let buffer = this.fileMap.get(filePath);
        if (buffer === undefined) {
            //  fixme: audio data buffering should likely be on a webworker
            // Async
            let req = new XMLHttpRequest();

            //  cheap javascript trick to retain values
            req.parent = this;
            req.filePath = filePath;
            req.cb = function (buffer) {
                req.parent.fileMap.set(req.filePath, buffer);
            };

            // XHR2
            req.open('GET', filePath, true);
            req.responseType = 'arraybuffer';
            req.onload = function () {
                this.parent.audioContext.decodeAudioData(req.response, req.cb);
            };
            req.send();
            return true;
        }
        return false;
    };

    this.oscillate = function ( frequency, when, duration, volume ){
        let oscillator = this.audioContext.createOscillator();
        oscillator.type = 'sine';
        oscillator.frequency.setValueAtTime(frequency, 0); // value in hertz

        let rampDuration = 0.008;
        let end = when + duration;

        let gainNode = this.audioContext.createGain();
        oscillator.connect(gainNode);
        gainNode.connect(this.audioContext.destination);

        gainNode.gain.setValueAtTime(0, when );
        gainNode.gain.linearRampToValueAtTime(volume, when + rampDuration);

        // Important! Setting a scheduled parameter value
        gainNode.gain.linearRampToValueAtTime(volume, end - rampDuration);
        gainNode.gain.linearRampToValueAtTime(0.001, end);

        oscillator.start(when);
        oscillator.stop(end+0.001 );
        return true;
    }

    this.play = function (filePath, when, duration, volume) {
        let buffer = this.fileMap.get(filePath);
        if (buffer === undefined) {
            return false;
        }

        //  a throwaway source object!  by api design
        //  completed buffer sources will be garbage collected
        let source = this.audioContext.createBufferSource();

        source.buffer = buffer;
        let rampDuration = 0.004;
        let gainNode = this.audioContext.createGain();
        let end = when + duration;
        source.connect(gainNode);
        source.onended = function () {
                    gainNode.disconnect();
                    gainNode = undefined;
                    //  fixme: dispose of source???
                };
        gainNode.connect(this.audioContext.destination);

//        console.log( '@'+this.audioContext.currentTime
//            +': '+filePath +' at '+when+' for '+duration+' to: '+end+' vol: '+volume);

        gainNode.gain.setValueAtTime(volume, when ); //  rely on a smooth recording start

        // Important! Setting a scheduled parameter value
        gainNode.gain.linearRampToValueAtTime(volume, end - rampDuration);
        gainNode.gain.linearRampToValueAtTime(0.005, end);

        source.start(when, 0, duration);
        source.stop(end+0.005 );

        this.mp3Sources.push(source);
        return true;
    };

    this.stop = function () {
        this.mp3Sources.forEach(function (item) {
            item.stop(0);
        });
        return true;
    };

    this.getCurrentTime = function () {
        return this.audioContext.currentTime;
    };

    this.getBaseLatency = function () {
        return this.audioContext.baseLatency;
    };

    this.getOutputLatency = function () {
        return this.audioContext.outputLatency;
    };

    this.test = function () {
        return this.fileMap.size;
    };

}
