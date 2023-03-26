#! /bin/bash

avrdude -c usbasp-clone -p t2313 -B 125kHz -U lfuse:w:0x62:m
