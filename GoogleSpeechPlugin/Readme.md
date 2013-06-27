Google speech recognition plugin
--------------------------------

This plugin implements Quartz Composer patch, which records audio uses google voice API to recognised text from audio.


Building
--------

Plugin requires libsprec and libjsonz, which are in submodules.

libsprec requeres libFLAC. Package "flac" from homebrew suits perfectly.

Build all required libraries using provided Makefile. 
