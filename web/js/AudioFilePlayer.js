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
    this.gain.gain.linearRampToValueAtTime(1, this.audioContext.currentTime + 0.01);
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

    this.play = function (filePath, when, duration) {
        let buffer = this.fileMap.get(filePath);
        if (buffer === undefined) {
            return false;
        }

        //  a throwaway source object!  by api design
        //  completed buffer sources will be garbage collected
        let source = this.audioContext.createBufferSource();
        source.buffer = buffer;
        source.connect(this.gain);
        source.start(when);
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
